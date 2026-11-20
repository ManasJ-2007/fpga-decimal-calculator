# FPGA 4-Digit Signed Decimal Calculator

**EE214: Digital Circuits Laboratory, IIT Bombay (Autumn 2026), Final Project**
Team of 2: Sashreek Sikder (25B3923) and Manas Jagtap (25B3922)

A 4-digit decimal calculator in **VHDL** on an Intel **MAX 10 FPGA (10M08SAE144C8G)**, built in Quartus Prime. Input comes from a 4×4 matrix keypad and output goes to a multiplexed 4-digit seven-segment display. It does addition, subtraction (with a minus sign) and multiplication on operands of up to 4 digits; results longer than four digits scroll across the display. Every control block is a finite-state machine.

## Highlights

- **Keypad scanner and debouncer FSM:** column scanning with 500-cycle (10 µs) settling, a 2-flip-flop synchroniser on the rows, and **17.5 ms debouncing (875,000 cycles at 50 MHz)** on both press and release. A held key gives exactly one pulse.
- **Display FSMs:** ~1 kHz digit multiplexing and 2 Hz scrolling for results of 5–8 digits, with blanking between loops.
- **Central calculator FSM:** an 8-state controller with an EXECUTE sub-FSM: load → ALU → **binary-to-BCD (double-dabble, 27 shifts, up to 8 digits)** → format (leading-zero blanking, minus sign placed left of the first digit).
- **Resources and timing (full design):** **1,072 / 8,064 logic elements (13%)**, 301 registers, 2 embedded multipliers, 21 pins; **Fmax 57.6 MHz** against the 50 MHz board clock.

## Test cases (from the course handout, verified on hardware)

| Keys | Result | Display |
|---|---|---|
| `9 0 0 0 B 1 2 3 4 D` | 9000 − 1234 = 7766 | static `7766` |
| `9 8 7 A 9 9 9 9 D` | 987 + 9999 = 10986 | scrolls `10986` |
| `9 8 7 6 C 5 4 D` | 9876 × 54 = 533304 | scrolls `533304` |
| `4 5 B 1 2 3 D` | 45 − 123 = −78 | static ` -78` |

Keys: `A` add, `B` subtract, `C` multiply, `D` equals, `*` delete last digit, `#` clear.

## Repository layout

```
src/task1_display/part_a/   display controller using the on-board BCD decoder (+ testbench)
src/task1_display/part_b/   own 7-segment decoder and scroll/mux FSMs (+ testbenches)
src/task2_keypad/           keypad scanner, synchroniser and debouncer FSM
src/task3_calculator/       full calculator: top-level FSM, ALU, BCD conversion, display
bitstream/                  calculator_top.sof, ready to program the MAX 10 board
reports/                    Quartus fit and timing summaries
report/                     full project report with block and state diagrams
```

## Build

Open `src/task3_calculator/Task_3.qpf` in Quartus Prime Lite 18.1 (MAX 10, 10M08SAE144C8G), compile, and program the board, or flash `bitstream/calculator_top.sof` directly with the Quartus Programmer.

## Who did what

Both of us wrote VHDL code for the project.

- **Sashreek Sikder:** VHDL coding, FSM design (keypad, display, calculator, EXECUTE phases), state diagrams, report.
- **Manas Jagtap:** VHDL coding, debugging the design and code, simulation, hardware testing on the FPGA board, and verification against the handout test cases.
