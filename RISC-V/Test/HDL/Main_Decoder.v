module Main_Decoder(
    input  wire [6:0] op,
    output wire       RegWrite,
    output wire [2:0] ImmSrc,
    output wire       ALUSrc,
    output wire       MemWrite,
    output wire [1:0] ResultSrc,
    output wire       Branch,
    output wire [1:0] ALUOp,
    output wire [1:0] Jump    // Expanded to 2 bits to differentiate JAL and JALR
);

    reg [12:0] control_signals; // Expanded to 13 bits to fit the new Jump signal
   
    always @(*) begin
        case(op)
            // Format: RegWrite_ImmSrc_ALUSrc_MemWrite_ResultSrc_Branch_ALUOp_Jump(2 bits)

            7'b0110011: control_signals = 13'b1_000_0_0_00_0_10_00; // R-type
            7'b0010011: control_signals = 13'b1_000_1_0_00_0_10_00; // I-type ALU
            7'b0000011: control_signals = 13'b1_000_1_0_01_0_00_00; // lw (I-type Load)
            7'b0100011: control_signals = 13'b0_001_1_1_00_0_00_00; // sw (S-type Store)
            7'b1100011: control_signals = 13'b0_010_0_0_00_1_01_00; // B-type (Branch)
            
            // Jump = 01 for JAL, 10 for JALR
            7'b1101111: control_signals = 13'b1_011_0_0_10_0_00_01; // jal (J-type)
            7'b1100111: control_signals = 13'b1_000_1_0_10_0_00_10; // jalr (I-type)
            
            // U-type Instructions
            7'b0110111: control_signals = 13'b1_100_1_0_00_0_11_00; // lui
            7'b0010111: control_signals = 13'b1_100_0_0_11_0_00_00; // auipc

            default:    control_signals = 13'b0_000_0_0_00_0_00_00; // Default/Reset
        endcase
    end

    // Unpack the control signals to the outputs
    assign {RegWrite, ImmSrc, ALUSrc, MemWrite, ResultSrc, Branch, ALUOp, Jump} = control_signals;    
   
endmodule