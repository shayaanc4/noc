NoC Router Project

A SystemVerilog–based network-on-chip communication protocol focused on high-throughput packet data flow—featuring escape-based framing, FIFO buffering, and fixed-priority routing across a scalable 2D mesh, with end-to-end verification via comprehensive testbenches.

📁 Repository Layout

.
├── LICENSE
├── README.md
├── .gitignore
│
├── src/                   ← all synthesizable RTL
│   ├── noc_params.sv
│   ├── packet_receiver.sv
│   ├── packet_sender.sv
│   ├── fifo_buffer.sv
│   ├── arbiter.sv
│   ├── router.sv
│   ├── tile.sv
│   └── network.sv
│
├── tb/                    ← all your testbenches
│   ├── packet_receiver_tb.sv
│   ├── router_tb.sv
│   ├── router_routing_tb.sv
│   ├── network_tb.sv
│   └── network_advanced_tb.sv
│
├── scripts/               ← helper scripts
│   └── run_sim.sh         ← e.g. ModelSim or Icarus invocation
│
└── docs/                  ← design docs, whitepapers
    └── design_notes.md

🔧 Prerequisites
	•	ModelSim / Questa or Icarus Verilog for RTL simulation
	•	Quartus / Vivado / Synplify for FPGA synthesis (optional)
	•	Unix-style shell for helper scripts

🏃 Quickstart (Simulation)

# from repo root
chmod +x scripts/run_sim.sh
scripts/run_sim.sh

You should see all testbenches pass:
	•	packet_receiver_tb
	•	router_tb
	•	router_routing_tb
	•	network_tb
	•	network_advanced_tb

🎯 Project Highlights
	•	Configurable packet size via noc_params.sv
	•	Escape-based framing (0x7E start/end, 0x7D escape)
	•	Fixed-priority arbiter (easily replaceable)
	•	2D mesh generator for arbitrary MESH_SIZE_X, MESH_SIZE_Y
	•	Processing element (PE) that accumulates payloads

📜 License

This code is released under the MIT License. See LICENSE for details.

🤝 Contributing

Feel free to open issues or pull requests. Please follow the existing style:
	•	2-space indentation
	•	Doxygen-style comments
	•	Separate combinational and sequential blocks

⸻

Happy routing! 🚀
