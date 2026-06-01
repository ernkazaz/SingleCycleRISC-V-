module ALU_Decoder(
    input  wire [1:0] ALUOp,
    input  wire [2:0] funct3,
    input  wire       funct7_5,  // Instruction bit 30
    input  wire       op_5,      // Instruction bit 5 (1 for R-type, 0 for I-type)
    output reg  [3:0] ALUControl
);

    always @(*) begin
        case(ALUOp)
            // Memory (LW/SW) and AUIPC only require addition
            2'b00: ALUControl = 4'b0000; 
            
            // Branches require subtraction to check equality/comparisons
            2'b01: ALUControl = 4'b0001; 
            
            // LUI requires the ALU to just pass the B input (Immediate) through
            2'b11: ALUControl = 4'b1010; 
            
            // R-type and I-type ALU instructions
            2'b10: begin                 
                case(funct3)
                    // ADD / SUB
                    3'b000: begin
                        // Only subtract if it is an R-type instruction AND funct7_5 is 1
                        if (funct7_5 & op_5) ALUControl = 4'b0001; // SUB
                        else                 ALUControl = 4'b0000; // ADD / ADDI
                    end
                    
                    3'b010: ALUControl = 4'b0101; // SLT / SLTI
                    3'b011: ALUControl = 4'b0110; // SLTU / SLTIU
                    3'b100: ALUControl = 4'b0100; // XOR / XORI
                    3'b110: ALUControl = 4'b0011; // OR / ORI
                    3'b111: ALUControl = 4'b0010; // AND / ANDI
                    
                    3'b001: ALUControl = 4'b0111; // SLL / SLLI
                    
                    // SRL / SRA
                    3'b101: begin
                        // funct7_5 differentiates Logical vs Arithmetic shift
                        if (funct7_5) ALUControl = 4'b1001; // SRA / SRAI
                        else          ALUControl = 4'b1000; // SRL / SRLI
                    end
                    
                    default: ALUControl = 4'bxxxx; // Undefined
                endcase
            end
            
            default: ALUControl = 4'bxxxx; // Undefined
        endcase
    end
endmodule