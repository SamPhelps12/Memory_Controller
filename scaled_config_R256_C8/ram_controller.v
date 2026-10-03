module ram_controller #(
    parameter R = 256,
    parameter C = 256,
    parameter N = 8,
    parameter AR_W   = $clog2(R),
    parameter AC_W   = $clog2(C),
    parameter ADDR_W = AR_W + AC_W        // flat external address width
) (
    input  wire               clk,
    input  wire                reset,
    input  wire                ce,        // chip enable
    input  wire                req,       // request strobe from outside world
    input  wire                rw,        // 1 = read, 0 = write
    input  wire [ADDR_W-1:0]   addr,      // flat address from outside world
    input  wire [N-1:0]        Qi,        // write data from outside world

    output wire                ready,     // pulses 1 cycle when op completes
    output wire [N-1:0]        Qa_out     // read data, valid only when ready=1
);

    localparam IDLE     = 2'b00;
    localparam DECODE   = 2'b01;
    localparam WAIT_RAM = 2'b10;
    localparam DONE     = 2'b11;

    reg [1:0] state, next_state;
    reg [ADDR_W-1:0] addr_reg;
    reg [N-1:0]      qi_reg;

    always @(posedge clk) begin
        if (state == DECODE) begin
            addr_reg <= addr;
            qi_reg   <= Qi;
        end
    end

    // Signals to/from the RAM sub-module
    wire [AR_W-1:0] ar;
    wire [AC_W-1:0] ac;
    wire [N-1:0]    Qi_ram;
    wire            req_ram;
    wire [N-1:0]    Qa;
    wire            valid;

    // Address decode
    assign ar = addr[ADDR_W-1:AC_W];
    assign ac = addr[AC_W-1:0];
    assign Qi_ram  = Qi;
    assign req_ram = (state == DECODE);   // 1-cycle pulse to the RAM

    // State register 
    always @(posedge clk) begin
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next-state logic 
    always @(*) begin
        case (state)
            IDLE:     next_state = (req && ce) ? DECODE : IDLE;
            DECODE:   next_state = WAIT_RAM;
            WAIT_RAM: next_state = DONE;
            DONE:     next_state = IDLE;
            default:  next_state = IDLE;
        endcase
    end

    // Output logic Moore-style outputs: ready and Qa_out depend only on the current state.
    
    assign ready  = (state == DONE);
    assign Qa_out = (state == DONE) ? Qa : {N{1'b0}};

    // RAM instantiation
    ram #(
        .R(R), .C(C), .N(N)
    ) u_ram (
        .clk    (clk),
        .reset  (reset),
        .req    (req_ram),
        .rw     (rw),
        .ar     (ar),
        .ac     (ac),
        .Qi     (Qi_ram),
        .Qa     (Qa),
        .valid  (valid)
    );

endmodule

