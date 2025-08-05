# NoC Router Project

## Overview

A SystemVerilog–based 2D mesh network-on-chip (NoC) communication protocol designed for high-throughput, low-overhead packet data flow over serialized byte streams. It implements:

- **Serialized byte streaming**: end-to-end packet transmission and reception via packet_sender and packet_receiver modules, ensuring correct byte ordering and escape encoding.
- **Escape-based packet framing**: 0x7E start/end, 0x7D escape for in-band control.
- **FIFO buffering**: per-port input/output queues to decouple traffic bursts.
- **Fixed-priority arbitration**: simple, deterministic arbitration across multiple input ports.
- **Scalable 2D mesh**: parameterized `MESH_SIZE_X` and `MESH_SIZE_Y` for arbitrary mesh dimensions.
- **Processing Element (PE)**: per-tile accumulator demonstrating payload-driven computation.

## Key Components

- **`noc_params.sv`**  
  Global parameters (packet size, address widths, mesh dimensions).

- **`packet_receiver.sv`**  
  Parses incoming byte streams into structured packets, applying escape decoding.

- **`packet_sender.sv`**  
  Serializes packets into byte streams with framing and escape encoding.

- **`fifo_buffer.sv`**  
  Parameterized circular buffer for packet queuing (configurable depth).

- **`arbiter.sv`**  
  Fixed-priority multiplexer selecting among buffered inputs.

- **`router.sv`**  
  Combines receivers, arbiters, and output buffers to route packets based on destination coordinates.

- **`tile.sv`**  
  Wraps `router` with a simple PE that accumulates incoming payloads.

- **`network.sv`**  
  Generates a 2D grid of tiles, wiring neighbor ports to form a mesh.

## Repository Layout

```
.
├── README.md
│
├── src/
│   ├── noc_params.sv
│   ├── packet_receiver.sv
│   ├── packet_sender.sv
│   ├── fifo_buffer.sv
│   ├── arbiter.sv
│   ├── router.sv
│   ├── tile.sv
│   └── network.sv
│
└── tb/
    ├── packet_receiver_tb.sv
    ├── router_tb.sv
    ├── router_routing_tb.sv
    ├── network_tb.sv
    └── network_advanced_tb.sv
```

## Simulation & Testing

Use any SystemVerilog simulator (ModelSim, Questa, Icarus) to compile `src/` and `tb/` files. Each testbench verifies end-to-end packet flow:

- Packet parsing (framing, escaping)
- Router arbitration and buffering
- Mesh connectivity across tiles

Common features of all testbenches:

1. **Packet Generation**  
   - `send_packet` tasks frame bytes with start/end markers and escape sequences for 0x7E/0x7D bytes.  
   - Parametrized destination and payload fields.

2. **Concurrency & Timing**  
   - `fork/join` constructs to stimulate multiple ports in parallel.  
   - Randomized inter-packet delays via `$urandom_range` to exercise arbitration and buffer behavior.

3. **Scoreboarding & Coverage**  
   - Dynamic arrays (`expected_list` or checker tables) store injected packet metadata.  
   - On each valid output, checkers match observed packets to expected entries, marking them seen.  
   - Final `check_all_seen` or `check_all` tasks report any missing/mismatched entries and conclude the simulation.
