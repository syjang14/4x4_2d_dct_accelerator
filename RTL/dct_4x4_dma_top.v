`timescale 1 ns / 1 ps

module dct_4x4_dma_top #(
    parameter C_S_AXI_CONTROL_ADDR_WIDTH = 12,
    parameter C_S_AXI_CONTROL_DATA_WIDTH = 32,

    parameter C_M00_AXI_ID_WIDTH     = 1,
    parameter C_M00_AXI_ADDR_WIDTH   = 32,
    parameter C_M00_AXI_DATA_WIDTH   = 256,
    parameter C_M00_AXI_AWUSER_WIDTH = 1,
    parameter C_M00_AXI_WUSER_WIDTH  = 1,
    parameter C_M00_AXI_BUSER_WIDTH  = 1,
    parameter C_M00_AXI_ARUSER_WIDTH = 1,
    parameter C_M00_AXI_RUSER_WIDTH  = 1
)
(
    input                                           ap_clk,
    input                                           ap_rst_n,

// AXI4-Standard interface
    output [C_M00_AXI_ID_WIDTH-1:0]     			m00_axi_awid,
    output                                 			m00_axi_awvalid,
    input                                  			m00_axi_awready,
    output [C_M00_AXI_ADDR_WIDTH-1:0]   			m00_axi_awaddr,
    output [7:0]                          			m00_axi_awlen,
    output [2:0]                          			m00_axi_awsize,
    output [1:0]                          			m00_axi_awburst,
    output [1:0]                          			m00_axi_awlock,
    output [3:0]                          			m00_axi_awcache,
    output [2:0]                          			m00_axi_awprot,
    output [3:0]                          			m00_axi_awqos,
    output [3:0]                          			m00_axi_awregion,
    output [C_M00_AXI_AWUSER_WIDTH-1:0] 			m00_axi_awuser,

    output [C_M00_AXI_ID_WIDTH-1:0]     			m00_axi_wid,
    output                                 			m00_axi_wvalid,
    input                                  			m00_axi_wready,
    output [C_M00_AXI_DATA_WIDTH-1:0]   		    m00_axi_wdata,
    output [(C_M00_AXI_DATA_WIDTH/8)-1:0] 	        m00_axi_wstrb,
    output                                 			m00_axi_wlast,
    output [C_M00_AXI_WUSER_WIDTH-1:0]  			m00_axi_wuser,

    input  [C_M00_AXI_ID_WIDTH-1:0]      			m00_axi_bid,
    input                                  			m00_axi_bvalid,
    output                                 			m00_axi_bready,
    input  [1:0]                           			m00_axi_bresp,
    input  [C_M00_AXI_BUSER_WIDTH-1:0]   			m00_axi_buser,

    output [C_M00_AXI_ID_WIDTH-1:0]     			m00_axi_arid,
    output                                 			m00_axi_arvalid,
    input                                  			m00_axi_arready,
    output [C_M00_AXI_ADDR_WIDTH-1:0]   			m00_axi_araddr,
    output [7:0]                          			m00_axi_arlen,
    output [2:0]                          			m00_axi_arsize,
    output [1:0]                          			m00_axi_arburst,
    output [1:0]                          			m00_axi_arlock,
    output [3:0]                          			m00_axi_arcache,
    output [2:0]                          			m00_axi_arprot,
    output [3:0]                          			m00_axi_arqos,
    output [3:0]                          			m00_axi_arregion,
    output [C_M00_AXI_ARUSER_WIDTH-1:0] 			m00_axi_aruser,

    input  [C_M00_AXI_ID_WIDTH-1:0]      			m00_axi_rid,
    input                                  			m00_axi_rvalid,
    output                                 			m00_axi_rready,
    input  [C_M00_AXI_DATA_WIDTH-1:0]    		    m00_axi_rdata,
    input  [1:0]                           			m00_axi_rresp,
    input                                  			m00_axi_rlast,
    input  [C_M00_AXI_RUSER_WIDTH-1:0]   			m00_axi_ruser,
    
// AXI4-Lite interface
    input                                       	s_axi_control_awvalid,
    output                                      	s_axi_control_awready,
    input  [C_S_AXI_CONTROL_ADDR_WIDTH-1:0]      	s_axi_control_awaddr,

    input                                       	s_axi_control_wvalid,
    output                                      	s_axi_control_wready,
    input  [C_S_AXI_CONTROL_DATA_WIDTH-1:0]   	    s_axi_control_wdata,
    input  [(C_S_AXI_CONTROL_DATA_WIDTH/8)-1:0]     s_axi_control_wstrb,

    input                                       	s_axi_control_arvalid,
    output                                      	s_axi_control_arready,
    input  [C_S_AXI_CONTROL_ADDR_WIDTH-1:0]      	s_axi_control_araddr,

    output                                      	s_axi_control_rvalid,
    input                                       	s_axi_control_rready,
    output [C_S_AXI_CONTROL_DATA_WIDTH-1:0]     	s_axi_control_rdata,
    output [1:0]                                  	s_axi_control_rresp,

    output                                      	s_axi_control_bvalid,
    input                                       	s_axi_control_bready,
    output [1:0]                                  	s_axi_control_bresp          
);

// gen areset
    reg areset;
    always @(posedge ap_clk) begin
        areset <= ~ap_rst_n;
    end

// declaration
    wire        ap_start;
    wire        ap_idle;
    wire        ap_done;
    wire        ap_ready;
    wire [31:0] rdma_transfer_byte;
    wire [31:0] rdma_mem_ptr;
    wire [31:0] wdma_transfer_byte;
    wire [31:0] wdma_mem_ptr;

    wire                             empty_n;
    wire                             rd_en;
    wire [C_M00_AXI_DATA_WIDTH-1:0] dout;

    wire                             wr_en;
    wire                             full_n;
    wire [C_M00_AXI_DATA_WIDTH-1:0] din;

    wire 		                     w_wr_en;
    wire		                     w_full_n;
    wire [C_M00_AXI_DATA_WIDTH-1:0] w_din;

// instantiation
    dma_ip_control #(
        .C_S_AXI_ADDR_WIDTH(C_S_AXI_CONTROL_ADDR_WIDTH),
        .C_S_AXI_DATA_WIDTH(C_S_AXI_CONTROL_DATA_WIDTH)
    ) u_dma_ip_control(
        .ACLK              (ap_clk),
        .ARESET            (areset),
        .ACLK_EN           (1'b1),

        .AWVALID           (s_axi_control_awvalid),
        .AWREADY           (s_axi_control_awready),
        .AWADDR            (s_axi_control_awaddr),

        .WVALID            (s_axi_control_wvalid),
        .WREADY            (s_axi_control_wready),
        .WDATA             (s_axi_control_wdata),
        .WSTRB             (s_axi_control_wstrb),

        .BVALID            (s_axi_control_bvalid),
        .BREADY            (s_axi_control_bready),
        .BRESP             (s_axi_control_bresp),

        .ARVALID           (s_axi_control_arvalid),
        .ARREADY           (s_axi_control_arready),
        .ARADDR            (s_axi_control_araddr),

        .RVALID            (s_axi_control_rvalid),
        .RREADY            (s_axi_control_rready),
        .RDATA             (s_axi_control_rdata),
        .RRESP             (s_axi_control_rresp),

        .ap_start          (ap_start),
        .ap_done           (ap_done),
        .ap_ready          (ap_ready),
        .ap_idle           (ap_idle),
        .rdma_transfer_byte(rdma_transfer_byte),
        .rdma_mem_ptr      (rdma_mem_ptr),
        .wdma_transfer_byte(wdma_transfer_byte),
        .wdma_mem_ptr      (wdma_mem_ptr)
    );

    dma_wrapper #(
        .C_M00_AXI_ID_WIDTH    (C_M00_AXI_ID_WIDTH),
        .C_M00_AXI_ADDR_WIDTH  (C_M00_AXI_ADDR_WIDTH),
        .C_M00_AXI_DATA_WIDTH  (C_M00_AXI_DATA_WIDTH),
        .C_M00_AXI_AWUSER_WIDTH(C_M00_AXI_AWUSER_WIDTH),
        .C_M00_AXI_WUSER_WIDTH (C_M00_AXI_WUSER_WIDTH),
        .C_M00_AXI_BUSER_WIDTH (C_M00_AXI_BUSER_WIDTH),
        .C_M00_AXI_ARUSER_WIDTH(C_M00_AXI_ARUSER_WIDTH),
        .C_M00_AXI_RUSER_WIDTH (C_M00_AXI_RUSER_WIDTH)
    ) u_dma_wrapper(
        .ap_clk            (ap_clk),
        .ap_rst_n          (ap_rst_n),

        .ap_start          (ap_start),
        .ap_done           (ap_done),
        .ap_idle           (ap_idle),
        .ap_ready          (ap_ready),

        .rdma_transfer_byte(rdma_transfer_byte),
        .rdma_mem_ptr      (rdma_mem_ptr),
        .wdma_transfer_byte(wdma_transfer_byte),
        .wdma_mem_ptr      (wdma_mem_ptr),
        
        .m00_axi_awid	   (m00_axi_awid),
        .m00_axi_awvalid   (m00_axi_awvalid),
        .m00_axi_awready   (m00_axi_awready),
        .m00_axi_awaddr	   (m00_axi_awaddr),
        .m00_axi_awlen	   (m00_axi_awlen),
        .m00_axi_awsize	   (m00_axi_awsize),
        .m00_axi_awburst   (m00_axi_awburst),
        .m00_axi_awlock	   (m00_axi_awlock),
        .m00_axi_awcache   (m00_axi_awcache),
        .m00_axi_awprot	   (m00_axi_awprot),
        .m00_axi_awqos	   (m00_axi_awqos),
        .m00_axi_awregion  (m00_axi_awregion),
        .m00_axi_awuser	   (m00_axi_awuser),

        .m00_axi_wid	   (m00_axi_wid),
        .m00_axi_wvalid	   (m00_axi_wvalid),
        .m00_axi_wready	   (m00_axi_wready),
        .m00_axi_wdata	   (m00_axi_wdata),
        .m00_axi_wstrb	   (m00_axi_wstrb),
        .m00_axi_wlast	   (m00_axi_wlast),
        .m00_axi_wuser	   (m00_axi_wuser),

        .m00_axi_bid	   (m00_axi_bid),
        .m00_axi_bvalid	   (m00_axi_bvalid),
        .m00_axi_bready	   (m00_axi_bready),
        .m00_axi_bresp	   (m00_axi_bresp),
        .m00_axi_buser	   (m00_axi_buser),

        .m00_axi_arid	   (m00_axi_arid),
        .m00_axi_arvalid   (m00_axi_arvalid),
        .m00_axi_arready   (m00_axi_arready),
        .m00_axi_araddr	   (m00_axi_araddr),
        .m00_axi_arlen	   (m00_axi_arlen),
        .m00_axi_arsize	   (m00_axi_arsize),
        .m00_axi_arburst   (m00_axi_arburst),
        .m00_axi_arlock	   (m00_axi_arlock),
        .m00_axi_arcache   (m00_axi_arcache),
        .m00_axi_arprot	   (m00_axi_arprot),
        .m00_axi_arqos	   (m00_axi_arqos),
        .m00_axi_arregion  (m00_axi_arregion),
        .m00_axi_aruser	   (m00_axi_aruser),

        .m00_axi_rid	   (m00_axi_rid),
        .m00_axi_rvalid	   (m00_axi_rvalid),
        .m00_axi_rready	   (m00_axi_rready),
        .m00_axi_rdata	   (m00_axi_rdata),
        .m00_axi_rresp	   (m00_axi_rresp),
        .m00_axi_rlast	   (m00_axi_rlast),
        .m00_axi_ruser	   (m00_axi_ruser),
    
        .empty_n           (empty_n),
        .rd_en             (rd_en),
        .dout              (dout),

        .wr_en             (wr_en),
        .full_n            (full_n),
        .din               (din)
    );

    dct_4x4 #(
        .PERF_OPT_ROW(1),
        .PERF_OPT_COL(1)
    ) u_dct_4x4(
        .clk  (ap_clk),
        .reset(areset),

        .i_valid(empty_n),
        .i_ready(rd_en),
        .i_data (dout),

        .o_valid(w_wr_en),
        .o_ready(w_full_n),
        .o_data (w_din)
    );

    sync_fifo #(
        .FIFO_IN_REG	(1),
        .FIFO_OUT_REG	(1),
        .FIFO_DATA_WIDTH(C_M00_AXI_DATA_WIDTH),
        .FIFO_DEPTH     (4)
    ) u_sync_fifo(
        .clk	(ap_clk),
        .reset	(areset),

        .s_valid(w_wr_en),
        .s_ready(w_full_n),
        .s_data	(w_din),

        .m_valid(wr_en),
        .m_ready(full_n),
        .m_data	(din)
    );

endmodule
