`timescale 1 ns / 1 ps

import axi_vip_pkg::*;
import slv_m00_axi_vip_pkg::*;
import control_dma_ip_vip_pkg::*;
module tb_dct_4x4_dma_top;

  parameter C_S_AXI_CONTROL_ADDR_WIDTH      = 12;
  parameter C_S_AXI_CONTROL_DATA_WIDTH      = 32;

  parameter C_M00_AXI_ID_WIDTH              = 1;
  parameter C_M00_AXI_ADDR_WIDTH            = 32;
  parameter C_M00_AXI_DATA_WIDTH            = 256;
  parameter C_M00_AXI_DATA_WIDTH_BYTE       = C_M00_AXI_DATA_WIDTH / 8;
  parameter C_M00_AXI_DATA_WIDTH_BYTE_LOG   = $clog2(C_M00_AXI_DATA_WIDTH_BYTE);
  parameter C_M00_AXI_AWUSER_WIDTH          = 1;
  parameter C_M00_AXI_WUSER_WIDTH           = 1;
  parameter C_M00_AXI_BUSER_WIDTH           = 1;
  parameter C_M00_AXI_ARUSER_WIDTH          = 1;
  parameter C_M00_AXI_RUSER_WIDTH           = 1;

  parameter C_M00_AXI_USER_VALUE            = 0;
  parameter C_M00_AXI_PROT_VALUE            = 0;
  parameter C_M00_AXI_CACHE_VALUE           = 3;


// User input parameter
    parameter USER_TRANSFER_LEN               = 32'd1024;
    parameter USER_RDMA_ADDR                  = 32'd0;

// DMA IP REG MAP
    parameter ADDR_AP_CTRL                    = 6'h00;
    parameter ADDR_RDMA_TRANSFER_BYTE_DATA_0  = 6'h04;
    parameter ADDR_RDMA_MEM_PTR_DATA_0        = 6'h08;
    parameter ADDR_WDMA_TRANSFER_BYTE_DATA_0  = 6'h0c;
    parameter ADDR_WDMA_MEM_PTR_DATA_0        = 6'h10;

// Control Register
    parameter CTRL_START_MASK                 = 32'h0000_0001;
    parameter CTRL_IDLE_MASK                  = 32'h0000_0002;
    parameter CTRL_READY_MASK                 = 32'h0000_0004;
    parameter CTRL_DONE_MASK                  = 32'h0000_0008;

    parameter LP_CLK_PERIOD_PS = 10000; // 100 MHz

//System Signals
    logic ap_clk = 0;

    initial begin: AP_CLK
        forever begin
            ap_clk = #(LP_CLK_PERIOD_PS/2) ~ap_clk;
        end
    end
 
//System Signals
    logic ap_rst_n       = 0;
    logic initial_reset  = 0;

    task automatic ap_rst_n_sequence(input integer unsigned width = 20);
    @(posedge ap_clk);
    #1ps;
        ap_rst_n = 0;
        repeat (width) @(posedge ap_clk);
    #1ps;
        ap_rst_n = 1;
    endtask

    initial begin: AP_RST
        ap_rst_n_sequence(50);
        initial_reset =1;
    end

// AXI4 master interface m00_axi
    wire [C_M00_AXI_ID_WIDTH-1:0]     	      m00_axi_awid;
    wire                                	  m00_axi_awvalid;
    wire                                	  m00_axi_awready;
    wire [C_M00_AXI_ADDR_WIDTH-1:0]   	      m00_axi_awaddr;
    wire [7:0]                                m00_axi_awlen;
    wire [2:0]                                m00_axi_awsize;
    wire [1:0]                                m00_axi_awburst;
    wire [1:0]                                m00_axi_awlock;
    wire [3:0]                                m00_axi_awcache;
    wire [2:0]                                m00_axi_awprot;
    wire [3:0]                                m00_axi_awqos;
    wire [3:0]                          	  m00_axi_awregion;
    wire [C_M00_AXI_AWUSER_WIDTH-1:0] 	      m00_axi_awuser;

    wire [C_M00_AXI_ID_WIDTH-1:0]     	      m00_axi_wid;
    wire                                	  m00_axi_wvalid;
    wire                                	  m00_axi_wready;
    wire [C_M00_AXI_DATA_WIDTH-1:0]           m00_axi_wdata;
    wire [(C_M00_AXI_DATA_WIDTH/8)-1:0]       m00_axi_wstrb;
    wire                                	  m00_axi_wlast;
    wire [C_M00_AXI_WUSER_WIDTH-1:0]  	      m00_axi_wuser;

    wire [C_M00_AXI_ID_WIDTH-1:0]      	      m00_axi_bid;
    wire                                 	  m00_axi_bvalid;
    wire                                 	  m00_axi_bready;
    wire [1:0]                           	  m00_axi_bresp;
    wire [C_M00_AXI_BUSER_WIDTH-1:0]   	      m00_axi_buser;

    wire [C_M00_AXI_ID_WIDTH-1:0]     	      m00_axi_arid;
    wire                                	  m00_axi_arvalid;
    wire                                	  m00_axi_arready;
    wire [C_M00_AXI_ADDR_WIDTH-1:0]   	      m00_axi_araddr;
    wire [7:0]                          	  m00_axi_arlen;
    wire [2:0]                          	  m00_axi_arsize;
    wire [1:0]                          	  m00_axi_arburst;
    wire [1:0]                          	  m00_axi_arlock;
    wire [3:0]                          	  m00_axi_arcache;
    wire [2:0]                          	  m00_axi_arprot;
    wire [3:0]                          	  m00_axi_arqos;
    wire [3:0]                          	  m00_axi_arregion;
    wire [C_M00_AXI_ARUSER_WIDTH-1:0] 	      m00_axi_aruser;

    wire [C_M00_AXI_ID_WIDTH-1:0]      	      m00_axi_rid;
    wire                                 	  m00_axi_rvalid;
    wire                                 	  m00_axi_rready;
    wire [C_M00_AXI_DATA_WIDTH-1:0]           m00_axi_rdata;
    wire [1:0]                           	  m00_axi_rresp;
    wire                                 	  m00_axi_rlast;
    wire [C_M00_AXI_RUSER_WIDTH-1:0]   	      m00_axi_ruser;
    
// AXI4 slave interface dma_ip_control
    wire                                      s_axi_control_awvalid;
    wire                                      s_axi_control_awready;
    wire [C_S_AXI_CONTROL_ADDR_WIDTH-1:0]     s_axi_control_awaddr;

    wire                                      s_axi_control_wvalid;
    wire                                      s_axi_control_wready;
    wire [C_S_AXI_CONTROL_DATA_WIDTH-1:0]     s_axi_control_wdata;
    wire [(C_S_AXI_CONTROL_DATA_WIDTH/8)-1:0] s_axi_control_wstrb;

    wire                                      s_axi_control_bvalid;
    wire                                      s_axi_control_bready;
    wire [1:0]                                s_axi_control_bresp;

    wire                                      s_axi_control_arvalid;
    wire                                      s_axi_control_arready;
    wire [C_S_AXI_CONTROL_ADDR_WIDTH-1:0]     s_axi_control_araddr;

    wire                                      s_axi_control_rvalid;
    wire                                      s_axi_control_rready;
    wire [C_S_AXI_CONTROL_DATA_WIDTH-1:0]     s_axi_control_rdata;
    wire [1:0]                                s_axi_control_rresp;


// instantiation
    dma_ip_top #(
        .C_S_AXI_CONTROL_ADDR_WIDTH(C_S_AXI_CONTROL_ADDR_WIDTH),
        .C_S_AXI_CONTROL_DATA_WIDTH(C_S_AXI_CONTROL_DATA_WIDTH),
        
        .C_M00_AXI_ID_WIDTH 	   (C_M00_AXI_ID_WIDTH),
        .C_M00_AXI_ADDR_WIDTH      (C_M00_AXI_ADDR_WIDTH),
        .C_M00_AXI_DATA_WIDTH      (C_M00_AXI_DATA_WIDTH),
        .C_M00_AXI_AWUSER_WIDTH    (C_M00_AXI_AWUSER_WIDTH),
        .C_M00_AXI_WUSER_WIDTH 	   (C_M00_AXI_WUSER_WIDTH),
        .C_M00_AXI_BUSER_WIDTH 	   (C_M00_AXI_BUSER_WIDTH),
        .C_M00_AXI_ARUSER_WIDTH    (C_M00_AXI_ARUSER_WIDTH),
        .C_M00_AXI_RUSER_WIDTH 	   (C_M00_AXI_RUSER_WIDTH)
    ) inst_dma_ip_top(
        .ap_clk               (ap_clk),
        .ap_rst_n             (ap_rst_n),

        .m00_axi_awid		  (m00_axi_awid),
        .m00_axi_awvalid	  (m00_axi_awvalid),
        .m00_axi_awready	  (m00_axi_awready),
        .m00_axi_awaddr	  	  (m00_axi_awaddr),
        .m00_axi_awlen	  	  (m00_axi_awlen),
        .m00_axi_awsize	  	  (m00_axi_awsize),
        .m00_axi_awburst	  (m00_axi_awburst),
        .m00_axi_awlock	  	  (m00_axi_awlock),
        .m00_axi_awcache	  (m00_axi_awcache),
        .m00_axi_awprot	  	  (m00_axi_awprot),
        .m00_axi_awqos	  	  (m00_axi_awqos),
        .m00_axi_awregion	  (m00_axi_awregion),
        .m00_axi_awuser	  	  (m00_axi_awuser),

        .m00_axi_wid		  (m00_axi_wid),
        .m00_axi_wvalid	  	  (m00_axi_wvalid),
        .m00_axi_wready	  	  (m00_axi_wready),
        .m00_axi_wdata	  	  (m00_axi_wdata),
        .m00_axi_wstrb	  	  (m00_axi_wstrb),
        .m00_axi_wlast	  	  (m00_axi_wlast),
        .m00_axi_wuser	  	  (m00_axi_wuser),

        .m00_axi_bid		  (m00_axi_bid),
        .m00_axi_bvalid	  	  (m00_axi_bvalid),
        .m00_axi_bready	  	  (m00_axi_bready),
        .m00_axi_bresp	  	  (m00_axi_bresp),
        .m00_axi_buser	  	  (m00_axi_buser),

        .m00_axi_arid		  (m00_axi_arid),
        .m00_axi_arvalid	  (m00_axi_arvalid),
        .m00_axi_arready	  (m00_axi_arready),
        .m00_axi_araddr	  	  (m00_axi_araddr),
        .m00_axi_arlen	  	  (m00_axi_arlen),
        .m00_axi_arsize	  	  (m00_axi_arsize),
        .m00_axi_arburst	  (m00_axi_arburst),
        .m00_axi_arlock	  	  (m00_axi_arlock),
        .m00_axi_arcache	  (m00_axi_arcache),
        .m00_axi_arprot	  	  (m00_axi_arprot),
        .m00_axi_arqos	  	  (m00_axi_arqos),
        .m00_axi_arregion	  (m00_axi_arregion),
        .m00_axi_aruser	  	  (m00_axi_aruser),

        .m00_axi_rid		  (m00_axi_rid),
        .m00_axi_rvalid	  	  (m00_axi_rvalid),
        .m00_axi_rready	  	  (m00_axi_rready),
        .m00_axi_rdata	  	  (m00_axi_rdata),
        .m00_axi_rresp	  	  (m00_axi_rresp),
        .m00_axi_rlast	  	  (m00_axi_rlast),
        .m00_axi_ruser	  	  (m00_axi_ruser),

        .s_axi_control_awvalid(s_axi_control_awvalid),
        .s_axi_control_awready(s_axi_control_awready),
        .s_axi_control_awaddr (s_axi_control_awaddr),

        .s_axi_control_wvalid (s_axi_control_wvalid),
        .s_axi_control_wready (s_axi_control_wready),
        .s_axi_control_wdata  (s_axi_control_wdata),
        .s_axi_control_wstrb  (s_axi_control_wstrb),

        .s_axi_control_bvalid (s_axi_control_bvalid),
        .s_axi_control_bready (s_axi_control_bready),
        .s_axi_control_bresp  (s_axi_control_bresp),

        .s_axi_control_arvalid(s_axi_control_arvalid),
        .s_axi_control_arready(s_axi_control_arready),
        .s_axi_control_araddr (s_axi_control_araddr),

        .s_axi_control_rvalid (s_axi_control_rvalid),
        .s_axi_control_rready (s_axi_control_rready),
        .s_axi_control_rdata  (s_axi_control_rdata),
        .s_axi_control_rresp  (s_axi_control_rresp)
    );

// Master Control instantiation
    control_dma_ip_vip inst_control_dma_ip_vip(
        .aclk         (ap_clk),
        .aresetn      (ap_rst_n),

        .m_axi_awvalid(s_axi_control_awvalid),
        .m_axi_awready(s_axi_control_awready),
        .m_axi_awaddr (s_axi_control_awaddr),

        .m_axi_wvalid (s_axi_control_wvalid),
        .m_axi_wready (s_axi_control_wready),
        .m_axi_wdata  (s_axi_control_wdata),
        .m_axi_wstrb  (s_axi_control_wstrb),

        .m_axi_bvalid (s_axi_control_bvalid),
        .m_axi_bready (s_axi_control_bready),
        .m_axi_bresp  (s_axi_control_bresp),

        .m_axi_arvalid(s_axi_control_arvalid),
        .m_axi_arready(s_axi_control_arready),
        .m_axi_araddr (s_axi_control_araddr),

        .m_axi_rvalid (s_axi_control_rvalid),
        .m_axi_rready (s_axi_control_rready),
        .m_axi_rdata  (s_axi_control_rdata),
        .m_axi_rresp  (s_axi_control_rresp)
    );

    control_dma_ip_vip_mst_t ctrl;

// Slave MM VIP instantiation (memory)
// only use 64b addr
    slv_m00_axi_vip #(
        .C_S_AXI_ID_WIDTH    (C_M00_AXI_ID_WIDTH),
        .C_S_AXI_ADDR_WIDTH  (C_M00_AXI_ADDR_WIDTH),
        .C_S_AXI_DATA_WIDTH  (C_M00_AXI_DATA_WIDTH),
        .C_S_AXI_AWUSER_WIDTH(C_M00_AXI_AWUSER_WIDTH),
        .C_S_AXI_WUSER_WIDTH (C_M00_AXI_WUSER_WIDTH),
        .C_S_AXI_BUSER_WIDTH (C_M00_AXI_BUSER_WIDTH),
        .C_S_AXI_ARUSER_WIDTH(C_M00_AXI_ARUSER_WIDTH),
        .C_S_AXI_RUSER_WIDTH (C_M00_AXI_RUSER_WIDTH),
        .C_S_AXI_USER_VALUE  (C_M00_AXI_USER_VALUE),
        .C_S_AXI_PROT_VALUE  (C_M00_AXI_PROT_VALUE),
        .C_S_AXI_CACHE_VALUE (C_M00_AXI_CACHE_VALUE)
    ) inst_slv_m00_axi_vip(  
        .aclk          		 (ap_clk),
        .aresetn       		 (ap_rst_n),

        .s_axi_awvalid	  	 (m00_axi_awvalid),
        .s_axi_awready	  	 (m00_axi_awready),
        .s_axi_awaddr	  	 (m00_axi_awaddr),
        .s_axi_awid		  	 (m00_axi_awid),
        .s_axi_awlen	  	 (m00_axi_awlen),
        .s_axi_awsize	  	 (m00_axi_awsize),
        .s_axi_awburst	 	 (m00_axi_awburst),
        .s_axi_awlock	  	 (m00_axi_awlock),
        .s_axi_awcache	 	 (m00_axi_awcache),
        .s_axi_awprot	  	 (m00_axi_awprot),
        .s_axi_awqos	  	 (m00_axi_awqos),
        .s_axi_awregion	 	 (m00_axi_awregion),
        .s_axi_awuser	  	 (m00_axi_awuser),
        .s_axi_wvalid	  	 (m00_axi_wvalid),
        .s_axi_wready	  	 (m00_axi_wready),
        .s_axi_wdata	  	 (m00_axi_wdata),
        .s_axi_wstrb	  	 (m00_axi_wstrb),
        .s_axi_wlast	  	 (m00_axi_wlast),
        .s_axi_wid		 	 (m00_axi_wid),
        .s_axi_wuser	  	 (m00_axi_wuser),
        .s_axi_arvalid	 	 (m00_axi_arvalid),
        .s_axi_arready	 	 (m00_axi_arready),
        .s_axi_araddr	  	 (m00_axi_araddr),
        .s_axi_arid		 	 (m00_axi_arid),
        .s_axi_arlen	  	 (m00_axi_arlen),
        .s_axi_arsize	  	 (m00_axi_arsize),
        .s_axi_arburst	 	 (m00_axi_arburst),
        .s_axi_arlock	  	 (m00_axi_arlock),
        .s_axi_arcache	 	 (m00_axi_arcache),
        .s_axi_arprot	  	 (m00_axi_arprot),
        .s_axi_arqos	  	 (m00_axi_arqos),
        .s_axi_arregion	 	 (m00_axi_arregion),
        .s_axi_aruser	  	 (m00_axi_aruser),
        .s_axi_rvalid	  	 (m00_axi_rvalid),
        .s_axi_rready	  	 (m00_axi_rready),
        .s_axi_rdata	  	 (m00_axi_rdata),
        .s_axi_rlast	  	 (m00_axi_rlast),
        .s_axi_rid		 	 (m00_axi_rid),
        .s_axi_ruser	  	 (m00_axi_ruser),
        .s_axi_rresp	  	 (m00_axi_rresp),
        .s_axi_bvalid	  	 (m00_axi_bvalid),
        .s_axi_bready	  	 (m00_axi_bready),
        .s_axi_bresp	  	 (m00_axi_bresp),
        .s_axi_bid		 	 (m00_axi_bid),
        .s_axi_buser	  	 (m00_axi_buser)
    );

slv_m00_axi_vip_slv_mem_t   m00_axi;

/////// Control interface blocking write
/////// The task will return when the BRESP has been returned from the kernel.
task automatic blocking_write_register (input bit [31:0] addr_in, input bit [31:0] data);
  axi_transaction   wr_xfer;
  axi_transaction   wr_rsp;
  wr_xfer = ctrl.wr_driver.create_transaction("wr_xfer");
  wr_xfer.set_driver_return_item_policy(XIL_AXI_PAYLOAD_RETURN);
  assert(wr_xfer.randomize() with {addr == addr_in;});
  wr_xfer.set_data_beat(0, data);
  ctrl.wr_driver.send(wr_xfer);
  ctrl.wr_driver.wait_rsp(wr_rsp);
endtask

/////////////////////////////////////////////////////////////////////////////////////////////////
// Control interface blocking read
// The task will return when the BRESP has been returned from the kernel.
task automatic read_register (input bit [31:0] addr, output bit [31:0] rddata);
  axi_transaction   rd_xfer;
  axi_transaction   rd_rsp;
  bit [31:0] rd_value;
  rd_xfer = ctrl.rd_driver.create_transaction("rd_xfer");
  rd_xfer.set_addr(addr);
  rd_xfer.set_driver_return_item_policy(XIL_AXI_PAYLOAD_RETURN);
  ctrl.rd_driver.send(rd_xfer);
  ctrl.rd_driver.wait_rsp(rd_rsp);
  rd_value = rd_rsp.get_data_beat(0);
  rddata = rd_value;
endtask

task backdoor_memory_write_byte (
	input int unsigned addr,
	input byte    unsigned data 
);
	int unsigned aligned_offset;
	bit [C_M00_AXI_DATA_WIDTH-1:0] 		bus_data;
	bit [C_M00_AXI_DATA_WIDTH_BYTE-1:0]  	bus_strb;

	bus_data       = {C_M00_AXI_DATA_WIDTH{1'b0}};
	bus_strb       = {C_M00_AXI_DATA_WIDTH_BYTE{1'b0}};
	aligned_offset = addr[C_M00_AXI_DATA_WIDTH_BYTE_LOG-1:0];

	bus_data       = bus_data + (data << (8*aligned_offset));
	bus_strb       = bus_strb + (1'b1 << aligned_offset);
	m00_axi.mem_model.backdoor_memory_write({addr[31:C_M00_AXI_DATA_WIDTH_BYTE_LOG], {C_M00_AXI_DATA_WIDTH_BYTE_LOG{1'b0}}}, bus_data, bus_strb);
endtask

task backdoor_memory_read_byte (
	input int unsigned addr,
	output byte   unsigned data 
);
	int unsigned aligned_offset;
	bit [C_M00_AXI_DATA_WIDTH-1:0] 		bus_data;
	bit [C_M00_AXI_DATA_WIDTH_BYTE-1:0]  	bus_strb;

	bus_data       = {C_M00_AXI_DATA_WIDTH{1'b0}};
	bus_strb       = {C_M00_AXI_DATA_WIDTH_BYTE{1'b0}};
	aligned_offset = addr[C_M00_AXI_DATA_WIDTH_BYTE_LOG-1:0];

	bus_data = m00_axi.mem_model.backdoor_memory_read({addr[31:C_M00_AXI_DATA_WIDTH_BYTE_LOG], {C_M00_AXI_DATA_WIDTH_BYTE_LOG{1'b0}}});
	data = bus_data[(8*aligned_offset) +: 8];
endtask

/////////////////////////////////////////////////////////////////////////////////////////////////
// Start the control VIP, SLAVE memory models and AXI4-Stream.
//`define RANDOM_TRANSACTION
task automatic start_vips();
  axi_ready_gen     rgen;
  $display("///////////////////////////////////////////////////////////////////////////");
  $display("Control Master: ctrl");
  ctrl = new("ctrl", tb_dma_ip.inst_control_dma_ip_vip.inst.IF);
  ctrl.start_master();

  $display("///////////////////////////////////////////////////////////////////////////");
  $display("Starting Memory slave: m00_axi");
  m00_axi = new("m00_axi", tb_dma_ip.inst_slv_m00_axi_vip.inst.IF);
`ifdef RANDOM_TRANSACTION
  $display("random transaction for checking DMA controller :) ");
  rgen = new("m00_axi_random transaction"); 
  m00_axi.mem_model.set_inter_beat_gap_delay_policy(XIL_AXI_MEMORY_DELAY_RANDOM);
  m00_axi.mem_model.set_inter_beat_gap_range(0,10);
`else
  $display("Ideal Case. for checking best performance :)");
  rgen = new("m00_axi_no_backpressure_allready"); 
  rgen.set_ready_policy(XIL_AXI_READY_GEN_NO_BACKPRESSURE);
  m00_axi.wr_driver.set_wready_gen(rgen);
  m00_axi.wr_driver.set_awready_gen(rgen);
  m00_axi.rd_driver.set_arready_gen(rgen);
`endif
/////////
 m00_axi.start_slave();

endtask

/////////////////////////////////////////////////////////////////////////////////////////////////
// Main Function
/////////////////////////////////////////////////////////////////////////////////////////////////
initial begin : STIMULUS
  bit [31:0] lite_rddata;
  byte unsigned ret_rd_value;
  byte unsigned ret_wr_value;
  bit error_found;
  integer error_counter;

  ret_rd_value  = 'd0;
  ret_wr_value  = 'd0;
  error_found   = 'd0;
  error_counter = 'd0;
  #200;
  $display( "==========================================");
  $display( "==TestBench for verification AMBA System==");
  $display( "==========================================");
  start_vips();

  $display("Transfer byte (read) = %d", USER_TRANSFER_LEN);
  $display("Transfer byte (write) = %d", USER_TRANSFER_LEN);
  $display("RDMA (source) address = %d", USER_RDMA_ADDR);
  $display("WDMA (destination) address = %d", USER_TRANSFER_LEN + USER_RDMA_ADDR);
  assert(USER_TRANSFER_LEN%C_M00_AXI_DATA_WIDTH_BYTE == 0)
  else $error("insert data width byte align. (align by %d)", C_M00_AXI_DATA_WIDTH_BYTE);
  assert( USER_RDMA_ADDR%C_M00_AXI_DATA_WIDTH_BYTE == 0)
  else $error("insert data width byte align. (align by %d)", C_M00_AXI_DATA_WIDTH_BYTE);
  assert(USER_TRANSFER_LEN <= 67108864) // 64MByte
  else $error("insert a value of transfer byte less than or equal to 67108864)");

  // initialize memory data
  // 0x0001, 0x0002, 0x0003, ..., 0x0010, 0x0001, 0x0002, ...
  for(longint unsigned slot = 0; slot < USER_TRANSFER_LEN; slot = slot+1) begin
    if(slot%2 == 0) begin
      ret_wr_value = 'd0;
    end
    else begin
      ret_wr_value = ((slot>>1) % 16) + 1;
    end
    backdoor_memory_write_byte(USER_RDMA_ADDR+USER_TRANSFER_LEN-slot-1, ret_wr_value);
  end


  blocking_write_register(ADDR_RDMA_TRANSFER_BYTE_DATA_0, USER_TRANSFER_LEN);
  blocking_write_register(ADDR_RDMA_MEM_PTR_DATA_0, USER_RDMA_ADDR);

  blocking_write_register(ADDR_WDMA_TRANSFER_BYTE_DATA_0, USER_TRANSFER_LEN);
  blocking_write_register(ADDR_WDMA_MEM_PTR_DATA_0, USER_RDMA_ADDR + USER_TRANSFER_LEN);

  // start. polling
  // 1. check idle
  while(1) begin
    read_register(ADDR_AP_CTRL, lite_rddata);
    $display( "ADDR_AP_CTRL check idle (hex) : %x", lite_rddata);
    if( (lite_rddata & CTRL_IDLE_MASK) == 32'b10) // IDLE
      break;
  end

  // 2. start
  blocking_write_register(ADDR_AP_CTRL, 32'b1);

  // 3. wait done
  while(1) begin
    read_register(ADDR_AP_CTRL, lite_rddata);
    $display( "ADDR_AP_CTRL wait done (hex) : %x", lite_rddata);
    if( (lite_rddata & CTRL_DONE_MASK) == 32'b1000) // DONE
      break;
  end

  $display( "================================================");
  $display( "==============Finish Simulation!!===============");
  $display( "================================================");
  $finish;
end

endmodule
