`timescale 1ns/1ps
import noc_params::*;

/// Tile unit: instantiates a router and a processing element (PE)
module tile #(
    parameter int X_COORD = 0,       		///< tile's X coordinate in mesh
    parameter int Y_COORD = 0        		///< tile's Y coordinate in mesh
)(
    input  logic         clk,        		///< system clock
    input  logic         rst,        		///< asynchronous reset
    input  logic [7:0]   in_bytes  [0:3], ///< byte inputs {0=N,1=E,2=S,3=W}
    output logic [7:0]   out_bytes [0:3]  ///< byte outputs {0=N,1=E,2=S,3=W}
);

    //----------------------------------------------------------------------
    // Local payload bus from router to PE
    //----------------------------------------------------------------------
    logic [PAYLOAD_SIZE-1:0] pe_payload;

    //----------------------------------------------------------------------
    // Router instance: handles all routing for this tile
    //----------------------------------------------------------------------
    router #(
      .X_COORD(X_COORD),
      .Y_COORD(Y_COORD)
    ) u_router (
      .clk         (clk),
      .rst         (rst),
      .in_bytes    (in_bytes),
      .out_bytes   (out_bytes),
      .pe_link     (pe_payload)
    );

    //----------------------------------------------------------------------
    // Processing Element (PE): consumes payload from router
    //----------------------------------------------------------------------
    pe u_pe (
      .clk      (clk),
      .rst      (rst),
      .pe_link  (pe_payload)
    );

endmodule 
