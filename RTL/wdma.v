module wdma
#(
	parameter C_M_AXI_GMEM_ID_WIDTH     = 1,
	parameter C_M_AXI_GMEM_ADDR_WIDTH   = 32,
	parameter C_M_AXI_GMEM_DATA_WIDTH   = 64,
	parameter C_M_AXI_GMEM_AWUSER_WIDTH = 1,
	parameter C_M_AXI_GMEM_WUSER_WIDTH  = 1,
	parameter C_M_AXI_GMEM_BUSER_WIDTH  = 1
)
(
	input                                    ap_clk,
	input                                    ap_rst_n,
	
	input                                    ap_start,
	input                                    ap_idle,
	input                                    ap_ready,
	input                                    ap_done,

	input [C_M_AXI_GMEM_ADDR_WIDTH-1:0]      transfer_byte,  // the number of data transfered
	input [C_M_AXI_GMEM_ADDR_WIDTH-1:0]      mem,            // base addr
	
	output [C_M_AXI_GMEM_ID_WIDTH-1:0]       m_axi_gmem_AWID,
    output                                   m_axi_gmem_AWVALID,
    input                                    m_axi_gmem_AWREADY,
    output [C_M_AXI_GMEM_ADDR_WIDTH-1:0]     m_axi_gmem_AWADDR,
    output [7:0]                             m_axi_gmem_AWLEN,
    output [2:0]                             m_axi_gmem_AWSIZE,
    output [1:0]                             m_axi_gmem_AWBURST,
    output [1:0]                             m_axi_gmem_AWLOCK,
    output [3:0]                             m_axi_gmem_AWCACHE,
    output [2:0]                             m_axi_gmem_AWPROT,
    output [3:0]                             m_axi_gmem_AWQOS,
    output [3:0]                             m_axi_gmem_AWREGION,
    output [C_M_AXI_GMEM_AWUSER_WIDTH-1:0]   m_axi_gmem_AWUSER,

    output [C_M_AXI_GMEM_ID_WIDTH-1:0]       m_axi_gmem_WID,
    output                                   m_axi_gmem_WVALID,
    input                                    m_axi_gmem_WREADY,
    output [C_M_AXI_GMEM_DATA_WIDTH-1:0]     m_axi_gmem_WDATA,
    output [(C_M_AXI_GMEM_DATA_WIDTH/8)-1:0] m_axi_gmem_WSTRB,
    output                                   m_axi_gmem_WLAST,
    output [C_M_AXI_GMEM_WUSER_WIDTH-1:0]    m_axi_gmem_WUSER,

    input [C_M_AXI_GMEM_ID_WIDTH-1:0]        m_axi_gmem_BID,
    input                                    m_axi_gmem_BVALID,
    output                                   m_axi_gmem_BREADY,
    input [1:0]                              m_axi_gmem_BRESP,
    input [C_M_AXI_GMEM_BUSER_WIDTH-1:0]     m_axi_gmem_BUSER,

	input                                    wr_en,
	output                                   full_n,
	input  [C_M_AXI_GMEM_DATA_WIDTH-1:0]     din
);

// gen ap_rst
	reg ap_rst;
	always @(posedge ap_clk) begin
		ap_rst <= ~ap_rst_n;
	end

// localparam
	localparam S_IDLE = 2'b00;
	localparam S_PRE  = 2'b01;
	localparam S_RUN  = 2'b10;
	localparam S_DONE = 2'b11;

	localparam AXI_DATA_SHIFT     = $clog2(C_M_AXI_GMEM_DATA_WIDTH/8);  // 7
	localparam NUM_AXI_AW_MOR     = 8'd4;
	localparam NUM_MAX_BURST      = 4;
	localparam NUM_AWLEN_BIT      = 9;

// Declaration
	reg [1:0] c_state, n_state;
    reg [1:0] c_state_aw, n_state_aw;
    reg [1:0] c_state_w, n_state_w;
	reg [1:0] c_state_b, n_state_b;

	wire run;
	wire is_done;
	wire is_done_aw;

	reg [C_M_AXI_GMEM_ADDR_WIDTH-1:0] r_transfer_byte;
    reg [C_M_AXI_GMEM_ADDR_WIDTH-1:0] r_mem;

	reg [C_M_AXI_GMEM_ADDR_WIDTH-AXI_DATA_SHIFT-1:0] r_num_hs_in_transfer;
	reg [C_M_AXI_GMEM_ADDR_WIDTH-1:0]                r_wdma_base_addr;

	wire aw_fifo_full_n;
	wire aw_fifo_empty_n;
	wire aw_fifo_read;
	wire w_fifo_full_n;
	wire w_fifo_empty_n;
	wire w_fifo_read;
	
	wire aw_hs = (m_axi_gmem_AWVALID & m_axi_gmem_AWREADY);
	wire w_hs  = (m_axi_gmem_WVALID  & m_axi_gmem_WREADY );
	wire b_hs  = (m_axi_gmem_BVALID  & m_axi_gmem_BREADY );

	reg [C_M_AXI_GMEM_ADDR_WIDTH-AXI_DATA_SHIFT-1:0] r_aw_hs_cnt;
	reg [C_M_AXI_GMEM_ADDR_WIDTH-AXI_DATA_SHIFT-1:0] r_w_hs_cnt;
	reg [C_M_AXI_GMEM_ADDR_WIDTH-AXI_DATA_SHIFT-1:0] r_b_hs_cnt;

	wire [NUM_AWLEN_BIT-1:0] burst_len_aw;
	wire [NUM_AWLEN_BIT-1:0] burst_len_w;
	wire [NUM_AWLEN_BIT-1:0] burst_len_b;
	reg [NUM_AWLEN_BIT-1:0] r_burst_len_aw;
	reg [NUM_AWLEN_BIT-1:0] r_burst_len_w;
	reg [NUM_AWLEN_BIT-1:0] r_burst_len_b;
	reg [NUM_AWLEN_BIT-1:0] r_m_axi_gmem_AWLEN;

	wire [C_M_AXI_GMEM_ADDR_WIDTH-AXI_DATA_SHIFT-1:0] remain_hs;

	wire [C_M_AXI_GMEM_ADDR_WIDTH-1:0] wdma_offset_addr;
	wire [C_M_AXI_GMEM_ADDR_WIDTH-1:0] w_m_axi_gmem_AWADDR;
	reg  [C_M_AXI_GMEM_ADDR_WIDTH-1:0] r_m_axi_gmem_AWADDR;

	wire [12:0]                addr_4k = 13'h1000;
    wire [NUM_AWLEN_BIT-1:0]   normal_burst_len;
    wire [NUM_AWLEN_BIT-1:0]   boundary_burst_len;
    wire                       is_4k_boundary;
    wire [12-AXI_DATA_SHIFT:0] last_addr_in_nxt_burst;

	wire is_burst_done_w;

	reg  [7:0] r_MOR_cnt;
	wire       is_MOR_full;

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

// fixed AXI ports
	assign m_axi_gmem_AWID     = 'd0;
	assign m_axi_gmem_AWSIZE   = 3'b101;  // 32 bytes = 256 bits
	assign m_axi_gmem_AWBURST  = 2'b01;   // INCR
	assign m_axi_gmem_AWLOCK   = 'd0; 
	assign m_axi_gmem_AWCACHE  = 'd0;
	assign m_axi_gmem_AWPROT   = 'd0;
	assign m_axi_gmem_AWQOS    = 'd0;
	assign m_axi_gmem_AWREGION = 'd0;
	assign m_axi_gmem_AWUSER   = 'd0;
	assign m_axi_gmem_WID      = 'd0;
	assign m_axi_gmem_WSTRB    = {(C_M_AXI_GMEM_DATA_WIDTH/8){1'b1}};
	assign m_axi_gmem_WUSER    = 'd0;

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

//assign is_done = is_last_b_hs && b_hs;

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
			r_wdma_base_addr     <= 'd0;
		end
		else if(w_s_pre) begin
			r_num_hs_in_transfer <= r_transfer_byte >> AXI_DATA_SHIFT; 
			r_wdma_base_addr     <= r_mem;
		end
	end

/////////////////////////////////////// AXI4 write control
/////////////////// AW Channel
// AW state machine
	always @(posedge ap_clk) begin
		if(ap_rst) begin
			c_state_aw <= S_IDLE;
		end
		else begin
			c_state_aw <= n_state_aw;
		end
	end

always @(*) begin
	case(c_state_aw)
		S_IDLE : n_state_aw = (w_s_run & aw_fifo_full_n & ~is_done_aw & ~is_MOR_full) ? S_PRE : S_IDLE;
		S_PRE  : n_state_aw = S_RUN;
		S_RUN  : n_state_aw = aw_hs ? S_IDLE : S_RUN;
		default: n_state_aw = c_state_aw; 
	endcase
end

	assign m_axi_gmem_AWVALID = (c_state_aw == S_RUN);

// aw_hs counter
	always @(posedge ap_clk) begin
		if(ap_rst) begin
			r_aw_hs_cnt <= 'd0;
		end
		else if(w_s_idle) begin
			r_aw_hs_cnt <= 'd0;
		end
		else if(aw_hs) begin
			r_aw_hs_cnt <= r_aw_hs_cnt + burst_len_aw;
		end
	end

	assign is_done_aw          = (r_aw_hs_cnt >= r_num_hs_in_transfer);
	assign remain_hs           = r_num_hs_in_transfer - r_aw_hs_cnt;
	assign wdma_offset_addr    = {r_aw_hs_cnt, {AXI_DATA_SHIFT{1'b0}}};
	assign w_m_axi_gmem_AWADDR = r_wdma_base_addr + wdma_offset_addr;

// burst length
	assign burst_len_aw = is_4k_boundary ? boundary_burst_len : normal_burst_len;

    assign normal_burst_len = (remain_hs >= NUM_MAX_BURST) ? NUM_MAX_BURST : remain_hs;
    assign boundary_burst_len = addr_4k[12:AXI_DATA_SHIFT] - w_m_axi_gmem_AWADDR[11:AXI_DATA_SHIFT];
    assign is_4k_boundary = (last_addr_in_nxt_burst > addr_4k[12:AXI_DATA_SHIFT]);
    assign last_addr_in_nxt_burst = w_m_axi_gmem_AWADDR[11:AXI_DATA_SHIFT] + normal_burst_len;

// FIFO : AW to W
	always @(posedge ap_clk) begin
		if(ap_rst) begin
			r_m_axi_gmem_AWADDR <= 'd0;
			r_burst_len_aw      <= 'd0;
			r_m_axi_gmem_AWLEN  <= 'd0;
		end
		else if(w_s_idle) begin
			r_m_axi_gmem_AWADDR <= 'd0;
			r_burst_len_aw      <= 'd0;
			r_m_axi_gmem_AWLEN  <= 'd0;
		end
		else if(c_state_aw == S_PRE) begin
			r_m_axi_gmem_AWADDR <= w_m_axi_gmem_AWADDR;
			r_burst_len_aw      <= burst_len_aw;
			r_m_axi_gmem_AWLEN  <= burst_len_aw - 1'b1;
		end
	end

	assign m_axi_gmem_AWADDR = r_m_axi_gmem_AWADDR;
	assign m_axi_gmem_AWLEN  = r_m_axi_gmem_AWLEN[7:0];

	sync_fifo #(
		.FIFO_IN_REG    (0),
		.FIFO_OUT_REG   (0),
		.FIFO_DATA_WIDTH(NUM_AWLEN_BIT),
		.FIFO_DEPTH     (NUM_AXI_AW_MOR)
	) u_sync_fifo_aw(
		.clk    (ap_clk),
		.reset  (ap_rst),

		.s_valid(aw_hs),
		.s_ready(aw_fifo_full_n),
		.s_data (r_burst_len_aw),

		.m_valid(aw_fifo_empty_n),
		.m_ready(aw_fifo_read),
		.m_data (burst_len_w)
	);

// MOR counter
	always @(posedge ap_clk) begin
		if(ap_rst) begin
			r_MOR_cnt <= 'd0;
		end
		else if(w_s_idle) begin
			r_MOR_cnt <= 'd0;
		end
		else if(aw_hs & ~b_hs) begin        
			r_MOR_cnt <= r_MOR_cnt + 1'b1;
		end
		else if(~aw_hs & b_hs) begin
			r_MOR_cnt <= r_MOR_cnt - 1'b1;
		end
	end

	assign is_MOR_full = (r_MOR_cnt == NUM_AXI_AW_MOR);

/////////////////// W Channel
// W state machine
	always @(posedge ap_clk) begin
		if(ap_rst) begin
			c_state_w <= S_IDLE;
		end
		else begin
			c_state_w <= n_state_w;
		end
	end

	always @(*) begin
		case(c_state_w)
			S_IDLE : n_state_w = (w_s_run & aw_fifo_empty_n & w_fifo_full_n) ? S_RUN : S_IDLE;
			S_RUN  : n_state_w = is_burst_done_w ? ((aw_fifo_empty_n & w_fifo_full_n) ? S_RUN : S_IDLE) : S_RUN;
			default: n_state_w = c_state_w;
		endcase
	end

	assign is_burst_done_w = m_axi_gmem_WLAST & w_hs;
	assign aw_fifo_read    = (c_state_w == S_RUN) & is_burst_done_w;

// w_hs counter
	always @(posedge ap_clk) begin
		if(ap_rst) begin
			r_w_hs_cnt <= 'd0;
		end
		else if(w_s_idle | is_burst_done_w) begin
			r_w_hs_cnt <= 'd0;
		end
		else if(w_hs) begin
			r_w_hs_cnt <= r_w_hs_cnt + 1'b1;
		end
	end

	assign m_axi_gmem_WLAST = (r_w_hs_cnt+1 == r_burst_len_w);

// burst length F/F
	always @(posedge ap_clk) begin
		if(ap_rst) begin
			r_burst_len_w <= 'd0;
		end
		else if(w_s_run) begin
			r_burst_len_w <= burst_len_w;
		end
	end

// bypass handshake
	assign m_axi_gmem_WVALID = wr_en;
	assign full_n            = m_axi_gmem_WREADY;
	assign m_axi_gmem_WDATA  = din;

// W to B FIFO
	sync_fifo #(
		.FIFO_IN_REG    (0),
		.FIFO_OUT_REG   (0),
		.FIFO_DATA_WIDTH(NUM_AWLEN_BIT),
		.FIFO_DEPTH     (NUM_AXI_AW_MOR)
	) u_sync_fifo_w(
		.clk    (ap_clk),
		.reset  (ap_rst),

		.s_valid(is_burst_done_w),
		.s_ready(w_fifo_full_n),
		.s_data (r_burst_len_w),

		.m_valid(w_fifo_empty_n),
		.m_ready(w_fifo_read),
		.m_data (burst_len_b)
	);

/////////////////// B Channel
// B state machine
	always @(posedge ap_clk) begin
		if(ap_rst) begin
			c_state_b <= S_IDLE;
		end
		else begin
			c_state_b <= n_state_b;
		end
	end

	always @(*) begin
		case(c_state_b)
			S_IDLE : n_state_b = (w_s_run & w_fifo_empty_n) ? S_RUN : S_IDLE;
			S_RUN  : n_state_b = b_hs ? S_IDLE : S_RUN;
			default: n_state_b = c_state_b;
		endcase
	end

	assign w_fifo_read       = b_hs;
	assign m_axi_gmem_BREADY = (c_state_b == S_RUN);

// b_hs counter
	always @(posedge ap_clk) begin
		if(ap_rst) begin
			r_b_hs_cnt <= 'd0;
		end
		else if(w_s_idle) begin
			r_b_hs_cnt <= 'd0;
		end
		else if(b_hs) begin
			r_b_hs_cnt <= r_b_hs_cnt + r_burst_len_b;
		end
	end

	assign is_done = (r_b_hs_cnt >= r_num_hs_in_transfer);

// burst length F/F
	always @(posedge ap_clk) begin
		if(ap_rst) begin
			r_burst_len_b <= 'd0;
		end
		else if(w_s_run) begin
			r_burst_len_b <= burst_len_b;
		end
	end

endmodule