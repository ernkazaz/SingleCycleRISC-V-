module Extend(
    input wire [31:7]  Instr,
    input wire [2:0]   ImmSrc,   // Expanded to 3 bits to fit all 5 formats
    output wire [31:0] ImmExt
);
   
    reg [31:0] ImmExtReg;
   
    always @(*) begin
        case(ImmSrc)
            // I-type (Loads, immediate arithmetic like ADDI)
            3'b000: ImmExtReg = {{20{Instr[31]}}, Instr[31:20]};
            
            // S-type (Stores)
            3'b001: ImmExtReg = {{20{Instr[31]}}, Instr[31:25], Instr[11:7]};
            
            // B-type (Branches)
            3'b010: ImmExtReg = {{20{Instr[31]}}, Instr[7], Instr[30:25], Instr[11:8], 1'b0};
            
            // J-type (JAL)
            3'b011: ImmExtReg = {{12{Instr[31]}}, Instr[19:12], Instr[20], Instr[30:21], 1'b0};
            
            // U-type (LUI, AUIPC)
            // The 20-bit immediate is shifted left by 12 bits, lower bits filled with 0
            3'b100: ImmExtReg = {Instr[31:12], 12'b0};
            
            default: ImmExtReg = 32'bx; // undefined
        endcase
    end
   
    assign ImmExt = ImmExtReg;

endmodule