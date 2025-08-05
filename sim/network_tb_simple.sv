`timescale 1ns/1ps
import noc_params::*;

module network_tb_simple;

  // Clock and reset
  logic clk, rst;

  // Boundary I/O
  logic [7:0] south_in   [0:MESH_SIZE_X-1];
  logic [7:0] south_out  [0:MESH_SIZE_X-1];
  logic [7:0] north_in   [0:MESH_SIZE_X-1];  // tied to 0
  logic [7:0] north_out  [0:MESH_SIZE_X-1];
  logic [7:0] west_in    [0:MESH_SIZE_Y-1];  // tied to 0
  logic [7:0] west_out   [0:MESH_SIZE_Y-1];
  logic [7:0] east_in    [0:MESH_SIZE_Y-1];  // tied to 0
  logic [7:0] east_out   [0:MESH_SIZE_Y-1];

  // DUT
  network dut (
    .clk(clk), .rst(rst),
    .south_in (south_in),
    .south_out(south_out),
    .north_in (north_in),
    .north_out(north_out),
    .west_in  (west_in),
    .west_out (west_out),
    .east_in  (east_in),
    .east_out (east_out)
  );

  // Tie unused inputs to 0
  initial begin
    north_in = '{default:8'h00};
    west_in  = '{default:8'h00};
    east_in  = '{default:8'h00};
  end

  // Clock
  initial clk = 0;
  always #5 clk = ~clk;

  // Decoders on each edge
  packet_t south_pkt  [0:MESH_SIZE_X-1]; logic south_valid  [0:MESH_SIZE_X-1];
  packet_t north_pkt  [0:MESH_SIZE_X-1]; logic north_valid  [0:MESH_SIZE_X-1];
  packet_t east_pkt   [0:MESH_SIZE_Y-1]; logic east_valid   [0:MESH_SIZE_Y-1];

  genvar i;
  generate
    for (i = 0; i < MESH_SIZE_X; i++) begin : SOUTH_DEC
      packet_receiver pr_s (
        .clk(clk), .rst(rst),
        .in_byte(south_out[i]),
        .pkt(south_pkt[i]),
        .out_valid(south_valid[i])
      );
      packet_receiver pr_n (
        .clk(clk), .rst(rst),
        .in_byte(north_out[i]),
        .pkt(north_pkt[i]),
        .out_valid(north_valid[i])
      );
    end
    for (i = 0; i < MESH_SIZE_Y; i++) begin : EAST_DEC
      packet_receiver pr_e (
        .clk(clk), .rst(rst),
        .in_byte(east_out[i]),
        .pkt(east_pkt[i]),
        .out_valid(east_valid[i])
      );
    end
  endgenerate

  // Helpers to send into south_in[port]
  task automatic send_byte(input int port, input logic [7:0] b);
    begin
      south_in[port] = b;
      #10;
    end
  endtask

  task automatic send_escaped(input int port, input logic [7:0] b);
    begin
      if (b == 8'h7E || b == 8'h7D) begin
        send_byte(port, 8'h7D);
        send_byte(port, b ^ 8'h20);
      end else
        send_byte(port, b);
    end
  endtask

  task automatic send_packet(input int port,
                             input logic [3:0] x_dest,
                             input logic [3:0] y_dest,
                             input logic [31:0] data);
    logic [7:0] dest8 = {x_dest, y_dest};
    begin
      // frame: 7E, dest, data[31:24], data[23:16], data[15:8], data[7:0], 7E, 00
      send_byte(port, 8'h7E);
      send_escaped(port, dest8);
      send_escaped(port, data[31:24]);
      send_escaped(port, data[23:16]);
      send_escaped(port, data[15:8]);
      send_escaped(port, data[7:0]);
      send_byte(port, 8'h7E);
      send_byte(port, 8'h00);
    end
  endtask

  // Test sequence: send 3 packets from the south edge
  initial begin
    rst = 1; South_init: south_in = '{default:8'h00};
    #20; rst = 0; #5;

    // 1) Dest at top row y=MESH_SIZE_Y-1 → should appear on north_out[x]
    send_packet(0, 4'h2, MESH_SIZE_Y-1, 32'hDEADBEEF);

    // 2) Dest on east edge x=MESH_SIZE_X-1, some middle row y=1 → appears on east_out[y]
    send_packet(1, MESH_SIZE_X-1, 4'h1, 32'hCAFEBABE);

    // 3) Dest on bottom row y=0, different x → local south edge → appears on south_out[x]
    send_packet(2, 4'h3, 4'h0, 32'h01234567);

    // wait for all to emerge
    #500;

    // Simple display of what we saw:
    if (north_valid[2]) $display("NORTH[2] => dest=0x%02h data=0x%08h",
                                 {north_pkt[2].x_dest,north_pkt[2].y_dest},
                                 north_pkt[2].payload);
    if (east_valid[1])  $display("EAST[1]  => dest=0x%02h data=0x%08h",
                                 {east_pkt[1].x_dest,east_pkt[1].y_dest},
                                 east_pkt[1].payload);
    if (south_valid[3]) $display("SOUTH[3] => dest=0x%02h data=0x%08h",
                                 {south_pkt[3].x_dest,south_pkt[3].y_dest},
                                 south_pkt[3].payload);

    $display("NETWORK TB DONE");
    $finish;
  end

endmodule