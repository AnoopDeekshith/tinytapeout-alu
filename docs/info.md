<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->
<!--- docs/info.md -->

## How it works

This project implements a **4-bit Arithmetic Logic Unit (ALU)** using combinational logic
in Verilog, synthesized for the Skywater 130nm process via TinyTapeout.

An ALU is the fundamental computational building block of any processor. It takes two
operands and an operation selector (opcode), and produces a result along with status
flags that describe properties of that result. This design supports 8 operations selected
by a 3-bit opcode, covering arithmetic, bitwise logic, and shift operations.

### Architecture Overview

The ALU is purely **combinational** — there are no registers or clocked elements. Every
time the inputs change, the output updates immediately through combinational logic paths.
The design uses a single `always @(*)` block with a `case` statement that routes the
inputs through the appropriate logic based on the opcode.

The two 4-bit operands A and B are packed into the 8-bit `ui_in` input port:
- `ui_in[3:0]` carries Operand A (least significant nibble)
- `ui_in[7:4]` carries Operand B (most significant nibble)

The 3-bit opcode is passed through `uio_in[2:0]` (the bidirectional I/O port used as
input). The remaining bidirectional pins are tied to 0 and their output-enable is
disabled since they are unused.

The result and flags are packed into `uo_out[7:0]`:
- `uo_out[3:0]` — 4-bit result of the operation
- `uo_out[4]` — Zero flag: set to 1 when the result is exactly 0
- `uo_out[5]` — Carry flag: set to 1 when an ADD overflows or SUB borrows
- `uo_out[6]` — Negative flag: set to 1 when the MSB of the result is 1 (two's complement sign bit)
- `uo_out[7]` — Unused, tied to 0

### Supported Operations

| Opcode | Mnemonic | Operation | Description |
|--------|----------|-----------|-------------|
| `3'b000` | ADD | `{carry, result} = A + B` | 4-bit addition. The carry bit captures overflow into the 5th bit. |
| `3'b001` | SUB | `{carry, result} = A - B` | 4-bit subtraction. The carry bit is set on borrow (when B > A). |
| `3'b010` | AND | `result = A & B` | Bitwise AND. Each output bit is 1 only if both input bits are 1. |
| `3'b011` | OR  | `result = A \| B` | Bitwise OR. Each output bit is 1 if either input bit is 1. |
| `3'b100` | XOR | `result = A ^ B` | Bitwise XOR. Each output bit is 1 if the input bits differ. |
| `3'b101` | NOT | `result = ~A` | Bitwise NOT of A. Inverts every bit. Operand B is ignored. |
| `3'b110` | LSL | `result = A << 1` | Logical shift left by 1. LSB is filled with 0. MSB is lost. |
| `3'b111` | LSR | `result = A >> 1` | Logical shift right by 1. MSB is filled with 0. LSB is lost. |

### Flag Logic

The three status flags are derived combinationally from the result:

**Zero Flag (`uo_out[4]`):** Computed as `(result == 4'b0000)`. This is a 4-input NOR
gate on the result bits — if all four bits are 0, the zero flag is asserted.

**Carry Flag (`uo_out[5]`):** The `carry` register is only meaningful for ADD and SUB.
For ADD, it captures the 5th bit of the sum (e.g., 15 + 1 = 16, which is `5'b10000`,
so carry=1 and result=0). For SUB, it captures the borrow bit (e.g., 0 - 1 requires
borrowing, so carry=1 and result=15 in two's complement). For all other operations,
carry is explicitly set to 0 at the start of the always block.

**Negative Flag (`uo_out[6]`):** Computed as `result[3]`, the MSB of the result. In
two's complement representation, a 1 in the MSB indicates a negative number. For 4-bit
values, any result ≥ 8 (i.e., 1000 to 1111 in binary) will assert the negative flag.

### Signal Flow Summary
```
<img width="1426" height="804" alt="image" src="https://github.com/user-attachments/assets/848a2642-b7cc-453a-b333-c03f6f9443e9" />

ui_in[3:0]  ──► A ──┐
                     ├──► ALU case logic ──► result[3:0] ──► uo_out[3:0]
ui_in[7:4]  ──► B ──┘         │                              
                               │              result==0  ──► uo_out[4] (Zero)
uio_in[2:0] ──► opcode ───────►│              carry      ──► uo_out[5] (Carry)
                                               result[3]  ──► uo_out[6] (Negative)
```

---

## How to test

The testbench is written in Python using **cocotb** (Coroutine-based Co-simulation
Test Bench), a framework that allows Python to drive and observe Verilog simulations.

### Testbench Structure

A clock is started at 100 KHz (10 us period). The design is held in reset for 10 clock
cycles to ensure all internal state is cleared. After reset is released, the testbench
waits 5 additional cycles to allow the gate-level netlist to fully settle from any
unknown (X) states before applying test vectors.

A helper function `apply_op(dut, A, B, op)` packs A and B into `ui_in` and the opcode
into `uio_in`, then waits one clock cycle. Since the ALU is combinational, the output
is stable by the next clock edge.

A helper function `safe_int(val)` safely converts cocotb's `LogicArray` type to a
Python integer, handling any residual X/Z values from gate-level simulation by treating
them as 0.

A `check()` coroutine applies inputs, reads outputs, compares against expected values,
and logs PASS/FAIL with full diagnostic information including opcode, operands, actual
result, and expected result.

### Test Coverage

The testbench applies **27 test vectors** covering all 8 operations:

**ADD (4 tests):** Basic addition (3+5=8), maximum non-overflow (7+8=15), carry
generation (15+1=0 with carry=1), and zero result (0+0=0).

**SUB (3 tests):** Basic subtraction (8-3=5), zero result (5-5=0), and borrow
generation (0-1=15 with carry=1).

**AND (3 tests):** Partial overlap (1100 & 1010 = 1000), all-zero (1111 & 0000 = 0000),
and all-ones (1111 & 1111 = 1111).

**OR (3 tests):** Complementary inputs (1100 | 0011 = 1111), all-zero (0000 | 0000 = 0),
and complementary alternating (1010 | 0101 = 1111).

**XOR (3 tests):** Identity check (A XOR A = 0), complementary inputs (1100 ^ 0011 = 1111),
and one-sided (1111 ^ 0000 = 1111).

**NOT (3 tests):** All-zeros inverted (0000 → 1111), all-ones inverted (1111 → 0000),
and alternating pattern (1010 → 0101).

**LSL (3 tests):** Single bit shift (0001 → 0010), two-bit value (0011 → 0110), and MSB
overflow (1000 → 0000, MSB shifted out).

**LSR (3 tests):** MSB shift (1000 → 0100), two-bit value (0011 → 0001), and LSB
overflow (0001 → 0000, LSB shifted out).

**Zero Flag (1 test):** Verifies `uo_out[4]` is asserted when result is 0.

**Negative Flag (1 test):** Verifies `uo_out[6]` is asserted when MSB of result is 1
(using 8+1=9=0b1001).

The testbench runs under both **RTL simulation** (behavioral Verilog) and **gate-level
simulation** (synthesized Skywater 130nm netlist), and all 27 tests pass in both modes.

---

## External hardware

None required. All inputs and outputs are through the TinyTapeout standard pin interface.

---



