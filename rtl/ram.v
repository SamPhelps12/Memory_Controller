// -----------------------------------------------------------------------------
// Module      : ram
// Description : Parameterized single-port RAM.
//               - R rows, C columns, N bits per word (default R=4, C=4, N=2).
//               - Synchronous write.
//               - Synchronous (registered) read: data appears on Qa exactly
//                 one clock cycle after a read request, with 'valid' pulsed
//                 high for that same cycle.
//               - Address decoding (ar, ac -> flat index) is purely
//                 combinational; only the read DATA path is registered.
// -----------------------------------------------------------------------------

module ram #(
    parameter R = 4,                  // number of rows
    parameter C = 4,                  // number of columns
    parameter N = 2,                  // bits per word
    parameter AR_W = $clog2(R),       // bits needed for row address, derived
    parameter AC_W = $clog2(C)        // bits needed for col address, derived
) (
    input  wire                 clk,
    input  wire                 reset,
    input  wire                 req,       // request strobe (>=1 cycle)
    input  wire                 rw,        // 1 = read, 0 = write
    input  wire [AR_W-1:0]      ar,        // row address
    input  wire [AC_W-1:0]      ac,        // column address
    input  wire [N-1:0]         Qi,        // write data
    output reg  [N-1:0]         Qa,        // read data (registered)
    output reg                  valid      // pulses 1 cycle when Qa is fresh
);

    // Flattened memory array: R*C words, each N bits wide.
    // Indexed as (ar * C) + ac.
    reg [N-1:0] mem [0:(R*C)-1];

    // Combinational flat index -- address decode has zero latency.
    wire [$clog2(R*C)-1:0] flat_addr;
    assign flat_addr = (ar * C) + ac;

    always @(posedge clk) begin
        if (reset) begin
            Qa    <= {N{1'b0}};
            valid <= 1'b0;
            // Memory contents are intentionally left undisturbed by reset --
            // reset only clears the output-side registers (Qa, valid).
        end else begin
            // Default: no new valid data unless a read happens this cycle.
            valid <= 1'b0;

            if (req) begin
                if (rw) begin
                    // ---- Read path: registered output ----
                    Qa    <= mem[flat_addr];
                    valid <= 1'b1;
                end else begin
                    // ---- Write path: synchronous write ----
                    mem[flat_addr] <= Qi;
                end
            end
        end
    end

endmodule
