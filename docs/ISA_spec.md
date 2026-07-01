# Custom Processor V2 — Project Log & ISA Specification

## Final Synthesis Results (With performance counters)

| Metric | Value |
|---|---|
| Technology | Xilinx Artix-7 xc7a35tcpg236-1 |
| Pipeline stages | 2 (IF + EX) |
| Slice LUTs | 215 (1.03%) |
| Flip-flops | 124 (0.30%) |
| Distributed RAM | 16 LUTs (regfile + data memory) |
| Max frequency | **136 MHz** |
| Critical path | 7.081 ns |
| Timing violations | 0 |
| Synthesis warnings | 0 |

## Simulation Results (With performance counters)

| Metric | Value |
|---|---|
| Tests passing | 10/10 |
| Instructions verified | NOP, MOV, STORE, LOAD, ADD, BRANCH, XOR, HLT |
| Cycles elapsed | 16 |
| Instructions retired | 8 |
| Branches taken | 1 |
| CPI | 2.00 |

## Summary
> "Designed a 2-stage pipelined 8-bit custom ISA processor in Verilog with
> 20 instructions, data memory, and hardware performance counters. Synthesized
> on Xilinx Artix-7 achieving 136 MHz with 215 LUTs and zero timing violations.
> Built a Python assembler verified end-to-end. CPI = 2.0 on benchmark program."

## Project Overview
A 2-stage pipelined 8-bit custom ISA processor designed in Verilog.
Synthesized on Xilinx Artix-7, achieving 129 MHz with full timing closure.

- **Architecture:** Accumulator-based, 8-bit datapath
- **Pipeline:** 2-stage (IF — Instruction Fetch, EX — Execute)
- **ISA width:** 8 bits (4-bit opcode + 4-bit operand)
- **Registers:** 16 general-purpose 8-bit registers (R0–R15)
- **Special registers:** Accumulator (ACC), Program Counter (PC, 4-bit)
- **Flags:** CB (Carry/Borrow), EXT (extended 8-bit overflow for MUL)

---

## Synthesis Results 

| Metric | Value |
|---|---|
| Target device | Xilinx Artix-7 xc7a35tcpg236-1 |
| Slice LUTs | 207 (1% utilization) |
| Flip-flops | 36 |
| Max frequency | **129 MHz** |
| Critical path | 7.742 ns |
| Timing violations | 0 |
| Pipeline stages | 2 (IF + EX) |

### Vivado Synthesis Terminal Output
```
Report Cell Usage:
| LUT6     |  99 |
| LUT2     |  50 |
| LUT4     |  41 |
| LUT5     |  37 |
| FDCE     |  28 |
| CARRY4   |  16 |
| RAMS32   |   8 |

Slice LUTs : 207 / 20800 (1.00%)
Flip-Flops :  36 / 41600 (0.09%)

WNS(ns) : 2.258
Max frequency: 1000 / (10 - 2.258) = 129 MHz
All user specified timing constraints are met.
Synthesis finished with 0 errors, 0 critical warnings and 0 warnings.
```

### Critical Path Analysis
```
Pipeline reg (PIPE)
  -> Register file read (RAMS32)       -- 0.376 ns
  -> ALU addition chain (3x CARRY4)   -- 0.961 ns
  -> Result mux (LUT6)                -- 0.543 ns
  -> Accumulator write (acc_reg)
Total data path delay: 7.591 ns
Slack: +2.258 ns (timing MET)
```

---

## Verification Results 

| Metric | Value |
|---|---|
| Testbench type | Self-checking (automatic PASS/FAIL) |
| Total tests | 7 |
| Passed | 7 |
| Failed | 0 |
| Instructions verified | NOP, MOV, BRANCH, ADD, RET, XOR, HLT |

### Simulation Terminal Output
```
==============================================
 Tiny Processor Self-Checking Testbench
 Pipeline: 2-stage IF/EX
==============================================
PASS [Test 1]   NOP x4: ACC should stay 0  | expected=0  got=0
PASS [Test 2]   MOV ACC,R1: ACC=R1=2       | expected=2  got=2
PASS [Test 3]   BRANCH+ADD R2: ACC=2+3=5   | expected=5  got=5
PASS [Test 4]   ADD R3: ACC=5+4=9          | expected=9  got=9
PASS [Test 5]   RET+XOR R1: ACC=9^2=11     | expected=11 got=11
PASS [Test 6]   MOV ACC,R7: ACC=R7=8       | expected=8  got=8
PASS [Test 7]   HLT: ACC stays 8           | expected=8  got=8
==============================================
 Results: 7 PASSED, 0 FAILED
 ALL TESTS PASSED - design is correct
==============================================
```

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
- **OPCODE** (bits 7:4): identifies the instruction type
- **OPERAND** (bits 3:0): register address (R0–R15) or branch target address

---

### Instruction Set Table

| Mnemonic | Encoding | Operation | Flags | Notes |
|---|---|---|---|---|
| NOP | `0000_0000` | No operation | — | Default/unused memory |
| LSL | `0000_0001` | ACC = ACC << 1 | — | Logical shift left |
| LSR | `0000_0010` | ACC = ACC >> 1 | — | Logical shift right |
| CIR | `0000_0011` | ACC = rotate right 1 | — | Circular rotate right |
| CIL | `0000_0100` | ACC = rotate left 1 | — | Circular rotate left |
| ASR | `0000_0101` | ACC = arithmetic shift right | — | Sign-preserving shift |
| INC | `0000_0110` | ACC = ACC + 1 | CB | Increment accumulator |
| DEC | `0000_0111` | ACC = ACC - 1 | CB | Decrement accumulator |
| ADD | `0001_rrrr` | ACC = ACC + R[rrrr] | CB | Add register to ACC |
| SUB | `0010_rrrr` | ACC = ACC - R[rrrr] | CB | Subtract register from ACC |
| MUL | `0011_rrrr` | ACC = ACC * R[rrrr] | EXT | High byte stored in EXT |
| AND | `0101_rrrr` | ACC = ACC & R[rrrr] | — | Bitwise AND |
| XOR | `0110_rrrr` | ACC = ACC ^ R[rrrr] | — | Bitwise XOR |
| CMP | `0111_rrrr` | Compare ACC vs R[rrrr] | CB | CB=1 if ACC < R[rrrr] |
| MOV ACC,Ri | `1001_rrrr` | ACC = R[rrrr] | — | Load register into ACC |
| MOV Ri,ACC | `1010_rrrr` | R[rrrr] = ACC | — | Store ACC into register |
| RET | `1011_xxxx` | PC = return_address | — | Return from branch |
| BRANCH | `1100_aaaa` | PC = aaaa | — | Unconditional jump |
| HLT | `1111_1111` | Halt execution | — | PC freezes |

**Key:** `rrrr` = 4-bit register index (R0–R15), `aaaa` = 4-bit branch target address, `xxxx` = don't care

---

### Flag Descriptions

| Flag | Width | Description |
|---|---|---|
| CB | 1 bit | Carry (ADD/INC) or Borrow (SUB/DEC) or comparison result (CMP) |
| EXT | 8 bits | High byte of MUL result (ACC * Ri produces 16-bit result, low 8 in ACC, high 8 in EXT) |

---

### Pipeline Behavior

```
Cycle:    1      2      3      4      5
         ----   ----   ----   ----   ----
Inst N:  [IF]  [EX]
Inst N+1:       [IF]  [EX]
Inst N+2:              [IF]  [EX]

Branch taken (e.g. BRANCH or RET):
Cycle:    1      2      3      4
         ----   ----   ----   ----
BRANCH:  [IF]  [EX]   <branch detected>
Wrong:          [IF]  [FLUSH] <- pipeline register cleared to NOP
Target:                [IF]  [EX]
```
Branch penalty = 1 cycle (one NOP bubble inserted on every taken branch)

---

### Register File Initialization

Registers are initialized at simulation start with values R[i] = i + 1:

| Register | Initial Value |
|---|---|
| R0 | 1 |
| R1 | 2 |
| R2 | 3 |
| R3 | 4 |
| R4 | 5 |
| R5 | 6 |
| R6 | 7 |
| R7 | 8 |
| R8–R15 | 9–16 |

---

### Sample Program (instruction_memory.v)

```
Addr  Encoding    Mnemonic        Comment
----  --------    --------        -------
0     00000000    NOP             padding
1     00000000    NOP             padding
2     00000000    NOP             padding
3     00000000    NOP             padding
4     10010001    MOV ACC, R1     ACC = 2
5     11001010    BRANCH 10       jump to subroutine at addr 10
6     01100001    XOR R1          ACC = ACC ^ 2  (executed after RET)
7     10010111    MOV ACC, R7     ACC = 8
8     11111111    HLT             stop
--    --------    --------        -------
10    00010010    ADD R2          ACC = ACC + 3 = 5
11    00010011    ADD R3          ACC = ACC + 4 = 9
12    10110000    RET             return to addr 6
```

**Execution trace:**
```
ACC=0 -> MOV R1 -> ACC=2 -> BRANCH 10
-> ADD R2 -> ACC=5 -> ADD R3 -> ACC=9
-> RET -> XOR R1 -> ACC=11 -> MOV R7
-> ACC=8 -> HLT
```