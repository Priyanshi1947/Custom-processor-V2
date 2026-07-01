`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 20.07.2025 15:20:26
// Design Name: 
// Module Name: ALU
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ALU (
    input [7:0] operandA, 
    input [7:0] operandB,
    input [7:0] opcode,         //operation code
    output reg [7:0] result,
    output reg CB,              //carry_borrow_register
    output reg [7:0] EXT        //extended register to store extra bits
);

    reg [8:0] temp_add_sub; // 9 bits to capture carry/borrow
    reg [15:0] temp_mul;

    always @(*) begin
        // Default values
        result = 8'b0;
        CB = 0;
        EXT = 8'b0;

        casex (opcode)
            8'b0001xxxx: begin // ADD
                temp_add_sub = operandA + operandB;
                result = temp_add_sub[7:0];
                CB = temp_add_sub[8];
            end
            8'b0010xxxx: begin // SUB
                temp_add_sub = {1'b0, operandA} - {1'b0, operandB};
                result = temp_add_sub[7:0];
                CB = temp_add_sub[8]; // Borrow flag: 1 if borrow occurred
            end
            8'b0011xxxx: begin // MUL
                temp_mul = operandA * operandB;
                result = temp_mul[7:0];
                EXT = temp_mul[15:8];
            end
            8'b00000001: result = operandA << 1; // LSL
            8'b00000010: result = operandA >> 1; // LSR
            8'b00000011: result = {operandA[0], operandA[7:1]}; // CIR
            8'b00000100: result = {operandA[6:0], operandA[7]}; // CIL
            8'b00000101: result = {operandA[7], operandA[7:1]}; // ASR
            8'b0101xxxx: result = operandA & operandB; // AND
            8'b0110xxxx: result = operandA ^ operandB; // XOR
            8'b0111xxxx: begin // CMP (compare)
                if (operandA >= operandB)
                    CB = 0;
                else
                    CB = 1;
                result = 8'b0; // No result update
            end
            8'b00000110: begin // INC
                temp_add_sub = operandA + 1;
                result = temp_add_sub[7:0];
                CB = temp_add_sub[8];
            end
            8'b00000111: begin // DEC
                temp_add_sub = {1'b0, operandA} - 1;
                result = temp_add_sub[7:0];
                CB = temp_add_sub[8];
            end
            default: result = operandA; // NOP or unknown opcode
        endcase
    end
endmodule


