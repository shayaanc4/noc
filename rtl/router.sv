`timescale 1ns/1ps
import noc_params::*;

/// Routing unit: handles packet reception, arbitration, routing, and forwarding
module router #(
    parameter int Y_COORD = 0,
    parameter int X_COORD = 0
)(
    input  logic                     		clk,         			///< system clock
    input  logic                     		rst,         			///< asynchronous reset
    input  logic       [7:0]        		in_bytes   [0:3], 		///< input byte streams: {0:N,1:E,2:S,3:W}
    output logic       [7:0]        		out_bytes  [0:3], 		///< output byte streams (to neighbors)
    output logic       [PAYLOAD_SIZE-1:0] pe_link       			///< local payload for this tile
);

    //----------------------------------------------------------------------
    // Local type aliases for clarity
    //----------------------------------------------------------------------
    typedef packet_t pkt_t;
    typedef logic    valid_t;

    //----------------------------------------------------------------------
    // Direction indices
    //----------------------------------------------------------------------
    localparam int DIR_N = 0;
    localparam int DIR_E = 1;
    localparam int DIR_S = 2;
    localparam int DIR_W = 3;

    //----------------------------------------------------------------------
    // Packet receiver outputs
    //----------------------------------------------------------------------
    pkt_t        rx_pkt   [0:3];    ///< raw packets from each direction
    valid_t      rx_valid [0:3];    ///< receiver `out_valid`s

    //----------------------------------------------------------------------
    // Input FIFOs
    //----------------------------------------------------------------------
    logic        in_fifo_empty [0:3];
	 logic        in_fifo_full  [0:3];
    logic        in_fifo_rd_en [0:3];
    pkt_t        in_fifo_data  [0:3];

    //----------------------------------------------------------------------
    // Arbiter handshake
    //----------------------------------------------------------------------
    pkt_t        arb_selected_pkt;
    logic        arb_valid;

    //----------------------------------------------------------------------
    // Output FIFOs
    //----------------------------------------------------------------------
    logic        out_fifo_empty [0:3];
	 logic        out_fifo_full  [0:3];
    logic        out_fifo_wr_en [0:3];
    logic        out_fifo_rd_en [0:3];
    pkt_t        out_fifo_data  [0:3];

    //----------------------------------------------------------------------
    // Packet sender state
    //----------------------------------------------------------------------
    logic        sending_active [0:3];

    //----------------------------------------------------------------------
    // Packet receivers (one per direction)
    //----------------------------------------------------------------------
    genvar d;
    generate
      for (d = 0; d < 4; d++) begin : RX_INST
        packet_receiver pr (
          .clk     (clk),
          .rst     (rst),
          .in_byte (in_bytes[d]),
          .pkt     (rx_pkt[d]),
          .valid	 (rx_valid[d])
        );
      end
    endgenerate

    //----------------------------------------------------------------------
    // Input FIFO buffers (one per receiver)
    //----------------------------------------------------------------------
    generate
      for (d = 0; d < 4; d++) begin : IN_FIFO_INST
        fifo_buffer in_buf (
          .clk        (clk),
          .rst        (rst),
          .wr_en      (rx_valid[d]),
          .rd_en      (in_fifo_rd_en[d]),
          .din 		 (rx_pkt[d]),
          .dout  		 (in_fifo_data[d]),
          .empty      (in_fifo_empty[d]),
			 .full		 (in_fifo_full[d])
        );
      end
    endgenerate

    //----------------------------------------------------------------------
    // Arbiter (fixed-priority): picks one packet from an input fifo
    //----------------------------------------------------------------------
    arbiter arb (
      .buf_empty     (in_fifo_empty),
      .buf_data   	(in_fifo_data),
      .buf_rd_en     (in_fifo_rd_en),
      .grant_pkt  	(arb_selected_pkt),
      .grant_valid   (arb_valid)
    );

    //----------------------------------------------------------------------
    // Output FIFO buffers
    //----------------------------------------------------------------------
    generate
      for (d = 0; d < 4; d++) begin : OUT_FIFO_INST
        fifo_buffer out_buf (
          .clk        (clk),
          .rst        (rst),
          .wr_en      (out_fifo_wr_en[d]),
          .rd_en      (out_fifo_rd_en[d]),
          .din 		 (arb_selected_pkt),
          .dout  		 (out_fifo_data[d]),
          .empty      (out_fifo_empty[d]),
			 .full		 (out_fifo_full[d])
        );
      end
    endgenerate

    //----------------------------------------------------------------------
    // Packet senders (one per direction)
    //----------------------------------------------------------------------
    generate
      for (d = 0; d < 4; d++) begin : PKT_SND_INST
        packet_sender ps (
          .clk      (clk),
          .rst      (rst),
          .valid_in (out_fifo_rd_en[d]),
          .pkt      (out_fifo_data[d]),
          .tx_byte  (out_bytes[d]),
          .valid_out(sending_active[d])
        );
      end
    endgenerate

    //----------------------------------------------------------------------
    // Route decoding
    //----------------------------------------------------------------------
    
	 // pkt_out_dir[d] = 1 if arb_selected_pkt goes to direction d
    logic pkt_out_dir [0:3];

    always_comb begin
      // default: nothing written
      out_fifo_wr_en = '{default: 0};
      pe_link        = '0;

      if (arb_valid) begin
        // local consumption if this tile's coords match pkt dest coords
        if (arb_selected_pkt.y_dest == Y_COORD && arb_selected_pkt.x_dest == X_COORD) pe_link = arb_selected_pkt.payload;
        else begin
          if 		(arb_selected_pkt.y_dest > Y_COORD) out_fifo_wr_en[DIR_N] = 1;
          else if (arb_selected_pkt.y_dest < Y_COORD) out_fifo_wr_en[DIR_S] = 1;
          else if (arb_selected_pkt.x_dest > X_COORD) out_fifo_wr_en[DIR_E] = 1;
          else if (arb_selected_pkt.x_dest < X_COORD) out_fifo_wr_en[DIR_W] = 1;
        end
      end
    end

    //----------------------------------------------------------------------
    // Read-enable for output FIFOs: when not empty and not currently sending
    //----------------------------------------------------------------------
    generate
      for (d = 0; d < 4; d++) begin : OUT_FIFO_RD_EN
        assign out_fifo_rd_en[d] = !out_fifo_empty[d] && !sending_active[d];
      end
    endgenerate


endmodule 
