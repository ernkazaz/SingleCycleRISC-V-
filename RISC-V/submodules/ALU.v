module ALU(
    input  wire [31:0] A, B,
    input  wire [3:0]  ALUControl,
    output wire        Zero,
    output wire [31:0] Result 
);

    reg [31:0] ResultReg;
    wire [31:0] Sum;

    // ALUControl[0] handles ADD (0) vs SUB (1)
    wire [31:0] temp = ALUControl[0] ? ~B : B;
    assign Sum = A + temp + {31'b0, ALUControl[0]}; 

    always @(*) begin
        case(ALUControl)
            4'b0000: ResultReg = Sum;       // ADD
            4'b0001: ResultReg = Sum;       // SUB
            4'b0010: ResultReg = A & B;     // AND
            4'b0011: ResultReg = A | B;     // OR
            4'b0100: ResultReg = A ^ B;     // XOR
            
            // SLT (Signed Less Than) - Native Verilog casting
            4'b0101: ResultReg = ($signed(A) < $signed(B)) ? 32'b1 : 32'b0; 
            
            // SLTU (Unsigned Less Than)
            4'b0110: ResultReg = (A < B) ? 32'b1 : 32'b0;
            
            // SLL (Shift Left Logical) - RV32I only shifts by lower 5 bits
            4'b0111: ResultReg = A << B[4:0];
            
            // SRL (Shift Right Logical)
            4'b1000: ResultReg = A >> B[4:0];
            
            // SRA (Shift Right Arithmetic) - Native Verilog casting
            4'b1001: ResultReg = $signed(A) >>> B[4:0];
            
            // PASS B (Useful for LUI, passing the extended immediate directly)
            4'b1010: ResultReg = B;
            
            default: ResultReg = 32'bx;
        endcase
    end

    assign Zero = (ResultReg == 32'b0);
    assign Result = ResultReg;

endmodule