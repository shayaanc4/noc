package noc_params;

	localparam MESH_SIZE_X = 10;
	localparam MESH_SIZE_Y = 10;
	
	localparam DEST_ADDR_SIZE_X = 4; // $clog2(MESH_SIZE_X);
	localparam DEST_ADDR_SIZE_Y = 4; // $clog2(MESH_SIZE_Y);
	
	localparam PAYLOAD_SIZE_BYTES = 4;
	localparam PAYLOAD_SIZE = 8*PAYLOAD_SIZE_BYTES;
	
	localparam PKT_SIZE = PAYLOAD_SIZE + DEST_ADDR_SIZE_X + DEST_ADDR_SIZE_Y;
	localparam PKT_SIZE_BYTES = PKT_SIZE/8;
	
	typedef struct packed
	{
		logic [DEST_ADDR_SIZE_X-1 : 0] 	x_dest;
		logic [DEST_ADDR_SIZE_Y-1 : 0] 	y_dest;
		logic [PAYLOAD_SIZE-1: 0] 			payload;
	} packet_t;

endpackage
