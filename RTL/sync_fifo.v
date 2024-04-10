`timescale 1ns / 1ps

module sync_fifo #( 
    parameter FIFO_IN_REG	  = 1,
	parameter FIFO_OUT_REG	  = 1,
	parameter FIFO_DATA_WIDTH = 32,
	parameter FIFO_DEPTH      = 4
)
(
    input clk,
	input reset,

	input          				 s_valid,
	output      				 s_ready,
	input  [FIFO_DATA_WIDTH-1:0] s_data,

	output         				 m_valid,
	input          				 m_ready,
	output [FIFO_DATA_WIDTH-1:0] m_data
);

// declaration
    localparam LOG_FIFO_DEPTH = $clog2(FIFO_DEPTH);

    wire                       w_s_valid;
    wire                       w_s_ready;
    wire [FIFO_DATA_WIDTH-1:0] w_s_data;
    wire                       w_m_valid;
    wire                       w_m_ready;
    wire [FIFO_DATA_WIDTH-1:0] w_m_data;

    wire full, empty;

    wire i_hs = w_s_valid & w_s_ready;
    wire o_hs = w_m_valid & w_m_ready;

    reg [LOG_FIFO_DEPTH-1:0]  wptr, wptr_nxt;
    reg [LOG_FIFO_DEPTH-1:0]  rptr, rptr_nxt;
    reg                       wptr_phase, wptr_phase_nxt;
    reg                       rptr_phase, rptr_phase_nxt;
    reg [FIFO_DATA_WIDTH-1:0] mem[0:FIFO_DEPTH-1];

// fifo write pointer
    integer i;
    always @(posedge clk) begin
        if(reset) begin
            wptr       <= 'd0;
            wptr_phase <= 'd0;
            for(i=0; i<FIFO_DEPTH; i=i+1)
                mem[i] <= 'd0;
        end
        else if(i_hs) begin
            wptr       <= wptr_nxt;
            wptr_phase <= wptr_phase_nxt;
            mem[wptr]  <= w_s_data;
        end
    end

    always @(*) begin
        if(wptr == FIFO_DEPTH-1) begin
            wptr_nxt       = 'd0;
            wptr_phase_nxt = ~wptr_phase;
        end
        else begin
            wptr_nxt       = wptr + 1'b1;
            wptr_phase_nxt = wptr_phase;
        end
    end

// fifo read pointer
    always @(posedge clk) begin
        if(reset) begin
            rptr       <= 'd0;
            rptr_phase <= 'd0;
        end
        else if(o_hs) begin
            rptr       <= rptr_nxt;
            rptr_phase <= rptr_phase_nxt;
        end
    end

    always @(*) begin
        if(rptr == FIFO_DEPTH-1) begin
            rptr_nxt       = 'd0;
            rptr_phase_nxt = ~rptr_phase;
        end
        else begin
            rptr_nxt       = rptr + 1'b1;
            rptr_phase_nxt = rptr_phase;
        end
    end

    assign w_m_data = mem[rptr];

// full, empty
    assign full  = (wptr == rptr) & (wptr_phase != rptr_phase);
    assign empty = (wptr == rptr) & (wptr_phase == rptr_phase);

    assign w_s_ready = ~full;
    assign w_m_valid = ~empty;

// skid buffer
    generate
        if(FIFO_IN_REG) begin
            skid_buffer #(
                .DATA_WIDTH(FIFO_DATA_WIDTH)
            ) u_skid_buffer_in(
                .clk  (clk),
                .reset(reset),

                .s_valid(s_valid),
                .s_ready(s_ready),
                .s_data	(s_data),

                .m_valid(w_s_valid),
                .m_ready(w_s_ready),
                .m_data	(w_s_data)
            );
        end
        else begin
            assign w_s_valid = s_valid;
            assign s_ready   = w_s_ready;
            assign w_s_data  = s_data;
        end
    endgenerate

    generate
        if(FIFO_OUT_REG) begin
            skid_buffer #(
                .DATA_WIDTH(FIFO_DATA_WIDTH)
            ) u_skid_buffer_out(
                .clk  (clk),
                .reset(reset),

                .s_valid(w_m_valid),
                .s_ready(w_m_ready),
                .s_data	(w_m_data),

                .m_valid(m_valid),
                .m_ready(m_ready),
                .m_data	(m_data)
            );
        end
        else begin
            assign m_valid   = w_m_valid;
            assign w_m_ready = m_ready;
            assign m_data    = w_m_data;
        end
    endgenerate

endmodule