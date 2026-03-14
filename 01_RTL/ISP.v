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
localparam IDLE       = 4'd0;
localparam LOAD_PARAM = 4'd1;
localparam RUN_BLC    = 4'd2;
localparam LSC_RUN    = 4'd3;
localparam RUN_CCM    = 4'd4;
localparam DATA_OUT   = 4'd5;
localparam RUN_DPC    = 4'd6;
localparam RUN_DEMOSAIC = 4'd7;

localparam signed [11:0] C11 = 12'sd1100;
localparam signed [11:0] C12 = -12'sd50;
localparam signed [11:0] C13 = -12'sd50;
localparam signed [11:0] C21 = -12'sd50;
localparam signed [11:0] C22 = 12'sd1100;
localparam signed [11:0] C23 = -12'sd50;
localparam signed [11:0] C31 = -12'sd50;
localparam signed [11:0] C32 = -12'sd50;
localparam signed [11:0] C33 = 12'sd1100;

reg [3:0] curr_state, next_state;
reg       in_valid_d1;
reg       param_valid_d1;
reg [7:0] param_cnt;
reg [7:0] blc_cnt;
reg       blc_done_r;
reg       blc_started;
reg [7:0] lsc_cnt;
reg [7:0] dpc_cnt;
reg [7:0] demo_cnt;
reg [7:0] out_cnt;

reg [11:0] gain_mem     [0:143];
reg [11:0] main_buffer  [0:255];
reg [11:0] dpc_buffer   [0:255];
reg [11:0] demo_r_buffer [0:255];
reg [11:0] demo_g_buffer [0:255];
reg [11:0] demo_b_buffer [0:255];
reg [3:0] row_cnt, col_cnt;
reg [6:0] b_offset;
reg [11:0] blc_p_s1;
reg [7:0]  idx_s1;
reg [3:0]  x_s1, y_s1;
reg        vld_s1;
reg [11:0] blc_p_s2;
reg [11:0] gain_s2;
reg [7:0]  idx_s2;
reg        vld_s2;

reg [3:0] x_now, y_now;
reg [2:0] x0_w, y0_w;
reg [1:0] rx_w, ry_w;
reg [5:0] idx00_w, idx01_w, idx10_w, idx11_w;
reg [7:0] gain_base_w;
reg [7:0] gain_idx00_w, gain_idx01_w, gain_idx10_w, gain_idx11_w;
reg [11:0] g00_w, g01_w, g10_w, g11_w;
reg [8:0] dx_w, ix_w, dy_w, iy_w;
reg [31:0] gain_accum_w;
reg [11:0] gain_w;
reg [31:0] lsc_accum_w;
reg [11:0] lsc_pixel_w;
reg [3:0] dpc_x_now, dpc_y_now;
reg [11:0] dpc_p_w;
reg [11:0] dpc_h_med_w, dpc_v_med_w, dpc_d1_med_w, dpc_d2_med_w;
reg [13:0] dpc_h_sad_w, dpc_v_sad_w, dpc_d1_sad_w, dpc_d2_sad_w;
reg [11:0] dpc_target_w, dpc_pixel_w;
reg [3:0] dx, dy;
reg [7:0] idx_n, idx_s, idx_e, idx_w;
reg [7:0] idx_nw, idx_ne, idx_sw, idx_se;
reg [11:0] p_c;
reg [11:0] p_n, p_s, p_e, p_w;
reg [11:0] p_nw, p_ne, p_sw, p_se;
reg [12:0] sum2_w;
reg [13:0] sum4_w;
reg [11:0] demo_r_w, demo_g_w, demo_b_w;
reg signed [25:0] ccm_r_raw_w, ccm_g_raw_w, ccm_b_raw_w;
reg [11:0] ccm_r_w, ccm_g_w, ccm_b_w;
reg [11:0] blc_pixel_w;

wire param_done_w;
wire blc_done_w;
wire lsc_done_w;
wire dpc_done_w;
wire demo_done_w;
wire out_done_w;
wire blc_fire_w;
wire [11:0] dpc_h0_w, dpc_h1_w, dpc_h2_w, dpc_h3_w;
wire [11:0] dpc_v0_w, dpc_v1_w, dpc_v2_w, dpc_v3_w;
wire [11:0] dpc_d10_w, dpc_d11_w, dpc_d12_w, dpc_d13_w;
wire [11:0] dpc_d20_w, dpc_d21_w, dpc_d22_w, dpc_d23_w;

function [11:0] clamp_u12;
    input signed [25:0] val_shifted;
    begin
        if (val_shifted[25])
            clamp_u12 = 12'd0;
        else if (val_shifted > 26'sd4095)
            clamp_u12 = 12'd4095;
        else
            clamp_u12 = val_shifted[11:0];
    end
endfunction

function [7:0] get_lsc_idx;
    input [3:0] x_target;
    input [3:0] y_target;
    input signed [2:0] dx;
    input signed [2:0] dy;
    reg [3:0] final_x, final_y;
    integer temp_x, temp_y;
    begin
        temp_x = $signed({1'b0, x_target}) + dx;
        temp_y = $signed({1'b0, y_target}) + dy;

        if (temp_x < 0)
            final_x = -temp_x;
        else if (temp_x > 15)
            final_x = 30 - temp_x;
        else
            final_x = temp_x;

        if (temp_y < 0)
            final_y = -temp_y;
        else if (temp_y > 15)
            final_y = 30 - temp_y;
        else
            final_y = temp_y;

        get_lsc_idx = {final_y[3:0], final_x[3:0]};
    end
endfunction

function [7:0] get_demo_idx;
    input [3:0] x_target;
    input [3:0] y_target;
    input signed [1:0] dx;
    input signed [1:0] dy;
    reg [3:0] fx, fy;
    integer tx, ty;
    begin
        tx = $signed({1'b0, x_target}) + dx;
        ty = $signed({1'b0, y_target}) + dy;

        if (tx < 0)
            fx = -tx;
        else if (tx > 15)
            fx = 30 - tx;
        else
            fx = tx[3:0];

        if (ty < 0)
            fy = -ty;
        else if (ty > 15)
            fy = 30 - ty;
        else
            fy = ty[3:0];

        get_demo_idx = {fy, fx};
    end
endfunction

function [11:0] median4_avg_u12;
    input [11:0] a;
    input [11:0] b;
    input [11:0] c;
    input [11:0] d;
    reg [11:0] s0, s1, s2, s3, tmp;
    reg [12:0] mid_sum;
    begin
        s0 = a;
        s1 = b;
        s2 = c;
        s3 = d;

        if (s0 > s1) begin tmp = s0; s0 = s1; s1 = tmp; end
        if (s2 > s3) begin tmp = s2; s2 = s3; s3 = tmp; end
        if (s0 > s2) begin tmp = s0; s0 = s2; s2 = tmp; end
        if (s1 > s3) begin tmp = s1; s1 = s3; s3 = tmp; end
        if (s1 > s2) begin tmp = s1; s1 = s2; s2 = tmp; end

        mid_sum = s1 + s2;
        median4_avg_u12 = mid_sum[12:1];
    end
endfunction

function [12:0] abs_diff_u12;
    input [11:0] a;
    input [11:0] b;
    begin
        if (a >= b)
            abs_diff_u12 = a - b;
        else
            abs_diff_u12 = b - a;
    end
endfunction

assign param_done_w = param_valid_d1 && !param_valid;
assign blc_fire_w   = in_valid;
assign blc_done_w   = (curr_state == RUN_BLC) && blc_started && !in_valid && !vld_s1 && !vld_s2;
assign lsc_done_w   = (curr_state == LSC_RUN) && (lsc_cnt == 8'd255);
assign dpc_done_w   = (curr_state == RUN_DPC)  && (dpc_cnt  == 8'd255);
assign demo_done_w  = (curr_state == RUN_DEMOSAIC) && (demo_cnt == 8'd255);
assign out_done_w   = (curr_state == DATA_OUT) && (out_cnt  == 8'd255);

assign dpc_h0_w  = main_buffer[get_lsc_idx(dpc_x_now, dpc_y_now, -3'sd2,  3'sd0)];
assign dpc_h1_w  = main_buffer[get_lsc_idx(dpc_x_now, dpc_y_now, -3'sd1,  3'sd0)];
assign dpc_h2_w  = main_buffer[get_lsc_idx(dpc_x_now, dpc_y_now,  3'sd1,  3'sd0)];
assign dpc_h3_w  = main_buffer[get_lsc_idx(dpc_x_now, dpc_y_now,  3'sd2,  3'sd0)];
assign dpc_v0_w  = main_buffer[get_lsc_idx(dpc_x_now, dpc_y_now,  3'sd0, -3'sd2)];
assign dpc_v1_w  = main_buffer[get_lsc_idx(dpc_x_now, dpc_y_now,  3'sd0, -3'sd1)];
assign dpc_v2_w  = main_buffer[get_lsc_idx(dpc_x_now, dpc_y_now,  3'sd0,  3'sd1)];
assign dpc_v3_w  = main_buffer[get_lsc_idx(dpc_x_now, dpc_y_now,  3'sd0,  3'sd2)];
assign dpc_d10_w = main_buffer[get_lsc_idx(dpc_x_now, dpc_y_now, -3'sd2, -3'sd2)];
assign dpc_d11_w = main_buffer[get_lsc_idx(dpc_x_now, dpc_y_now, -3'sd1, -3'sd1)];
assign dpc_d12_w = main_buffer[get_lsc_idx(dpc_x_now, dpc_y_now,  3'sd1,  3'sd1)];
assign dpc_d13_w = main_buffer[get_lsc_idx(dpc_x_now, dpc_y_now,  3'sd2,  3'sd2)];
assign dpc_d20_w = main_buffer[get_lsc_idx(dpc_x_now, dpc_y_now,  3'sd2, -3'sd2)];
assign dpc_d21_w = main_buffer[get_lsc_idx(dpc_x_now, dpc_y_now,  3'sd1, -3'sd1)];
assign dpc_d22_w = main_buffer[get_lsc_idx(dpc_x_now, dpc_y_now, -3'sd1,  3'sd1)];
assign dpc_d23_w = main_buffer[get_lsc_idx(dpc_x_now, dpc_y_now, -3'sd2,  3'sd2)];

always @(*) begin
    next_state = curr_state;
    case (curr_state)
        IDLE: begin
            if (param_valid)
                next_state = LOAD_PARAM;
            else if (in_valid)
                next_state = RUN_BLC;
        end
        LOAD_PARAM: begin
            if (param_done_w)
                next_state = IDLE;
        end
        RUN_BLC: begin
            if (blc_done_w)
                next_state = RUN_DPC;
        end
        LSC_RUN: begin
            next_state = RUN_DPC;
        end
        RUN_DPC: begin
            if (dpc_done_w)
                next_state = RUN_DEMOSAIC;
        end
        RUN_DEMOSAIC: begin
            if (demo_done_w)
                next_state = DATA_OUT;
        end
        DATA_OUT: begin
            if (out_done_w)
                next_state = IDLE;
        end
        default: next_state = IDLE;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        curr_state <= IDLE;
    else
        curr_state <= next_state;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        in_valid_d1 <= 1'b0;
    else
        in_valid_d1 <= in_valid;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        param_valid_d1 <= 1'b0;
    else
        param_valid_d1 <= param_valid;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        param_cnt <= 8'd0;
    else if (param_valid) begin
        gain_mem[param_cnt] <= param_gain;
        param_cnt <= param_cnt + 8'd1;
    end
    else if (curr_state == IDLE)
        param_cnt <= 8'd0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        blc_cnt <= 8'd0;
    else if (blc_fire_w)
        blc_cnt <= blc_cnt + 8'd1;
    else if (curr_state == IDLE)
        blc_cnt <= 8'd0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        blc_started <= 1'b0;
    else if (curr_state == IDLE)
        blc_started <= 1'b0;
    else if (curr_state == RUN_BLC && in_valid)
        blc_started <= 1'b1;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        blc_done_r <= 1'b0;
    else if (curr_state != RUN_BLC)
        blc_done_r <= 1'b0;
    else if (in_valid_d1 && !in_valid)
        blc_done_r <= 1'b1;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        row_cnt <= 4'd0;
    else if (blc_fire_w && col_cnt == 4'd15)
        row_cnt <= row_cnt + 4'd1;
    else if (curr_state == IDLE)
        row_cnt <= 4'd0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        col_cnt <= 4'd0;
    else if (blc_fire_w && col_cnt == 4'd15)
        col_cnt <= 4'd0;
    else if (blc_fire_w)
        col_cnt <= col_cnt + 4'd1;
    else if (curr_state == IDLE)
        col_cnt <= 4'd0;
end

always @(*) begin
    case ({row_cnt[0], col_cnt[0]})
        2'b00: b_offset = 7'd64;
        2'b01: b_offset = 7'd48;
        2'b10: b_offset = 7'd52;
        default: b_offset = 7'd72;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        lsc_cnt <= 8'd0;
    else if (curr_state == LSC_RUN)
        lsc_cnt <= lsc_cnt + 8'd1;
    else
        lsc_cnt <= 8'd0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        dpc_cnt <= 8'd0;
    else if (curr_state == RUN_DPC)
        dpc_cnt <= dpc_cnt + 8'd1;
    else
        dpc_cnt <= 8'd0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        demo_cnt <= 8'd0;
    else if (curr_state == RUN_DEMOSAIC)
        demo_cnt <= demo_cnt + 8'd1;
    else
        demo_cnt <= 8'd0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        out_cnt <= 8'd0;
    else if (curr_state == DATA_OUT)
        out_cnt <= out_cnt + 8'd1;
    else
        out_cnt <= 8'd0;
end

always @(*) begin
    if (in > b_offset)
        blc_pixel_w = in - b_offset;
    else
        blc_pixel_w = 12'd0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        blc_p_s1 <= 12'd0;
        idx_s1   <= 8'd0;
        x_s1     <= 4'd0;
        y_s1     <= 4'd0;
        vld_s1   <= 1'b0;
        blc_p_s2 <= 12'd0;
        gain_s2  <= 12'd0;
        idx_s2   <= 8'd0;
        vld_s2   <= 1'b0;
    end
    else if ((curr_state == RUN_BLC) || in_valid || vld_s1 || vld_s2) begin
        if (vld_s2)
            main_buffer[idx_s2] <= lsc_pixel_w;

        blc_p_s2 <= blc_p_s1;
        gain_s2  <= gain_w;
        idx_s2   <= idx_s1;
        vld_s2   <= vld_s1;

        if (in_valid) begin
            blc_p_s1 <= blc_pixel_w;
            idx_s1   <= blc_cnt;
            x_s1     <= col_cnt;
            y_s1     <= row_cnt;
            vld_s1   <= 1'b1;
        end
        else begin
            vld_s1 <= 1'b0;
        end
    end
    else begin
        vld_s1 <= 1'b0;
        vld_s2 <= 1'b0;
    end
end

// LSC: lookup x0/rx/y0/ry and dx/ix/dy/iy in the same cycle, then fetch g00/g01/g10/g11.
always @(*) begin
    x_now = x_s1;
    y_now = y_s1;

    case (x_now)
        4'd0:  begin x0_w = 3'd0; rx_w = 2'd0; end
        4'd1:  begin x0_w = 3'd0; rx_w = 2'd1; end
        4'd2:  begin x0_w = 3'd0; rx_w = 2'd2; end
        4'd3:  begin x0_w = 3'd1; rx_w = 2'd0; end
        4'd4:  begin x0_w = 3'd1; rx_w = 2'd1; end
        4'd5:  begin x0_w = 3'd1; rx_w = 2'd2; end
        4'd6:  begin x0_w = 3'd2; rx_w = 2'd0; end
        4'd7:  begin x0_w = 3'd2; rx_w = 2'd1; end
        4'd8:  begin x0_w = 3'd2; rx_w = 2'd2; end
        4'd9:  begin x0_w = 3'd3; rx_w = 2'd0; end
        4'd10: begin x0_w = 3'd3; rx_w = 2'd1; end
        4'd11: begin x0_w = 3'd3; rx_w = 2'd2; end
        4'd12: begin x0_w = 3'd4; rx_w = 2'd0; end
        4'd13: begin x0_w = 3'd4; rx_w = 2'd1; end
        default: begin x0_w = 3'd4; rx_w = 2'd2; end
    endcase

    case (rx_w)
        2'd0: begin dx_w = 9'd0;   ix_w = 9'd256; end
        2'd1: begin dx_w = 9'd85;  ix_w = 9'd171; end
        2'd2: begin dx_w = 9'd171; ix_w = 9'd85;  end
        default: begin dx_w = 9'd0; ix_w = 9'd256; end
    endcase

    case (y_now)
        4'd0:  begin y0_w = 3'd0; ry_w = 2'd0; end
        4'd1:  begin y0_w = 3'd0; ry_w = 2'd1; end
        4'd2:  begin y0_w = 3'd0; ry_w = 2'd2; end
        4'd3:  begin y0_w = 3'd1; ry_w = 2'd0; end
        4'd4:  begin y0_w = 3'd1; ry_w = 2'd1; end
        4'd5:  begin y0_w = 3'd1; ry_w = 2'd2; end
        4'd6:  begin y0_w = 3'd2; ry_w = 2'd0; end
        4'd7:  begin y0_w = 3'd2; ry_w = 2'd1; end
        4'd8:  begin y0_w = 3'd2; ry_w = 2'd2; end
        4'd9:  begin y0_w = 3'd3; ry_w = 2'd0; end
        4'd10: begin y0_w = 3'd3; ry_w = 2'd1; end
        4'd11: begin y0_w = 3'd3; ry_w = 2'd2; end
        4'd12: begin y0_w = 3'd4; ry_w = 2'd0; end
        4'd13: begin y0_w = 3'd4; ry_w = 2'd1; end
        default: begin y0_w = 3'd4; ry_w = 2'd2; end
    endcase

    case (ry_w)
        2'd0: begin dy_w = 9'd0;   iy_w = 9'd256; end
        2'd1: begin dy_w = 9'd85;  iy_w = 9'd171; end
        2'd2: begin dy_w = 9'd171; iy_w = 9'd85;  end
        default: begin dy_w = 9'd0; iy_w = 9'd256; end
    endcase

    idx00_w = (y0_w << 2) + (y0_w << 1) + x0_w;
    idx01_w = (y0_w << 2) + (y0_w << 1) + x0_w + 3'd1;
    idx10_w = ((y0_w + 3'd1) << 2) + ((y0_w + 3'd1) << 1) + x0_w;
    idx11_w = ((y0_w + 3'd1) << 2) + ((y0_w + 3'd1) << 1) + x0_w + 3'd1;

    case ({y_now[0], x_now[0]})
        2'b00: gain_base_w = 8'd0;
        2'b01: gain_base_w = 8'd36;
        2'b10: gain_base_w = 8'd72;
        default: gain_base_w = 8'd108;
    endcase

    gain_idx00_w = gain_base_w + idx00_w;
    gain_idx01_w = gain_base_w + idx01_w;
    gain_idx10_w = gain_base_w + idx10_w;
    gain_idx11_w = gain_base_w + idx11_w;

    g00_w = gain_mem[gain_idx00_w];
    g01_w = gain_mem[gain_idx01_w];
    g10_w = gain_mem[gain_idx10_w];
    g11_w = gain_mem[gain_idx11_w];
end

// LSC: calculate G(x,y), then apply it to P(x,y).
always @(*) begin
    gain_accum_w = (g00_w * ix_w * iy_w) +
                   (g10_w * ix_w * dy_w) +
                   (g01_w * dx_w * iy_w) +
                   (g11_w * dx_w * dy_w) +
                   32'd32768;
    gain_w = gain_accum_w[31:16];

    lsc_accum_w = (blc_p_s2 * gain_s2) + 32'd512;
    if (lsc_accum_w[31:22] != 0)
        lsc_pixel_w = 12'd4095;
    else
        lsc_pixel_w = lsc_accum_w[21:10];
end

// DPC: form 4 directions, compare SAD, and replace the center pixel if it differs from target by more than 320.
always @(*) begin
    dpc_x_now = dpc_cnt[3:0];
    dpc_y_now = dpc_cnt[7:4];
    dpc_p_w   = main_buffer[dpc_cnt];

    dpc_h_med_w  = median4_avg_u12(dpc_h0_w,  dpc_h1_w,  dpc_h2_w,  dpc_h3_w);
    dpc_v_med_w  = median4_avg_u12(dpc_v0_w,  dpc_v1_w,  dpc_v2_w,  dpc_v3_w);
    dpc_d1_med_w = median4_avg_u12(dpc_d10_w, dpc_d11_w, dpc_d12_w, dpc_d13_w);
    dpc_d2_med_w = median4_avg_u12(dpc_d20_w, dpc_d21_w, dpc_d22_w, dpc_d23_w);

    dpc_h_sad_w  = abs_diff_u12(dpc_h0_w,  dpc_h_med_w)  + abs_diff_u12(dpc_h1_w,  dpc_h_med_w)  +
                   abs_diff_u12(dpc_h2_w,  dpc_h_med_w)  + abs_diff_u12(dpc_h3_w,  dpc_h_med_w);
    dpc_v_sad_w  = abs_diff_u12(dpc_v0_w,  dpc_v_med_w)  + abs_diff_u12(dpc_v1_w,  dpc_v_med_w)  +
                   abs_diff_u12(dpc_v2_w,  dpc_v_med_w)  + abs_diff_u12(dpc_v3_w,  dpc_v_med_w);
    dpc_d1_sad_w = abs_diff_u12(dpc_d10_w, dpc_d1_med_w) + abs_diff_u12(dpc_d11_w, dpc_d1_med_w) +
                   abs_diff_u12(dpc_d12_w, dpc_d1_med_w) + abs_diff_u12(dpc_d13_w, dpc_d1_med_w);
    dpc_d2_sad_w = abs_diff_u12(dpc_d20_w, dpc_d2_med_w) + abs_diff_u12(dpc_d21_w, dpc_d2_med_w) +
                   abs_diff_u12(dpc_d22_w, dpc_d2_med_w) + abs_diff_u12(dpc_d23_w, dpc_d2_med_w);

    // Default to H, then apply the tie-break priority H > V > D1 > D2.
    dpc_target_w = dpc_h_med_w;
    if (dpc_v_sad_w < dpc_h_sad_w) begin
        if ((dpc_v_sad_w <= dpc_d1_sad_w) && (dpc_v_sad_w <= dpc_d2_sad_w))
            dpc_target_w = dpc_v_med_w;
        else if ((dpc_d1_sad_w < dpc_v_sad_w) && (dpc_d1_sad_w <= dpc_d2_sad_w))
            dpc_target_w = dpc_d1_med_w;
        else
            dpc_target_w = dpc_d2_med_w;
    end
    else begin
        if ((dpc_d1_sad_w < dpc_h_sad_w) && (dpc_d1_sad_w <= dpc_d2_sad_w))
            dpc_target_w = dpc_d1_med_w;
        else if ((dpc_d2_sad_w < dpc_h_sad_w) && (dpc_d2_sad_w < dpc_d1_sad_w))
            dpc_target_w = dpc_d2_med_w;
    end

    if (abs_diff_u12(dpc_p_w, dpc_target_w) > 13'd320)
        dpc_pixel_w = dpc_target_w;
    else
        dpc_pixel_w = dpc_p_w;
end

always @(posedge clk) begin
    if (curr_state == RUN_DPC)
        dpc_buffer[dpc_cnt] <= dpc_pixel_w;
end

// Demosaic: extract the 3x3 window from dpc_buffer and interpolate missing RGB components.
always @(*) begin
    dx = demo_cnt[3:0];
    dy = demo_cnt[7:4];

    p_c  = dpc_buffer[demo_cnt];
    p_n  = dpc_buffer[get_demo_idx(dx, dy,  2'sd0, -2'sd1)];
    p_s  = dpc_buffer[get_demo_idx(dx, dy,  2'sd0,  2'sd1)];
    p_e  = dpc_buffer[get_demo_idx(dx, dy,  2'sd1,  2'sd0)];
    p_w  = dpc_buffer[get_demo_idx(dx, dy, -2'sd1,  2'sd0)];
    p_nw = dpc_buffer[get_demo_idx(dx, dy, -2'sd1, -2'sd1)];
    p_ne = dpc_buffer[get_demo_idx(dx, dy,  2'sd1, -2'sd1)];
    p_sw = dpc_buffer[get_demo_idx(dx, dy, -2'sd1,  2'sd1)];
    p_se = dpc_buffer[get_demo_idx(dx, dy,  2'sd1,  2'sd1)];

    case ({dy[0], dx[0]})
        2'b00: begin
            demo_r_w = p_c;
            sum4_w   = p_n + p_s + p_e + p_w;
            demo_g_w = sum4_w >> 2;
            sum4_w   = p_nw + p_ne + p_sw + p_se;
            demo_b_w = sum4_w >> 2;
        end
        2'b01: begin
            sum2_w   = p_w + p_e;
            demo_r_w = sum2_w >> 1;
            demo_g_w = p_c;
            sum2_w   = p_n + p_s;
            demo_b_w = sum2_w >> 1;
        end
        2'b10: begin
            sum2_w   = p_n + p_s;
            demo_r_w = sum2_w >> 1;
            demo_g_w = p_c;
            sum2_w   = p_w + p_e;
            demo_b_w = sum2_w >> 1;
        end
        default: begin
            sum4_w   = p_nw + p_ne + p_sw + p_se;
            demo_r_w = sum4_w >> 2;
            sum4_w   = p_n + p_s + p_e + p_w;
            demo_g_w = sum4_w >> 2;
            demo_b_w = p_c;
        end
    endcase
end

always @(posedge clk) begin
    if (curr_state == RUN_DEMOSAIC) begin
        demo_r_buffer[demo_cnt] <= demo_r_w;
        demo_g_buffer[demo_cnt] <= demo_g_w;
        demo_b_buffer[demo_cnt] <= demo_b_w;
    end
end

// CCM: calculate one RGB output from one LSC pixel.
always @(*) begin
    ccm_r_raw_w = ($signed({1'b0, demo_r_buffer[out_cnt]}) * C11)
                + ($signed({1'b0, demo_g_buffer[out_cnt]}) * C12)
                + ($signed({1'b0, demo_b_buffer[out_cnt]}) * C13)
                + 26'sd512;
    ccm_g_raw_w = ($signed({1'b0, demo_r_buffer[out_cnt]}) * C21)
                + ($signed({1'b0, demo_g_buffer[out_cnt]}) * C22)
                + ($signed({1'b0, demo_b_buffer[out_cnt]}) * C23)
                + 26'sd512;
    ccm_b_raw_w = ($signed({1'b0, demo_r_buffer[out_cnt]}) * C31)
                + ($signed({1'b0, demo_g_buffer[out_cnt]}) * C32)
                + ($signed({1'b0, demo_b_buffer[out_cnt]}) * C33)
                + 26'sd512;

    ccm_r_w = clamp_u12(ccm_r_raw_w >>> 10);
    ccm_g_w = clamp_u12(ccm_g_raw_w >>> 10);
    ccm_b_w = clamp_u12(ccm_b_raw_w >>> 10);
end

// Output 256 RGB pixels after all stages finish.
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_valid <= 1'b0;
        r_out     <= 12'd0;
        g_out     <= 12'd0;
        b_out     <= 12'd0;
    end
    else if (curr_state == DATA_OUT) begin
        out_valid <= 1'b1;
        r_out     <= ccm_r_w;
        g_out     <= ccm_g_w;
        b_out     <= ccm_b_w;
    end
    else begin
        out_valid <= 1'b0;
        r_out     <= 12'd0;
        g_out     <= 12'd0;
        b_out     <= 12'd0;
    end
end

endmodule
