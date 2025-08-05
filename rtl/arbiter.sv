`timescale 1ns/1ps
import noc_params::*;

/// Arbiter: 4-input fixed priority
module arbiter(
    input  logic             buf_empty 	[0:3], ///< high if buffer is empty
    input  packet_t          buf_data  	[0:3], ///< packet data from each buffer
    output logic             buf_rd_en  	[0:3], ///< assert to read from buffer
    output packet_t          grant_pkt,          ///< selected packet output
    output logic             grant_valid         ///< high when a packet is granted
);

    //----------------------------------------------------------------------
    // Default assignments
    //----------------------------------------------------------------------
    always_comb begin
        buf_rd_en    = '{default:1'b0};
        grant_pkt    = '0;
        grant_valid  = 1'b0;

        // Priority: port 0 -> 1 -> 2 -> 3
        if (!buf_empty[0]) begin
            buf_rd_en[0]   = 1'b1;
            grant_pkt      = buf_data[0];
            grant_valid    = 1'b1;
        end else if (!buf_empty[1]) begin
            buf_rd_en[1]   = 1'b1;
            grant_pkt      = buf_data[1];
            grant_valid    = 1'b1;
        end else if (!buf_empty[2]) begin
            buf_rd_en[2]   = 1'b1;
            grant_pkt      = buf_data[2];
            grant_valid    = 1'b1;
        end else if (!buf_empty[3]) begin
            buf_rd_en[3]   = 1'b1;
            grant_pkt      = buf_data[3];
            grant_valid    = 1'b1;
        end
    end

endmodule
