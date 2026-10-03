module ram #(
    parameter R = 256,                  // number of rows
    parameter C = 256,                  // number of columns
    parameter N = 8,                  // bits per word
    parameter AR_W = $clog2(R),       // bits needed for row address
    parameter AC_W = $clog2(C)        // bits needed for col address
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

    reg [N-1:0] mem [0:(R*C)-1];  //Memory Array

    wire [$clog2(R*C)-1:0] flat_addr;  //a wire hat will hold the single flat index number into the mem array
    assign flat_addr = (ar * C) + ac;  //row/column to flat index conversion formula — the "address decoding"

    always @(posedge clk) begin
        if (reset) begin
            Qa    <= {N{1'b0}};
            valid <= 1'b0;
        end else begin
            valid <= 1'b0;             // Default condition: no new valid data unless a read happens this cycle

            if (req) begin
                if (rw) begin
                    Qa    <= mem[flat_addr];
                    valid <= 1'b1;
                end else begin
                    mem[flat_addr] <= Qi;
                end
            end
        end
    end
endmodule