`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 20.07.2025 17:03:36
// Design Name: 
// Module Name: register_file
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

module register_file(
    input clk,
    input en,
    input [3:0] addr,
    input [7:0] data_in,
    output reg [7:0] data_out
);
    reg [7:0] registers [15:0];

    integer i;
    
    
    initial begin
        // Initialize registers with unique non-zero values, e.g., 1, 2, 3, ..., 16
        for (i = 0; i < 16; i = i + 1)
            registers[i] = i + 8'd1;
    end

    always @(*) begin
        data_out = registers[addr];
    end

    always @(posedge clk) begin
        if (en) begin
            registers[addr] <= data_in;
        end
    end
endmodule
