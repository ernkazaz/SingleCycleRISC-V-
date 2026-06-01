`timescale 1ns / 1ps

// Datapath for Single-Cycle RISC-V Processor

module Datapath(
    input  wire        clk, rst,
    input  wire        RegWrite, ALUSrc, MemWrite,
    input  wire [1:0]  PCSrc, ResultSrc,
    input  wire [2:0]  ImmSrc,
    input  wire [3:0]  ALUControl,
    input  wire [4:0]  Debug_Source_select,
    // SPI pins (connect to Nexys A7 ACL header via top module)
    input  wire        ACL_MISO,
    output wire        ACL_SCLK,
    output wire        ACL_MOSI,
    output wire        ACL_CSN,
    // Status flags
    output wire        Zero, Negative, Carry, Overflow,
    // Observation ports
    output wire [31:0] PC, Instr, Debug_out
);

    wire [31:0] PCNext, PCPlus4, PCTarget;
    wire [31:0] RD1, RD2, ImmExt, SrcB;
    wire [31:0] ALUResult, ReadData, Result;

    // PC logic
    Mux_4to1 #(.WIDTH(32)) PCSrc_Mux (
        .select      (PCSrc),
        .input_0     (PCPlus4),
        .input_1     (PCTarget),
        .input_2     (ALUResult),
        .input_3     (32'b0),        // unused
        .output_value(PCNext)
    );

    Register_rsten #(.WIDTH(32)) PC_reg (
        .clk   (clk),
        .reset (rst),
        .we    (1'b1),
        .DATA  (PCNext),
        .OUT   (PC)
    );

    Adder #(.WIDTH(32)) PCPlus4_adder (
        .DATA_A (PC),
        .DATA_B (32'd4),
        .OUT    (PCPlus4)
    );

    // Instruction memory 
    Instruction_memory #(.BYTE_SIZE(4), .ADDR_WIDTH(32)) Instr_mem (
        .ADDR (PC),
        .RD   (Instr)
    );

    // Register file 
    Register_file #(.WIDTH(32)) Reg_file (
        .clk                 (clk),
        .write_enable        (RegWrite),
        .reset               (rst),
        .Source_select_0     (Instr[19:15]),   // rs1
        .Source_select_1     (Instr[24:20]),   // rs2
        .Debug_Source_select (Debug_Source_select),
        .Destination_select  (Instr[11:7]),    // rd
        .DATA                (Result),
        .out_0               (RD1),
        .out_1               (RD2),
        .Debug_out           (Debug_out)
    );

    // Immediate extension
    Extend Extender (
        .Instr  (Instr[31:7]),
        .ImmSrc (ImmSrc),
        .ImmExt (ImmExt)
    );

    // Branch / jump target
    Adder #(.WIDTH(32)) PCTarget_adder (
        .DATA_A (PC),
        .DATA_B (ImmExt),
        .OUT    (PCTarget)
    );

    // ALU source mux
    Mux_2to1 #(.WIDTH(32)) SrcB_Mux (
        .select       (ALUSrc),
        .input_0      (RD2),
        .input_1      (ImmExt),
        .output_value (SrcB)
    );

    // ALU
    ALU Alu_inst (
        .A          (RD1),
        .B          (SrcB),
        .ALUControl (ALUControl),
        .Zero       (Zero),
        .Negative   (Negative),
        .Carry      (Carry),
        .Overflow   (Overflow),
        .Result     (ALUResult)
    );

    // Memory system (RAM + SPI peripheral)
    MemorySystem #(.DEPTH(256), .ADDR_WIDTH(32)) Mem_sys (
        .clk      (clk),
        .rst      (rst),
        .WE       (MemWrite),
        .funct3   (Instr[14:12]),
        .ADDR     (ALUResult),
        .WD       (RD2),
        .RD       (ReadData),
        .ACL_SCLK (ACL_SCLK),
        .ACL_MOSI (ACL_MOSI),
        .ACL_MISO (ACL_MISO),
        .ACL_CSN  (ACL_CSN)
    );

    // Result mux
    // ResultSrc: 00=ALUResult, 01=ReadData, 10=PCPlus4, 11=PCTarget (AUIPC)
    Mux_4to1 #(.WIDTH(32)) Result_Mux (
        .select       (ResultSrc),
        .input_0      (ALUResult),
        .input_1      (ReadData),
        .input_2      (PCPlus4),
        .input_3      (PCTarget),
        .output_value (Result)
    );

endmodule