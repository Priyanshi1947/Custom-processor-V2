`timescale 1ns / 1ps
// data_memory.v
// 16-byte synchronous data RAM
// Harvard-style: separate from instruction_memory
// Write: synchronous (posedge clk, we=1)
// Read: asynchronous (combinational)

module data_memory (
    input        clk,
    input        we,
    input  [3:0] addr,
    input  [7:0] data_in,
    output [7:0] data_out
);
    reg [7:0] mem [0:15];

    initial begin
        mem[0]  = 8'hA1;
        mem[1]  = 8'hB2;
        mem[2]  = 8'hC3;
        mem[3]  = 8'hD4;
        mem[4]  = 8'hE5;
        mem[5]  = 8'hF6;
        mem[6]  = 8'h11;
        mem[7]  = 8'h22;
        mem[8]  = 8'h33;
        mem[9]  = 8'h44;
        mem[10] = 8'h55;
        mem[11] = 8'h66;
        mem[12] = 8'h77;
        mem[13] = 8'h88;
        mem[14] = 8'h99;
        mem[15] = 8'hAA;
    end

    always @(posedge clk) begin
        if (we)
            mem[addr] <= data_in;
    end

    assign data_out = mem[addr];

endmodule