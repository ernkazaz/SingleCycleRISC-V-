`timescale 1ns / 1ps

// Project_top - Nexys A7 top-level module for the RISC-V Single-Cycle Computer
//
// Board connections:
//   CLK100MHZ  → system clock (used for processor and MSSD)
//   BTND       → synchronous reset  (debounced)
//   SW[4:0]    → register file debug port select
//   7-seg      → upper byte shows PC[7:0], lower 3 bytes show debug register
//   ACL_*      → on-board ADXL362 SPI accelerometer pins

module Project_top (
    //////////// Clock //////////
    input  wire        CLK100MHZ,
    //////////// Buttons //////////
    input  wire        BTNU,
    input  wire        BTNL,
    input  wire        BTNC,
    input  wire        BTNR,
    input  wire        BTND,
    //////////// Switches //////////
    input  wire [15:0] SW,
    //////////// LEDs //////////
    output wire [15:0] LED,
    //////////// 7-Segment display //////////
    output wire [7:0]  AN,
    output wire        CA, CB, CC, CD, CE, CF, CG, DP,
    //////////// SPI Accelerometer (ADXL362) //////////
    input  wire        ACL_MISO,
    output wire        ACL_SCLK,
    output wire        ACL_MOSI,
    output wire        ACL_CSN
);

    // Debounced buttons
    wire [4:0] buttons;
    debouncer debouncer_0 (
        .clk     (CLK100MHZ),
        .buttons ({BTNU, BTNL, BTNC, BTNR, BTND}),
        .out     (buttons)
    );
    // buttons[4]=BTNU  buttons[3]=BTNL  buttons[2]=BTNC
    // buttons[1]=BTNR  buttons[0]=BTND  ← reset

    wire rst = buttons[0];   // BTND = reset

    // Debug wires
    wire [31:0] debug_reg_out;
    wire [31:0] PC;

    // Mirror switches to LEDs (handy for seeing debug select)
    assign LED = SW;

    // 7-Segment display
    // Upper 8 bits  = PC[7:0]   (leftmost two digits)
    // Lower 24 bits = debug register [23:0]
    MSSD mssd_0 (
        .clk     (CLK100MHZ),
        .value   ({PC[7:0], debug_reg_out[23:0]}),
        .dpValue (8'b01000000),
        .display ({CG, CF, CE, CD, CC, CB, CA}),
        .DP      (DP),
        .AN      (AN)
    );

    // RISC-V Single-Cycle Computer
    Single_Cycle_Computer my_computer (
        .clk              (CLK100MHZ),
        .rst              (rst),
        .debug_reg_select (SW[4:0]),   // 5 bits → x0..x31
        .debug_reg_out    (debug_reg_out),
        .PC               (PC),
        .ACL_MISO         (ACL_MISO),
        .ACL_SCLK         (ACL_SCLK),
        .ACL_MOSI         (ACL_MOSI),
        .ACL_CSN          (ACL_CSN)
    );

endmodule