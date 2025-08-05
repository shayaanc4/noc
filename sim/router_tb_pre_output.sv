`timescale 1ns/1ps
import noc_params::*;
module router_tb_pre_output;

    logic clk, rst;
    logic [7:0] input_port [0:3];
    logic [7:0] output_port [0:3];
    logic [PAYLOAD_SIZE-1:0] pe_link; // monitor if needed

    // DUT
    router dut (
        .clk(clk),
        .rst(rst),
        .input_port(input_port),
        .output_port(output_port),
        .pe_link(pe_link)
    );

    // simple visibility monitor
//    always @(posedge clk) begin
//        integer i;
//        for (i = 0; i < 4; i++) begin
//            if (output_port[i] !== 8'hx)
//                $display("[%0t] output_port[%0d] = 0x%02h", $time, i, output_port[i]);
//        end
//        $display("[%0t] pe_link = 0x%0h", $time, pe_link);
//    end

    // clock
    initial clk = 0;
    always #5 clk = ~clk;

    // Scoreboard entry
    typedef struct {
        logic [7:0] dest_byte; // {x_dest, y_dest}
        logic [31:0] data;
        bit seen;
    } expected_entry_t;

    expected_entry_t expected_list[$];

    // Add expected with x,y and human payload
    task automatic add_expected_xy(input logic [3:0] x_dest, input logic [3:0] y_dest, input [31:0] data);
		 expected_entry_t e;
		 e.dest_byte = {x_dest, y_dest}; // direct {x,y}
		 e.data = data;
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

    // escaping
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

    // send one packet (frame: 7E dest data[3:0] end 7E then 00)
    task automatic send_packet(input int port, input [7:0] dest, input [31:0] data);
        begin
            send_byte_to_port(port, 8'h7E);
            send_escaped_byte_to_port(port, dest);
            send_escaped_byte_to_port(port, data[31:24]);
            send_escaped_byte_to_port(port, data[23:16]);
            send_escaped_byte_to_port(port, data[15:8]);
            send_escaped_byte_to_port(port, data[7:0]);
            send_byte_to_port(port, 8'h7E);
            send_byte_to_port(port, 8'h00);
        end
    endtask

    // per-port burst traffic
    task automatic traffic_on_port(input int port, input logic [3:0] x_dest, input logic [3:0] y_dest);
        integer i;
        logic [7:0] dest;
        logic [31:0] payload;
        begin
            for (i = 0; i < 3; i++) begin
                dest = {x_dest + i, y_dest}; // example variation in x
                payload = $urandom; // random 32-bit
                add_expected_xy(dest[7:4], dest[3:0], payload);
                send_packet(port, dest, payload);
                #($urandom_range(0,2)*10);
            end
        end
    endtask

    // normalize observed packet and match
    function automatic string pkt_to_string(packet_t p);
		 automatic logic [7:0] norm_dest;
		 automatic logic [31:0] norm_data;
		 begin
			  norm_dest = {p.x_dest, p.y_dest}; 
			  norm_data = p.payload;
			  return $sformatf("sel_pkt: dest=0x%02h data=0x%08h", norm_dest, norm_data);
		 end
	endfunction

    always @(posedge clk) begin
		 if (dut.arb.o_valid) begin
			  automatic packet_t p;
			  automatic logic [7:0] seen_dest;
			  automatic logic [31:0] seen_data;
			  automatic integer idx;
			  automatic bit matched;

			  p = dut.arb.sel_pkt;
			  seen_dest = {p.x_dest, p.y_dest};
			  seen_data = p.payload;
			  matched = 0;

			  for (idx = 0; idx < expected_list.size(); idx++) begin
					if (!expected_list[idx].seen
						 && expected_list[idx].dest_byte == seen_dest
						 && expected_list[idx].data == seen_data) begin
						 expected_list[idx].seen = 1;
						 matched = 1;
						 $display("[%0t] MATCHED packet: dest=0x%02h data=0x%08h (entry %0d)",
									 $time, seen_dest, seen_data, idx);
						 break;
					end
			  end
			  if (!matched) begin
					$display("[%0t] WARNING: unexpected or duplicate sel_pkt: %s", $time, pkt_to_string(p));
			  end
		 end
	end

    // final check
    task automatic check_all_seen();
        integer i;
        for (i = 0; i < expected_list.size(); i++) begin
            if (!expected_list[i].seen) begin
                $error("Expected packet not seen: dest=0x%02h data=0x%08h (idx %0d)",
                       expected_list[i].dest_byte, expected_list[i].data, i);
            end
        end
    endtask

    initial begin
        // init
        clk = 0;
        rst = 1;
        input_port[0] = 8'h00;
        input_port[1] = 8'h00;
        input_port[2] = 8'h00;
        input_port[3] = 8'h00;

        #25; rst = 0;
        #5;

        // concurrent traffic to stress arbiter
        fork
            begin
                traffic_on_port(0, 4'h1, 4'h0); // dests 0x10,0x20,...
            end
            begin
                traffic_on_port(1, 4'h2, 4'h0);
            end
            begin
                traffic_on_port(2, 4'h3, 4'h0);
            end
            begin
                traffic_on_port(3, 4'h4, 4'h0);
            end
        join

        // manual overlapping bursts
        fork
            begin
                add_expected_xy(4'hA, 4'hA, 32'hDEADBEEF);
                send_packet(0, {4'hA,4'hA}, 32'hDEADBEEF);
                #15;
                add_expected_xy(4'hB, 4'hB, 32'hCAFEBABE);
                send_packet(0, {4'hB,4'hB}, 32'hCAFEBABE);
            end
            begin
                add_expected_xy(4'hC, 4'hC, 32'h01234567);
                send_packet(1, {4'hC,4'hC}, 32'h01234567);
                #5;
                add_expected_xy(4'hD, 4'hD, 32'h89ABCDEF);
                send_packet(1, {4'hD,4'hD}, 32'h89ABCDEF);
            end
            begin
                add_expected_xy(4'hE, 4'hE, 32'hFEEDFACE);
                send_packet(2, {4'hE,4'hE}, 32'hFEEDFACE);
            end
            begin
                add_expected_xy(4'hF, 4'hF, 32'h0BADF00D);
                send_packet(3, {4'hF,4'hF}, 32'h0BADF00D);
            end
        join

        // wait for arbiter outputs to settle
        #500;

        check_all_seen();

        $display("TESTBENCH COMPLETE");
        $stop;
    end

endmodule