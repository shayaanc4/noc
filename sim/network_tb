`timescale 1ns/1ps
import noc_params::*;

module network_tb;

  //------------------------------------------------------------------------
  // Parameters & directions
  //------------------------------------------------------------------------
  localparam int NX       = MESH_SIZE_X;
  localparam int NY       = MESH_SIZE_Y;
  localparam int NUM_PKTS = 5;
  typedef enum int { DIR_SOUTH, DIR_NORTH, DIR_WEST, DIR_EAST } inject_dir_e;

  //------------------------------------------------------------------------
  // Clock, reset, boundary I/O
  //------------------------------------------------------------------------
  logic           clk, rst;
  logic [7:0]     south_in  [0:NX-1], south_out [0:NX-1];
  logic [7:0]     north_in  [0:NX-1], north_out [0:NX-1];
  logic [7:0]     west_in   [0:NY-1], west_out  [0:NY-1];
  logic [7:0]     east_in   [0:NY-1], east_out  [0:NY-1];

  //------------------------------------------------------------------------
  // DUT
  //------------------------------------------------------------------------
  network dut (
    .clk       (clk),     .rst       (rst),
    .south_in  (south_in),.south_out (south_out),
    .north_in  (north_in),.north_out (north_out),
    .west_in   (west_in), .west_out  (west_out),
    .east_in   (east_in), .east_out  (east_out)
  );

  // tie off unused inputs
  initial begin
    south_in = '{default:8'h00};
    north_in = '{default:8'h00};
    west_in  = '{default:8'h00};
    east_in  = '{default:8'h00};
  end

  // clock
  initial clk = 0;
  always #5 clk = ~clk;

  //------------------------------------------------------------------------
  // Packet decoders on each boundary
  //------------------------------------------------------------------------
  packet_t south_pkt  [0:NX-1]; logic south_vld  [0:NX-1];
  packet_t north_pkt  [0:NX-1]; logic north_vld  [0:NX-1];
  packet_t  west_pkt  [0:NY-1]; logic  west_vld  [0:NY-1];
  packet_t  east_pkt  [0:NY-1]; logic  east_vld  [0:NY-1];

  genvar i;
  generate
    for (i = 0; i < NX; i++) begin : SN_DEC
      packet_receiver pr_s (
        .clk(clk), .rst(rst),
        .in_byte(south_out[i]),
        .pkt(south_pkt[i]),
        .out_valid(south_vld[i])
      );
      packet_receiver pr_n (
        .clk(clk), .rst(rst),
        .in_byte(north_out[i]),
        .pkt(north_pkt[i]),
        .out_valid(north_vld[i])
      );
    end
    for (i = 0; i < NY; i++) begin : WE_DEC
      packet_receiver pr_w (
        .clk(clk), .rst(rst),
        .in_byte(west_out[i]),
        .pkt(west_pkt[i]),
        .out_valid(west_vld[i])
      );
      packet_receiver pr_e (
        .clk(clk), .rst(rst),
        .in_byte(east_out[i]),
        .pkt(east_pkt[i]),
        .out_valid(east_vld[i])
      );
    end
  endgenerate

  //------------------------------------------------------------------------
  // Scoreboard entry type
  //------------------------------------------------------------------------
  typedef struct {
    logic [7:0]    dest_byte;
    logic [31:0]   payload;
    inject_dir_e   egress_dir;
    int            egress_port;
    bit            seen;
  } exp_entry_t;

  exp_entry_t expected_list[$];

  //------------------------------------------------------------------------
  // Add to scoreboard only if on boundary
  //------------------------------------------------------------------------
  task automatic add_expected(
    inject_dir_e    egr_dir,
    int              egr_port,
    logic [3:0]      x_dest,
    logic [3:0]      y_dest,
    logic [31:0]     data
  );
    exp_entry_t e;
    e.dest_byte    = {x_dest,y_dest};
    e.payload      = data;
    e.egress_dir   = egr_dir;
    e.egress_port  = egr_port;
    e.seen         = 0;
    expected_list.push_back(e);
  endtask

  //------------------------------------------------------------------------
  // Byte‐level traffic tasks
  //------------------------------------------------------------------------
  task automatic send_byte(
    inject_dir_e dir,
    int           port,
    logic [7:0]   b
  );
    begin
      case(dir)
        DIR_SOUTH: south_in[port] = b;
        DIR_NORTH: north_in[port] = b;
        DIR_WEST :  west_in[port]  = b;
        DIR_EAST :  east_in[port]  = b;
      endcase
      #10;
    end
  endtask

  task automatic send_escaped(
    inject_dir_e dir,
    int           port,
    logic [7:0]   b
  );
    begin
      if (b==8'h7E||b==8'h7D) begin
        send_byte(dir,port,8'h7D);
        send_byte(dir,port,b ^ 8'h20);
      end else
        send_byte(dir,port,b);
    end
  endtask

  //------------------------------------------------------------------------
  // Packet injection: only scoreboard boundary‐destined ones
  //------------------------------------------------------------------------
  task automatic send_packet(
    inject_dir_e dir,
    int           port,
    logic [3:0]   x_dest,
    logic [3:0]   y_dest,
    logic [31:0]  data
  );
    logic [7:0] dest8 = {x_dest,y_dest};
    inject_dir_e route;
    int           route_port;
    begin
      // pick egress
      if      (y_dest == 0)       begin route = DIR_SOUTH; route_port = x_dest; end
      else if (y_dest == NY-1)    begin route = DIR_NORTH; route_port = x_dest; end
      else if (x_dest == 0)       begin route = DIR_WEST;  route_port = y_dest; end
      else if (x_dest == NX-1)    begin route = DIR_EAST;  route_port = y_dest; end
      else begin
        // interior: skip scoreboard
        route = DIR_SOUTH; route_port = 0;
      end

      // only record if on perimeter
      if ( (y_dest==0) || (y_dest==NY-1) 
        || (x_dest==0) || (x_dest==NX-1) ) 
      begin
        add_expected(route, route_port, x_dest, y_dest, data);
      end

      // framing
      send_byte   (dir,port,8'h7E);
      send_escaped(dir,port,dest8);
      send_escaped(dir,port,data[31:24]);
      send_escaped(dir,port,data[23:16]);
      send_escaped(dir,port,data[15:8]);
      send_escaped(dir,port,data[7:0]);
      send_byte   (dir,port,8'h7E);
      send_byte   (dir,port,8'h00);
    end
  endtask

  //------------------------------------------------------------------------
  // Scoreboard monitor
  //------------------------------------------------------------------------
  always @(posedge clk) begin
    foreach (expected_list[idx]) begin
      if (!expected_list[idx].seen) begin
        automatic exp_entry_t e = expected_list[idx];
        case(e.egress_dir)
          DIR_SOUTH: if ( south_vld[e.egress_port]
                     && {south_pkt[e.egress_port].x_dest,
                         south_pkt[e.egress_port].y_dest} == e.dest_byte
                     && south_pkt[e.egress_port].payload    == e.payload) begin
                        expected_list[idx].seen = 1;
                        $display("[%0t] SEEN SOUTH[%0d] dest=0x%02h data=0x%08h",
                                 $time,e.egress_port,e.dest_byte,e.payload);
                     end
          DIR_NORTH: if ( north_vld[e.egress_port]
                     && {north_pkt[e.egress_port].x_dest,
                         north_pkt[e.egress_port].y_dest} == e.dest_byte
                     && north_pkt[e.egress_port].payload    == e.payload) begin
                        expected_list[idx].seen = 1;
                        $display("[%0t] SEEN NORTH[%0d] dest=0x%02h data=0x%08h",
                                 $time,e.egress_port,e.dest_byte,e.payload);
                     end
          DIR_WEST:  if (  west_vld[e.egress_port]
                     && { west_pkt[e.egress_port].x_dest,
                          west_pkt[e.egress_port].y_dest} == e.dest_byte
                     &&  west_pkt[e.egress_port].payload    == e.payload) begin
                        expected_list[idx].seen = 1;
                        $display("[%0t] SEEN WEST[%0d]  dest=0x%02h data=0x%08h",
                                 $time,e.egress_port,e.dest_byte,e.payload);
                     end
          DIR_EAST:  if (  east_vld[e.egress_port]
                     && { east_pkt[e.egress_port].x_dest,
                          east_pkt[e.egress_port].y_dest} == e.dest_byte
                     &&  east_pkt[e.egress_port].payload    == e.payload) begin
                        expected_list[idx].seen = 1;
                        $display("[%0t] SEEN EAST[%0d]  dest=0x%02h data=0x%08h",
                                 $time,e.egress_port,e.dest_byte,e.payload);
                     end
        endcase
      end
    end
  end

  //------------------------------------------------------------------------
  // Final check
  //------------------------------------------------------------------------
  task automatic check_all();
    foreach (expected_list[i]) begin
      if (!expected_list[i].seen) begin
        $error("MISSING: egr_dir=%0d egr_port=%0d dest=0x%02h data=0x%08h",
               expected_list[i].egress_dir,
               expected_list[i].egress_port,
               expected_list[i].dest_byte,
               expected_list[i].payload);
      end
    end
  endtask

  //------------------------------------------------------------------------
  // Test sequence
  //------------------------------------------------------------------------
  initial begin
    rst = 1;
    #20; rst = 0;
    #5;

    for (int idx = 0; idx < NUM_PKTS; idx++) begin
      automatic inject_dir_e d      = inject_dir_e'($urandom_range(0,3));
      automatic int           port   = (d==DIR_SOUTH||d==DIR_NORTH)
                                      ? $urandom_range(0,NX-1)
                                      : $urandom_range(0,NY-1);
      automatic logic [3:0]   xdest  = $urandom_range(0,NX-1);
      automatic logic [3:0]   ydest  = $urandom_range(0,NY-1);
      automatic logic [31:0]  payload= $urandom;

      send_packet(d, port, xdest, ydest, payload);
      #($urandom_range(1,5)*10);
    end

    #2000;
    check_all();
    $display("=== ADVANCED NETWORK TB COMPLETE ===");
    $stop;
  end

endmodule
