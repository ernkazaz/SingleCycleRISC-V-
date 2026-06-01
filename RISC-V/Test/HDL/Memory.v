`timescale 1ns / 1ps

module Memory #(
    parameter DEPTH     = 256,
    parameter ADDR_WIDTH = 32
)(
    input  wire        clk,
    input  wire        WE,
    input  wire [2:0]  funct3,           // controls access width
    input  wire [ADDR_WIDTH-1:0] ADDR,
    input  wire [31:0] WD,
    output reg  [31:0] RD                // changed to reg for always block
);
    reg [7:0] mem [0:DEPTH-1];

    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = 8'h00;
        end
    end

    // ── Combinational read with sign/zero extension ──────────────────
    // Sınır taşmalarını engellemek için adresleri güvenli maskeliyoruz
    wire [ADDR_WIDTH-1:0] addr0 = ADDR & (DEPTH - 1);
    wire [ADDR_WIDTH-1:0] addr1 = (ADDR + 1) & (DEPTH - 1);
    wire [ADDR_WIDTH-1:0] addr2 = (ADDR + 2) & (DEPTH - 1);
    wire [ADDR_WIDTH-1:0] addr3 = (ADDR + 3) & (DEPTH - 1);

    wire [7:0]  byte_rd  = mem[addr0];
    wire [15:0] half_rd  = {mem[addr1], mem[addr0]};  // little-endian

    always @(*) begin
        case (funct3)
            3'b000: RD = {{24{byte_rd[7]}},  byte_rd};        // LB  - sign-extend byte
            3'b001: RD = {{16{half_rd[15]}}, half_rd};        // LH  - sign-extend halfword
            3'b010: RD = {mem[addr3], mem[addr2], mem[addr1], mem[addr0]}; // LW
            3'b100: RD = {24'b0, byte_rd};                    // LBU - zero-extend byte
            3'b101: RD = {16'b0, half_rd};                    // LHU - zero-extend halfword
            default: RD = 32'b0;
        endcase
    end

    // ── Synchronous write with byte enables ──────────────────────────
    always @(posedge clk) begin
        if (WE) begin
            case (funct3)
                3'b000: begin                                  // SB - 1 byte
                    mem[addr0] <= WD[7:0];
                end
                3'b001: begin                                  // SH - 2 bytes
                    mem[addr0]   <= WD[7:0];
                    mem[addr1] <= WD[15:8];
                end
                3'b010: begin                                  // SW - 4 bytes
                    mem[addr0]   <= WD[7:0];
                    mem[addr1] <= WD[15:8];
                    mem[addr2] <= WD[23:16];
                    mem[addr3] <= WD[31:24];
                end
                default: ; 
            endcase
        end
    end
endmodule