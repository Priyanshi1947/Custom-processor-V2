`timescale 1ns / 1ps
// tiny_processor.v -- 2-stage pipelined version with data memory
// Stage 1 (IF): PC -> instruction_memory -> if_ex_reg
// Stage 2 (EX): if_ex_reg -> decoder -> regfile -> ALU -> accumulator
// New: data_memory connected for LOAD/STORE instructions

module tiny_processor (
    input        clk,
    input        reset,
    input  [3:0] start_address,
    output [7:0] acc_out,
    output [3:0] pc,
    output [7:0] ir_out,
    output       alu_enable_out,
    output       reg_write_out,
    output [7:0] alu_opcode_out,
    output [7:0] instruction_out,
    output [7:0] result_out,
    output [7:0] ext_out,
    output [7:0] reg_data_out,
    output       cb_out,
    output [7:0] mem_data_out,  // new: expose data memory read for testbench
    output [31:0] cycle_count_out, // performance counter: total cycles
    output [31:0] instr_count_out, // performance counter: instructions retired
    output [31:0] branch_count_out // performance counter: branches taken
);

    // ── Accumulator ───────────────────────────────────────
    reg [7:0] acc = 8'b0;

    // ── Performance counters ──────────────────────────────
    reg [31:0] cycle_count  = 32'b0;
    reg [31:0] instr_count  = 32'b0;
    reg [31:0] branch_count = 32'b0;

    // ── Branch / return state ─────────────────────────────
    reg [3:0] return_address;
    reg [3:0] branch_addr;

    // ── Control signals ───────────────────────────────────
    wire alu_enable, reg_write, branch_enable, halt;
    wire mem_read, mem_write;
    wire [7:0] alu_opcode;

    // ── Datapath wires ────────────────────────────────────
    wire [7:0] if_instruction;
    wire [7:0] ex_instruction;
    wire [3:0] ex_pc;
    wire [7:0] result;
    wire [7:0] ext;
    wire [7:0] reg_data;
    wire       cb;
    wire [7:0] dmem_data;      // data memory read output

    wire flush = branch_enable;

    // ════════════════════════════════════════════════════
    // STAGE 1 -- IF
    // ════════════════════════════════════════════════════

    program_counter PC (
        .clk           (clk),
        .reset         (reset),
        .start_address (start_address),
        .branch_enable (branch_enable),
        .halt          (halt),
        .branch_address(branch_addr),
        .pc            (pc)
    );

    instruction_memory IM (
        .addr (pc),
        .data (if_instruction)
    );

    if_ex_reg PIPE (
        .clk            (clk),
        .reset          (reset),
        .flush          (flush),
        .halt           (halt),
        .if_instruction (if_instruction),
        .if_pc          (pc),
        .ex_instruction (ex_instruction),
        .ex_pc          (ex_pc)
    );

    // ════════════════════════════════════════════════════
    // STAGE 2 -- EX
    // ════════════════════════════════════════════════════

    instruction_decoder ID (
        .opcode       (ex_instruction),
        .alu_enable   (alu_enable),
        .reg_write    (reg_write),
        .branch_enable(branch_enable),
        .halt         (halt),
        .mem_read     (mem_read),
        .mem_write    (mem_write),
        .alu_opcode   (alu_opcode)
    );

    register_file RF (
        .clk     (clk),
        .en      (reg_write | mem_read),  // write on MOV or LOAD
        .addr    (ex_instruction[3:0]),
        .data_in (mem_read ? dmem_data : acc),  // LOAD writes mem, else ACC
        .data_out(reg_data)
    );

    ALU ALU_inst (
        .operandA(acc),
        .operandB(reg_data),
        .opcode  (alu_opcode),
        .result  (result),
        .CB      (cb),
        .EXT     (ext)
    );

    // Data memory
    data_memory DMEM (
        .clk     (clk),
        .we      (mem_write),
        .addr    (ex_instruction[3:0]),
        .data_in (acc),          // STORE writes ACC to memory
        .data_out(dmem_data)
    );

    // ── Return address logic ──────────────────────────────
    always @(posedge clk or posedge reset) begin
        if (reset)
            return_address <= 4'b0;
        else if (branch_enable && (ex_instruction[7:4] != 4'b1011))
            return_address <= ex_pc + 4'b0001;
    end

    // ── Branch address mux ────────────────────────────────
    always @(*) begin
        if (branch_enable) begin
            if (ex_instruction[7:4] == 4'b1011)
                branch_addr = return_address;
            else
                branch_addr = ex_instruction[3:0];
        end else begin
            branch_addr = 4'b0000;
        end
    end

    // ── Performance counter logic ─────────────────────────
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cycle_count  <= 32'b0;
            instr_count  <= 32'b0;
            branch_count <= 32'b0;
        end else if (!halt) begin
            // count every active cycle
            cycle_count <= cycle_count + 1;
            // count every instruction that completes in EX
            // (ex_instruction != NOP means real work is done)
            if (ex_instruction != 8'b0)
                instr_count <= instr_count + 1;
            // count every branch taken
            if (branch_enable)
                branch_count <= branch_count + 1;
        end
    end

    // ── Accumulator write ─────────────────────────────────
    always @(posedge clk or posedge reset) begin
        if (reset)
            acc <= 8'b0;
        else if (mem_read)
            acc <= dmem_data;    // LOAD: ACC = mem[addr]
        else if (alu_enable && (ex_instruction[7:4] == 4'b1001))
            acc <= reg_data;     // MOV ACC, Ri
        else if (alu_enable)
            acc <= result;       // arithmetic/logic
    end

    // ── Output assignments ────────────────────────────────
    assign acc_out        = acc;
    assign ir_out         = ex_instruction;
    assign alu_enable_out = alu_enable;
    assign reg_write_out  = reg_write;
    assign alu_opcode_out = alu_opcode;
    assign instruction_out= if_instruction;
    assign result_out     = result;
    assign ext_out        = ext;
    assign reg_data_out   = reg_data;
    assign cb_out         = cb;
    assign mem_data_out   = dmem_data;
    assign cycle_count_out  = cycle_count;
    assign instr_count_out  = instr_count;
    assign branch_count_out = branch_count;

endmodule