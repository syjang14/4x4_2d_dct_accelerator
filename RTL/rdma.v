module rdma #(
    parameter C_M_AXI_GMEM_ID_WIDTH     = 1,
    parameter C_M_AXI_GMEM_ADDR_WIDTH   = 32,
    parameter C_M_AXI_GMEM_DATA_WIDTH   = 64,
    parameter C_M_AXI_GMEM_ARUSER_WIDTH = 1,
    parameter C_M_AXI_GMEM_RUSER_WIDTH  = 1
)
(
    input                                    ap_clk,
    input                                    ap_rst_n,

    input                                    ap_start,
    output                                   ap_idle,
    output                                   ap_ready,
    output                                   ap_done,

    input [C_M_AXI_GMEM_ADDR_WIDTH-1:0]      transfer_byte,
    input [C_M_AXI_GMEM_ADDR_WIDTH-1:0]      mem,

    output [C_M_AXI_GMEM_ID_WIDTH-1:0]       m_axi_gmem_ARID,
    output                                   m_axi_gmem_ARVALID,
    input                                    m_axi_gmem_ARREADY,
    output [C_M_AXI_GMEM_ADDR_WIDTH-1:0]     m_axi_gmem_ARADDR,
    output [7:0]                             m_axi_gmem_ARLEN,
    output [2:0]                             m_axi_gmem_ARSIZE,
    output [1:0]                             m_axi_gmem_ARBURST,
    output [1:0]                             m_axi_gmem_ARLOCK,
    output [3:0]                             m_axi_gmem_ARCACHE,
    output [2:0]                             m_axi_gmem_ARPROT,
    output [3:0]                             m_axi_gmem_ARQOS,
    output [3:0]                             m_axi_gmem_ARREGION,
    output [C_M_AXI_GMEM_ARUSER_WIDTH-1:0]   m_axi_gmem_ARUSER,

    input  [C_M_AXI_GMEM_ID_WIDTH-1:0]       m_axi_gmem_RID,
    input                                    m_axi_gmem_RVALID,
    output                                   m_axi_gmem_RREADY,
    input  [C_M_AXI_GMEM_DATA_WIDTH-1:0]     m_axi_gmem_RDATA,
    input  [1:0]                             m_axi_gmem_RRESP,
    input                                    m_axi_gmem_RLAST,
    input  [C_M_AXI_GMEM_RUSER_WIDTH-1:0]    m_axi_gmem_RUSER,

    output                                   empty_n,
    input                                    rd_en,
    output [C_M_AXI_GMEM_DATA_WIDTH-1:0]     dout
);

// gen ap_rst
    reg ap_rst;
    always @(posedge ap_clk) begin
        ap_rst <= ~ap_rst_n;
    end

// declaration
    localparam S_IDLE = 2'b00;
    localparam S_PRE  = 2'b01;
    localparam S_RUN  = 2'b10;
    localparam S_DONE = 2'b11;

	localparam AXI_DATA_SHIFT = $clog2(C_M_AXI_GMEM_DATA_WIDTH/8);
    localparam NUM_AXI_AR_MOR = 8'd4;
    localparam NUM_MAX_BURST  = 4;
    localparam NUM_ARLEN_BIT  = 9;

    reg [1:0] c_state, n_state;
    reg [1:0] c_state_ar, n_state_ar;
    reg [1:0] c_state_r, n_state_r;

	wire run;  
	wire is_done;
	wire is_done_ar;

    reg [C_M_AXI_GMEM_ADDR_WIDTH-1:0] r_transfer_byte;
    reg [C_M_AXI_GMEM_ADDR_WIDTH-1:0] r_mem;

    reg [C_M_AXI_GMEM_ADDR_WIDTH-AXI_DATA_SHIFT-1:0] r_num_hs_in_transfer;
    reg [C_M_AXI_GMEM_ADDR_WIDTH-1:0]                r_rdma_base_addr;

	wire ar_fifo_full_n;
	wire ar_fifo_empty_n;
	wire ar_fifo_read;

	wire ar_hs = m_axi_gmem_ARVALID & m_axi_gmem_ARREADY;
	wire r_hs  = m_axi_gmem_RVALID  & m_axi_gmem_RREADY;

    reg [C_M_AXI_GMEM_ADDR_WIDTH-AXI_DATA_SHIFT-1:0] r_ar_hs_cnt;
    reg [C_M_AXI_GMEM_ADDR_WIDTH-AXI_DATA_SHIFT-1:0] r_r_hs_cnt;

    wire [NUM_ARLEN_BIT-1:0] burst_len_ar;
    wire [NUM_ARLEN_BIT-1:0] burst_len_r;
    reg  [NUM_ARLEN_BIT-1:0] r_burst_len_ar;
    reg  [NUM_ARLEN_BIT-1:0] r_m_axi_gmem_ARLEN;

    wire [C_M_AXI_GMEM_ADDR_WIDTH-AXI_DATA_SHIFT-1:0] remain_hs;

    wire [C_M_AXI_GMEM_ADDR_WIDTH-1:0] rdma_offset_addr;
    wire [C_M_AXI_GMEM_ADDR_WIDTH-1:0] w_m_axi_gmem_ARADDR;
    reg  [C_M_AXI_GMEM_ADDR_WIDTH-1:0] r_m_axi_gmem_ARADDR;

    wire [12:0]                addr_4k = 13'h1000;
    wire [NUM_ARLEN_BIT-1:0]   normal_burst_len;
    wire [NUM_ARLEN_BIT-1:0]   boundary_burst_len;
    wire                       is_4k_boundary;
    wire [12-AXI_DATA_SHIFT:0] last_addr_in_nxt_burst;

	wire is_burst_done_r;

// gen run (1 tick)
    reg tick_ff;
    always @(posedge ap_clk) begin
        if(ap_rst) begin
            tick_ff <= 1'b0;
        end
        else begin
            tick_ff <= ap_start;
        end
    end
    assign run = ap_start & ~tick_ff;

// latch input
    always @(posedge ap_clk) begin
        if(ap_rst) begin
            r_transfer_byte <= 'd0;
            r_mem           <= 'd0;
        end
        else if(run) begin
            r_transfer_byte <= transfer_byte;
            r_mem           <= mem;
        end
    end

// fixed AXI4 ports
	assign m_axi_gmem_ARID     = 'd0;
    assign m_axi_gmem_ARSIZE   = 3'b101;  // 32 byte = 256 bits
    assign m_axi_gmem_ARBURST  = 2'b01;   // INCR
    assign m_axi_gmem_ARLOCK   = 'd0;
    assign m_axi_gmem_ARCACHE  = 'd0;
    assign m_axi_gmem_ARPROT   = 'd0;
    assign m_axi_gmem_ARQOS    = 'd0;
    assign m_axi_gmem_ARREGION = 'd0;
    assign m_axi_gmem_ARUSER   = 'd0;

/////////////////////////////////////// main control
// main state machine
    always @(posedge ap_clk) begin
        if(ap_rst) begin
            c_state <= S_IDLE;
        end
        else begin
            c_state <= n_state;
        end
    end
    
    always @(*) begin
        case(c_state)
            S_IDLE : n_state = run ? S_PRE : S_IDLE;
            S_PRE  : n_state = S_RUN;
            S_RUN  : n_state = is_done ? S_DONE : S_RUN;
            S_DONE : n_state = S_IDLE;
			default: n_state = c_state;
        endcase
    end

    wire w_s_idle = (c_state == S_IDLE);
    wire w_s_pre  = (c_state == S_PRE);
    wire w_s_run  = (c_state == S_RUN);
    wire w_s_done = (c_state == S_DONE);

    assign ap_idle  = w_s_idle;
    assign ap_ready = w_s_pre;
    assign ap_done  = w_s_done;

// latch data
    always @(posedge ap_clk) begin
        if(ap_rst) begin
            r_num_hs_in_transfer <= 'd0;
            r_rdma_base_addr     <= 'd0;
        end
        else if(w_s_pre) begin
            r_num_hs_in_transfer <= r_transfer_byte >> AXI_DATA_SHIFT;
            r_rdma_base_addr     <= r_mem;
        end
    end

/////////////////////////////////////// AXI4 read control
/////////////////// AR Channel
// AR state machine
    always @(posedge ap_clk) begin
        if(ap_rst) begin
            c_state_ar <= S_IDLE;
        end
        else begin
            c_state_ar <= n_state_ar;
        end
    end
    
	always @(*) begin
        case(c_state_ar)
            S_IDLE : n_state_ar = (w_s_run & ar_fifo_full_n & ~is_done_ar) ? S_PRE : S_IDLE;
            S_PRE  : n_state_ar = S_RUN;
            S_RUN  : n_state_ar = ar_hs ? S_IDLE : S_RUN;
            default: n_state_ar = c_state_ar;
        endcase
    end

	assign m_axi_gmem_ARVALID = (c_state_ar == S_RUN);

// ar_hs counter
    always @(posedge ap_clk) begin
        if(ap_rst) begin
            r_ar_hs_cnt <= 'd0;
        end
        else if(w_s_idle) begin
            r_ar_hs_cnt <= 'd0;
        end
        else if(ar_hs) begin
            r_ar_hs_cnt <= r_ar_hs_cnt + burst_len_ar;
        end
    end

	assign is_done_ar          = (r_ar_hs_cnt >= r_num_hs_in_transfer);
	assign remain_hs           = r_num_hs_in_transfer - r_ar_hs_cnt;
    assign rdma_offset_addr    = {r_ar_hs_cnt, {AXI_DATA_SHIFT{1'b0}}};
    assign w_m_axi_gmem_ARADDR = r_rdma_base_addr + rdma_offset_addr;

// burst length
    assign burst_len_ar = is_4k_boundary ? boundary_burst_len : normal_burst_len;

    assign normal_burst_len = (remain_hs >= NUM_MAX_BURST) ? NUM_MAX_BURST : remain_hs;
    assign boundary_burst_len = addr_4k[12:AXI_DATA_SHIFT] - w_m_axi_gmem_ARADDR[11:AXI_DATA_SHIFT];
    assign is_4k_boundary = (last_addr_in_nxt_burst > addr_4k[12:AXI_DATA_SHIFT]);
    assign last_addr_in_nxt_burst = w_m_axi_gmem_ARADDR[11:AXI_DATA_SHIFT] + normal_burst_len;

// FIFO : AR to R
    always @(posedge ap_clk) begin
        if(ap_rst) begin
            r_m_axi_gmem_ARADDR <= 'd0;
            r_burst_len_ar      <= 'd0;
            r_m_axi_gmem_ARLEN  <= 'd0;
        end
        else if(w_s_idle) begin
            r_m_axi_gmem_ARADDR <= 'd0;
            r_burst_len_ar      <= 'd0;
            r_m_axi_gmem_ARLEN  <= 'd0;
        end
        else if(c_state_ar == S_PRE) begin
            r_m_axi_gmem_ARADDR <= w_m_axi_gmem_ARADDR;
            r_burst_len_ar      <= burst_len_ar;
            r_m_axi_gmem_ARLEN  <= burst_len_ar - 1'b1;
        end
    end

    assign m_axi_gmem_ARADDR = r_m_axi_gmem_ARADDR;
    assign m_axi_gmem_ARLEN  = r_m_axi_gmem_ARLEN[7:0];

    sync_fifo #(
        .FIFO_IN_REG    (0),
        .FIFO_OUT_REG   (0),
        .FIFO_DATA_WIDTH(NUM_ARLEN_BIT),
        .FIFO_DEPTH     (NUM_AXI_AR_MOR) 
    ) u_fifo_ar(
        .clk    (ap_clk),
        .reset  (ap_rst),

        .s_valid(ar_hs),
        .s_ready(ar_fifo_full_n),
        .s_data	(r_burst_len_ar),

        .m_valid(ar_fifo_empty_n),
        .m_ready(ar_fifo_read),
        .m_data	(burst_len_r)
    );

/////////////////// R Channel
// R state machine
    always @(posedge ap_clk) begin
        if(ap_rst) begin
            c_state_r <= S_IDLE;
        end
        else begin
            c_state_r <= n_state_r;
        end
    end

    always @(*) begin
        case(c_state_r)
            S_IDLE : n_state_r = (w_s_run & ar_fifo_empty_n) ? S_RUN : S_IDLE;
            S_RUN  : n_state_r = is_burst_done_r ? (ar_fifo_empty_n ? S_RUN : S_IDLE) : S_RUN;
            default: n_state_r = c_state_r;
        endcase
    end

	assign is_burst_done_r = m_axi_gmem_RLAST & r_hs;
	assign ar_fifo_read = (c_state_r == S_RUN) & is_burst_done_r;


// r_hs counter
    always @(posedge ap_clk) begin
        if(ap_rst) begin
            r_r_hs_cnt <= 'd0;
        end
        else if(w_s_idle) begin
            r_r_hs_cnt <= 'd0;
        end
        else if(r_hs) begin
            r_r_hs_cnt <= r_r_hs_cnt + 1'b1;
        end
    end

	assign is_done = (r_r_hs_cnt >= r_num_hs_in_transfer);

// bypass handshake.
    assign empty_n           = m_axi_gmem_RVALID;
	assign m_axi_gmem_RREADY = rd_en;
	assign dout              = m_axi_gmem_RDATA;

endmodule
