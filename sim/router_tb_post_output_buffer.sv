`timescale 1ns/1ps
import noc_params::*;
module router_routing_tb;

    // instantiate router at (x=1,y=1) so we can test all directions
    localparam LOGICAL_X = 1;
    localparam LOGICAL_Y = 1;

    logic clk, rst;
    logic [7:0] input_port [0:3];
    logic [PAYLOAD_SIZE*8-1:0] pe_link;

    router #(.x(LOGICAL_X), .y(LOGICAL_Y)) dut (
        .clk(clk),
        .rst(rst),
        .input_port(input_port),
        .output_port(), // unused
        .pe_link(pe_link)
    );

    // clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // routing expectation types
    typedef enum logic [2:0] {
        TO_LOCAL,
        TO_NORTH,
        TO_EAST,
        TO_SOUTH,
        TO_WEST
    } route_t;

    // scoreboard entry
    typedef struct {
        logic [7:0] dest_byte; // {x_dest,y_dest}
        logic [31:0] payload;  // big-endian payload
        route_t expected_route;
        bit seen;
    } expected_entry_t;

    expected_entry_t expected_list[$];

    // helper to add an expected packet and deduce its route
    task automatic add_expected(input logic [3:0] x_dest, input logic [3:0] y_dest, input [31:0] payload);
        expected_entry_t e;
        e.dest_byte = {x_dest, y_dest};
        e.payload = payload;
        if ({x_dest, y_dest} == {LOGICAL_X[3:0], LOGICAL_Y[3:0]})
            e.expected_route = TO_LOCAL;
        else if (y_dest > LOGICAL_Y)
            e.expected_route = TO_NORTH;
        else if (y_dest < LOGICAL_Y)
            e.expected_route = TO_SOUTH;
        else if (x_dest > LOGICAL_X)
            e.expected_route = TO_EAST;
        else if (x_dest < LOGICAL_X)
            e.expected_route = TO_WEST;
        else
            e.expected_route = TO_LOCAL;
        e.seen = 0;
        expected_list.push_back(e);
    endtask

    // send byte pulse
    task automatic send_byte_to_port(input int port, input [7:0] b);
        begin
            input_port[port] = b;
            #10;
        end
    endtask

    // escape logic
    task automatic send_escaped_byte_to_port(input int port, input [7:0] b);
        begin
            if (b == 8'h7E || b == 8'h7D) begin
                send_byte_to_port(port, 8'h7D);
                send_byte_to_port(port, b ^ 8'h20);
            end else begin
                send_byte_to_port(port, b);
            end
        end
    endtask

    // build and send packet: framing {7E, dest, payload[31:24], payload[23:16], payload[15:8], payload[7:0], 7E, 00}
    task automatic send_packet(input int port, input logic [3:0] x_dest, input logic [3:0] y_dest, input [31:0] payload);
        logic [7:0] dest;
        begin
            dest = {x_dest, y_dest};
            add_expected(x_dest, y_dest, payload);
            send_byte_to_port(port, 8'h7E);                   // start
            send_escaped_byte_to_port(port, dest);             // dest
            send_escaped_byte_to_port(port, payload[31:24]);   // payload big-endian
            send_escaped_byte_to_port(port, payload[23:16]);
            send_escaped_byte_to_port(port, payload[15:8]);
            send_escaped_byte_to_port(port, payload[7:0]);
            send_byte_to_port(port, 8'h7E);                   // end
            send_byte_to_port(port, 8'h00);                   // terminator
        end
    endtask

    // scoreboard checking on every cycle
	always @(posedge clk) begin
		 integer i;
		 for (i = 0; i < expected_list.size(); i++) begin
			  if (!expected_list[i].seen) begin
					// declarations first
					automatic expected_entry_t e;
					automatic logic [3:0] x_dest;
					automatic logic [3:0] y_dest;
					automatic bit matched;

					// then assignments
					e = expected_list[i];
					x_dest = e.dest_byte[7:4];
					y_dest = e.dest_byte[3:0];
					matched = 0;

					// LOCAL: should appear on pe_link when dest == router coordinate
					if (e.expected_route == TO_LOCAL) begin
						 if (pe_link == e.payload) begin
							  expected_list[i].seen = 1;
							  matched = 1;
							  $display("[%0t] ROUTED OK LOCAL dest=0x%02h payload=0x%08h",
										  $time, e.dest_byte, e.payload);
						 end
					end else begin
						 // Non-local: check direction-specific output buffer via hierarchical access
						 if (e.expected_route == TO_NORTH) begin
							  if (dut.pkt_out_en[0]
									&& !dut.output_buf_empty[0]
									&& {dut.output_buf_out[0].x_dest, dut.output_buf_out[0].y_dest} == e.dest_byte
									&& dut.output_buf_out[0].payload == e.payload) begin
									expected_list[i].seen = 1;
									matched = 1;
									$display("[%0t] ROUTED OK NORTH dest=0x%02h payload=0x%08h",
												$time, e.dest_byte, e.payload);
							  end
						 end
						 else if (e.expected_route == TO_EAST) begin
							  if (dut.pkt_out_en[1]
									&& !dut.output_buf_empty[1]
									&& {dut.output_buf_out[1].x_dest, dut.output_buf_out[1].y_dest} == e.dest_byte
									&& dut.output_buf_out[1].payload == e.payload) begin
									expected_list[i].seen = 1;
									matched = 1;
									$display("[%0t] ROUTED OK EAST dest=0x%02h payload=0x%08h",
												$time, e.dest_byte, e.payload);
							  end
						 end
						 else if (e.expected_route == TO_SOUTH) begin
							  if (dut.pkt_out_en[2]
									&& !dut.output_buf_empty[2]
									&& {dut.output_buf_out[2].x_dest, dut.output_buf_out[2].y_dest} == e.dest_byte
									&& dut.output_buf_out[2].payload == e.payload) begin
									expected_list[i].seen = 1;
									matched = 1;
									$display("[%0t] ROUTED OK SOUTH dest=0x%02h payload=0x%08h",
												$time, e.dest_byte, e.payload);
							  end
						 end
						 else if (e.expected_route == TO_WEST) begin
							  if (dut.pkt_out_en[3]
									&& !dut.output_buf_empty[3]
									&& {dut.output_buf_out[3].x_dest, dut.output_buf_out[3].y_dest} == e.dest_byte
									&& dut.output_buf_out[3].payload == e.payload) begin
									expected_list[i].seen = 1;
									matched = 1;
									$display("[%0t] ROUTED OK WEST dest=0x%02h payload=0x%08h",
												$time, e.dest_byte, e.payload);
							  end
						 end
					end
			  end
		 end
	end

    // final check
    task automatic check_all_seen();
        integer i;
        for (i = 0; i < expected_list.size(); i++) begin
            if (!expected_list[i].seen) begin
                $error("Missing routed packet: dest=0x%02h payload=0x%08h expected route=%0d",
                       expected_list[i].dest_byte, expected_list[i].payload, expected_list[i].expected_route);
            end
        end
    endtask

    initial begin
        // reset and init
        clk = 0;
        rst = 1;
        input_port[0] = 8'h00;
        input_port[1] = 8'h00;
        input_port[2] = 8'h00;
        input_port[3] = 8'h00;

        #25; rst = 0;
        #5;

        // Test scenarios:
        // 1. Local (dest == {1,1})
        send_packet(0, LOGICAL_X, LOGICAL_Y, 32'hDEADBEEF);       // should appear on pe_link
        // 2. North (y > 1)
        send_packet(1, LOGICAL_X, LOGICAL_Y + 1, 32'hCAFEBABE);   // output_buf_n
        // 3. East (x > 1)
        send_packet(2, LOGICAL_X + 1, LOGICAL_Y, 32'h01234567);   // output_buf_e
        // 4. South (y < 1)
        send_packet(3, LOGICAL_X, LOGICAL_Y - 1, 32'hFEEDFACE);   // output_buf_s
        // 5. West (x < 1)
        send_packet(0, LOGICAL_X - 1, LOGICAL_Y, 32'h0BADF00D);   // output_buf_w

        // give time for routing to propagate
        #500;

        check_all_seen();
        $display("ROUTING TB COMPLETE");
        $finish;
    end


endmodule
