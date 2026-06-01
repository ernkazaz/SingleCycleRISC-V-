`timescale 1ns / 1ps

// Single_Cycle_Computer
// Wires the Controller and Datapath together for the RISC-V processor.
// SPI ACL pins are exposed so the top module can route them to FPGA pins.

module Single_Cycle_Computer (
    input  wire        clk,
    input  wire        rst,
    // Debug / observation
    input  wire [4:0]  debug_reg_select,
    output wire [31:0] debug_reg_out,
    output wire [31:0] PC,
    // SPI (Nexys A7 on-board ADXL362 accelerometer)
    input  wire        ACL_MISO,
    output wire        ACL_SCLK,
    output wire        ACL_MOSI,
    output wire        ACL_CSN
);

    // ── Instruction fields (Datapath → Controller) ───────────────────────
    wire [31:0] Instr;

    // ── ALU flags (Datapath → Controller) ────────────────────────────────
    wire Zero, Negative, Carry, Overflow;

    // ── Control signals (Controller → Datapath) ──────────────────────────
    wire [1:0]  PCSrc;
    wire [1:0]  ResultSrc;
    wire        MemWrite;
    wire        ALUSrc;
    wire [2:0]  ImmSrc;
    wire        RegWrite;
    wire [3:0]  ALUControl;

    // ── Controller ────────────────────────────────────────────────────────
    Controller my_controller (
        .Instr      (Instr),
        .Zero       (Zero),
        .Negative   (Negative),
        .Carry      (Carry),
        .Overflow   (Overflow),
        .PCSrc      (PCSrc),
        .ResultSrc  (ResultSrc),
        .MemWrite   (MemWrite),
        .ALUSrc     (ALUSrc),
        .ImmSrc     (ImmSrc),
        .RegWrite   (RegWrite),
        .ALUControl (ALUControl)
    );

    // ── Datapath ──────────────────────────────────────────────────────────
    Datapath my_datapath (
        .clk                  (clk),
        .rst                  (rst),
        .RegWrite             (RegWrite),
        .ALUSrc               (ALUSrc),
        .MemWrite             (MemWrite),
        .PCSrc                (PCSrc),
        .ResultSrc            (ResultSrc),
        .ImmSrc               (ImmSrc),
        .ALUControl           (ALUControl),
        .Debug_Source_select  (debug_reg_select),
        .ACL_MISO             (ACL_MISO),
        .ACL_SCLK             (ACL_SCLK),
        .ACL_MOSI             (ACL_MOSI),
        .ACL_CSN              (ACL_CSN),
        .Zero                 (Zero),
        .Negative             (Negative),
        .Carry                (Carry),
        .Overflow             (Overflow),
        .PC                   (PC),
        .Instr                (Instr),
        .Debug_out            (debug_reg_out)
    );

endmodule