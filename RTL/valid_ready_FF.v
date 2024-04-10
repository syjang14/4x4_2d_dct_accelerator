`timescale 1ns / 1ps

module valid_ready_FF #(
    parameter DATA_WIDTH = 128
)
(
    input clk,
    input reset,

    input                   i_valid,
    output                  i_ready,
    input  [DATA_WIDTH-1:0] i_data,

    output reg                  o_valid,
    input                       o_ready,
    output reg [DATA_WIDTH-1:0] o_data
);

    assign i_ready = o_ready | ~o_valid;

    always @(posedge clk) begin
        if(reset) begin
            o_valid <= 1'b0;
            o_data  <= 'd0;
        end
        else if(i_ready) begin
            o_valid <= i_valid;
            o_data  <= i_data;
        end
    end

endmodule