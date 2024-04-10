`timescale 1ns / 1ps

module skid_buffer #(
    parameter DATA_WIDTH = 8
)
(
    input clk,
    input reset,

    input                   s_valid,
    output                  s_ready,
    input  [DATA_WIDTH-1:0] s_data,

    output                  m_valid,
    input                   m_ready,
    output [DATA_WIDTH-1:0] m_data
);

// state 
    localparam S_PIPE = 1'b0; // Stage where data is piped out or stored to temp buffer
    localparam S_SKID = 1'b1; // Stage to wait after data skid happened

// declaration
    reg c_state;
    reg n_state;
    
    reg                  r_s_ready;
    reg                  r_m_valid, r_m_valid_tmp;
    reg [DATA_WIDTH-1:0] r_m_data, r_m_data_tmp;

    wire ready = m_ready | ~m_valid;

// state machine
    always @(posedge clk) begin
        if(reset) begin
            c_state <= S_PIPE;
        end
        else begin
            c_state <= n_state;
        end
    end

    always @(*) begin
        case(c_state)
            S_PIPE : n_state = ready ? S_PIPE : S_SKID;
            S_SKID : n_state = ready ? S_PIPE : S_SKID;
            default: n_state = c_state;
        endcase
    end

// main
    always @(posedge clk) begin
        if(reset) begin
            r_s_ready <= 'd0;
            r_m_valid <= 'd0;
            r_m_data  <= 'd0;
            r_m_valid_tmp <= 'd0;
            r_m_data_tmp  <= 'd0;
        end
        else if(c_state == S_PIPE) begin
            if(ready) begin
                r_s_ready <= 1'b1;
                r_m_valid <= s_valid;
                r_m_data  <= s_data;
            end
            else begin
                r_s_ready     <= 1'b0;
                r_m_valid_tmp <= s_valid;
                r_m_data_tmp  <= s_data;
            end
        end
        else if(c_state == S_SKID) begin
            if(ready) begin
                r_s_ready <= 1'b1;
                r_m_valid <= r_m_valid_tmp;
                r_m_data  <= r_m_data_tmp;
            end
        end
    end

    assign s_ready = r_s_ready;
    assign m_valid = r_m_valid;
    assign m_data  = r_m_data;
  
endmodule
