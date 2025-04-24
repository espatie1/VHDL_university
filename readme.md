# Mini VHDL Projects

This repository contains two independent yet complementary VHDL designs that can be used together or in isolation:

* **`cpu.vhd`** – a tiny 8‑bit soft‑core CPU able to run a Brain‑F*** interpreter.
* **`uart_rx.vhd` / `uart_rx_fsm.vhd`** – a hardware UART receiver (RX) with a clean, synchronous interface.

Both designs are fully self‑contained VHDL‑93 sources with no vendor primitives. The files sit side‑by‑side in the same directory so you can drag‑and‑drop them into any VHDL project, simulation test‑bench or synthesis flow.

---

## Directory Layout
```
.
├── cpu.vhd            -- 8‑bit CPU core
├── uart_rx.vhd        -- top‑level UART receiver
├── uart_rx_fsm.vhd    -- internal finite‑state machine used by the receiver
└── uart.pdf           -- short documentation for UART receiver
```

---

## 1. `cpu.vhd` – 8‑bit CPU Core

### Key facts
* **Purpose:** Executes a minimal instruction set tailored for a BrainF*** interpreter embedded in ROM.
* **Data width:** 8 bits
* **Address width:** 13 bits (8 KiB data memory)
* **Clocking:** Single rising‑edge synchronous design
* **Reset:** Active‑high asynchronous `RESET`

### External interface
| Signal | Dir | Width | Function |
|--------|-----|-------|----------|
| `CLK`  | in  | 1 | System clock |
| `RESET`| in  | 1 | Global reset (async, active‑high) |
| `EN`   | in  | 1 | Clock‑enable for single‑step operation |
| **Data RAM** ||||
| `DATA_ADDR` | out | 13 | Byte address into external RAM |
| `DATA_WDATA`| out | 8  | Write data |
| `DATA_RDATA`| in  | 8  | Read data |
| `DATA_RDWR` | out | 1  | 0 = read, 1 = write |
| `DATA_EN`   | out | 1  | Access strobe |
| **Input port** ||||
| `IN_DATA` | in  | 8 | External input byte |
| `IN_VLD`  | in  | 1 | Input data valid |
| `IN_REQ`  | out | 1 | Request next byte |
| **Output port** ||||
| `OUT_DATA`| out | 8 | Output byte |
| `OUT_BUSY`| in  | 1 | Output target busy |
| `OUT_WE`  | out | 1 | Write enable |
| **Status** ||||
| `READY` | out | 1 | Core finished reset/start‑up |
| `DONE`  | out | 1 | Program halted |

### Typical use
Connect `DATA_*` to a single‑port RAM and hook `IN_* / OUT_*` to your I/O (e.g. the UART receiver below). Drive `EN` high for free‑running execution or toggle it for instruction‑by‑instruction tracing.

---

## 2. `uart_rx.vhd` – UART Receiver (8 N 1, oversampling 16×)

### Architecture
`uart_rx.vhd` instantiates `uart_rx_fsm.vhd`, which implements the state machine. The top level provides a small wrapper with datapath logic and output latching.

### Default parameters
* **Protocol:** 1 start, 8 data, no parity, 1 stop
* **Oversampling:** 16× (internal clock must be 16× the desired baud)
* **Throughput:** 1 byte per frame, continuous reception

### External interface
| Signal | Dir | Width | Function |
|--------|-----|-------|----------|
| `CLK` | in | 1 | System clock (16× baud) |
| `RST` | in | 1 | Synchronous reset |
| `DIN` | in | 1 | Serial data from UART line |
| `DOUT` | out | 8 | Received byte |
| `DOUT_VLD` | out | 1 | Pulses **1 CLK** when `DOUT` is valid |

### Integration tips
Simply feed `DOUT` into the CPU’s `IN_DATA` port and gate `DOUT_VLD` to `IN_VLD`. Baud‑rate adaptation is done by picking a suitable system clock or inserting a clock‑divider in front of the receiver.

---

## Synthesis & Simulation

Both sources are plain VHDL‑93 compliant and synthesise cleanly on all major FPGA tools (Xilinx, Intel/Altera, Lattice, Microchip) as well as standard simulators (GHDL/ModelSim/Riviera).

Reference command‑line example using **GHDL**:

```sh
ghdl -a cpu.vhd uart_rx_fsm.vhd uart_rx.vhd
ghdl -e cpu        # or uart_rx for stand‑alone test‑benches
```

---

## License
MIT – see header of each file for details.

---

*Happy hacking!*

