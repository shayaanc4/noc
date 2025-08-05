`timescale 1ns/1ps
import noc_params::*;

/// Generic FIFO buffer for packet_t elements
module fifo_buffer #(
    parameter int unsigned DEPTH      = 16,                    ///< number of entries
    parameter int unsigned ADDR_WIDTH = $clog2(DEPTH)          ///< address width
)(
    input  logic         clk,      ///< system clock
    input  logic         rst,      ///< asynchronous reset
    input  logic         wr_en,    ///< enqueue when asserted & not full
    input  logic         rd_en,    ///< dequeue when asserted & not empty
    input  packet_t      din,      ///< data to write
    output packet_t      dout,     ///< data read
    output logic         empty,    ///< high when empty
    output logic         full      ///< high when full
);

	//----------------------------------------------------------------------
	// Storage and pointers
	//----------------------------------------------------------------------
	packet_t buffer_mem [0:DEPTH-1];   ///< circular memory
	logic [ADDR_WIDTH:0] write_ptr,    ///< MSB for full detection
								read_ptr;     ///< MSB for empty detection

	//----------------------------------------------------------------------
	// Status flags
	//----------------------------------------------------------------------
	assign empty = (write_ptr == read_ptr);
	assign full  = (write_ptr[ADDR_WIDTH] != read_ptr[ADDR_WIDTH])
						&& (write_ptr[ADDR_WIDTH-1:0] == read_ptr[ADDR_WIDTH-1:0]);

	//----------------------------------------------------------------------
	// Output data always reflects current read location
	//----------------------------------------------------------------------
	assign dout = buffer_mem[read_ptr[ADDR_WIDTH-1:0]];

	//----------------------------------------------------------------------
	// Write and read pointer updates
	//----------------------------------------------------------------------
	always_ff @(posedge clk or posedge rst) begin
		 if (rst) begin
			  write_ptr <= '0;
			  read_ptr  <= '0;
		 end else begin
			  // Enqueue
			  if (wr_en && !full) begin
					buffer_mem[write_ptr[ADDR_WIDTH-1:0]] <= din;
					write_ptr <= write_ptr + 1;
			  end
			  // Dequeue
			  if (rd_en && !empty) begin
					read_ptr <= read_ptr + 1;
			  end
		 end
	end

endmodule
