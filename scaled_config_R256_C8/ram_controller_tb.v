module ram_controller_tb;

    localparam R = 256;
    localparam C = 256;
    localparam N = 8;
    localparam AR_W   = 8;
    localparam AC_W   = 8;
    localparam ADDR_W = AR_W + AC_W;

    reg                clk;
    reg                reset;
    reg                ce;
    reg                req;
    reg                rw;
    reg  [ADDR_W-1:0]  addr;
    reg  [N-1:0]       Qi;
    wire               ready;
    wire [N-1:0]       Qa_out;

    integer errors;

    // ---------------- DUT instantiation ----------------
    ram_controller #(
        .R(R), .C(C), .N(N)
    ) dut (
        .clk    (clk),
        .reset  (reset),
        .ce     (ce),
        .req    (req),
        .rw     (rw),
        .addr   (addr),
        .Qi     (Qi),
        .ready  (ready),
        .Qa_out (Qa_out)
    );

    // ---------------- Clock: 100MHz -> 10ns period ----------------
    initial clk = 0;
    always #5 clk = ~clk;

    // ---------------- Helper task: issue one op, check 3-cycle latency + data ----------------
    task automatic do_op(
        input                 rw_val,
        input [ADDR_W-1:0]    a,
        input [N-1:0]         wdata,
        input [N-1:0]         expected_rdata,
        input                 check_rdata,
        input [8*24:1]        label
    );
        integer cycles;
        begin
            @(negedge clk);
            req = 1; rw = rw_val; addr = a; Qi = wdata;
            cycles = 0;
            @(negedge clk);
            req = 0;
            cycles = cycles + 1;
            while (ready !== 1'b1) begin
                @(negedge clk);
                cycles = cycles + 1;
            end

            if (cycles !== 3) begin
                $display("ERROR: %0s latency mismatch, expected 3 cycles, got %0d", label, cycles);
                errors = errors + 1;
            end else begin
                $display("PASS : %0s latency = %0d cycles as expected", label, cycles);
            end

            if (check_rdata) begin
                if (Qa_out !== expected_rdata) begin
                    $display("ERROR: %0s expected Qa_out=%0d, got %0d", label, expected_rdata, Qa_out);
                    errors = errors + 1;
                end else begin
                    $display("PASS : %0s Qa_out=%0d as expected", label, Qa_out);
                end
            end
            @(negedge clk);  // let DONE->IDLE transition settle before next op
        end
    endtask

    // ---------------- Stimulus ----------------
    initial begin
        errors = 0;
        reset = 1; ce = 1; req = 0; rw = 0; addr = 0; Qi = 0;

        @(negedge clk);
        @(negedge clk);
        reset = 0;

        // ---- 1. Idle behavior ----
        repeat (3) @(negedge clk);
        if (ready !== 1'b0) begin
            $display("ERROR: expected ready=0 while idle, got ready=%b", ready);
            errors = errors + 1;
        end else begin
            $display("PASS : ready stays 0 while idle");
        end

        // ---- 5. ce gating: req=1 but ce=0 must NOT start a transaction ----
        ce = 0;
        @(negedge clk);
        req = 1; rw = 0; addr = 4'd5; Qi = 2'd2;
        repeat (5) @(negedge clk);   // hold for 5 cycles, well beyond 3-cycle latency
        if (ready !== 1'b0) begin
            $display("ERROR: ce=0 should block the transaction, but ready went high");
            errors = errors + 1;
        end else begin
            $display("PASS : ce=0 correctly blocks the transaction (ready stayed 0)");
        end
        req = 0;
        @(negedge clk);
        ce = 1;
        @(negedge clk);

        // ---- 2, 3, 6. Single write + read-back at several addresses, checking 3-cycle latency each time ----
        do_op(1'b0, 4'd0,  2'd1, 2'd0, 1'b0, "write addr0=1 ");
        do_op(1'b1, 4'd0,  2'd0, 2'd1, 1'b1, "read  addr0   ");

        do_op(1'b0, 4'd15, 2'd2, 2'd0, 1'b0, "write addr15=2");
        do_op(1'b1, 4'd15, 2'd0, 2'd2, 1'b1, "read  addr15  ");

        do_op(1'b0, 4'd9,  2'd3, 2'd0, 1'b0, "write addr9=3 ");
        do_op(1'b1, 4'd9,  2'd0, 2'd3, 1'b1, "read  addr9   ");

        // ---- 4. Multiple sequential transactions with idle gaps in between ----
        repeat (4) @(negedge clk);   // idle gap
        do_op(1'b0, 4'd6,  2'd1, 2'd0, 1'b0, "write addr6=1 ");
        repeat (2) @(negedge clk);   // idle gap
        do_op(1'b1, 4'd6,  2'd0, 2'd1, 1'b1, "read  addr6   ");
        repeat (3) @(negedge clk);   // idle gap

        // overwrite addr0 with a new value, confirm it updates correctly
        do_op(1'b0, 4'd0,  2'd3, 2'd0, 1'b0, "overwrite addr0=3");
        do_op(1'b1, 4'd0,  2'd0, 2'd3, 1'b1, "read  addr0 again");

        // ---- Summary ----
        @(negedge clk);
        if (errors == 0)
            $display("\n=== ALL TESTS PASSED ===");
        else
            $display("\n=== %0d TEST(S) FAILED ===", errors);

        $finish;
    end

endmodule

