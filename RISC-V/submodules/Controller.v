`timescale 1ns / 1ps

module Controller(
    input  wire [31:0] Instr,
    input  wire        Zero, Negative, Carry, Overflow,
    output wire [1:0]  PCSrc,
    output wire [1:0]  ResultSrc,
    output wire        MemWrite,
    output wire        ALUSrc,
    output wire [2:0]  ImmSrc,
    output wire        RegWrite,
    output wire [3:0]  ALUControl
);

    // Internal wires connecting the submodules
    wire [1:0] ALUOp;
    wire       Branch;
    wire [1:0] Jump;

    // Instruction decoding (Slicing the 32-bit bus)
    wire [6:0] op       = Instr[6:0];
    wire [2:0] funct3   = Instr[14:12];
    wire       funct7_5 = Instr[30]; // Used to distinguish ADD/SUB and SRL/SRA
    wire       op_5     = Instr[5];  // Used to distinguish R-type from I-type ALU ops

    // Instantiate the Main Decoder
    Main_Decoder main_dec (
        .op(op),
        .RegWrite(RegWrite),
        .ImmSrc(ImmSrc),
        .ALUSrc(ALUSrc),
        .MemWrite(MemWrite),
        .ResultSrc(ResultSrc),
        .Branch(Branch),
        .ALUOp(ALUOp),
        .Jump(Jump)
    );

    // Instantiate the ALU Decoder
    ALU_Decoder alu_dec (
        .ALUOp(ALUOp),
        .funct3(funct3),
        .funct7_5(funct7_5),
        .op_5(op_5),
        .ALUControl(ALUControl)
    );

    // Instantiate the PC Logic Block
    PC_Logic pc_log (
        .Branch(Branch),
        .Zero(Zero),
        .Negative(Negative),
        .Carry(Carry),
        .Overflow(Overflow),
        .Jump(Jump),
        .PCSrc(PCSrc)
    );

endmodule