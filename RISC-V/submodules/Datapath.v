`timescale 1ns / 1ps

module Datapath(
    input clk, rst,
    input RegWrite, ALUSrc, MemWrite,
    input [1:0] PCSrc, ResultSrc,
    input [2:0] ImmSrc,
    input [3:0] ALUControl,
    input [4:0] Debug_Source_select, 
    output Zero, Negative, Carry, Overflow,
    output [31:0] PC, Instr, Debug_out
    );
    
    wire [31:0] PCNext, PCPlus4, PCTarget, RD1, RD2, ImmExt, SrcB, ALUResult, ReadData, Result;
    
    Mux_4to1 #(.WIDTH(32)) PCSrc_Mux (
        .select(PCSrc),
        .input_0(PCPlus4),
        .input_1(PCTarget),
        .input_2(ALUResult),
        .output_value(PCNext)
    );
    
    Register_rsten #(.WIDTH(32)) PC_reg (
        .clk(clk),
        .reset(rst),
        .we(1'b1),
        .DATA(PCNext),
        .OUT(PC)
    );
    
    
    Adder #(.WIDTH(32)) PCPlus4_adder (
        .DATA_A(PC),
        .DATA_B(32'd4),
        .OUT(PCPlus4)
    );
    
    
    Instruction_memory #(.BYTE_SIZE(4), .ADDR_WIDTH(32)) Instr_mem (
        .ADDR(PC),
        .RD(Instr)
    );
    
    Register_file #(.WIDTH(32)) Reg_file (
        .clk(clk),
        .write_enable(RegWrite),
        .reset(rst),
        .Source_select_0(Instr[19:15]),
        .Source_select_1(Instr[24:20]),
        .Debug_Source_select(Debug_Source_select),
        .Destination_select(Instr[11:7]),
        .DATA(Result),
        .out_0(RD1),
        .out_1(RD2),
        .Debug_out(Debug_out)
     );
    
    Extend Extender(
        .Instr(Instr[31:7]),
        .ImmSrc(ImmSrc),
        .ImmExt(ImmExt)
    );
    
    Adder #(.WIDTH(32)) PCTarget_adder (
        .DATA_A(PC),
        .DATA_B(ImmExt),
        .OUT(PCTarget)
    );
    
    Mux_2to1 #(.WIDTH(32)) SrcB_Mux (
        .select(ALUSrc),
        .input_0(RD2),
        .input_1(ImmExt),
        .output_value(SrcB)
    );
    
    ALU Alu_inst(
        .A(RD1),
        .B(SrcB),
        .ALUControl(ALUControl),
        .Zero(Zero),
        .Negative(Negative),
        .Carry(Carry),
        .Overflow(Overflow),
        .Result(ALUResult)
    );
    
    Memory #(.DEPTH(256), .ADDR_WIDTH(32)) Data_mem (
        .clk(clk),
        .WE(MemWrite),
        .funct3(Instr[14:12]),
        .ADDR(ALUResult),
        .WD(RD2),
        .RD(ReadData)
    );
    
    Mux_4to1 #(.WIDTH(32)) Result_Mux (
        .select(ResultSrc),
        .input_0(ALUResult),
        .input_1(ReadData),
        .input_2(PCPlus4),
        .input_3(PCTarget),
        .output_value(Result)
    );
    
endmodule
