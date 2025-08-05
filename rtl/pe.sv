`timescale 1ns/1ps
import noc_params::*;

/// Processing Element (PE): accumulates incoming payloads each cycle
module pe (
    input  logic                          clk,      ///< system clock
    input  logic                          rst,      ///< synchronous reset
    input  logic [PAYLOAD_SIZE-1:0]       pe_link  ///< incoming data payload
);

    /// Accumulator register
    logic [PAYLOAD_SIZE-1:0] acc_reg;

    /// Sequential logic: on reset clear accumulator, otherwise accumulate
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            acc_reg <= '0;
        end else begin
            acc_reg <= acc_reg + pe_link;
        end
    end

endmodule
