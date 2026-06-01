module Memory #(
    parameter DEPTH     = 256,
    parameter ADDR_WIDTH = 32
)(
    input  wire        clk,
    input  wire        WE,
    input  wire [2:0]  funct3,           // added: controls access width
    input  wire [ADDR_WIDTH-1:0] ADDR,
    input  wire [31:0] WD,
    output reg  [31:0] RD                // changed to reg for always block
);
    reg [7:0] mem [0:DEPTH-1];

    // ── Combinational read with sign/zero extension ──────────────────
    wire [7:0]  byte_rd  = mem[ADDR];
    wire [15:0] half_rd  = {mem[ADDR+1], mem[ADDR]};  // little-endian

    always @(*) begin
        case (funct3)
            3'b000: RD = {{24{byte_rd[7]}},  byte_rd};        // LB  - sign-extend byte
            3'b001: RD = {{16{half_rd[15]}}, half_rd};        // LH  - sign-extend halfword
            3'b010: RD = {mem[ADDR+3], mem[ADDR+2],
                          mem[ADDR+1], mem[ADDR]};             // LW
            3'b100: RD = {24'b0, byte_rd};                    // LBU - zero-extend byte
            3'b101: RD = {16'b0, half_rd};                    // LHU - zero-extend halfword
            default: RD = 32'bx;
        endcase
    end

    // ── Synchronous write with byte enables ──────────────────────────
    always @(posedge clk) begin
        if (WE) begin
            case (funct3)
                3'b000: begin                                  // SB - 1 byte
                    mem[ADDR] <= WD[7:0];
                end
                3'b001: begin                                  // SH - 2 bytes
                    mem[ADDR]   <= WD[7:0];
                    mem[ADDR+1] <= WD[15:8];
                end
                3'b010: begin                                  // SW - 4 bytes
                    mem[ADDR]   <= WD[7:0];
                    mem[ADDR+1] <= WD[15:8];
                    mem[ADDR+2] <= WD[23:16];
                    mem[ADDR+3] <= WD[31:24];
                end
                default: ; // no write for unrecognised funct3
            endcase
        end
    end
endmodule
