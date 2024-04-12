`timescale 1ns / 1ps

module dct_4x4 #(
    parameter PERF_OPT_ROW = 0,
    parameter PERF_OPT_COL = 0
)
(
    input clk,
    input reset,

    input          i_valid,
    output         i_ready,
    input  [255:0] i_data,

    output         o_valid,
    input          o_ready,
    output [255:0] o_data
);

// declaration
    wire [127:0] i_data_128;
    wire         w_valid;
    wire         w_ready;
    wire [127:0] w_data;

    reg row_valid;
    reg col_valid;
    reg weight_valid;
    reg dct_valid;

    wire row_ready;
    wire col_ready;
    wire weight_ready;
    wire dct_ready;

    wire        [7:0] x[0:3][0:3];
    reg signed [11:0] row_out[0:3][0:3];
    reg signed [14:0] col_out[0:3][0:3];
    reg signed [19:0] weight_out[0:3][0:3];
    reg signed [15:0] dct_out[0:3][0:3];

    // weight coeffient
    // 1bit - 0bit - 5bit (sign - integer - fractional)
    wire signed [5:0] coeff_A = 6'b0_00011;  // 0.1
    wire signed [5:0] coeff_B = 6'b0_00101;  // 1/(2*sqrt(10)) = 0.158113883
    wire signed [5:0] coeff_C = 6'b0_01000;  // 0.25

    genvar i,j;
    integer n, m;

// latch input
    generate
        for(i=0; i<4; i=i+1) begin
            for(j=0; j<4; j=j+1) begin
                assign i_data_128[(32*i+8*j)+:8] = i_data[(64*i+16*j)+:8];
            end
        end
    endgenerate


    valid_ready_FF #(128) u_valid_ready_FF(
        clk, reset, i_valid, i_ready, i_data_128, w_valid, w_ready, w_data
    );
    
    generate
        for(i=0; i<4; i=i+1) begin
            for(j=0; j<4; j=j+1) begin
                assign x[i][j] = w_data[127-(32*i+8*j)-:8];
            end
        end
    endgenerate

// row operation
    generate
    if(~PERF_OPT_ROW) begin
        assign w_ready = row_ready | ~row_valid;
        always @(posedge clk) begin
            if(reset) begin
                row_valid <= 'd0;
                for(n=0; n<4; n=n+1) begin
                    for(m=0; m<4; m=m+1) begin
                        row_out[n][m] <= 'd0;
                    end
                end
            end
            else if(w_ready) begin
                row_valid <= w_valid;
                // 1 1 1 1
                row_out[0][0] <= x[0][0] + x[1][0] + x[2][0] + x[3][0];
                row_out[0][1] <= x[0][1] + x[1][1] + x[2][1] + x[3][1];
                row_out[0][2] <= x[0][2] + x[1][2] + x[2][2] + x[3][2];
                row_out[0][3] <= x[0][3] + x[1][3] + x[2][3] + x[3][3];
                // 2 1 -1 -2
                row_out[1][0] <= (x[0][0]<<1) + x[1][0] - x[2][0] - (x[3][0]<<1);
                row_out[1][1] <= (x[0][1]<<1) + x[1][1] - x[2][1] - (x[3][1]<<1);
                row_out[1][2] <= (x[0][2]<<1) + x[1][2] - x[2][2] - (x[3][2]<<1);
                row_out[1][3] <= (x[0][3]<<1) + x[1][3] - x[2][3] - (x[3][3]<<1);
                // 1 -1 -1 1
                row_out[2][0] <= x[0][0] - x[1][0] - x[2][0] + x[3][0];
                row_out[2][1] <= x[0][1] - x[1][1] - x[2][1] + x[3][1];
                row_out[2][2] <= x[0][2] - x[1][2] - x[2][2] + x[3][2];
                row_out[2][3] <= x[0][3] - x[1][3] - x[2][3] + x[3][3];
                // 1 -2 2 -1
                row_out[3][0] <= x[0][0] - (x[1][0]<<1) + (x[2][0]<<1) - x[3][0];
                row_out[3][1] <= x[0][1] - (x[1][1]<<1) + (x[2][1]<<1) - x[3][1];
                row_out[3][2] <= x[0][2] - (x[1][2]<<1) + (x[2][2]<<1) - x[3][2];
                row_out[3][3] <= x[0][3] - (x[1][3]<<1) + (x[2][3]<<1) - x[3][3];
            end
        end
    end

    // combination logic for performance optimization
    else if(PERF_OPT_ROW) begin
        assign w_ready = row_ready;
        always @(*) begin
            row_valid = w_valid;
            // 1 1 1 1
            row_out[0][0] = x[0][0] + x[1][0] + x[2][0] + x[3][0];
            row_out[0][1] = x[0][1] + x[1][1] + x[2][1] + x[3][1];
            row_out[0][2] = x[0][2] + x[1][2] + x[2][2] + x[3][2];
            row_out[0][3] = x[0][3] + x[1][3] + x[2][3] + x[3][3];
            // 2 1 -1 -2
            row_out[1][0] = (x[0][0]<<1) + x[1][0] - x[2][0] - (x[3][0]<<1);
            row_out[1][1] = (x[0][1]<<1) + x[1][1] - x[2][1] - (x[3][1]<<1);
            row_out[1][2] = (x[0][2]<<1) + x[1][2] - x[2][2] - (x[3][2]<<1);
            row_out[1][3] = (x[0][3]<<1) + x[1][3] - x[2][3] - (x[3][3]<<1);
            // 1 -1 -1 1
            row_out[2][0] = x[0][0] - x[1][0] - x[2][0] + x[3][0];
            row_out[2][1] = x[0][1] - x[1][1] - x[2][1] + x[3][1];
            row_out[2][2] = x[0][2] - x[1][2] - x[2][2] + x[3][2];
            row_out[2][3] = x[0][3] - x[1][3] - x[2][3] + x[3][3];
            // 1 -2 2 -1
            row_out[3][0] = x[0][0] - (x[1][0]<<1) + (x[2][0]<<1) - x[3][0];
            row_out[3][1] = x[0][1] - (x[1][1]<<1) + (x[2][1]<<1) - x[3][1];
            row_out[3][2] = x[0][2] - (x[1][2]<<1) + (x[2][2]<<1) - x[3][2];
            row_out[3][3] = x[0][3] - (x[1][3]<<1) + (x[2][3]<<1) - x[3][3];
        end
    end
    endgenerate

// column operation (trasnposed)
    generate
    if(~PERF_OPT_COL) begin
        assign row_ready = col_ready | ~col_valid;
        always @(posedge clk) begin
            if(reset) begin
                col_valid <= 'd0;
                for(n=0; n<4; n=n+1) begin
                    for(m=0; m<4; m=m+1) begin
                        col_out[n][m] <= 'd0;
                    end
                end
            end
            else if(row_ready) begin
                col_valid <= row_valid;
                // 1 1 1 1
                col_out[0][0] <= row_out[0][0] + row_out[0][1] + row_out[0][2] + row_out[0][3];
                col_out[1][0] <= row_out[1][0] + row_out[1][1] + row_out[1][2] + row_out[1][3];
                col_out[2][0] <= row_out[2][0] + row_out[2][1] + row_out[2][2] + row_out[2][3];
                col_out[3][0] <= row_out[3][0] + row_out[3][1] + row_out[3][2] + row_out[3][3];
                // 2 1 -1 2
                col_out[0][1] <= (row_out[0][0]<<1) + row_out[0][1] - row_out[0][2] - (row_out[0][3]<<1);
                col_out[1][1] <= (row_out[1][0]<<1) + row_out[1][1] - row_out[1][2] - (row_out[1][3]<<1);
                col_out[2][1] <= (row_out[2][0]<<1) + row_out[2][1] - row_out[2][2] - (row_out[2][3]<<1);
                col_out[3][1] <= (row_out[3][0]<<1) + row_out[3][1] - row_out[3][2] - (row_out[3][3]<<1);
                // 1 -1 -1 1
                col_out[0][2] <= row_out[0][0] - row_out[0][1] - row_out[0][2] + row_out[0][3];
                col_out[1][2] <= row_out[1][0] - row_out[1][1] - row_out[1][2] + row_out[1][3];
                col_out[2][2] <= row_out[2][0] - row_out[2][1] - row_out[2][2] + row_out[2][3];
                col_out[3][2] <= row_out[3][0] - row_out[3][1] - row_out[3][2] + row_out[3][3];
                // 1 -2 2 -1
                col_out[0][3] <= row_out[0][0] - (row_out[0][1]<<1) + (row_out[0][2]<<1) - row_out[0][3];
                col_out[1][3] <= row_out[1][0] - (row_out[1][1]<<1) + (row_out[1][2]<<1) - row_out[1][3];
                col_out[2][3] <= row_out[2][0] - (row_out[2][1]<<1) + (row_out[2][2]<<1) - row_out[2][3];
                col_out[3][3] <= row_out[3][0] - (row_out[3][1]<<1) + (row_out[3][2]<<1) - row_out[3][3];
            end
        end
    end

    // combination logic for performance optimization
    else if(PERF_OPT_COL) begin
        assign row_ready = col_ready;
        always @(*) begin
            col_valid = row_valid;
            // 1 1 1 1
            col_out[0][0] = row_out[0][0] + row_out[0][1] + row_out[0][2] + row_out[0][3];
            col_out[1][0] = row_out[1][0] + row_out[1][1] + row_out[1][2] + row_out[1][3];
            col_out[2][0] = row_out[2][0] + row_out[2][1] + row_out[2][2] + row_out[2][3];
            col_out[3][0] = row_out[3][0] + row_out[3][1] + row_out[3][2] + row_out[3][3];
            // 2 1 -1 2
            col_out[0][1] = (row_out[0][0]<<1) + row_out[0][1] - row_out[0][2] - (row_out[0][3]<<1);
            col_out[1][1] = (row_out[1][0]<<1) + row_out[1][1] - row_out[1][2] - (row_out[1][3]<<1);
            col_out[2][1] = (row_out[2][0]<<1) + row_out[2][1] - row_out[2][2] - (row_out[2][3]<<1);
            col_out[3][1] = (row_out[3][0]<<1) + row_out[3][1] - row_out[3][2] - (row_out[3][3]<<1);
            // 1 -1 -1 1
            col_out[0][2] = row_out[0][0] - row_out[0][1] - row_out[0][2] + row_out[0][3];
            col_out[1][2] = row_out[1][0] - row_out[1][1] - row_out[1][2] + row_out[1][3];
            col_out[2][2] = row_out[2][0] - row_out[2][1] - row_out[2][2] + row_out[2][3];
            col_out[3][2] = row_out[3][0] - row_out[3][1] - row_out[3][2] + row_out[3][3];
            // 1 -2 2 -1
            col_out[0][3] = row_out[0][0] - (row_out[0][1]<<1) + (row_out[0][2]<<1) - row_out[0][3];
            col_out[1][3] = row_out[1][0] - (row_out[1][1]<<1) + (row_out[1][2]<<1) - row_out[1][3];
            col_out[2][3] = row_out[2][0] - (row_out[2][1]<<1) + (row_out[2][2]<<1) - row_out[2][3];
            col_out[3][3] = row_out[3][0] - (row_out[3][1]<<1) + (row_out[3][2]<<1) - row_out[3][3];
        end
    end
    endgenerate

// weight multiply (hadamard)
    assign col_ready = weight_ready | ~weight_valid;
    always @(posedge clk) begin
        if(reset) begin
            weight_valid <= 'd0;
            for(n=0; n<4; n=n+1) begin
                for(m=0; m<4; m=m+1) begin
                    weight_out[n][m] <= 'd0;
                end
            end
        end
        // 1bit - 12bit - 5bit (sign - integer - fractional)
        else if(col_ready) begin
            weight_valid <= col_valid;
            weight_out[0][0] <= coeff_C * col_out[0][0];
            weight_out[0][1] <= coeff_B * col_out[0][1];
            weight_out[0][2] <= coeff_C * col_out[0][2];
            weight_out[0][3] <= coeff_B * col_out[0][3];
            weight_out[1][0] <= coeff_B * col_out[1][0];
            weight_out[1][1] <= coeff_A * col_out[1][1];
            weight_out[1][2] <= coeff_B * col_out[1][2];
            weight_out[1][3] <= coeff_A * col_out[1][3];
            weight_out[2][0] <= coeff_C * col_out[2][0];
            weight_out[2][1] <= coeff_B * col_out[2][1];
            weight_out[2][2] <= coeff_C * col_out[2][2];
            weight_out[2][3] <= coeff_B * col_out[2][3];
            weight_out[3][0] <= coeff_B * col_out[3][0];
            weight_out[3][1] <= coeff_A * col_out[3][1];
            weight_out[3][2] <= coeff_B * col_out[3][2];
            weight_out[3][3] <= coeff_A * col_out[3][3];
        end
    end

    assign weight_ready = dct_ready | ~dct_valid;
    always @(posedge clk) begin
        if(reset) begin
            dct_valid <= 'd0;
            for(n=0; n<4; n=n+1) begin
                for(m=0; m<4; m=m+1) begin
                    dct_out[n][m] <= 'd0;
                end
            end
        end
        else if(weight_ready) begin
            dct_valid <= weight_valid;
            dct_out[0][0] <= {weight_out[0][0][19], weight_out[0][0][15:5], weight_out[0][0][4:1]};
            dct_out[0][1] <= {weight_out[0][1][19], weight_out[0][1][15:5], weight_out[0][1][4:1]};
            dct_out[0][2] <= {weight_out[0][2][19], weight_out[0][2][15:5], weight_out[0][2][4:1]};
            dct_out[0][3] <= {weight_out[0][3][19], weight_out[0][3][15:5], weight_out[0][3][4:1]};
            dct_out[1][0] <= {weight_out[1][0][19], weight_out[1][0][15:5], weight_out[1][0][4:1]};
            dct_out[1][1] <= {weight_out[1][1][19], weight_out[1][1][15:5], weight_out[1][1][4:1]};
            dct_out[1][2] <= {weight_out[1][2][19], weight_out[1][2][15:5], weight_out[1][2][4:1]};
            dct_out[1][3] <= {weight_out[1][3][19], weight_out[1][3][15:5], weight_out[1][3][4:1]};
            dct_out[2][0] <= {weight_out[2][0][19], weight_out[2][0][15:5], weight_out[2][0][4:1]};
            dct_out[2][1] <= {weight_out[2][1][19], weight_out[2][1][15:5], weight_out[2][1][4:1]};
            dct_out[2][2] <= {weight_out[2][2][19], weight_out[2][2][15:5], weight_out[2][2][4:1]};
            dct_out[2][3] <= {weight_out[2][3][19], weight_out[2][3][15:5], weight_out[2][3][4:1]};
            dct_out[3][0] <= {weight_out[3][0][19], weight_out[3][0][15:5], weight_out[3][0][4:1]};
            dct_out[3][1] <= {weight_out[3][1][19], weight_out[3][1][15:5], weight_out[3][1][4:1]};
            dct_out[3][2] <= {weight_out[3][2][19], weight_out[3][2][15:5], weight_out[3][2][4:1]};
            dct_out[3][3] <= {weight_out[3][3][19], weight_out[3][3][15:5], weight_out[3][3][4:1]};
        end
    end

// assign output
    assign o_valid = dct_valid;
    assign o_data = {
        dct_out[0][0], dct_out[0][1], dct_out[0][2], dct_out[0][3],
        dct_out[1][0], dct_out[1][1], dct_out[1][2], dct_out[1][3],
        dct_out[2][0], dct_out[2][1], dct_out[2][2], dct_out[2][3],
        dct_out[3][0], dct_out[3][1], dct_out[3][2], dct_out[3][3]
    };


endmodule