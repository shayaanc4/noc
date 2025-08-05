`timescale 1ns/1ps
import noc_params::*;

/// Packet receiver with SLIP-like framing and escape handling
module packet_receiver (
    input  logic         clk,        ///< system clock
    input  logic         rst,        ///< asynchronous reset
    input  logic [7:0]   in_byte,    ///< serial-framed input byte
    output packet_t      pkt,        ///< assembled packet output
    output logic         valid       ///< high for one cycle when pkt is ready
);

	//----------------------------------------------------------------------
	// States for framing state machine
	//----------------------------------------------------------------------
	typedef enum logic [2:0] {
		 S_IDLE,         ///< waiting for frame start 0x7E
		 S_RECV,         ///< collecting data bytes
		 S_ESCAPE,       ///< previous byte was escape 0x7D
		 S_CHECK_END     ///< waiting for closing 0x7E
	} state_t;

	state_t                    			state, next_state;
	logic [$clog2(PKT_SIZE_BYTES)-1:0] 	byte_cnt;  				///< number of data bytes received
	logic [PKT_SIZE-1:0]        			shift_reg;        	///< shift register for incoming data
	logic                        			done_flag;       		///< asserted when full packet received

	//----------------------------------------------------------------------
	// Packet field extraction
	//----------------------------------------------------------------------
	assign pkt.x_dest  = shift_reg[PKT_SIZE-1                     -: DEST_ADDR_SIZE_X];
	assign pkt.y_dest  = shift_reg[PKT_SIZE-DEST_ADDR_SIZE_X-1    -: DEST_ADDR_SIZE_Y];
	assign pkt.payload = shift_reg[PAYLOAD_SIZE-1 : 0];

	//----------------------------------------------------------------------
	// Sequential logic: state transitions, shift register, counters
	//----------------------------------------------------------------------
	always_ff @(posedge clk or posedge rst) begin
		 if (rst) begin
			  state      <= S_IDLE;
			  shift_reg  <= '0;
			  byte_cnt   <= '0;
			  valid      <= 1'b0;
		 end else begin
			  state      <= next_state;
			  valid      <= done_flag;

			  case (state)
					S_RECV: begin
						 if (in_byte != 8'h7D) begin
							  shift_reg <= (shift_reg << 8) | in_byte;
							  byte_cnt  <= byte_cnt + 1;
						 end
					end
					S_ESCAPE: begin
						 shift_reg <= (shift_reg << 8) | (in_byte ^ 8'h20);
						 byte_cnt  <= byte_cnt + 1;
					end
					default: byte_cnt <= '0;
			  endcase
		 end
	end

	//----------------------------------------------------------------------
	// Combinational logic: next state and done flag logic
	//----------------------------------------------------------------------
	always_comb begin
		 next_state = state;
		 done_flag  = 1'b0;

		 case (state)
			  S_IDLE:
					if (in_byte == 8'h7E) next_state = S_RECV;

			  S_RECV: begin
					if (in_byte == 8'h7D)
						 next_state = S_ESCAPE;                  ///< escape sequence
					else if (byte_cnt == PKT_SIZE_BYTES - 1)
						 next_state = S_CHECK_END;               ///< ready for ending delimiter
					else if (in_byte == 8'h7E)
						 next_state = S_IDLE;                    ///< stray delimiter, reset
					else
						 next_state = S_RECV;
			  end

			  S_ESCAPE:
					next_state = (byte_cnt == PKT_SIZE_BYTES - 1)
									 ? S_CHECK_END
									 : S_RECV;

			  S_CHECK_END:
					if (in_byte == 8'h7E) begin
						 next_state = S_IDLE;
						 done_flag  = 1'b1;       
					end

			  default: next_state = S_IDLE;
		 endcase
	end

endmodule
