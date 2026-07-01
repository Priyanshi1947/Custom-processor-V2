# Custom Processor V2

A 2-stage pipelined 8-bit custom ISA processor designed in Verilog, synthesized on Xilinx Artix-7 at **136 MHz** with zero timing violations.

---

## Key Specs

| Metric | Value |
|---|---|
| Pipeline | 2-stage IF/EX |
| Max frequency | **136 MHz** |
| Slice LUTs | 215 (1% of Artix-7) |
| Flip-flops | 124 |
| Instructions supported | 20 |
| Data memory | 16 bytes |
| CPI (benchmark) | 2.00 |
| Testbench | 10/10 passing |
| Timing violations | 0 |
| Synthesis warnings | 0 |

---

## Project Structure

```
Custom-Processor-V2/
├── rtl/
│   ├── tiny_processor.v        ← top-level: 2-stage pipeline + perf counters
│   ├── if_ex_reg.v             ← IF/EX pipeline register with branch flush
│   ├── ALU.v                   ← arithmetic and logic unit (10 operations)
│   ├── instruction_decoder.v   ← control signal generation
│   ├── instruction_memory.v    ← 16-entry instruction ROM
│   ├── data_memory.v           ← 16-byte data RAM (Harvard architecture)
│   ├── register_file.v         ← 16 x 8-bit general purpose registers
│   └── program_counter.v       ← PC with branch and halt support
├── tb/
│   └── tiny_processor_tb.v     ← self-checking testbench, 10/10 PASS
├── synth/
│   ├── timing.xdc              ← 100 MHz clock constraint
│   ├── timing.rpt              ← Vivado timing report
│   └── utilization.rpt         ← Vivado utilization report
└── docs/
    ├── ISA_spec.md             ← full ISA specification and project log
    └── assembler.py            ← Python assembler for custom ISA
```

---

## Architecture Overview

```
         STAGE 1 — IF                    STAGE 2 — EX
  ┌─────────────────────┐        ┌──────────────────────────┐
  │  program_counter    │        │  instruction_decoder      │
  │  instruction_memory │        │  register_file            │
  └────────┬────────────┘        │  ALU                      │
           │                     │  data_memory (LOAD/STORE) │
     [IF/EX pipeline reg]        │  accumulator              │
     (flush on branch)           │  performance counters     │
           │                     └──────────────────────────┘
           └─────────────────────^
```

**Harvard architecture:** instruction memory and data memory are separate modules, enabling simultaneous fetch and memory access.

---

## ISA Specification

### Instruction Format

```
 7   6   5   4   3   2   1   0
+---+---+---+---+---+---+---+---+
|     OPCODE    |    OPERAND    |
+---+---+---+---+---+---+---+---+
  bits [7:4]       bits [3:0]
```

### Instruction Set

| Mnemonic | Encoding | Operation | Flags |
|---|---|---|---|
| NOP | `0000_0000` | No operation | — |
| LSL | `0000_0001` | ACC = ACC << 1 | — |
| LSR | `0000_0010` | ACC = ACC >> 1 | — |
| CIR | `0000_0011` | ACC = rotate right 1 | — |
| CIL | `0000_0100` | ACC = rotate left 1 | — |
| ASR | `0000_0101` | ACC = arithmetic shift right | — |
| INC | `0000_0110` | ACC = ACC + 1 | CB |
| DEC | `0000_0111` | ACC = ACC - 1 | CB |
| ADD Rn | `0001_rrrr` | ACC = ACC + R[n] | CB |
| SUB Rn | `0010_rrrr` | ACC = ACC - R[n] | CB |
| MUL Rn | `0011_rrrr` | ACC = ACC * R[n] | EXT |
| AND Rn | `0101_rrrr` | ACC = ACC & R[n] | — |
| XOR Rn | `0110_rrrr` | ACC = ACC ^ R[n] | — |
| CMP Rn | `0111_rrrr` | Compare ACC vs R[n] | CB |
| MOV ACC,Rn | `1001_rrrr` | ACC = R[n] | — |
| MOV Rn,ACC | `1010_rrrr` | R[n] = ACC | — |
| RET | `1011_0000` | PC = return address | — |
| BRANCH addr | `1100_aaaa` | PC = addr | — |
| LOAD addr | `1101_aaaa` | ACC = mem[addr] | — |
| STORE addr | `1110_aaaa` | mem[addr] = ACC | — |
| HLT | `1111_1111` | Halt execution | — |

**Key:** `rrrr` = 4-bit register index (R0–R15), `aaaa` = 4-bit address (0–15)

---

## Pipeline Behavior

```
Normal flow (no branch):
Cycle:   1      2      3      4      5
        ----   ----   ----   ----   ----
Inst N: [IF]  [EX]
Inst N+1:      [IF]  [EX]
Inst N+2:             [IF]  [EX]

Branch taken:
Cycle:   1      2      3      4
        ----   ----   ----   ----
BRANCH: [IF]  [EX]
Wrong:          [IF]  [FLUSH]   <- pipeline register cleared to NOP
Target:                [IF]  [EX]

Branch penalty = 1 cycle bubble per taken branch
```

---

## Performance Counters

Three 32-bit hardware counters are built into the processor:

| Counter | Description |
|---|---|
| `cycle_count` | Total clock cycles elapsed since reset |
| `instr_count` | Instructions retired in EX stage |
| `branch_count` | Branches taken (pipeline flushes) |

**CPI = cycle_count / instr_count**

Benchmark result on test program:

```
Cycles elapsed  : 16
Instructions    : 8
Branches taken  : 1
CPI             : 2.00
```

---

## Synthesis Results

Targeting Xilinx Artix-7 (xc7a35tcpg236-1) at 100 MHz constraint:

```
Slice LUTs      :  215  /  20800  (1.03%)
Flip-Flops      :  124  /  41600  (0.30%)
Distributed RAM :   16 LUTs (register file + data memory)
Block RAM       :    0
DSPs            :    0

WNS             : +2.768 ns
Max frequency   : 1000 / (10 - 2.768) = 136 MHz
Failing endpoints: 0
Synthesis warnings: 0
```

Critical path: `pipeline register → register file → ALU adder → accumulator` (7.081 ns, 8 logic levels)

---

## How to Run

### Simulation (Vivado)

```tcl
open_project vivado_proj/tiny_proc.xpr
launch_simulation
run all
```

Expected output:
```
PASS [Test 1]  NOP x4: ACC stays 0       | expected=0 got=0
PASS [Test 2]  MOV ACC,R1: ACC=2         | expected=2 got=2
...
PASS [Test 10] HLT confirmed: ACC stays 9 | expected=9 got=9
Results: 10 PASSED, 0 FAILED
ALL TESTS PASSED - design is correct
CPI: 2.00
```

### Synthesis (Vivado Tcl)

```tcl
synth_design -top tiny_processor -part xc7a35tcpg236-1
create_clock -period 10.000 -name clk [get_ports clk]
report_utilization
report_timing_summary
```

### Assembler

```bash
# Assemble built-in test program
python docs/assembler.py

# Assemble custom program
python docs/assembler.py myprogram.asm
```

Assembler outputs:
- `docs/assembled_memory.v` — paste initial block into `instruction_memory.v`
- `docs/assembled_memory.hex` — hex format for `$readmemh` compatibility

---

## Known Hardware Behaviors

**Load-use hazard:** A STORE followed immediately by a LOAD to the same address requires one NOP between them. The synchronous write / asynchronous read asymmetry in `data_memory.v` means the written value is not available until the next cycle. Production designs resolve this with forwarding logic.

```
STORE 15        ; mem[15] = ACC
NOP             ; required hazard buffer
LOAD  15        ; ACC = mem[15]  <- correct
```

**Branch penalty:** Every taken branch flushes one instruction from the IF stage, inserting a 1-cycle NOP bubble into the pipeline. CPI overhead = `branch_count / instr_count`.

---

## Future Work

- 3-stage pipeline (IF, EX, WB) to push frequency toward 200+ MHz
- Load-use forwarding logic to eliminate the NOP requirement
- Branch prediction to reduce branch penalty toward 0 cycles
- Expanded instruction memory (256 entries via 8-bit PC)
- UART output port for observable computation results
- Fibonacci and bubble sort demo programs

---

## Tools

- Xilinx Vivado 2019.2 (synthesis, simulation via XSim)
- Python 3 (assembler)

---

*Designed by Priyanshi Shah*