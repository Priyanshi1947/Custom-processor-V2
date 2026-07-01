# Custom Processor V2 — Code Reference

> This document provides line-by-line explanation of every Verilog module and the testbench.
> Referenced from the [Technical Report](Custom_Processor_V2_IEEE_Report.html) and [README](../README.md).

---

## Table of Contents

1. [tiny_processor.v — Top Level](#1-tiny_processorv--top-level)
2. [if_ex_reg.v — Pipeline Register](#2-if_ex_regv--pipeline-register)
3. [instruction_decoder.v — Control Signals](#3-instruction_decoderv--control-signals)
4. [ALU.v — Arithmetic Logic Unit](#4-aluv--arithmetic-logic-unit)
5. [register_file.v — Register File](#5-register_filev--register-file)
6. [program_counter.v — Program Counter](#6-program_counterv--program-counter)
7. [data_memory.v — Data Memory](#7-data_memoryv--data-memory)
8. [instruction_memory.v — Instruction ROM](#8-instruction_memoryv--instruction-rom)
9. [tiny_processor_tb.v — Self-Checking Testbench](#9-tiny_processor_tbv--self-checking-testbench)

---

## 1. `tiny_processor.v` — Top Level

This is the top-level module that wires all submodules together and implements the 2-stage pipeline.

### Port Declaration

```verilog
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
    output [7:0] mem_data_out,
    output [31:0] cycle_count_out,
    output [31:0] instr_count_out,
    output [31:0] branch_count_out
);
```

**Why so many outputs?** Most outputs beyond `acc_out` and `pc` exist purely for testbench observability — they let the testbench monitor internal signals without needing hierarchical references. In a production design, these would be behind a debug interface (like JTAG) rather than exposed as top-level ports.

- `start_address` — allows the PC to begin at a non-zero address, useful for placing programs at different memory offsets
- `mem_data_out` — exposes the data memory read port so the testbench can verify LOAD values independently
- `cycle_count_out`, `instr_count_out`, `branch_count_out` — the hardware performance counters, exposed for testbench readout

---

### Internal State Registers

```verilog
    reg [7:0] acc = 8'b0;

    reg [31:0] cycle_count  = 32'b0;
    reg [31:0] instr_count  = 32'b0;
    reg [31:0] branch_count = 32'b0;

    reg [3:0] return_address;
    reg [3:0] branch_addr;
```

**Key design decision — accumulator-based architecture:** `acc` is the only general-purpose computation register visible to the programmer. All ALU results write here. This simplifies the datapath at the cost of requiring explicit MOV instructions to save intermediate values.

**Performance counters are 32-bit** — wide enough to count 4 billion cycles before overflow. At 136 MHz that's ~31 seconds of continuous operation before rollover. For longer programs, extend to 64-bit.

**`return_address`** — saves the PC+1 value before any branch executes. This is how RET knows where to jump back. Only one level of call-return is supported — nested calls would overwrite this register.

---

### Key Wire Declarations

```verilog
    wire flush = branch_enable;
```

**This single line is the branch hazard management mechanism.** `flush` is not a separate signal — it is `branch_enable` renamed for clarity. When the decoder sees a BRANCH or RET instruction in EX, `branch_enable` goes high, which simultaneously:
1. Tells the PC to jump to the target address
2. Tells the IF/EX pipeline register to load NOP, discarding the wrong instruction

No additional logic needed — the wire alias makes the intent self-documenting.

---

### Stage 1 — IF (Instruction Fetch)

```verilog
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
```

**The IF stage is entirely combinational except for the PC and pipeline register.** PC updates on posedge clk, instruction_memory reads combinationally from the new PC, and the result is latched into if_ex_reg on the next posedge. This means `if_instruction` is valid for the entire clock cycle after the PC updates.

**Notice `branch_address` comes from `branch_addr`** — a registered signal updated in the EX stage. The PC reads this mux output combinationally, so the new PC value is ready before the next posedge when the PC will actually update.

---

### Stage 2 — EX (Execute)

```verilog
    register_file RF (
        .clk     (clk),
        .en      (reg_write | mem_read),
        .addr    (ex_instruction[3:0]),
        .data_in (mem_read ? dmem_data : acc),
        .data_out(reg_data)
    );
```

**Two things happen here that are non-obvious:**

1. `en = reg_write | mem_read` — the register file writes on both MOV Rn,ACC (reg_write) and LOAD (mem_read). LOAD writes the memory data into a register, not just the accumulator.

2. `data_in = mem_read ? dmem_data : acc` — a mux selects what gets written. On LOAD, the memory data goes into the register. On MOV Rn,ACC, the accumulator value goes in. This is a 2:1 mux synthesized from a LUT.

```verilog
    data_memory DMEM (
        .clk     (clk),
        .we      (mem_write),
        .addr    (ex_instruction[3:0]),
        .data_in (acc),
        .data_out(dmem_data)
    );
```

**STORE always writes ACC.** The address comes from `ex_instruction[3:0]` — the lower 4 bits of the STORE opcode. So `STORE 15` encodes as `1110_1111`, and bits [3:0] = 1111 = address 15.

---

### Branch Address Logic

```verilog
    always @(posedge clk or posedge reset) begin
        if (reset)
            return_address <= 4'b0;
        else if (branch_enable && (ex_instruction[7:4] != 4'b1011))
            return_address <= ex_pc + 4'b0001;
    end

    always @(*) begin
        if (branch_enable) begin
            if (ex_instruction[7:4] == 4'b1011)
                branch_addr = return_address;   // RET
            else
                branch_addr = ex_instruction[3:0]; // BRANCH
        end else begin
            branch_addr = 4'b0000;
        end
    end
```

**The return address is saved ONLY on non-RET branches.** `4'b1011` is the RET opcode upper nibble. If we saved the return address on RET itself, we'd overwrite the address we're about to jump to — a subtle bug that would cause incorrect behavior on nested calls.

**`branch_addr` is combinational** — it uses the current `ex_instruction` and `return_address` to produce the target PC every cycle. The PC module reads this combinationally on every cycle, but only uses it when `branch_enable` is asserted.

---

### Performance Counter Logic

```verilog
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cycle_count  <= 32'b0;
            instr_count  <= 32'b0;
            branch_count <= 32'b0;
        end else if (!halt) begin
            cycle_count <= cycle_count + 1;
            if (ex_instruction != 8'b0)
                instr_count <= instr_count + 1;
            if (branch_enable)
                branch_count <= branch_count + 1;
        end
    end
```

**Why `ex_instruction != 8'b0` for instruction count?** NOP is encoded as `0x00`. When a branch flushes the pipeline, the IF/EX register is loaded with `8'b0` (NOP). We don't want to count those NOP bubbles as real instructions — only actual program instructions should increment `instr_count`. This gives a meaningful CPI measurement.

**Counters freeze on halt** — `!halt` gates all three counters. This means the CPI measurement reflects only the active execution period, not the idle time after HLT.

---

### Accumulator Write Logic

```verilog
    always @(posedge clk or posedge reset) begin
        if (reset)
            acc <= 8'b0;
        else if (mem_read)
            acc <= dmem_data;
        else if (alu_enable && (ex_instruction[7:4] == 4'b1001))
            acc <= reg_data;
        else if (alu_enable)
            acc <= result;
    end
```

**Priority order matters here:**
1. `mem_read` (LOAD) — highest priority, writes memory data to ACC
2. `alu_enable && opcode[7:4] == 1001` (MOV ACC, Rn) — writes register data to ACC
3. `alu_enable` (all other ALU ops) — writes ALU result to ACC

MOV ACC, Rn needs special handling because it asserts `alu_enable` but the result should come from the register file, not the ALU output. The opcode `1001_rrrr` identifies this case. All other ALU instructions use the ALU `result` output normally.

---

### Output Assignments

```verilog
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
```

**Note the distinction:** `ir_out = ex_instruction` (the instruction currently in EX) while `instruction_out = if_instruction` (the instruction currently being fetched in IF). The testbench monitors `ir_out` to see what's executing and `instruction_out` to see what's being fetched — two different pipeline stages simultaneously.

---

## 2. `if_ex_reg.v` — Pipeline Register

```verilog
module if_ex_reg (
    input        clk,
    input        reset,
    input        flush,
    input        halt,
    input  [7:0] if_instruction,
    input  [3:0] if_pc,
    output reg [7:0] ex_instruction,
    output reg [3:0] ex_pc
);
    always @(posedge clk or posedge reset) begin
        if (reset || flush) begin
            ex_instruction <= 8'b00000000; // NOP
            ex_pc          <= 4'b0000;
        end else if (!halt) begin
            ex_instruction <= if_instruction;
            ex_pc          <= if_pc;
        end
    end
endmodule
```

**This is the simplest module but the most architecturally important.** It is the physical boundary between the two pipeline stages. Everything to the left of it is IF; everything to the right is EX.

**Three operating modes:**
- `reset || flush` → load NOP (0x00). Reset clears on startup; flush discards wrong instruction after branch
- `!halt` → normal operation, latch the fetched instruction and PC
- `halt` → neither condition — the register holds its current value (implicit latch hold via non-blocking with no assignment)

**Why store `ex_pc` as well as `ex_instruction`?** The return address calculation needs to know what PC value fetched the branch instruction: `return_address = ex_pc + 1`. Without storing the PC in the pipeline register, this information would be lost by the time the branch reaches EX.

**`flush` and `reset` are OR'd together** — both produce the same result (NOP). This is intentional: a branch flush is functionally identical to a mini-reset of the pipeline register. They're combined into one condition for clarity.

---

## 3. `instruction_decoder.v` — Control Signals

```verilog
module instruction_decoder (
    input  [7:0] opcode,
    output reg   alu_enable,
    output reg   reg_write,
    output reg   branch_enable,
    output reg   halt,
    output reg   mem_read,
    output reg   mem_write,
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
            8'b1001xxxx: begin alu_enable = 1; alu_opcode = opcode; end
            8'b1010xxxx: begin reg_write  = 1; end
            8'b1011xxxx: begin branch_enable = 1; end
            8'b1100xxxx: begin branch_enable = 1; end
            8'b1101xxxx: begin mem_read   = 1; end
            8'b1110xxxx: begin mem_write  = 1; end
            8'b11111111: begin halt       = 1; end
            default:     begin alu_enable = 0; alu_opcode = 8'b0; end
        endcase
    end
endmodule
```

**Why set all outputs to 0 before the casex?** This prevents latch inference. If a signal is not assigned in all paths through a combinational always block, Verilog infers a latch to hold the previous value. By defaulting everything to 0 first, every path through casex sees an assignment — the synthesizer generates pure combinational logic (LUTs), not latches.

**casex vs case:** `casex` treats x (unknown) and z (high-impedance) bits as don't-care in the pattern. `8'b0001xxxx` matches any opcode with upper 4 bits = 0001, regardless of the lower 4 bits. This is correct here because the lower 4 bits are the register address — not part of the instruction class. Regular `case` would require 16 separate entries for each ADD variant (ADD R0 through ADD R15).

**`alu_opcode = opcode`** — the full 8-bit opcode is passed to the ALU, not just the upper 4 bits. The ALU uses the full opcode for its own casex, including the lower 4 bits to distinguish shift/rotate operations (0000_0001 through 0000_0111) from each other.

**LOAD (1101) only asserts `mem_read`, not `alu_enable`** — the ALU is not used. The accumulator write logic in tiny_processor.v checks `mem_read` first and bypasses the ALU entirely.

**HLT matches `8'b11111111` exactly** — not `8'b1111xxxx`. This is deliberate: `1111_0000` through `1111_1110` are reserved for future instructions. Only the specific all-ones pattern halts.

---

## 4. `ALU.v` — Arithmetic Logic Unit

```verilog
module ALU (
    input [7:0] operandA,
    input [7:0] operandB,
    input [7:0] opcode,
    output reg [7:0] result,
    output reg CB,
    output reg [7:0] EXT
);
    reg [8:0] temp_add_sub;
    reg [15:0] temp_mul;
```

**`temp_add_sub` is 9 bits** — one wider than the 8-bit operands. The 9th bit captures the carry out of ADD or the borrow out of SUB. This is then split: `result = temp[7:0]`, `CB = temp[8]`.

**`temp_mul` is 16 bits** — the product of two 8-bit numbers can be up to 16 bits (255 × 255 = 65025 = 0xFE01). The result is split: `result = temp[7:0]` (low byte stored in ACC), `EXT = temp[15:8]` (high byte stored in EXT register).

---

### Arithmetic Operations

```verilog
            8'b0001xxxx: begin // ADD
                temp_add_sub = operandA + operandB;
                result = temp_add_sub[7:0];
                CB = temp_add_sub[8];
            end
            8'b0010xxxx: begin // SUB
                temp_add_sub = {1'b0, operandA} - {1'b0, operandB};
                result = temp_add_sub[7:0];
                CB = temp_add_sub[8];
            end
```

**Why `{1'b0, operandA}` for SUB?** Zero-extending both operands to 9 bits before subtracting ensures the borrow is captured correctly in bit 8. Without the extension, Verilog would perform 8-bit subtraction and the result would already be truncated before we could capture the borrow.

**CB on SUB = 1 means borrow occurred** (result went negative). This is the same convention as the ARM processor's C flag on subtraction.

---

### Shift and Rotate Operations

```verilog
            8'b00000001: result = operandA << 1;                      // LSL
            8'b00000010: result = operandA >> 1;                      // LSR
            8'b00000011: result = {operandA[0], operandA[7:1]};       // CIR
            8'b00000100: result = {operandA[6:0], operandA[7]};       // CIL
            8'b00000101: result = {operandA[7], operandA[7:1]};       // ASR
```

**These use exact 8-bit patterns (not casex with don't-cares)** — because these are in the 0000_xxxx class where the lower 4 bits distinguish operations. They must be matched before the `8'b0000xxxx` case, which is why they appear first. In Verilog casex, the first matching case wins.

**CIR (Circular Rotate Right):** `{operandA[0], operandA[7:1]}` — bit 0 wraps around to become bit 7. This is a barrel shift with wrap-around.

**ASR (Arithmetic Shift Right):** `{operandA[7], operandA[7:1]}` — the sign bit (bit 7) is replicated into the vacated position, preserving the sign of a two's complement number.

---

### Compare Operation

```verilog
            8'b0111xxxx: begin // CMP
                if (operandA >= operandB)
                    CB = 0;
                else
                    CB = 1;
                result = 8'b0;
            end
```

**CMP does not update the accumulator** — `result = 8'b0` but this is irrelevant because the `tiny_processor.v` accumulator update block only writes to ACC when `alu_enable` is high AND the result is meaningful. The CB flag is the only output that matters from CMP. A future BRANCH_IF_CARRY instruction could use CB to implement conditional branching.

---

## 5. `register_file.v` — Register File

```verilog
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
```

**Two separate always blocks** — one combinational for read, one clocked for write. This is the standard Verilog pattern for a synchronous-write, asynchronous-read memory, which Vivado infers as distributed RAM (RAM16X1S primitives).

**`data_out = registers[addr]`** is combinational — the register data is available immediately when the address changes, without waiting for a clock edge. This is critical for the pipeline: the EX stage reads the register and feeds it to the ALU in the same cycle, within the 10ns clock period.

**Initial values R[i] = i+1** — R0=1, R1=2, ..., R15=16. These non-zero distinct values serve as implicit test data. When the testbench runs `ADD R2`, it adds 3 (R2's initial value) to the accumulator. If the result is wrong, it's immediately clear which register was read incorrectly.

**`en` is gated write** — without enable, the register file is read-only every cycle. The write only occurs when explicitly requested by either MOV Rn,ACC (reg_write) or LOAD (mem_read), both of which assert `en` from the tiny_processor wiring.

---

## 6. `program_counter.v` — Program Counter

```verilog
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
            pc          <= 4'b0000;
            first_cycle <= 1'b1;
        end else if (first_cycle) begin
            pc          <= start_address;
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
```

**The `first_cycle` trick resolves a synthesis warning.** The original design did `pc <= start_address` on reset, which means the reset net was driving a load (set) operation — Vivado sees both a reset and a set from the same signal, which is ambiguous in hardware. The fix: reset always clears to 0 (pure asynchronous reset), and `start_address` is loaded on the first active clock cycle using a separate `first_cycle` flag. This gives the same behavior but with clean synthesis semantics.

**Priority order of the if-else chain:**
1. `reset` — asynchronous, overrides everything
2. `first_cycle` — one-shot load of start_address
3. `halt` — freeze PC (implicit hold, `pc <= pc` is a no-op)
4. `branch_enable` — load branch target
5. default — increment

**`halt` holds the PC** — `pc <= pc` looks redundant but explicitly documents the intent. Without it, the else branch at the bottom would increment the PC during halt, causing the processor to fetch instructions after HLT. The explicit hold prevents this.

**4-bit PC limits the design to 16 instruction addresses.** This is the primary scalability constraint. Extending to 8-bit requires no changes to the pipeline structure — only the PC width, instruction_memory depth, and branch address encoding change.

---

## 7. `data_memory.v` — Data Memory

```verilog
module data_memory (
    input        clk,
    input        we,
    input  [3:0] addr,
    input  [7:0] data_in,
    output [7:0] data_out
);
    reg [7:0] mem [0:15];

    initial begin
        mem[0]  = 8'hA1;  mem[1]  = 8'hB2;  mem[2]  = 8'hC3;
        mem[3]  = 8'hD4;  mem[4]  = 8'hE5;  mem[5]  = 8'hF6;
        mem[6]  = 8'h11;  mem[7]  = 8'h22;  mem[8]  = 8'h33;
        mem[9]  = 8'h44;  mem[10] = 8'h55;  mem[11] = 8'h66;
        mem[12] = 8'h77;  mem[13] = 8'h88;  mem[14] = 8'h99;
        mem[15] = 8'hAA;
    end

    always @(posedge clk) begin
        if (we)
            mem[addr] <= data_in;
    end

    assign data_out = mem[addr];
endmodule
```

**`assign data_out = mem[addr]`** — this is the asynchronous read. The output is a wire driven by a continuous assignment from the memory array. The moment `addr` changes, `data_out` changes combinationally — no clock edge required.

**Synchronous write, asynchronous read** — this is the asymmetry that causes the load-use hazard. When STORE executes, `we=1` and the write commits at the next posedge clk. But LOAD reads via `assign data_out` combinationally in the same cycle LOAD is in EX. If STORE was in EX the previous cycle, its write committed at the posedge between those cycles — so LOAD sees the updated value. But if STORE is in the immediately preceding cycle WITH NO NOP, the write commits at the SAME posedge that LOAD is reading from — a race condition that the simulator resolves by reading before writing.

**Distinct initial values (0xA1–0xAA)** — not sequential, not zero. If the LOAD address decode is wrong and we read address 7 instead of 15, we get 0x22 instead of 0xAA — immediately obvious. All-zeros initialization would make many address errors invisible.

**`output [7:0] data_out` is a wire, not reg** — because it's driven by `assign`, not by an always block. This is correct and intentional. `output reg` would require a clocked always block, making the read synchronous — which would add a cycle of latency to every LOAD.

---

## 8. `instruction_memory.v` — Instruction ROM

```verilog
module instruction_memory (
    input  wire [3:0] addr,
    output reg  [7:0] data
);
    reg [7:0] memory [0:15];

    // Auto-generated by assembler.py
    initial begin
        memory[ 0] = 8'b00000000; // 0x00  NOP
        memory[ 1] = 8'b00000000; // 0x00  NOP
        memory[ 2] = 8'b00000000; // 0x00  NOP
        memory[ 3] = 8'b00000000; // 0x00  NOP
        memory[ 4] = 8'b10010001; // 0x91  MOV ACC, R1
        memory[ 5] = 8'b11101111; // 0xef  STORE [15], ACC
        memory[ 6] = 8'b00000000; // 0x00  NOP (hazard buffer)
        memory[ 7] = 8'b10010011; // 0x93  MOV ACC, R3
        memory[ 8] = 8'b11011111; // 0xdf  LOAD [15]
        memory[ 9] = 8'b00010010; // 0x12  ADD R2
        memory[10] = 8'b11001101; // 0xcd  BRANCH 13
        memory[11] = 8'b01100001; // 0x61  XOR R1 (skipped)
        memory[12] = 8'b11111111; // 0xff  HLT (skipped)
        memory[13] = 8'b00010011; // 0x13  ADD R3
        memory[14] = 8'b11101110; // 0xee  STORE [14], ACC
        memory[15] = 8'b11111111; // 0xff  HLT
    end

    always @(*) begin
        data = memory[addr];
    end
endmodule
```

**Decoding the encoding manually:**

| Address | Binary | Decoding |
|---|---|---|
| 4 | `1001_0001` | opcode=1001 (MOV ACC,Rn), Rn=0001 (R1) |
| 5 | `1110_1111` | opcode=1110 (STORE), addr=1111 (15) |
| 7 | `1001_0011` | opcode=1001 (MOV ACC,Rn), Rn=0011 (R3) |
| 8 | `1101_1111` | opcode=1101 (LOAD), addr=1111 (15) |
| 9 | `0001_0010` | opcode=0001 (ADD), Rn=0010 (R2) |
| 10 | `1100_1101` | opcode=1100 (BRANCH), addr=1101 (13) |
| 13 | `0001_0011` | opcode=0001 (ADD), Rn=0011 (R3) |
| 14 | `1110_1110` | opcode=1110 (STORE), addr=1110 (14) |

**`output reg [7:0] data`** — even though the read is combinational (always @(*)), the output is declared as `reg` because it's assigned inside an always block. In Verilog, `reg` does not mean registered — it means "assigned in a procedural block." The synthesis result is combinational LUTs, not flip-flops.

**`input wire [3:0] addr`** — explicit `wire` declaration. Verilog defaults module inputs to wire, so this is stylistically explicit rather than functionally necessary. It documents that `addr` is a combinational input.

**The initial block is auto-generated by assembler.py** — this is the key integration point between the software toolchain and the hardware. Running `python docs/assembler.py myprogram.asm` produces a new initial block that can be pasted here to change the program without touching any other Verilog file.

**Addresses 11 and 12 (XOR R1, HLT) are never executed** — they exist in memory but the BRANCH at address 10 jumps over them to address 13. They serve as dead code demonstrating that the branch works correctly. A future enhancement would use these addresses for subroutine code.

---

## 9. `tiny_processor_tb.v` — Self-Checking Testbench

### DUT Instantiation

```verilog
    tiny_processor uut (
        .clk             (clk),
        .reset           (reset),
        .start_address   (4'b0000),
        ...
        .cycle_count_out (cycle_count_out),
        .instr_count_out (instr_count_out),
        .branch_count_out(branch_count_out)
    );
```

**`start_address = 4'b0000`** — the program starts at address 0. This is hardcoded in the testbench. For programs that start at a different address, this would be changed. Named port connections (.port_name(signal)) are used throughout — this is mandatory for large port lists because positional connections become unmaintainable and error-prone.

---

### Clock Generation

```verilog
    initial clk = 0;
    always #5 clk = ~clk;
```

**Two-statement clock generation** — `initial` sets the starting value, `always` toggles every 5ns. Period = 10ns = 100 MHz. This matches the synthesis clock constraint in timing.xdc, so simulation and synthesis operate at the same frequency.

---

### Check Task

```verilog
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
```

**`===` (identity operator) vs `==` (equality operator):** `==` returns x if either operand contains x or z. `===` treats x and z as literal values — `8'bx === 8'bx` is true, `8'bx === 8'd5` is false. This is critical in testbenches: if the accumulator is uninitialized (x) when we expect 0, `==` gives an indeterminate result (simulates as false, looks like a failure even if the design might be correct), while `===` correctly identifies the mismatch.

**`input [8*32-1:0] label`** — a 256-bit wide input used to pass string literals. In Verilog, strings are packed into bit vectors — each character is 8 bits, so a 32-character string needs 256 bits. This is a legacy Verilog technique; SystemVerilog's `string` type would be cleaner.

**`pass_count` and `fail_count` use blocking assignments (=)** — inside a task called from an initial block, blocking is correct. These are testbench control variables, not hardware registers.

---

### Reset Sequence

```verilog
        reset = 1;
        @(posedge clk); #1;
        @(posedge clk); #1;
        reset = 0;
```

**Two clock cycles of reset** — ensures all flip-flops in the design (pipeline register, PC, accumulator, counters) have been held in reset for at least one full clock period, guaranteeing a clean known state. One cycle might be insufficient if there are multi-cycle reset paths.

**`#1` after each posedge** — samples signals 1 picosecond after the clock edge, after all flip-flop outputs have settled. This eliminates the race condition where the testbench reads a signal at the exact moment a flip-flop is transitioning. This 1ps delay is standard practice in synchronous testbenches.

---

### Pipeline-Aware Test Timing

```verilog
        // cycle 1-5: NOPs, ACC=0
        repeat(5) @(posedge clk); #1;
        check(1, 8'd0, acc_out, "NOP x4: ACC stays 0");

        // cycle 6: t=76ns — MOV ACC,R1 in EX, but wait one more
        repeat(2) @(posedge clk); #1;
        check(2, 8'd2, acc_out, "MOV ACC,R1: ACC=2");
```

**Why `repeat(2)` for MOV ACC,R1 instead of `repeat(1)`?** The pipeline has 2 stages. When MOV ACC,R1 enters IF at cycle 6, it reaches EX at cycle 7, and the accumulator updates at the END of cycle 7's clock edge. We sample at cycle 7's posedge + 1ps, which is exactly when the accumulator has the new value. The extra cycle accounts for the IF→EX pipeline latency.

**Timing was derived from actual simulation trace** — not estimated. A monitoring always block was added temporarily:

```verilog
    always @(posedge clk) begin
        $display("t=%0t PC=%0d IR=%b ACC=%0d", $time, pc, ir_out, acc_out);
    end
```

This produced a cycle-by-cycle log that was used to identify exactly which cycle each instruction's result appeared in the accumulator. Only after this trace was the testbench timing finalized. This is the correct methodology — never assume pipeline timing, always measure it.

---

### Performance Counter Readout

```verilog
        if (instr_count_out > 0)
            $display(" CPI             : %0d.%02d",
                cycle_count_out / instr_count_out,
                ((cycle_count_out * 100) / instr_count_out) % 100);
```

**Verilog doesn't support floating-point `$display`** — so CPI is displayed as integer division with a separately computed decimal part. `cycle_count / instr_count` gives the integer part. `(cycle_count * 100) / instr_count % 100` gives the two decimal digits. For CPI=2.00: 16/8=2 (integer), (16*100)/8 % 100 = 200 % 100 = 0 (decimal). Displayed as "2.00".

**Guard `instr_count_out > 0`** — prevents division by zero if the processor halts before executing any instructions (e.g., HLT at address 0).

---

## Key Design Decisions Summary

| Decision | Choice | Reason |
|---|---|---|
| Pipeline depth | 2-stage | Critical path was fetch+execute; 2 stages directly addresses this |
| Memory architecture | Harvard | Separate instruction/data buses eliminate structural hazards |
| Register architecture | Accumulator | Simplifies encoding: only 4 bits needed for register operand |
| Branch hazard | Flush (always) | Simplest correct solution; 1-cycle penalty acceptable at this scale |
| Load-use hazard | NOP (programmer burden) | Simpler than hardware forwarding; documented as known limitation |
| Reset style | Async clear | Avoids set/reset priority ambiguity in synthesis |
| Memory read | Asynchronous | Allows register file and data memory read within same EX cycle |
| Counter width | 32-bit | Sufficient for billions of cycles; wider than needed but clean |
| Testbench style | Self-checking with task | Scalable, no manual waveform inspection needed |
| Initial values | Distinct non-zero | Makes address decode errors immediately visible |

---

*Code Reference for Custom Processor V2 — Priyanshi Shah, July 2026*
*See also: [README](../README.md) | [ISA Specification](ISA_spec.md) | [Interview Question Bank](Interview_Question_Bank.md)*
