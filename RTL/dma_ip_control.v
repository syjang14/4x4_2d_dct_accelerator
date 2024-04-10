`timescale 1ns / 1ps

module dma_ip_control #(
    parameter C_S_AXI_ADDR_WIDTH = 6,
    parameter C_S_AXI_DATA_WIDTH = 32
)
(
    input                               ACLK,
    input                               ARESET,
    input                               ACLK_EN,

    input  [C_S_AXI_ADDR_WIDTH-1:0]     AWADDR,
    input                               AWVALID,
    output                              AWREADY,

    input                               WVALID,
    output                              WREADY,
    input  [C_S_AXI_DATA_WIDTH-1:0]     WDATA,
    input  [(C_S_AXI_DATA_WIDTH/8)-1:0] WSTRB,

    output                              BVALID,
    input                               BREADY,
    output [1:0]                        BRESP,

    input                               ARVALID,
    output                              ARREADY,
    input  [C_S_AXI_ADDR_WIDTH-1:0]     ARADDR,
    
    output                              RVALID,
    input                               RREADY,
    output [C_S_AXI_DATA_WIDTH-1:0]     RDATA,
    output [1:0]                        RRESP,

    output                              ap_start,
    input                               ap_done,
    input                               ap_ready,
    input                               ap_idle,
    output [31:0]                       rdma_transfer_byte,
    output [31:0]                       rdma_mem_ptr,
    output [31:0]                       wdma_transfer_byte,
    output [31:0]                       wdma_mem_ptr
);
//------------------------Address Info-------------------
//
// 0x00 : Control signals
//        bit 0  - ap_start (Read/Write/COH)
//        bit 1  - ap_idle  (Read)
//        bit 2  - ap_ready (Read/COR)
//        bit 3  - ap_done  (Read/COR)
//        others - reserved
// 0x04 : Data signal of rdma_transfer_byte
//        bit 31~0 - rdma_transfer_byte[31:0] (Read/Write)
// 0x08 : Data signal of rdma_mem_ptr
//        bit 31~0 - rdma_mem_ptr[31:0] (Read/Write)
// 0x0c : Data signal of wdma_transfer_byte
//        bit 31~0 - wdma_transfer_byte[31:0] (Read/Write)
// 0x10 : Data signal of wdma_mem_ptr
//        bit 31~0 - wdma_mem_ptr[31:0] (Read/Write)
//
// (COR = Clear on Read, COH = Clear on Handshake)

//declaration
    localparam
        // register address
        ADDR_AP_CTRL                   = 6'h00,
        ADDR_RDMA_TRANSFER_BYTE_DATA_0 = 6'h04,
        ADDR_RDMA_MEM_PTR_DATA_0       = 6'h08,
        ADDR_WDMA_TRANSFER_BYTE_DATA_0 = 6'h0c,
        ADDR_WDMA_MEM_PTR_DATA_0       = 6'h10,
        // state
        S_IDLE = 2'b00,
        S_DATA = 2'b01,
        S_RESP = 2'b10,
        S_RST  = 2'b11,
        // bit width
        ADDR_BITS = C_S_AXI_ADDR_WIDTH,
        DATA_BITS = C_S_AXI_DATA_WIDTH;

    reg  [1:0]           c_state_w;
    reg  [1:0]           n_state_w;
    reg  [ADDR_BITS-1:0] waddr;
    wire [DATA_BITS-1:0] wmask = { {8{WSTRB[3]}}, {8{WSTRB[2]}}, {8{WSTRB[1]}}, {8{WSTRB[0]}} }; 

    reg [1:0]           c_state_r;
    reg [1:0]           n_state_r;
    reg [DATA_BITS-1:0] rdata;

    wire aw_hs = AWVALID & AWREADY;
    wire w_hs  = WVALID  & WREADY;
    wire ar_hs = ARVALID & ARREADY;

    // registers
    reg         reg_ap_start;
    reg         reg_ap_idle;
    reg         reg_ap_ready;
    reg         reg_ap_done;
    reg  [31:0] reg_rdma_transfer_byte;
    reg  [31:0] reg_rdma_mem_ptr;
    reg  [31:0] reg_wdma_transfer_byte;
    reg  [31:0] reg_wdma_mem_ptr;

/////////////////////////////////////// AXI4-Lite write
// write state machine
    always @(posedge ACLK) begin
        if(ARESET) begin
            c_state_w <= S_RST;
        end
        else if(ACLK_EN) begin
            c_state_w <= n_state_w;
        end
    end

    always @(*) begin
        case(c_state_w)
            S_IDLE : n_state_w = AWVALID ? S_DATA : S_IDLE;
            S_DATA : n_state_w = WVALID  ? S_RESP : S_DATA;
            S_RESP : n_state_w = BREADY  ? S_IDLE : S_RESP;
            default: n_state_w = S_IDLE;
        endcase
    end

    assign AWREADY = (c_state_w == S_IDLE);
    assign WREADY  = (c_state_w == S_DATA);
    assign BVALID  = (c_state_w == S_RESP);
    assign BRESP   = 2'b00;  // OKAY

// write address
    always @(posedge ACLK) begin
        if(ACLK_EN) begin
            if(aw_hs) begin
                waddr <= AWADDR;
            end
        end
    end

/////////////////////////////////////// AXI4-Lite read
// read state machine
    always @(posedge ACLK) begin
        if(ARESET) begin
            c_state_r <= S_RST;
        end
        else if(ACLK_EN) begin
            c_state_r <= n_state_r;
        end
    end

    always @(*) begin
        case(c_state_r)
            S_IDLE : n_state_r = ARVALID ? S_DATA : S_IDLE;
            S_DATA : n_state_r = RREADY  ? S_IDLE : S_DATA;
            default: n_state_r = S_IDLE;
        endcase
    end

    assign ARREADY = (c_state_r == S_IDLE);
    assign RVALID  = (c_state_r == S_DATA);
    assign RRESP   = 2'b00;  // OKAY

// read data
    always @(posedge ACLK) begin
        if (ACLK_EN) begin
            if (ar_hs) begin
                rdata <= 'd0;
                case (ARADDR)
                    ADDR_AP_CTRL: begin
                        rdata[0] <= reg_ap_start;
                        rdata[1] <= reg_ap_idle;
                        rdata[2] <= reg_ap_ready;
                        rdata[3] <= reg_ap_done;
                    end
                    ADDR_RDMA_TRANSFER_BYTE_DATA_0: begin
                        rdata <= reg_rdma_transfer_byte;
                    end
                    ADDR_RDMA_MEM_PTR_DATA_0: begin
                        rdata <= reg_rdma_mem_ptr;
                    end
                    ADDR_WDMA_TRANSFER_BYTE_DATA_0: begin
                        rdata <= reg_wdma_transfer_byte;
                    end
                    ADDR_WDMA_MEM_PTR_DATA_0: begin
                        rdata <= reg_wdma_mem_ptr;
                    end
                endcase
            end
        end
    end

    assign RDATA = rdata;

/////////////////////////////////////// registers
// reg_ap_start
    always @(posedge ACLK) begin
        if(ARESET) begin
            reg_ap_start <= 1'b0;
        end
        else if(ACLK_EN) begin
            if (w_hs & (waddr == ADDR_AP_CTRL)) begin
                reg_ap_start <= WDATA[0] & WSTRB[0];
            end
            else if(ap_ready) begin
                reg_ap_start <= 1'b0;  // clear on handshake (auto restart)
            end
        end
    end

// reg_ap_idle
    always @(posedge ACLK) begin
        if(ARESET) begin
            reg_ap_idle <= 1'b0;
        end
        else if(ACLK_EN) begin
            reg_ap_idle <= ap_idle;
        end
    end

// reg_ap_ready
    always @(posedge ACLK) begin
        if(ARESET) begin
            reg_ap_ready <= 1'b0;
        end
        else if(ACLK_EN) begin
            if(ap_ready) begin
                reg_ap_ready <= 1'b1;
            end
            else if(ar_hs & (ARADDR == ADDR_AP_CTRL)) begin
                reg_ap_ready <= 1'b0;  // clear on read
            end
        end
    end

// reg_ap_done
    always @(posedge ACLK) begin
        if(ARESET) begin
            reg_ap_done <= 1'b0;
        end
        else if (ACLK_EN) begin
            if(ap_done) begin
                reg_ap_done <= 1'b1;
            end
            else if(ar_hs & (ARADDR == ADDR_AP_CTRL)) begin
                reg_ap_done <= 1'b0;  // clear on read
            end
        end
    end

// reg_rdma_transfer_byte
    always @(posedge ACLK) begin
        if(ARESET) begin
            reg_rdma_transfer_byte <= 'd0;
        end
        else if(ACLK_EN) begin
            if(w_hs & (waddr == ADDR_RDMA_TRANSFER_BYTE_DATA_0)) begin
                reg_rdma_transfer_byte <= (WDATA & wmask) | (reg_rdma_transfer_byte & ~wmask);
            end
        end
    end

// reg_rdma_mem_ptr
    always @(posedge ACLK) begin
        if(ARESET) begin
            reg_rdma_mem_ptr <= 'd0;
        end
        else if(ACLK_EN) begin
            if(w_hs & (waddr == ADDR_RDMA_MEM_PTR_DATA_0)) begin
                reg_rdma_mem_ptr <= (WDATA & wmask) | (reg_rdma_mem_ptr & ~wmask);
            end
        end
    end

// reg_wdma_transfer_byte
    always @(posedge ACLK) begin
        if(ARESET) begin
            reg_wdma_transfer_byte <= 'd0;
        end
        else if(ACLK_EN) begin
            if(w_hs & (waddr == ADDR_WDMA_TRANSFER_BYTE_DATA_0)) begin
                reg_wdma_transfer_byte <= (WDATA & wmask) | (reg_wdma_transfer_byte & ~wmask);
            end
        end
    end

// reg_wdma_mem_ptr
    always @(posedge ACLK) begin
        if(ARESET) begin
            reg_wdma_mem_ptr <= 'd0;
        end
        else if(ACLK_EN) begin
            if(w_hs & (waddr == ADDR_WDMA_MEM_PTR_DATA_0)) begin
                reg_wdma_mem_ptr <= (WDATA & wmask) | (reg_wdma_mem_ptr & ~wmask);
            end
        end
    end

    assign ap_start           = reg_ap_start;
    assign rdma_transfer_byte = reg_rdma_transfer_byte;
    assign rdma_mem_ptr       = reg_rdma_mem_ptr;
    assign wdma_transfer_byte = reg_wdma_transfer_byte;
    assign wdma_mem_ptr       = reg_wdma_mem_ptr;

endmodule
