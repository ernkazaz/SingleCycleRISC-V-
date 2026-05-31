module PC_Logic(
    input      Branch,
    input      Zero, Negative, Carry, Overflow,
    input [2:0] funct3,
    input [1:0] Jump,
    output reg [1:0] PCSrc
);
    reg BranchTaken;
    always @(*) begin
        case(funct3)
            3'b000: BranchTaken = Zero;                    // BEQ
            3'b001: BranchTaken = ~Zero;                   // BNE
            3'b100: BranchTaken = Negative ^ Overflow;     // BLT
            3'b101: BranchTaken = ~(Negative ^ Overflow);  // BGE
            3'b110: BranchTaken = ~Carry;                  // BLTU
            3'b111: BranchTaken = Carry;                   // BGEU
            default: BranchTaken = 1'b0;
        endcase
    end

    always @(*) begin
        if      (Jump == 2'b01)           PCSrc = 2'b01; // JAL  → PCTarget
        else if (Jump == 2'b10)           PCSrc = 2'b10; // JALR → ALUResult
        else if (Branch && BranchTaken)   PCSrc = 2'b01; // branch taken → PCTarget
        else                              PCSrc = 2'b00; // PC+4
    end
endmodule