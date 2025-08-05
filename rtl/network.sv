`timescale 1ns/1ps
import noc_params::*;

/// Top-level Network: instantiates a 2D mesh of tiles and connects their ports
module network(
	input  logic                 clk,          ///< system clock
   input  logic                 rst,          ///< asynchronous reset

	// South edge I/O (y = 0)
	input  logic [7:0]           south_in     [0:MESH_SIZE_X-1],
	output logic [7:0]           south_out    [0:MESH_SIZE_X-1],

	// North edge I/O (y = MESH_SIZE_Y-1)
	input  logic [7:0]           north_in     [0:MESH_SIZE_X-1],
	output logic [7:0]           north_out    [0:MESH_SIZE_X-1],

	// West edge I/O  (x = 0)
	input  logic [7:0]           west_in      [0:MESH_SIZE_Y-1],
	output logic [7:0]           west_out     [0:MESH_SIZE_Y-1],

	// East edge I/O  (x = MESH_SIZE_X-1)
	input  logic [7:0]           east_in      [0:MESH_SIZE_Y-1],
	output logic [7:0]           east_out     [0:MESH_SIZE_Y-1]
);

	//----------------------------------------------------------------------
	// Internal inter-tile wires
	//----------------------------------------------------------------------
	logic [7:0] wire_sn [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-2]; // south -> north
	logic [7:0] wire_ns [0:MESH_SIZE_X-1][0:MESH_SIZE_Y-2]; // north -> south
	logic [7:0] wire_we [0:MESH_SIZE_X-2][0:MESH_SIZE_Y-1]; // west  -> east
	logic [7:0] wire_ew [0:MESH_SIZE_X-2][0:MESH_SIZE_Y-1]; // east  -> west

	//----------------------------------------------------------------------
	// Instantiate each tile and hook up its ports
	//----------------------------------------------------------------------
	genvar x, y;
	generate
		for (y = 0; y < MESH_SIZE_Y; y++) begin: row
			for (x = 0; x < MESH_SIZE_X; x++) begin: col

				// Per-tile port vectors
				logic [7:0] tile_in  [0:3];
				logic [7:0] tile_out [0:3];

				// North input  (tile_in[0]): either neighbor or north_in array
				assign tile_in[0] = (y == MESH_SIZE_Y-1)
										 ? north_in[x]
										 : wire_ns[x][y];

				// East input   (tile_in[1]): either neighbor or east_in array
				assign tile_in[1] = (x == MESH_SIZE_X-1)
										 ? east_in[y]
										 : wire_ew[x][y];

				// South input  (tile_in[2]): either neighbor or south_in array
				assign tile_in[2] = (y == 0)
										 ? south_in[x]
										 : wire_sn[x][y-1];

				// West input   (tile_in[3]): either neighbor or west_in array
				assign tile_in[3] = (x == 0)
										 ? west_in[y]
										 : wire_we[x-1][y];

				// Instantiate the tile
				tile #(.X_COORD(x), .Y_COORD(y)) tile_inst (
					.clk         (clk),
					.rst         (rst),
					.in_bytes  	 (tile_in),
					.out_bytes 	 (tile_out)
				);
			  
				// North output (tile_out[0]) → either north_out or vertical wire upward
				if 	(y == MESH_SIZE_Y-1) assign north_out[x] 		= tile_out[0];
				else 								assign wire_sn[x][y] 	= tile_out[0];

				// East output  (tile_out[1]) → either east_out or horizontal wire rightward
				if 	(x == MESH_SIZE_X-1) assign east_out[y] 		= tile_out[1];
				else 								assign wire_we[x][y] 	= tile_out[1];

				// South output (tile_out[2]) → either south_out or vertical wire downward
				if 	(y == 0) 				assign south_out[x] 		= tile_out[2];
				else 								assign wire_ns[x][y-1] = tile_out[2];

				// West output  (tile_out[3]) → either west_out or horizontal wire leftward
				if 	(x == 0) 				assign west_out[y] 		= tile_out[3];
				else 								assign wire_ew[x-1][y] = tile_out[3];

			end
		end
	endgenerate

endmodule 