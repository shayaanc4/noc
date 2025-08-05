# NoC Router Project

## Overview

A SystemVerilog–based network-on-chip (NoC) communication protocol designed for high-throughput, low-overhead packet data flow. It implements:

- **Escape-based framing**: 0x7E start/end, 0x7D escape for in-band control.
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
