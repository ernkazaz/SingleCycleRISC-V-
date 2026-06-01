module ALU(
    input  wire [31:0] A, B,
    input  wire [3:0]  ALUControl,
    output wire        Zero,
    output wire        Negative,   // ADD: Result[31]
    output wire        Carry,      // ADD: unsigned overflow
    output wire        Overflow,   // ADD: signed overflow
    output wire [31:0] Result 
);
    reg [31:0] ResultReg;

    // Extend to 33 bits to capture carry out
    wire [32:0] Sum;
    wire [31:0] temp = ALUControl[0] ? ~B : B;
    assign Sum = {1'b0, A} + {1'b0, temp} + {32'b0, ALUControl[0]};

    always @(*) begin
        case(ALUControl)
            4'b0000: ResultReg = Sum[31:0];  // ADD
            4'b0001: ResultReg = Sum[31:0];  // SUB
            4'b0010: ResultReg = A & B;
            4'b0011: ResultReg = A | B;
            4'b0100: ResultReg = A ^ B;
            4'b0101: ResultReg = ($signed(A) < $signed(B)) ? 32'b1 : 32'b0;
            4'b0110: ResultReg = (A < B) ? 32'b1 : 32'b0;
            4'b0111: ResultReg = A << B[4:0];
            4'b1000: ResultReg = A >> B[4:0];
            4'b1001: ResultReg = $signed(A) >>> B[4:0];
            4'b1010: ResultReg = B;
            default: ResultReg = 32'b0;     // safe default for synthesis
        endcase
    end

    assign Result   = ResultReg;
    assign Zero     = (ResultReg == 32'b0);
    assign Negative = ResultReg[31];
    assign Carry    = Sum[32];                         // only meaningful for ADD/SUB
    assign Overflow = (~(A[31] ^ temp[31])) & (A[31] ^ Sum[31]);
endmodule