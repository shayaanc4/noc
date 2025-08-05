`timescale 1ns/1ps
import noc_params::*;
module router_tb_simple;

    logic clk, rst;
    logic [7:0] input_port [0:3];
    logic [7:0] output_port [0:3];
    logic [PAYLOAD_SIZE-1:0] pe_link;

    // Instantiate router (assumes DATA_SZ is defined in noc_params)
    router dut (
        .clk(clk),
        .rst(rst),
        .input_port(input_port),
        .output_port(output_port),
        .pe_link(pe_link)
    );

    // simple change detection for outputs
    always @(posedge clk) begin
        integer i;
        for (i = 0; i < 4; i++) begin
            if (output_port[i] !== 8'hx)
                $display("[%0t] output_port[%0d] = 0x%02h", $time, i, output_port[i]);
        end
        $display("[%0t] pe_link = 0x%0h", $time, pe_link);
    end

    always #5 clk = ~clk;

    // internal function to send a byte with escaping rules
    task automatic send_byte_to_port(input int port, input [7:0] b);
        begin
            input_port[port] = b;
            #10;
        end
    endtask

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

    task automatic send_packet(input int port, input [7:0] dest, input [31:0] data);
        begin
            // Frame start
            send_byte_to_port(port, 8'h7E);
            // Destination (with escaping)
            send_escaped_byte_to_port(port, dest);
            send_escaped_byte_to_port(port, data[31:24]);
            send_escaped_byte_to_port(port, data[23:16]);
				send_escaped_byte_to_port(port, data[15:8]);
				send_escaped_byte_to_port(port, data[7:0]);
            // Frame end
            send_byte_to_port(port, 8'h7E);
            // Padding
            send_byte_to_port(port, 8'h00);
        end
    endtask

    initial begin
        // initialize
        clk = 1;
        rst = 1;
        input_port[0] = 8'h00;
        input_port[1] = 8'h00;
        input_port[2] = 8'h00;
        input_port[3] = 8'h00;

        #20; rst = 0;
        #5;

        // Send same example packet to all four ports in staggered fashion
        // Packet: dest=0x11, data=0x2233, framed with 0x7E and no escapes needed here
        send_packet(0, 8'h11, 32'h11111111); 
		  send_packet(1, 8'h11, 32'h22222222);
        #10;
        send_packet(2, 8'h11, 32'h33333333);
        #10;
        send_packet(3, 8'h11, 32'h44444444);

        // Send packet with escapes: dest=0x7E, data=7D44
        send_packet(0, 8'h00, 32'h22222222);
        #10;
        send_packet(1, 8'h00, 32'h33333333);

        // Another with escaped low byte: dest=0x01, data=0x027E
        send_packet(2, 8'h10, 32'h44444444);
        #10;
        send_packet(3, 8'h10, 32'h55555555);

        #200;
        $stop;
    end

endmodule
