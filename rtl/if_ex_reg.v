`timescale 1ns / 1ps
// IF/EX Pipeline Register
// Holds the fetched instruction and PC between the two pipeline stages.
// On reset OR flush (branch taken), clears to NOP (8'b0).

module if_ex_reg (
    input        clk,
    input        reset,
    input        flush,       // 1 = branch was taken, kill the fetched instruction
    input        halt,
    input  [7:0] if_instruction,  // instruction coming out of instruction_memory
    input  [3:0] if_pc,           // PC that fetched this instruction
    output reg [7:0] ex_instruction,  // instruction entering the EX stage
    output reg [3:0] ex_pc
);
    always @(posedge clk or posedge reset) begin
        if (reset || flush) begin
            ex_instruction <= 8'b00000000; // NOP — not a real instruction
            ex_pc          <= 4'b0000;
        end else if (!halt) begin
            ex_instruction <= if_instruction;
            ex_pc          <= if_pc;
        end
    end
endmodule