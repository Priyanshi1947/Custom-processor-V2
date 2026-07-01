`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 

// Design Name: 
// Module Name: program_counter
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

`timescale 1ns / 1ps
// program_counter.v
// Fixed: reset always clears to 0, start_address loaded on first cycle
// Eliminates set/reset priority ambiguity warning

module program_counter (
    input        clk,
    input        reset,
    input  [3:0] start_address,
    input        branch_enable,
    input        halt,
    input  [3:0] branch_address,
    output reg [3:0] pc
);
    reg first_cycle;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc         <= 4'b0000;  // pure reset to 0
            first_cycle <= 1'b1;
        end else if (first_cycle) begin
            pc          <= start_address; // load start address on first active cycle
            first_cycle <= 1'b0;
        end else if (halt) begin
            pc <= pc;
        end else if (branch_enable) begin
            pc <= branch_address;
        end else begin
            pc <= pc + 4'b0001;
        end
    end

endmodule
