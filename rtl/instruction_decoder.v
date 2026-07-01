`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 20.07.2025 16:57:41
// Design Name: 
// Module Name: instruction_decoder
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



// Decodes 8-bit instruction into control signals
// Updated: added LOAD (1101) and STORE (1110) opcodes

module instruction_decoder (
    input  [7:0] opcode,
    output reg   alu_enable,
    output reg   reg_write,
    output reg   branch_enable,
    output reg   halt,
    output reg   mem_read,    // new: 1 = LOAD instruction
    output reg   mem_write,   // new: 1 = STORE instruction
    output reg [7:0] alu_opcode
);
    always @(*) begin
        alu_enable   = 0;
        reg_write    = 0;
        branch_enable= 0;
        halt         = 0;
        mem_read     = 0;
        mem_write    = 0;
        alu_opcode   = 8'b0;

        casex (opcode)
            8'b0000xxxx: begin alu_enable = 1; alu_opcode = opcode; end
            8'b0001xxxx: begin alu_enable = 1; alu_opcode = opcode; end
            8'b0010xxxx: begin alu_enable = 1; alu_opcode = opcode; end
            8'b0011xxxx: begin alu_enable = 1; alu_opcode = opcode; end
            8'b0101xxxx: begin alu_enable = 1; alu_opcode = opcode; end
            8'b0110xxxx: begin alu_enable = 1; alu_opcode = opcode; end
            8'b1001xxxx: begin alu_enable = 1; alu_opcode = opcode; end // MOV ACC, Ri
            8'b1010xxxx: begin reg_write  = 1; end                      // MOV Ri, ACC
            8'b1011xxxx: begin branch_enable = 1; end                   // RET
            8'b1100xxxx: begin branch_enable = 1; end                   // BRANCH
            8'b1101xxxx: begin mem_read   = 1; end                      // LOAD
            8'b1110xxxx: begin mem_write  = 1; end                      // STORE
            8'b11111111: begin halt       = 1; end                      // HLT
            default:     begin alu_enable = 0; alu_opcode = 8'b0; end
        endcase
    end
endmodule