module ISP(
    //Input Port
    clk,
    rst_n,

    in_valid,
    in,
    param_valid,
    param_gain,

    //Output Port
    out_valid,
    r_out,
    g_out,
    b_out
    );

//==============================
//   INPUT/OUTPUT DECLARATION
//==============================
input clk;
input rst_n;
input in_valid;
input [11:0] in;
input param_valid;
input [11:0] param_gain;

output reg out_valid;
output reg [11:0] r_out;
output reg [11:0] g_out;
output reg [11:0] b_out;

//==============================
//   Design
//==============================

reg        in_valid_d1;
reg [11:0] in_d1;
reg        param_valid_d1;
reg [11:0] param_gain_d1;
reg        blc_valid_d1;
reg [11:0] blc_pixel_d1;
reg        lsc_valid_d1;
reg [11:0] lsc_pixel_d1;
reg        dpc_valid_d1;
reg [11:0] dpc_pixel_d1;
reg        dm_valid_d1;
reg [11:0] dm_r_d1;
reg [11:0] dm_g_d1;
reg [11:0] dm_b_d1;

//------------------------------
//   BLC
//------------------------------
wire [11:0] blc_pixel;
wire        dpc_out_valid;
wire [11:0] dpc_out_pixel;
wire        dm_out_valid;
wire [11:0] dm_r_out;
wire [11:0] dm_g_out;
wire [11:0] dm_b_out;
wire        ccm_out_valid;
wire [11:0] ccm_r_out;
wire [11:0] ccm_g_out;
wire [11:0] ccm_b_out;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        in_valid_d1    <= 1'b0;
        in_d1          <= 12'd0;
        param_valid_d1 <= 1'b0;
        param_gain_d1  <= 12'd0;
    end
    else begin
        in_valid_d1    <= in_valid;
        in_d1          <= in;
        param_valid_d1 <= param_valid;
        param_gain_d1  <= param_gain;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_valid <= 1'b0;
        r_out     <= 12'd0;
        g_out     <= 12'd0;
        b_out     <= 12'd0;
    end
    else begin
        out_valid <= ccm_out_valid;
        if (ccm_out_valid) begin
            r_out <= ccm_r_out;
            g_out <= ccm_g_out;
            b_out <= ccm_b_out;
        end
        else begin
            r_out <= 12'd0;
            g_out <= 12'd0;
            b_out <= 12'd0;
        end
    end
end

blc u_blc (
    .clk      (clk),
    .rst_n    (rst_n),
    .in_valid (in_valid_d1),
    .in       (in_d1),
    .blc_pixel(blc_pixel)
);
//------------------------------
//   LSC
//------------------------------
wire       lsc_valid;
wire [11:0] lsc_pixel;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        blc_valid_d1 <= 1'b0;
        blc_pixel_d1 <= 12'd0;
        lsc_valid_d1 <= 1'b0;
        lsc_pixel_d1 <= 12'd0;
        dpc_valid_d1 <= 1'b0;
        dpc_pixel_d1 <= 12'd0;
        dm_valid_d1  <= 1'b0;
        dm_r_d1      <= 12'd0;
        dm_g_d1      <= 12'd0;
        dm_b_d1      <= 12'd0;
    end
    else begin
        blc_valid_d1 <= in_valid_d1;
        blc_pixel_d1 <= blc_pixel;

        lsc_valid_d1 <= lsc_valid;
        lsc_pixel_d1 <= lsc_pixel;

        dpc_valid_d1 <= dpc_out_valid;
        dpc_pixel_d1 <= dpc_out_pixel;

        dm_valid_d1 <= dm_out_valid;
        dm_r_d1     <= dm_r_out;
        dm_g_d1     <= dm_g_out;
        dm_b_d1     <= dm_b_out;
    end
end

lsc u_lsc (
    .clk        (clk),
    .rst_n      (rst_n),
    .in_valid   (blc_valid_d1),
    .blc_pixel  (blc_pixel_d1),
    .param_valid(param_valid_d1),
    .param_gain (param_gain_d1),
    .lsc_valid  (lsc_valid),
    .lsc_pixel  (lsc_pixel)
);
dpc u_dpc (
    .clk          (clk),
    .rst_n        (rst_n),
    .lsc_valid    (lsc_valid_d1),
    .lsc_pixel    (lsc_pixel_d1),
    .dpc_out_valid(dpc_out_valid),
    .dpc_out_pixel(dpc_out_pixel)
);
demosaic_bilinear_3x3 #(
    .PIXW(12),
    .IMG_W(16),
    .IMG_H(16),
    .ROWW(4),
    .COLW(4)
) u_demosaic_bilinear_3x3 (
    .clk      (clk),
    .rst_n    (rst_n),
    .in_valid (dpc_valid_d1),
    .pixel_in (dpc_pixel_d1),
    .out_valid(dm_out_valid),
    .r_out    (dm_r_out),
    .g_out    (dm_g_out),
    .b_out    (dm_b_out)
);

ccm u_ccm (
    .clk      (clk),
    .rst_n    (rst_n),
    .in_valid (dm_valid_d1),
    .r_in     (dm_r_d1),
    .g_in     (dm_g_d1),
    .b_in     (dm_b_d1),
    .out_valid(ccm_out_valid),
    .r_out    (ccm_r_out),
    .g_out    (ccm_g_out),
    .b_out    (ccm_b_out)
);
endmodule

module demosaic_bilinear_3x3 #(
    parameter PIXW  = 8,
    parameter IMG_W = 16,
    parameter IMG_H = 16,
    parameter ROWW  = 4,
    parameter COLW  = 4
)(
    input                   clk,
    input                   rst_n,
    input                   in_valid,
    input      [PIXW-1:0]   pixel_in,
    output                  out_valid,
    output     [PIXW-1:0]   r_out,
    output     [PIXW-1:0]   g_out,
    output     [PIXW-1:0]   b_out
);

localparam [ROWW-1:0] LAST_ROW = IMG_H - 1;
localparam [COLW-1:0] LAST_COL = IMG_W - 1;

reg [PIXW-1:0] frame_mem [0:IMG_H-1][0:IMG_W-1];
reg [ROWW-1:0] wr_row;
reg [COLW-1:0] wr_col;
reg [ROWW-1:0] rd_row;
reg [COLW-1:0] rd_col;
reg            frame_ready;
reg            out_valid_r;
reg [PIXW-1:0] r_out_r;
reg [PIXW-1:0] g_out_r;
reg [PIXW-1:0] b_out_r;

function [ROWW-1:0] mirror_row_idx;
    input integer idx;
    begin
        if (idx < 0)
            mirror_row_idx = -idx;
        else if (idx > (IMG_H-1))
            mirror_row_idx = (2*IMG_H-2) - idx;
        else
            mirror_row_idx = idx[ROWW-1:0];
    end
endfunction

function [COLW-1:0] mirror_col_idx;
    input integer idx;
    begin
        if (idx < 0)
            mirror_col_idx = -idx;
        else if (idx > (IMG_W-1))
            mirror_col_idx = (2*IMG_W-2) - idx;
        else
            mirror_col_idx = idx[COLW-1:0];
    end
endfunction

wire [ROWW-1:0] row_m1 = mirror_row_idx($signed({1'b0, rd_row}) - 1);
wire [ROWW-1:0] row_0  = mirror_row_idx($signed({1'b0, rd_row}));
wire [ROWW-1:0] row_p1 = mirror_row_idx($signed({1'b0, rd_row}) + 1);
wire [COLW-1:0] col_m1 = mirror_col_idx($signed({1'b0, rd_col}) - 1);
wire [COLW-1:0] col_0  = mirror_col_idx($signed({1'b0, rd_col}));
wire [COLW-1:0] col_p1 = mirror_col_idx($signed({1'b0, rd_col}) + 1);

wire [PIXW-1:0] nw_in = frame_mem[row_m1][col_m1];
wire [PIXW-1:0] n_in  = frame_mem[row_m1][col_0 ];
wire [PIXW-1:0] ne_in = frame_mem[row_m1][col_p1];
wire [PIXW-1:0] w_in  = frame_mem[row_0 ][col_m1];
wire [PIXW-1:0] c_in  = frame_mem[row_0 ][col_0 ];
wire [PIXW-1:0] e_in  = frame_mem[row_0 ][col_p1];
wire [PIXW-1:0] sw_in = frame_mem[row_p1][col_m1];
wire [PIXW-1:0] s_in  = frame_mem[row_p1][col_0 ];
wire [PIXW-1:0] se_in = frame_mem[row_p1][col_p1];

wire [PIXW+1:0] cross_sum = n_in + s_in + w_in + e_in;
wire [PIXW+1:0] diag_sum  = nw_in + ne_in + sw_in + se_in;
wire [PIXW  :0] h_sum     = w_in + e_in;
wire [PIXW  :0] v_sum     = n_in + s_in;

wire [PIXW-1:0] cross_avg = (cross_sum + 2'd2) >> 2;
wire [PIXW-1:0] diag_avg  = (diag_sum  + 2'd2) >> 2;
wire [PIXW-1:0] h_avg     = (h_sum     + 1'd1) >> 1;
wire [PIXW-1:0] v_avg     = (v_sum     + 1'd1) >> 1;

reg [PIXW-1:0] calc_r;
reg [PIXW-1:0] calc_g;
reg [PIXW-1:0] calc_b;

always @(*) begin
    if ((rd_row[0] == 1'b0) && (rd_col[0] == 1'b0)) begin
        calc_r = c_in;
        calc_g = cross_avg;
        calc_b = diag_avg;
    end
    else if ((rd_row[0] == 1'b0) && (rd_col[0] == 1'b1)) begin
        calc_r = h_avg;
        calc_g = c_in;
        calc_b = v_avg;
    end
    else if ((rd_row[0] == 1'b1) && (rd_col[0] == 1'b0)) begin
        calc_r = v_avg;
        calc_g = c_in;
        calc_b = h_avg;
    end
    else begin
        calc_r = diag_avg;
        calc_g = cross_avg;
        calc_b = c_in;
    end
end

assign out_valid = out_valid_r;
assign r_out = r_out_r;
assign g_out = g_out_r;
assign b_out = b_out_r;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_row     <= {ROWW{1'b0}};
        wr_col     <= {COLW{1'b0}};
        rd_row     <= {ROWW{1'b0}};
        rd_col     <= {COLW{1'b0}};
        frame_ready <= 1'b0;
        out_valid_r <= 1'b0;
        r_out_r     <= {PIXW{1'b0}};
        g_out_r     <= {PIXW{1'b0}};
        b_out_r     <= {PIXW{1'b0}};
    end
    else begin
        out_valid_r <= 1'b0;
        r_out_r     <= {PIXW{1'b0}};
        g_out_r     <= {PIXW{1'b0}};
        b_out_r     <= {PIXW{1'b0}};

        if (in_valid && !frame_ready) begin
            frame_mem[wr_row][wr_col] <= pixel_in;
            if ((wr_row == LAST_ROW) && (wr_col == LAST_COL)) begin
                wr_row      <= {ROWW{1'b0}};
                wr_col      <= {COLW{1'b0}};
                rd_row      <= {ROWW{1'b0}};
                rd_col      <= {COLW{1'b0}};
                frame_ready <= 1'b1;
            end
            else if (wr_col == LAST_COL) begin
                wr_col <= {COLW{1'b0}};
                wr_row <= wr_row + {{(ROWW-1){1'b0}}, 1'b1};
            end
            else begin
                wr_col <= wr_col + {{(COLW-1){1'b0}}, 1'b1};
            end
        end
        else if (frame_ready) begin
            out_valid_r <= 1'b1;
            r_out_r     <= calc_r;
            g_out_r     <= calc_g;
            b_out_r     <= calc_b;

            if ((rd_row == LAST_ROW) && (rd_col == LAST_COL)) begin
                rd_row      <= {ROWW{1'b0}};
                rd_col      <= {COLW{1'b0}};
                frame_ready <= 1'b0;
            end
            else if (rd_col == LAST_COL) begin
                rd_col <= {COLW{1'b0}};
                rd_row <= rd_row + {{(ROWW-1){1'b0}}, 1'b1};
            end
            else begin
                rd_col <= rd_col + {{(COLW-1){1'b0}}, 1'b1};
            end
        end
    end
end

endmodule

module demosaic_bilinear_3x3_core #(
    parameter PIXW  = 8,
    parameter ROWW  = 5,
    parameter COLW  = 5
)(
    input                   clk,
    input                   rst_n,
    input                   in_valid,
    input      [ROWW-1:0]   row_in,
    input      [COLW-1:0]   col_in,
    input      [PIXW-1:0]   nw_in,
    input      [PIXW-1:0]   n_in,
    input      [PIXW-1:0]   ne_in,
    input      [PIXW-1:0]   w_in,
    input      [PIXW-1:0]   c_in,
    input      [PIXW-1:0]   e_in,
    input      [PIXW-1:0]   sw_in,
    input      [PIXW-1:0]   s_in,
    input      [PIXW-1:0]   se_in,
    output reg              out_valid,
    output reg [PIXW-1:0]   r_out,
    output reg [PIXW-1:0]   g_out,
    output reg [PIXW-1:0]   b_out
);

localparam [1:0] R_SITE     = 2'd0;
localparam [1:0] B_SITE     = 2'd1;
localparam [1:0] G_ON_R_ROW = 2'd2;
localparam [1:0] G_ON_B_ROW = 2'd3;

reg [ROWW-1:0] row_d0, row_d1, row_d2;
reg [COLW-1:0] col_d0, col_d1, col_d2;
reg            vld_d0, vld_d1, vld_d2;

reg [PIXW-1:0] nw_r, n_r, ne_r;
reg [PIXW-1:0] w_r , c_r, e_r;
reg [PIXW-1:0] sw_r, s_r, se_r;

reg [1:0]      pixel_type_r;
reg [PIXW-1:0] c_d1;
reg [PIXW+1:0] cross_sum_r;
reg [PIXW+1:0] diag_sum_r;
reg [PIXW  :0] h_sum_r;
reg [PIXW  :0] v_sum_r;

wire [PIXW-1:0] cross_avg_w;
wire [PIXW-1:0] diag_avg_w;
wire [PIXW-1:0] h_avg_w;
wire [PIXW-1:0] v_avg_w;

assign cross_avg_w = (cross_sum_r + 2'd2) >> 2;
assign diag_avg_w  = (diag_sum_r  + 2'd2) >> 2;
assign h_avg_w     = (h_sum_r     + 1'd1) >> 1;
assign v_avg_w     = (v_sum_r     + 1'd1) >> 1;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        row_d0 <= {ROWW{1'b0}}; row_d1 <= {ROWW{1'b0}}; row_d2 <= {ROWW{1'b0}};
        col_d0 <= {COLW{1'b0}}; col_d1 <= {COLW{1'b0}}; col_d2 <= {COLW{1'b0}};
        vld_d0 <= 1'b0; vld_d1 <= 1'b0; vld_d2 <= 1'b0;
        out_valid <= 1'b0;
    end
    else begin
        if (in_valid) begin
            row_d0 <= row_in;
            col_d0 <= col_in;
        end

        vld_d0 <= in_valid;
        vld_d1 <= vld_d0;
        vld_d2 <= vld_d1;

        if (vld_d0) begin
            row_d1 <= row_d0;
            col_d1 <= col_d0;
        end

        if (vld_d1) begin
            row_d2 <= row_d1;
            col_d2 <= col_d1;
        end

        out_valid <= vld_d1;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        nw_r <= {PIXW{1'b0}}; n_r <= {PIXW{1'b0}}; ne_r <= {PIXW{1'b0}};
        w_r  <= {PIXW{1'b0}}; c_r <= {PIXW{1'b0}}; e_r  <= {PIXW{1'b0}};
        sw_r <= {PIXW{1'b0}}; s_r <= {PIXW{1'b0}}; se_r <= {PIXW{1'b0}};
    end
    else if (in_valid) begin
        nw_r <= nw_in; n_r <= n_in; ne_r <= ne_in;
        w_r  <= w_in;  c_r <= c_in; e_r  <= e_in;
        sw_r <= sw_in; s_r <= s_in; se_r <= se_in;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pixel_type_r <= R_SITE;
        c_d1         <= {PIXW{1'b0}};
        cross_sum_r  <= {(PIXW+2){1'b0}};
        diag_sum_r   <= {(PIXW+2){1'b0}};
        h_sum_r      <= {(PIXW+1){1'b0}};
        v_sum_r      <= {(PIXW+1){1'b0}};
    end
    else if (vld_d0) begin
        c_d1        <= c_r;
        cross_sum_r <= n_r + s_r + w_r + e_r;
        diag_sum_r  <= nw_r + ne_r + sw_r + se_r;
        h_sum_r     <= w_r + e_r;
        v_sum_r     <= n_r + s_r;

        if ((row_d0[0] == 1'b0) && (col_d0[0] == 1'b0))
            pixel_type_r <= R_SITE;
        else if ((row_d0[0] == 1'b0) && (col_d0[0] == 1'b1))
            pixel_type_r <= G_ON_R_ROW;
        else if ((row_d0[0] == 1'b1) && (col_d0[0] == 1'b0))
            pixel_type_r <= G_ON_B_ROW;
        else
            pixel_type_r <= B_SITE;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        r_out <= {PIXW{1'b0}};
        g_out <= {PIXW{1'b0}};
        b_out <= {PIXW{1'b0}};
    end
    else if (vld_d1) begin
        case (pixel_type_r)
            R_SITE: begin
                r_out <= c_d1;
                g_out <= cross_avg_w;
                b_out <= diag_avg_w;
            end
            B_SITE: begin
                r_out <= diag_avg_w;
                g_out <= cross_avg_w;
                b_out <= c_d1;
            end
            G_ON_R_ROW: begin
                r_out <= h_avg_w;
                g_out <= c_d1;
                b_out <= v_avg_w;
            end
            G_ON_B_ROW: begin
                r_out <= v_avg_w;
                g_out <= c_d1;
                b_out <= h_avg_w;
            end
            default: begin
                r_out <= {PIXW{1'b0}};
                g_out <= {PIXW{1'b0}};
                b_out <= {PIXW{1'b0}};
            end
        endcase
    end
end

endmodule

module ccm(
    input               clk,
    input               rst_n,
    input               in_valid,
    input      [11:0]   r_in,
    input      [11:0]   g_in,
    input      [11:0]   b_in,
    output reg          out_valid,
    output reg [11:0]   r_out,
    output reg [11:0]   g_out,
    output reg [11:0]   b_out
);

localparam signed [11:0] CCM_MAIN   = 12'sd1100;
localparam signed [11:0] CCM_SUB    = 12'sd50;
localparam signed [11:0] ROUND_BIAS = 12'sd512;
localparam signed [12:0] CLAMP_MAX  = 13'sd4095;

reg valid_s1, valid_s2, valid_s3, valid_s4, valid_s5;
reg [12:0] sum_rg_s1, sum_rb_s1, sum_gb_s1;
reg [11:0] r_s1, g_s1, b_s1;
reg signed [23:0] r_gain_s2, g_gain_s2, b_gain_s2;
reg signed [23:0] gb_sub_s2, rb_sub_s2, rg_sub_s2;
reg signed [24:0] r_raw_s3, g_raw_s3, b_raw_s3;
reg signed [13:0] r_shift_s4, g_shift_s4, b_shift_s4;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        valid_s1  <= 1'b0;
        sum_rg_s1 <= 13'd0;
        sum_rb_s1 <= 13'd0;
        sum_gb_s1 <= 13'd0;
        r_s1      <= 12'd0;
        g_s1      <= 12'd0;
        b_s1      <= 12'd0;
    end
    else begin
        valid_s1  <= in_valid;
        sum_rg_s1 <= r_in + g_in;
        sum_rb_s1 <= r_in + b_in;
        sum_gb_s1 <= g_in + b_in;
        r_s1      <= r_in;
        g_s1      <= g_in;
        b_s1      <= b_in;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        valid_s2  <= 1'b0;
        r_gain_s2 <= 24'sd0;
        g_gain_s2 <= 24'sd0;
        b_gain_s2 <= 24'sd0;
        gb_sub_s2 <= 24'sd0;
        rb_sub_s2 <= 24'sd0;
        rg_sub_s2 <= 24'sd0;
    end
    else begin
        valid_s2  <= valid_s1;
        r_gain_s2 <= $signed({1'b0, r_s1})      * CCM_MAIN;
        g_gain_s2 <= $signed({1'b0, g_s1})      * CCM_MAIN;
        b_gain_s2 <= $signed({1'b0, b_s1})      * CCM_MAIN;
        gb_sub_s2 <= $signed({1'b0, sum_gb_s1}) * CCM_SUB;
        rb_sub_s2 <= $signed({1'b0, sum_rb_s1}) * CCM_SUB;
        rg_sub_s2 <= $signed({1'b0, sum_rg_s1}) * CCM_SUB;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        valid_s3 <= 1'b0;
        r_raw_s3 <= 25'sd0;
        g_raw_s3 <= 25'sd0;
        b_raw_s3 <= 25'sd0;
    end
    else begin
        valid_s3 <= valid_s2;
        r_raw_s3 <= r_gain_s2 - gb_sub_s2;
        g_raw_s3 <= g_gain_s2 - rb_sub_s2;
        b_raw_s3 <= b_gain_s2 - rg_sub_s2;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        valid_s4   <= 1'b0;
        r_shift_s4 <= 14'sd0;
        g_shift_s4 <= 14'sd0;
        b_shift_s4 <= 14'sd0;
    end
    else begin
        valid_s4   <= valid_s3;
        r_shift_s4 <= (r_raw_s3 + ROUND_BIAS) >>> 10;
        g_shift_s4 <= (g_raw_s3 + ROUND_BIAS) >>> 10;
        b_shift_s4 <= (b_raw_s3 + ROUND_BIAS) >>> 10;
    end
end

function [11:0] clamp_u12;
    input signed [13:0] val;
    begin
        if (val < 0)
            clamp_u12 = 12'd0;
        else if (val > CLAMP_MAX)
            clamp_u12 = 12'd4095;
        else
            clamp_u12 = val[11:0];
    end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        valid_s5 <= 1'b0;
        out_valid <= 1'b0;
        r_out <= 12'd0;
        g_out <= 12'd0;
        b_out <= 12'd0;
    end
    else begin
        valid_s5 <= valid_s4;
        out_valid <= valid_s5;
        r_out <= clamp_u12(r_shift_s4);
        g_out <= clamp_u12(g_shift_s4);
        b_out <= clamp_u12(b_shift_s4);
    end
end

endmodule

module dpc (
    input               clk,
    input               rst_n,
    input               lsc_valid,
    input      [11:0]   lsc_pixel,
    output reg          dpc_out_valid,
    output reg [11:0]   dpc_out_pixel
);

localparam [2:0] DPC_IDLE    = 3'd0;
localparam [2:0] DPC_LOADWIN = 3'd1;
localparam [2:0] DPC_SCORE   = 3'd2;
localparam [2:0] DPC_APPLY   = 3'd3;
localparam [2:0] DPC_OUT     = 3'd4;
localparam [11:0] DPC_TH = 12'd320;

reg [11:0] dpc_img [0:15][0:15];
reg [3:0] dpc_wr_row, dpc_wr_col;
reg       dpc_frame_loaded, dpc_frame_clear;
reg [2:0] dpc_state;
reg [3:0] dpc_row, dpc_col;
reg [11:0] win00, win01, win02, win03, win04;
reg [11:0] win10, win11, win12, win13, win14;
reg [11:0] win20, win21, win22, win23, win24;
reg [11:0] win30, win31, win32, win33, win34;
reg [11:0] win40, win41, win42, win43, win44;
reg [11:0] center_p;
reg [11:0] h0, h1, h2, h3;
reg [11:0] v0, v1, v2, v3;
reg [11:0] d10, d11, d12, d13;
reg [11:0] d20, d21, d22, d23;
reg [11:0] med_h, med_v, med_d1, med_d2;
reg [14:0] score_h, score_v, score_d1, score_d2;
reg [11:0] best_target, corrected_p;
reg [14:0] best_score, best_score_comb;
reg [12:0] center_diff;
reg [11:0] best_target_comb;

function [3:0] mirror_idx_16;
    input integer idx;
    begin
        if (idx < 0) mirror_idx_16 = -idx;
        else if (idx > 15) mirror_idx_16 = 30 - idx;
        else mirror_idx_16 = idx[3:0];
    end
endfunction

function [12:0] abs_diff_10;
    input [11:0] a, b;
    begin
        if (a >= b) abs_diff_10 = a - b;
        else        abs_diff_10 = b - a;
    end
endfunction

function [11:0] min2_10;
    input [11:0] a, b;
    begin
        if (a < b) min2_10 = a;
        else       min2_10 = b;
    end
endfunction

function [11:0] max2_10;
    input [11:0] a, b;
    begin
        if (a > b) max2_10 = a;
        else       max2_10 = b;
    end
endfunction

function [11:0] median4_10;
    input [11:0] a, b, c, d;
    reg [11:0] min_ab, max_ab, min_cd, max_cd, mid_lo, mid_hi;
    reg [12:0] mid_sum;
    begin
        min_ab = min2_10(a, b);
        max_ab = max2_10(a, b);
        min_cd = min2_10(c, d);
        max_cd = max2_10(c, d);
        mid_lo = max2_10(min_ab, min_cd);
        mid_hi = min2_10(max_ab, max_cd);
        mid_sum = mid_lo + mid_hi;
        median4_10 = mid_sum[10:1];
    end
endfunction

function [14:0] score4_10;
    input [11:0] p0, p1, p2, p3, med;
    reg [12:0] a0, a1, a2, a3;
    begin
        a0 = abs_diff_10(p0, med);
        a1 = abs_diff_10(p1, med);
        a2 = abs_diff_10(p2, med);
        a3 = abs_diff_10(p3, med);
        score4_10 = a0 + a1 + a2 + a3;
    end
endfunction

wire [3:0] r_m2 = mirror_idx_16($signed({1'b0,dpc_row}) - 2);
wire [3:0] r_m1 = mirror_idx_16($signed({1'b0,dpc_row}) - 1);
wire [3:0] r_0  = mirror_idx_16($signed({1'b0,dpc_row}) + 0);
wire [3:0] r_p1 = mirror_idx_16($signed({1'b0,dpc_row}) + 1);
wire [3:0] r_p2 = mirror_idx_16($signed({1'b0,dpc_row}) + 2);
wire [3:0] c_m2 = mirror_idx_16($signed({1'b0,dpc_col}) - 2);
wire [3:0] c_m1 = mirror_idx_16($signed({1'b0,dpc_col}) - 1);
wire [3:0] c_0  = mirror_idx_16($signed({1'b0,dpc_col}) + 0);
wire [3:0] c_p1 = mirror_idx_16($signed({1'b0,dpc_col}) + 1);
wire [3:0] c_p2 = mirror_idx_16($signed({1'b0,dpc_col}) + 2);
wire [11:0] win00_n = dpc_img[r_m2][c_m2];
wire [11:0] win01_n = dpc_img[r_m2][c_m1];
wire [11:0] win02_n = dpc_img[r_m2][c_0 ];
wire [11:0] win03_n = dpc_img[r_m2][c_p1];
wire [11:0] win04_n = dpc_img[r_m2][c_p2];
wire [11:0] win10_n = dpc_img[r_m1][c_m2];
wire [11:0] win11_n = dpc_img[r_m1][c_m1];
wire [11:0] win12_n = dpc_img[r_m1][c_0 ];
wire [11:0] win13_n = dpc_img[r_m1][c_p1];
wire [11:0] win14_n = dpc_img[r_m1][c_p2];
wire [11:0] win20_n = dpc_img[r_0 ][c_m2];
wire [11:0] win21_n = dpc_img[r_0 ][c_m1];
wire [11:0] win22_n = dpc_img[r_0 ][c_0 ];
wire [11:0] win23_n = dpc_img[r_0 ][c_p1];
wire [11:0] win24_n = dpc_img[r_0 ][c_p2];
wire [11:0] win30_n = dpc_img[r_p1][c_m2];
wire [11:0] win31_n = dpc_img[r_p1][c_m1];
wire [11:0] win32_n = dpc_img[r_p1][c_0 ];
wire [11:0] win33_n = dpc_img[r_p1][c_p1];
wire [11:0] win34_n = dpc_img[r_p1][c_p2];
wire [11:0] win40_n = dpc_img[r_p2][c_m2];
wire [11:0] win41_n = dpc_img[r_p2][c_m1];
wire [11:0] win42_n = dpc_img[r_p2][c_0 ];
wire [11:0] win43_n = dpc_img[r_p2][c_p1];
wire [11:0] win44_n = dpc_img[r_p2][c_p2];

always @(*) begin
    best_score_comb  = score_h;
    best_target_comb = med_h;
    if (score_v < best_score_comb) begin best_score_comb = score_v; best_target_comb = med_v; end
    if (score_d1 < best_score_comb) begin best_score_comb = score_d1; best_target_comb = med_d1; end
    if (score_d2 < best_score_comb) begin best_score_comb = score_d2; best_target_comb = med_d2; end
end

wire [12:0] center_diff_comb = abs_diff_10(center_p, best_target_comb);
wire        defect_force_comb = (center_p == 12'd0) || (center_p == 12'd4095);
wire [11:0] corrected_p_comb = defect_force_comb ? best_target_comb : center_p;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dpc_state <= DPC_IDLE; dpc_row <= 4'd0; dpc_col <= 4'd0; dpc_frame_clear <= 1'b0;
    end else begin
        dpc_frame_clear <= 1'b0;
        case (dpc_state)
            DPC_IDLE: begin dpc_row <= 4'd0; dpc_col <= 4'd0; if (dpc_frame_loaded) dpc_state <= DPC_LOADWIN; end
            DPC_LOADWIN: dpc_state <= DPC_SCORE;
            DPC_SCORE:   dpc_state <= DPC_APPLY;
            DPC_APPLY:   dpc_state <= DPC_OUT;
            DPC_OUT: begin
                if ((dpc_row == 4'd15) && (dpc_col == 4'd15)) begin dpc_state <= DPC_IDLE; dpc_frame_clear <= 1'b1; end
                else begin
                    if (dpc_col == 4'd15) begin dpc_col <= 4'd0; dpc_row <= dpc_row + 4'd1; end
                    else dpc_col <= dpc_col + 4'd1;
                    dpc_state <= DPC_LOADWIN;
                end
            end
            default: dpc_state <= DPC_IDLE;
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dpc_wr_row <= 4'd0; dpc_wr_col <= 4'd0; dpc_frame_loaded <= 1'b0;
    end else begin
        if (dpc_frame_clear) begin
            dpc_wr_row <= 4'd0; dpc_wr_col <= 4'd0; dpc_frame_loaded <= 1'b0;
        end else if (lsc_valid && !dpc_frame_loaded) begin
            dpc_img[dpc_wr_row][dpc_wr_col] <= lsc_pixel;
            if ((dpc_wr_row == 4'd15) && (dpc_wr_col == 4'd15)) begin
                dpc_wr_row <= 4'd0; dpc_wr_col <= 4'd0; dpc_frame_loaded <= 1'b1;
            end else if (dpc_wr_col == 4'd15) begin
                dpc_wr_col <= 4'd0; dpc_wr_row <= dpc_wr_row + 4'd1;
            end else dpc_wr_col <= dpc_wr_col + 4'd1;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        win00 <= 12'd0; win01 <= 12'd0; win02 <= 12'd0; win03 <= 12'd0; win04 <= 12'd0;
        win10 <= 12'd0; win11 <= 12'd0; win12 <= 12'd0; win13 <= 12'd0; win14 <= 12'd0;
        win20 <= 12'd0; win21 <= 12'd0; win22 <= 12'd0; win23 <= 12'd0; win24 <= 12'd0;
        win30 <= 12'd0; win31 <= 12'd0; win32 <= 12'd0; win33 <= 12'd0; win34 <= 12'd0;
        win40 <= 12'd0; win41 <= 12'd0; win42 <= 12'd0; win43 <= 12'd0; win44 <= 12'd0;
        center_p <= 12'd0; h0 <= 12'd0; h1 <= 12'd0; h2 <= 12'd0; h3 <= 12'd0; v0 <= 12'd0; v1 <= 12'd0; v2 <= 12'd0; v3 <= 12'd0;
        d10 <= 12'd0; d11 <= 12'd0; d12 <= 12'd0; d13 <= 12'd0; d20 <= 12'd0; d21 <= 12'd0; d22 <= 12'd0; d23 <= 12'd0;
        med_h <= 12'd0; med_v <= 12'd0; med_d1 <= 12'd0; med_d2 <= 12'd0; score_h <= 15'd0; score_v <= 15'd0; score_d1 <= 15'd0; score_d2 <= 15'd0;
        best_target <= 12'd0; best_score <= 15'd0; center_diff <= 13'd0; corrected_p <= 12'd0;
    end else begin
        case (dpc_state)
            DPC_LOADWIN: begin
                win00 <= win00_n; win01 <= win01_n; win02 <= win02_n; win03 <= win03_n; win04 <= win04_n;
                win10 <= win10_n; win11 <= win11_n; win12 <= win12_n; win13 <= win13_n; win14 <= win14_n;
                win20 <= win20_n; win21 <= win21_n; win22 <= win22_n; win23 <= win23_n; win24 <= win24_n;
                win30 <= win30_n; win31 <= win31_n; win32 <= win32_n; win33 <= win33_n; win34 <= win34_n;
                win40 <= win40_n; win41 <= win41_n; win42 <= win42_n; win43 <= win43_n; win44 <= win44_n;
                center_p <= win22_n;
            end
            DPC_SCORE: begin
                h0 <= win20; h1 <= win20; h2 <= win24; h3 <= win24;
                v0 <= win02; v1 <= win02; v2 <= win42; v3 <= win42;
                d10 <= win00; d11 <= win00; d12 <= win44; d13 <= win44;
                d20 <= win04; d21 <= win04; d22 <= win40; d23 <= win40;
                med_h  <= (win20 + win24 + 1'd1) >> 1;
                med_v  <= (win02 + win42 + 1'd1) >> 1;
                med_d1 <= (win00 + win44 + 1'd1) >> 1;
                med_d2 <= (win04 + win40 + 1'd1) >> 1;
                score_h  <= abs_diff_10(win20, win24);
                score_v  <= abs_diff_10(win02, win42);
                score_d1 <= abs_diff_10(win00, win44);
                score_d2 <= abs_diff_10(win04, win40);
            end
            DPC_APPLY: begin
                best_score <= best_score_comb; best_target <= best_target_comb; center_diff <= center_diff_comb; corrected_p <= corrected_p_comb;
            end
            default: begin end
        endcase
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin dpc_out_valid <= 1'b0; dpc_out_pixel <= 12'd0; end
    else begin dpc_out_valid <= 1'b0; if (dpc_state == DPC_OUT) begin dpc_out_valid <= 1'b1; dpc_out_pixel <= corrected_p; end end
end

endmodule

module lsc (
    input               clk,
    input               rst_n,
    input               in_valid,
    input      [11:0]   blc_pixel,
    input               param_valid,
    input      [11:0]   param_gain,
    output reg          lsc_valid,
    output reg [11:0]   lsc_pixel
);

reg [11:0] mesh_r  [0:35];
reg [11:0] mesh_gr [0:35];
reg [11:0] mesh_gb [0:35];
reg [11:0] mesh_b  [0:35];
reg [1:0] mesh_ch_cnt;
reg [2:0] mesh_row_cnt;
reg [2:0] mesh_col_cnt;
reg [5:0] mesh_wr_idx;
reg [5:0] mesh_idx00_s1, mesh_idx01_s1, mesh_idx10_s1, mesh_idx11_s1;
integer i, j;
reg [3:0] x_cnt, y_cnt;
reg        lsc_vld_s0;
reg [11:0] pix_s0;
reg [3:0]  x_s0, y_s0;
reg [1:0] color_s0;
reg [2:0] x0_s0, y0_s0;
reg [1:0] rx_s0, ry_s0;
reg        lsc_vld_s1;
reg [11:0] pix_s1;
reg [1:0]  color_s1;
reg [2:0]  x0_s1, y0_s1;
reg [1:0]  rx_s1, ry_s1;
reg [8:0]  dx_s1, ix_s1;
reg [8:0]  dy_s1, iy_s1;
reg [11:0] g00_s1, g01_s1, g10_s1, g11_s1;
reg        lsc_vld_s2;
reg [11:0] pix_s2;
reg [11:0] g00_s2, g01_s2, g10_s2, g11_s2;
reg [8:0]  dx_s2, ix_s2, dy_s2, iy_s2;
reg [20:0] g00_ix_s2, g01_dx_s2, g10_ix_s2, g11_dx_s2;
reg        lsc_vld_s3;
reg [11:0] pix_s3;
reg [20:0] g00_ix_s3, g01_dx_s3, g10_ix_s3, g11_dx_s3;
reg [8:0]  dy_s3, iy_s3;
reg [29:0] term00_s3, term01_s3, term10_s3, term11_s3;
reg [31:0] gain_sum_s3;
reg [11:0] gain_s3;
reg        lsc_vld_s4;
reg [11:0] pix_s4;
reg [11:0] gain_s4;
reg [23:0] pix_mul_s4;
reg [13:0] pix_round_s4;
reg [11:0] pix_lsc_s4;

always @(*) begin
    mesh_wr_idx   = {3'd0, mesh_row_cnt} * 6'd6 + {3'd0, mesh_col_cnt};
    mesh_idx00_s1 = {3'd0, y0_s1} * 6'd6 + {3'd0, x0_s1};
    mesh_idx01_s1 = {3'd0, y0_s1} * 6'd6 + ({3'd0, x0_s1} + 6'd1);
    mesh_idx10_s1 = ({3'd0, y0_s1} + 6'd1) * 6'd6 + {3'd0, x0_s1};
    mesh_idx11_s1 = ({3'd0, y0_s1} + 6'd1) * 6'd6 + ({3'd0, x0_s1} + 6'd1);
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mesh_ch_cnt  <= 2'd0;
        mesh_row_cnt <= 3'd0;
        mesh_col_cnt <= 3'd0;
        for (i = 0; i < 6; i = i + 1) begin
            for (j = 0; j < 6; j = j + 1) begin
                mesh_r [i*6+j] <= 12'd0;
                mesh_gr[i*6+j] <= 12'd0;
                mesh_gb[i*6+j] <= 12'd0;
                mesh_b [i*6+j] <= 12'd0;
            end
        end
    end
    else if (param_valid) begin
        case (mesh_ch_cnt)
            2'd0: mesh_r [mesh_wr_idx] <= param_gain;
            2'd1: mesh_gr[mesh_wr_idx] <= param_gain;
            2'd2: mesh_gb[mesh_wr_idx] <= param_gain;
            2'd3: mesh_b [mesh_wr_idx] <= param_gain;
        endcase
        if (mesh_col_cnt == 3'd5) begin
            mesh_col_cnt <= 3'd0;
            if (mesh_row_cnt == 3'd5) begin
                mesh_row_cnt <= 3'd0;
                mesh_ch_cnt  <= mesh_ch_cnt + 2'd1;
            end
            else begin
                mesh_row_cnt <= mesh_row_cnt + 3'd1;
            end
        end
        else begin
            mesh_col_cnt <= mesh_col_cnt + 3'd1;
        end
    end
    else begin
        mesh_ch_cnt  <= 2'd0;
        mesh_row_cnt <= 3'd0;
        mesh_col_cnt <= 3'd0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        x_cnt <= 4'd0;
        y_cnt <= 4'd0;
    end
    else if (in_valid) begin
        if (x_cnt == 4'd15) begin
            x_cnt <= 4'd0;
            if (y_cnt == 4'd15)
                y_cnt <= 4'd0;
            else
                y_cnt <= y_cnt + 4'd1;
        end
        else begin
            x_cnt <= x_cnt + 4'd1;
        end
    end
    else begin
        x_cnt <= 4'd0;
        y_cnt <= 4'd0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        lsc_vld_s0 <= 1'b0;
        pix_s0     <= 12'd0;
        x_s0       <= 4'd0;
        y_s0       <= 4'd0;
    end
    else begin
        lsc_vld_s0 <= in_valid;
        if (in_valid) begin
            pix_s0 <= blc_pixel;
            x_s0   <= x_cnt;
            y_s0   <= y_cnt;
        end
    end
end

always @(*) begin
    case ({y_s0[0], x_s0[0]})
        2'b00: color_s0 = 2'd0;
        2'b01: color_s0 = 2'd1;
        2'b10: color_s0 = 2'd2;
        default: color_s0 = 2'd3;
    endcase
    if      (x_s0 <= 4'd2)  x0_s0 = 3'd0;
    else if (x_s0 <= 4'd5)  x0_s0 = 3'd1;
    else if (x_s0 <= 4'd8)  x0_s0 = 3'd2;
    else if (x_s0 <= 4'd11) x0_s0 = 3'd3;
    else                    x0_s0 = 3'd4;
    if      (y_s0 <= 4'd2)  y0_s0 = 3'd0;
    else if (y_s0 <= 4'd5)  y0_s0 = 3'd1;
    else if (y_s0 <= 4'd8)  y0_s0 = 3'd2;
    else if (y_s0 <= 4'd11) y0_s0 = 3'd3;
    else                    y0_s0 = 3'd4;
    case (x0_s0)
        3'd0: case (x_s0) 4'd0: rx_s0 = 2'd0; 4'd1: rx_s0 = 2'd1; default: rx_s0 = 2'd2; endcase
        3'd1: case (x_s0) 4'd3: rx_s0 = 2'd0; 4'd4: rx_s0 = 2'd1; default: rx_s0 = 2'd2; endcase
        3'd2: case (x_s0) 4'd6: rx_s0 = 2'd0; 4'd7: rx_s0 = 2'd1; default: rx_s0 = 2'd2; endcase
        3'd3: case (x_s0) 4'd9: rx_s0 = 2'd0; 4'd10: rx_s0 = 2'd1; default: rx_s0 = 2'd2; endcase
        default: case (x_s0) 4'd12: rx_s0 = 2'd0; 4'd13: rx_s0 = 2'd1; default: rx_s0 = 2'd2; endcase
    endcase
    case (y0_s0)
        3'd0: case (y_s0) 4'd0: ry_s0 = 2'd0; 4'd1: ry_s0 = 2'd1; default: ry_s0 = 2'd2; endcase
        3'd1: case (y_s0) 4'd3: ry_s0 = 2'd0; 4'd4: ry_s0 = 2'd1; default: ry_s0 = 2'd2; endcase
        3'd2: case (y_s0) 4'd6: ry_s0 = 2'd0; 4'd7: ry_s0 = 2'd1; default: ry_s0 = 2'd2; endcase
        3'd3: case (y_s0) 4'd9: ry_s0 = 2'd0; 4'd10: ry_s0 = 2'd1; default: ry_s0 = 2'd2; endcase
        default: case (y_s0) 4'd12: ry_s0 = 2'd0; 4'd13: ry_s0 = 2'd1; default: ry_s0 = 2'd2; endcase
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        lsc_vld_s1 <= 1'b0;
        pix_s1     <= 12'd0;
        color_s1   <= 2'd0;
        x0_s1      <= 3'd0;
        y0_s1      <= 3'd0;
        rx_s1      <= 2'd0;
        ry_s1      <= 2'd0;
    end
    else begin
        lsc_vld_s1 <= lsc_vld_s0;
        pix_s1     <= pix_s0;
        color_s1   <= color_s0;
        x0_s1      <= x0_s0;
        y0_s1      <= y0_s0;
        rx_s1      <= rx_s0;
        ry_s1      <= ry_s0;
    end
end

always @(*) begin
    case (rx_s1)
        2'd0: begin dx_s1 = 9'd0;   ix_s1 = 9'd256; end
        2'd1: begin dx_s1 = 9'd85;  ix_s1 = 9'd171; end
        default: begin dx_s1 = 9'd171; ix_s1 = 9'd85; end
    endcase
    case (ry_s1)
        2'd0: begin dy_s1 = 9'd0;   iy_s1 = 9'd256; end
        2'd1: begin dy_s1 = 9'd85;  iy_s1 = 9'd171; end
        default: begin dy_s1 = 9'd171; iy_s1 = 9'd85; end
    endcase
end

always @(*) begin
    g00_s1 = 12'd0; g01_s1 = 12'd0; g10_s1 = 12'd0; g11_s1 = 12'd0;
    case (color_s1)
        2'd0: begin g00_s1 = mesh_r [mesh_idx00_s1];  g01_s1 = mesh_r [mesh_idx01_s1];  g10_s1 = mesh_r [mesh_idx10_s1];  g11_s1 = mesh_r [mesh_idx11_s1]; end
        2'd1: begin g00_s1 = mesh_gr[mesh_idx00_s1]; g01_s1 = mesh_gr[mesh_idx01_s1]; g10_s1 = mesh_gr[mesh_idx10_s1]; g11_s1 = mesh_gr[mesh_idx11_s1]; end
        2'd2: begin g00_s1 = mesh_gb[mesh_idx00_s1]; g01_s1 = mesh_gb[mesh_idx01_s1]; g10_s1 = mesh_gb[mesh_idx10_s1]; g11_s1 = mesh_gb[mesh_idx11_s1]; end
        default: begin g00_s1 = mesh_b [mesh_idx00_s1]; g01_s1 = mesh_b [mesh_idx01_s1]; g10_s1 = mesh_b [mesh_idx10_s1]; g11_s1 = mesh_b [mesh_idx11_s1]; end
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        lsc_vld_s2 <= 1'b0; pix_s2 <= 12'd0; g00_s2 <= 12'd0; g01_s2 <= 12'd0; g10_s2 <= 12'd0; g11_s2 <= 12'd0;
        dx_s2 <= 9'd0; ix_s2 <= 9'd0; dy_s2 <= 9'd0; iy_s2 <= 9'd0;
    end
    else begin
        lsc_vld_s2 <= lsc_vld_s1; pix_s2 <= pix_s1; g00_s2 <= g00_s1; g01_s2 <= g01_s1; g10_s2 <= g10_s1; g11_s2 <= g11_s1;
        dx_s2 <= dx_s1; ix_s2 <= ix_s1; dy_s2 <= dy_s1; iy_s2 <= iy_s1;
    end
end

always @(*) begin
    g00_ix_s2 = g00_s2 * ix_s2;
    g01_dx_s2 = g01_s2 * dx_s2;
    g10_ix_s2 = g10_s2 * ix_s2;
    g11_dx_s2 = g11_s2 * dx_s2;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        lsc_vld_s3 <= 1'b0; pix_s3 <= 12'd0; g00_ix_s3 <= 21'd0; g01_dx_s3 <= 21'd0; g10_ix_s3 <= 21'd0; g11_dx_s3 <= 21'd0; dy_s3 <= 9'd0; iy_s3 <= 9'd0;
    end
    else begin
        lsc_vld_s3 <= lsc_vld_s2; pix_s3 <= pix_s2; g00_ix_s3 <= g00_ix_s2; g01_dx_s3 <= g01_dx_s2; g10_ix_s3 <= g10_ix_s2; g11_dx_s3 <= g11_dx_s2; dy_s3 <= dy_s2; iy_s3 <= iy_s2;
    end
end

always @(*) begin
    term00_s3 = g00_ix_s3 * iy_s3;
    term01_s3 = g01_dx_s3 * iy_s3;
    term10_s3 = g10_ix_s3 * dy_s3;
    term11_s3 = g11_dx_s3 * dy_s3;
    gain_sum_s3 = term00_s3 + term01_s3 + term10_s3 + term11_s3 + 32'd32768;
    gain_s3     = gain_sum_s3[31:16];
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        lsc_vld_s4 <= 1'b0; pix_s4 <= 12'd0; gain_s4 <= 12'd0;
    end
    else begin
        lsc_vld_s4 <= lsc_vld_s3; pix_s4 <= pix_s3; gain_s4 <= gain_s3;
    end
end

always @(*) begin
    pix_mul_s4   = pix_s4 * gain_s4;
    pix_round_s4 = (pix_mul_s4 + 24'd512) >> 10;
    if (pix_round_s4 > 14'd4095) pix_lsc_s4 = 12'd4095;
    else                         pix_lsc_s4 = pix_round_s4[11:0];
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        lsc_valid <= 1'b0; lsc_pixel <= 12'd0;
    end
    else begin
        lsc_valid <= lsc_vld_s4; lsc_pixel <= pix_lsc_s4;
    end
end

endmodule

module blc (
    input               clk,
    input               rst_n,
    input               in_valid,
    input      [11:0]   in,
    output     [11:0]   blc_pixel
);

localparam [11:0] BLC_RED     = 12'd64;
localparam [11:0] BLC_GREEN_R = 12'd48;
localparam [11:0] BLC_GREEN_B = 12'd52;
localparam [11:0] BLC_BLUE    = 12'd72;

reg  [7:0]  pix_cnt;
reg  [11:0] blc_mem [0:255];
reg  [11:0] blc_offset;
wire        row_is_even;
wire        col_is_even;

assign row_is_even = ~pix_cnt[4];
assign col_is_even = ~pix_cnt[0];

always @(*) begin
    if (row_is_even) begin
        if (col_is_even)
            blc_offset = BLC_RED;
        else
            blc_offset = BLC_GREEN_R;
    end
    else begin
        if (col_is_even)
            blc_offset = BLC_GREEN_B;
        else
            blc_offset = BLC_BLUE;
    end
end

assign blc_pixel = (in > blc_offset) ? (in - blc_offset) : 12'd0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pix_cnt <= 8'd0;
    end
    else begin
        if (in_valid) begin
            blc_mem[pix_cnt] <= blc_pixel;
            if (pix_cnt == 8'd255)
                pix_cnt <= 8'd0;
            else
                pix_cnt <= pix_cnt + 8'd1;
        end
    end
end

endmodule
