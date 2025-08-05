`timescale 1ns/1ps
import noc_params::*;
module packet_receiver_tb;

    logic clk, rst;
    logic [7:0] in_byte;
    packet_t pkt;
    logic out_valid;

    packet_receiver uut (
        .clk(clk),
        .rst(rst),
        .in_byte(in_byte),
        .pkt(pkt),
        .out_valid(out_valid)
    );

    always #5 clk = ~clk;

    // Task to send a byte on the input line
    task send_byte(input [7:0] b);
        begin
            in_byte = b;
            #10;
        end
    endtask

    initial begin

        clk = 1; rst = 1; in_byte = 8'h00;

        #20; rst = 0;

        #5;

        // Packet 1: {7E, 11, 22, 33, 7E} → dest = 11, data = 0x2233
        send_byte(8'h7E);
        send_byte(8'h11);
        send_byte(8'h22);
        send_byte(8'h33);
        send_byte(8'h44);
        send_byte(8'h55);
        send_byte(8'h7E);
        send_byte(8'h00);

        // Packet 2: {7E, 7D, 5E, 7D, 5D, 44, 7E}
        // dest = 7E, data = 7D44
        send_byte(8'h7E);
        send_byte(8'h7D); send_byte(8'h5E); // ESC dest = 7E
        send_byte(8'h7D); send_byte(8'h5D); // ESC data_hi = 7D
        send_byte(8'h44);                   // data_lo
        send_byte(8'h55);
        send_byte(8'h7D); send_byte(8'h5D);
        send_byte(8'h7E);
        send_byte(8'h00);

        // Packet 3: {7E, 01, 02, 7D, 5E, 7E}
        // dest = 01, data = 0x027E
        send_byte(8'h7E);
        send_byte(8'h01);
        send_byte(8'h02);
        send_byte(8'h7D); send_byte(8'h5E); // ESC data_lo = 7E
        send_byte(8'h7D); send_byte(8'h5D);
        send_byte(8'h11);
        send_byte(8'h7E);
        send_byte(8'h00);

        #100;
        $finish;
    end

endmodule