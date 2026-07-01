`timescale 1ns / 1ps
// tiny_processor_tb.v -- self-checking + performance counter readout

module tiny_processor_tb;

    reg clk;
    reg reset;

    wire [7:0]  acc_out;
    wire [3:0]  pc;
    wire [7:0]  ir_out;
    wire        alu_enable_out, reg_write_out;
    wire [7:0]  alu_opcode_out;
    wire [7:0]  instruction_out;
    wire [7:0]  result_out;
    wire [7:0]  ext_out;
    wire [7:0]  reg_data_out;
    wire        cb_out;
    wire [7:0]  mem_data_out;
    wire [31:0] cycle_count_out;
    wire [31:0] instr_count_out;
    wire [31:0] branch_count_out;

    integer pass_count;
    integer fail_count;

    tiny_processor uut (
        .clk             (clk),
        .reset           (reset),
        .start_address   (4'b0000),
        .acc_out         (acc_out),
        .pc              (pc),
        .ir_out          (ir_out),
        .alu_enable_out  (alu_enable_out),
        .reg_write_out   (reg_write_out),
        .alu_opcode_out  (alu_opcode_out),
        .instruction_out (instruction_out),
        .result_out      (result_out),
        .ext_out         (ext_out),
        .reg_data_out    (reg_data_out),
        .cb_out          (cb_out),
        .mem_data_out    (mem_data_out),
        .cycle_count_out (cycle_count_out),
        .instr_count_out (instr_count_out),
        .branch_count_out(branch_count_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task check;
        input [63:0]     test_num;
        input [7:0]      expected;
        input [7:0]      actual;
        input [8*32-1:0] label;
        begin
            if (actual === expected) begin
                $display("PASS [Test %0d] %s | expected=%0d got=%0d",
                          test_num, label, expected, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL [Test %0d] %s | expected=%0d got=%0d  <---",
                          test_num, label, expected, actual);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tiny_processor_tb.vcd");
        $dumpvars(0, tiny_processor_tb);

        pass_count = 0;
        fail_count = 0;

        $display("==============================================");
        $display(" Tiny Processor Self-Checking Testbench");
        $display(" Pipeline: 2-stage IF/EX + LOAD/STORE");
        $display("==============================================");

        reset = 1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        reset = 0;

        // cycle 1-5: NOPs, ACC=0
        repeat(5) @(posedge clk); #1;
        check(1, 8'd0, acc_out, "NOP x4: ACC stays 0");

        // cycle 6: MOV ACC,R1 complete, ACC=2
        repeat(2) @(posedge clk); #1;
        check(2, 8'd2, acc_out, "MOV ACC,R1: ACC=2");

        // cycle 7: STORE executing, ACC=2
        repeat(1) @(posedge clk); #1;
        check(3, 8'd2, acc_out, "STORE [15]: ACC still 2");

        // cycle 8: NOP hazard buffer, ACC=2
        repeat(1) @(posedge clk); #1;
        check(4, 8'd2, acc_out, "NOP hazard buffer: ACC still 2");

        // cycle 9: MOV ACC,R3 complete, ACC=4
        repeat(1) @(posedge clk); #1;
        check(5, 8'd4, acc_out, "MOV ACC,R3: ACC=4");

        // cycle 10: LOAD complete, ACC=2
        repeat(1) @(posedge clk); #1;
        check(6, 8'd2, acc_out, "LOAD [15]: ACC=mem[15]=2");

        // cycle 11: ADD R2 complete, ACC=5
        repeat(1) @(posedge clk); #1;
        check(7, 8'd5, acc_out, "ADD R2: ACC=2+3=5");

        // cycle 14: BRANCH+ADD R3 complete, ACC=9
        repeat(3) @(posedge clk); #1;
        check(8, 8'd9, acc_out, "BRANCH+ADD R3: ACC=5+4=9");

        // cycle 15: HLT, ACC=9
        repeat(1) @(posedge clk); #1;
        check(9, 8'd9, acc_out, "STORE [14] done, HLT: ACC=9");

        // cycle 16: ACC still 9
        repeat(1) @(posedge clk); #1;
        check(10, 8'd9, acc_out, "HLT confirmed: ACC stays 9");

        // ?? Performance counter readout ???????????????????
        $display("==============================================");
        $display(" Performance Counters");
        $display("==============================================");
        $display(" Cycles elapsed  : %0d", cycle_count_out);
        $display(" Instructions    : %0d", instr_count_out);
        $display(" Branches taken  : %0d", branch_count_out);
        if (instr_count_out > 0)
            $display(" CPI             : %0d.%02d",
                cycle_count_out / instr_count_out,
                ((cycle_count_out * 100) / instr_count_out) % 100);
        $display("==============================================");

        // ?? Test summary ??????????????????????????????????
        $display(" Results: %0d PASSED, %0d FAILED", pass_count, fail_count);
        if (fail_count == 0)
            $display(" ALL TESTS PASSED - design is correct");
        else
            $display(" FAILURES DETECTED - check above");
        $display("==============================================");

        $finish;
    end

endmodule
