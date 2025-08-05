`timescale 1ns/1ps
import noc_params::*;

/// Serial packet sender: frames and escapes packet_t fields
module packet_sender (
    input  logic        clk,       ///< system clock
    input  logic        rst,       ///< synchronous reset
    input  logic        valid_in,  ///< new packet ready
    input  packet_t     pkt,       ///< packet to transmit
    output logic [7:0]  tx_byte,   ///< serialized output byte
    output logic        valid_out  ///< high while tx_byte is valid
);

	//----------------------------------------------------------------------
	// State machine for framing
	//----------------------------------------------------------------------
	typedef enum logic [2:0] {
		 S_IDLE,     ///< await valid_in
		 S_START,    ///< send start delimiter 0x7E
		 S_DATA,     ///< send data bytes
		 S_ESC,      ///< send escaped byte
		 S_END       ///< send end delimiter 0x7E
	} send_state_t;

	send_state_t state, next_state;
	logic [$clog2(PKT_SIZE_BYTES)-1:0] byte_index; 	///< byte counter
	logic [PKT_SIZE-1:0]               shift_reg; 	///< concatenated {x_dest,y_dest,payload}
	logic [7:0]                        curr_byte; 	///< current data byte

	//----------------------------------------------------------------------
	// Sequential logic: capture packet and update pointers
	//----------------------------------------------------------------------
	always_ff @(posedge clk or posedge rst) begin
		 if (rst) begin
			  state      <= S_IDLE;
			  byte_index <= '0;
			  shift_reg  <= '0;
		 end else begin
			  // latch new packet at start
			  if (state == S_IDLE && valid_in)
				shift_reg <= {pkt.x_dest, pkt.y_dest, pkt.payload};
			  state <= next_state;
			  
			  // increment byte index after sending data or escape
			  if ((state == S_DATA || state == S_ESC) && next_state != S_ESC)
				byte_index <= byte_index + 1;
			  else if (state == S_END)
				byte_index <= '0;
		 end
	end

	//----------------------------------------------------------------------
	// Combinational logic: next state, outputs
	//----------------------------------------------------------------------
	always_comb begin
		 next_state = state;
		 tx_byte    = 8'h00;
		 valid_out  = (state != S_IDLE);

		 // compute current byte (MSB-first)
		 curr_byte = shift_reg[PKT_SIZE-1 - byte_index*8 -: 8];

		 case (state)
			  S_IDLE: if (valid_in) next_state = S_START;

			  S_START: begin
				tx_byte    = 8'h7E;
				next_state = S_DATA;
			  end

			  S_DATA: begin
				if (curr_byte == 8'h7E || curr_byte == 8'h7D) begin
					 tx_byte    = 8'h7D;
					 next_state = S_ESC;
				end else begin
					 tx_byte    = curr_byte;
					 next_state = (byte_index == PKT_SIZE_BYTES - 1)
									  ? S_END : S_DATA;
				end
			  end

			  S_ESC: begin
				tx_byte    = curr_byte ^ 8'h20;
				next_state = (byte_index == PKT_SIZE_BYTES - 1)
								 ? S_END : S_DATA;
			  end

			  S_END: begin
				tx_byte    = 8'h7E;
				next_state = S_IDLE;
			  end

			  default: next_state = S_IDLE;
		 endcase
	end


endmodule 
