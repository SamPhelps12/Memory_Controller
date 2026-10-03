// -----------------------------------------------------------------------------
// Testbench  : ram_tb
// Purpose    : Standalone verification of the `ram` module ONLY.
//              The controller/FSM is NOT involved here -- this testbench
//              drives req/rw/ar/ac/Qi directly, exactly as the controller
//              will eventually do, so any bugs found here are isolated to
//              the RAM itself.
//
// Checks:
//   1. Reset behavior      -> Qa=0, valid=0 after reset
//   2. Write then read-back -> correct data appears exactly 1 cycle after
//                               a read request, with valid pulsed that cycle
//   3. Multiple locations   -> corners of the 4x4 grid, to confirm the
//                               flattening formula (ar*C + ac) indexes
//                               correctly and locations don't collide
//   4. Back-to-back requests -> a read immediately followed by another
//                                request on the very next cycle
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module ram_tb;

    // Parameters matching the locked design (R=4, C=4, N=2)
    localparam R = 4;
    localparam C = 4;
    localparam N = 2;
    localparam AR_W = 2;   // $clog2(4)
    localparam AC_W = 2;   // $clog2(4)

    reg              clk;
    reg              reset;
    reg              req;
    reg              rw;        // 1 = read, 0 = write
    reg  [AR_W-1:0]  ar;
    reg  [AC_W-1:0]  ac;
    reg  [N-1:0]     Qi;
    wire [N-1:0]     Qa;
    wire             valid;

    integer errors;

    // ---------------- DUT instantiation ----------------
    ram #(
        .R(R), .C(C), .N(N)
    ) dut (
        .clk    (clk),
        .reset  (reset),
        .req    (req),
        .rw     (rw),
        .ar     (ar),
        .ac     (ac),
        .Qi     (Qi),
        .Qa     (Qa),
        .valid  (valid)
    );

    // ---------------- Clock generation: 100MHz -> 10ns period ----------------
    initial clk = 0;
    always #5 clk = ~clk;

    // ---------------- Helper tasks ----------------

    // Issue a single-cycle write request
    task do_write(input [AR_W-1:0] a_row, input [AC_W-1:0] a_col, input [N-1:0] data);
        begin
            @(negedge clk);
            req = 1; rw = 0; ar = a_row; ac = a_col; Qi = data;
            @(negedge clk);
            req = 0;
        end
    endtask

    // Issue a single-cycle read request, then check Qa/valid one cycle later
    task do_read_check(input [AR_W-1:0] a_row, input [AC_W-1:0] a_col, input [N-1:0] expected);
        begin
            @(negedge clk);
            req = 1; rw = 1; ar = a_row; ac = a_col;
            @(negedge clk);
            req = 0;
            // Qa/valid are now registered from last cycle's read request
            if (valid !== 1'b1) begin
                $display("ERROR: valid not asserted after read of ar=%0d ac=%0d at time %0t", a_row, a_col, $time);
                errors = errors + 1;
            end
            if (Qa !== expected) begin
                $display("ERROR: ar=%0d ac=%0d expected Qa=%0d, got Qa=%0d at time %0t", a_row, a_col, expected, Qa, $time);
                errors = errors + 1;
            end else begin
                $display("PASS : ar=%0d ac=%0d Qa=%0d as expected at time %0t", a_row, a_col, Qa, $time);
            end
        end
    endtask

    // ---------------- Stimulus ----------------
    initial begin
        errors = 0;
        req = 0; rw = 0; ar = 0; ac = 0; Qi = 0;
        reset = 1;

        // ---- 1. Reset check ----
        @(negedge clk);
        @(negedge clk);
        if (Qa !== 0 || valid !== 0) begin
            $display("ERROR: after reset expected Qa=0 valid=0, got Qa=%0d valid=%0d", Qa, valid);
            errors = errors + 1;
        end else begin
            $display("PASS : reset correctly clears Qa/valid");
        end
        reset = 0;
        @(negedge clk);

        // ---- 2 & 3. Write then read-back, multiple locations (corners) ----
        do_write(2'd0, 2'd0, 2'd1);   // row0,col0 = 1
        do_write(2'd3, 2'd3, 2'd2);   // row3,col3 = 2
        do_write(2'd0, 2'd3, 2'd3);   // row0,col3 = 3
        do_write(2'd3, 2'd0, 2'd0);   // row3,col0 = 0
        do_write(2'd2, 2'd1, 2'd1);   // row2,col1 = 1 (used in earlier flat_addr example)

        do_read_check(2'd0, 2'd0, 2'd1);
        do_read_check(2'd3, 2'd3, 2'd2);
        do_read_check(2'd0, 2'd3, 2'd3);
        do_read_check(2'd3, 2'd0, 2'd0);
        do_read_check(2'd2, 2'd1, 2'd1);

        // ---- 4. Back-to-back requests: read immediately followed by another read ----
        @(negedge clk);
        req = 1; rw = 1; ar = 2'd0; ac = 2'd0;   // read row0,col0 (expect 1)
        @(negedge clk);
        // Immediately issue the next read on the very next cycle, without
        // de-asserting req in between.
        req = 1; rw = 1; ar = 2'd3; ac = 2'd3;   // read row3,col3 (expect 2)
        // Check result of the FIRST read now (1 cycle after its request)
        if (valid !== 1'b1 || Qa !== 2'd1) begin
            $display("ERROR: back-to-back read #1 expected Qa=1 valid=1, got Qa=%0d valid=%0d", Qa, valid);
            errors = errors + 1;
        end else begin
            $display("PASS : back-to-back read #1 Qa=%0d as expected", Qa);
        end
        @(negedge clk);
        req = 0;
        // Check result of the SECOND read now
        if (valid !== 1'b1 || Qa !== 2'd2) begin
            $display("ERROR: back-to-back read #2 expected Qa=2 valid=1, got Qa=%0d valid=%0d", Qa, valid);
            errors = errors + 1;
        end else begin
            $display("PASS : back-to-back read #2 Qa=%0d as expected", Qa);
        end

        // ---- Summary ----
        @(negedge clk);
        if (errors == 0)
            $display("\n=== ALL TESTS PASSED ===");
        else
            $display("\n=== %0d TEST(S) FAILED ===", errors);

        $finish;
    end

endmodule
