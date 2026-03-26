module ISP (
    input clk,
    input rst_n,
    input in_valid,
    input [11:0] in,
    input param_valid,
    input [11:0] param_gain,
    output reg out_valid,
    output reg [11:0] r_out,
    output reg [11:0] g_out,
    output reg [11:0] b_out
);

// ==========================================================================
// FSM Parameters
// ==========================================================================
localparam IDLE     = 2'd0;
localparam DATA_IN  = 2'd1; 
localparam DPC_ST   = 2'd2; 
localparam DATA_OUT = 2'd3; 


// ==========================================================================
// Signals
// ==========================================================================
// FSM state
reg [1:0] state, next_state;

// buffer
reg [11:0] param_buffer_R  [0:5][0:5];
reg [11:0] param_buffer_Gr [0:5][0:5];
reg [11:0] param_buffer_Gb [0:5][0:5];
reg [11:0] param_buffer_B  [0:5][0:5];

reg [11:0] lsc_buf [0:15][0:15];
reg [11:0] dpc_buf [0:15][0:15];

// param addr
reg [2:0] p_x, p_y;
reg [1:0] p_ch;

// input counter
reg [7:0] in_count;

// input reg
reg [11:0] in_reg; 
reg in_valid_reg; 
reg [7:0] in_count_reg;

// BLC
reg [11:0] blc_reg; 
reg blc_valid_reg; 
reg [7:0] blc_count;

// LSC
reg [11:0] lsc_g00, lsc_g01, lsc_g10, lsc_g11;
reg [8:0] lsc_ix, lsc_dx, lsc_iy, lsc_dy;
reg [8:0] lsc2_iy, lsc2_dy;
reg [16:0] lsc3_Gxy; 

reg [11:0] lsc_reg; 
reg [21:0] lsc2_G_top, lsc2_G_bot;
reg [11:0] lsc3_reg; 
reg [28:0] lsc4_reg; 
reg [11:0] lsc5_reg; 

reg lsc_valid_reg; 
reg lsc3_valid;
reg lsc4_valid;  
reg lsc5_valid; 

reg [7:0] lsc_count;
reg [7:0] lsc3_count;
reg [7:0] lsc4_count;
reg [7:0] lsc5_count;

// DPC
reg dpc_gen_done; 
reg [7:0] dpc_gen_count;

reg dpc1_valid; 
reg dpc2_valid; 
reg dpc3_valid; 
reg dpc4_valid; 

reg [7:0] dpc1_count; 
reg [7:0] dpc2_count; 
reg [7:0] dpc3_count; 
reg [7:0] dpc4_count; 

reg [11:0] dpc3_pc;
reg [11:0] dpc4_pc;

reg [11:0] dpc4_target;

reg [11:0] dpc1_pc;
reg [11:0] dpc1_H0, dpc1_H1, dpc1_H2, dpc1_H3, dpc1_V0, dpc1_V1, dpc1_V2, dpc1_V3;
reg [11:0] dpc1_D1_0, dpc1_D1_1, dpc1_D1_2, dpc1_D1_3, dpc1_D2_0, dpc1_D2_1, dpc1_D2_2, dpc1_D2_3;

reg [11:0] dpc2_pc;
reg [11:0] dpc2_med_H, dpc2_med_V, dpc2_med_D1, dpc2_med_D2;
reg [11:0] dpc2_H0, dpc2_H1, dpc2_H2, dpc2_H3, dpc2_V0, dpc2_V1, dpc2_V2, dpc2_V3;
reg [11:0] dpc2_D1_0, dpc2_D1_1, dpc2_D1_2, dpc2_D1_3, dpc2_D2_0, dpc2_D2_1, dpc2_D2_2, dpc2_D2_3;

reg [11:0] dpc3_med_H, dpc3_med_V, dpc3_med_D1, dpc3_med_D2;
reg [13:0] dpc3_sad_H, dpc3_sad_V, dpc3_sad_D1, dpc3_sad_D2;

// DM + CCM
reg out_gen_done; 
reg [7:0] out_gen_count;

reg [11:0] out1_c, out1_n, out1_s, out1_w, out1_e, out1_nw, out1_ne, out1_sw, out1_se;
reg [11:0] dm_r_c, dm_g_c, dm_b_c;

reg signed [24:0] s_dm_r, s_dm_g, s_dm_b;

reg signed [24:0] out3_R11, out3_G11, out3_B11;
reg signed [24:0] out3_R50, out3_G50, out3_B50;

reg signed [25:0] out4_r_calc, out4_g_calc, out4_b_calc;

reg out1_valid; 
reg out2_valid; 
reg out3_valid; 
reg out4_valid; 

reg [7:0] out1_count;
reg [7:0] out2_count; 
reg [7:0] out3_count;
reg [7:0] out4_count;

// ==========================================================================
// Design
// ==========================================================================
// counter decode
wire [3:0] in_count_y = in_count_reg[7:4]; 
wire [3:0] in_count_x = in_count_reg[3:0];

wire [3:0] lsc_write_y = lsc5_count[7:4];
wire [3:0] lsc_write_x = lsc5_count[3:0];

wire [3:0] lsc_read_y = dpc_gen_count[7:4];
wire [3:0] lsc_read_x = dpc_gen_count[3:0];

wire [3:0] dpc_write_y = dpc4_count[7:4];
wire [3:0] dpc_write_x = dpc4_count[3:0];

wire [3:0] dpc_read_y = out_gen_count[7:4];
wire [3:0] dpc_read_x = out_gen_count[3:0];

// param gain channel
wire is_r  = (in_count_y[0] == 0 && in_count_x[0] == 0);
wire is_gr = (in_count_y[0] == 0 && in_count_x[0] == 1);
wire is_gb = (in_count_y[0] == 1 && in_count_x[0] == 0);
wire is_b  = (in_count_y[0] == 1 && in_count_x[0] == 1);

// BLC
wire [11:0] blc_c = is_r  ? ((in_reg > 'd64) ? (in_reg - 'd64) : 'd0) : 
                    is_gr ? ((in_reg > 'd48) ? (in_reg - 'd48) : 'd0) : 
                    is_gb ? ((in_reg > 'd52) ? (in_reg - 'd52) : 'd0) : ((in_reg > 'd72) ? (in_reg - 'd72) : 'd0);

// LSC
wire [2:0] x0_c = (in_count_x >= 'd12) ? 'd4 : (in_count_x >= 'd9) ? 'd3 : (in_count_x >= 'd6) ? 'd2 : (in_count_x >= 'd3) ? 'd1 : 'd0;
wire [2:0] y0_c = (in_count_y >= 'd12) ? 'd4 : (in_count_y >= 'd9) ? 'd3 : (in_count_y >= 'd6) ? 'd2 : (in_count_y >= 'd3) ? 'd1 : 'd0;
wire [2:0] rx   = (in_count_x >= 'd12) ? (in_count_x > 'd14 ? 'd2 : in_count_x - 'd12) : (in_count_x - x0_c * 'd3);
wire [2:0] ry   = (in_count_y >= 'd12) ? (in_count_y > 'd14 ? 'd2 : in_count_y - 'd12) : (in_count_y - y0_c * 'd3);

wire [8:0] dx = (rx == 'd0) ? 'd0   : (rx == 'd1) ? 'd85  : 'd171; 
wire [8:0] dy = (ry == 'd0) ? 'd0   : (ry == 'd1) ? 'd85  : 'd171; 
wire [8:0] ix = (rx == 'd0) ? 'd256 : (rx == 'd1) ? 'd171 : 'd85;
wire [8:0] iy = (ry == 'd0) ? 'd256 : (ry == 'd1) ? 'd171 : 'd85;

wire [11:0] g00 = is_r ? param_buffer_R[y0_c][x0_c]     : is_gr ? param_buffer_Gr[y0_c][x0_c]     : is_gb ? param_buffer_Gb[y0_c][x0_c]     : param_buffer_B[y0_c][x0_c];
wire [11:0] g01 = is_r ? param_buffer_R[y0_c][x0_c+1]   : is_gr ? param_buffer_Gr[y0_c][x0_c+1]   : is_gb ? param_buffer_Gb[y0_c][x0_c+1]   : param_buffer_B[y0_c][x0_c+1];
wire [11:0] g10 = is_r ? param_buffer_R[y0_c+1][x0_c]   : is_gr ? param_buffer_Gr[y0_c+1][x0_c]   : is_gb ? param_buffer_Gb[y0_c+1][x0_c]   : param_buffer_B[y0_c+1][x0_c];
wire [11:0] g11 = is_r ? param_buffer_R[y0_c+1][x0_c+1] : is_gr ? param_buffer_Gr[y0_c+1][x0_c+1] : is_gb ? param_buffer_Gb[y0_c+1][x0_c+1] : param_buffer_B[y0_c+1][x0_c+1];

// calculate Gxy = (g00*ix + g01*dx) * iy + (g10*ix + g11*dx) * dy
wire [20:0] g00_ix_c, g01_dx_c, g10_ix_c, g11_dx_c;
wire [30:0] g_top_iy_c, g_bot_dy_c;
Mult_LUT1 u_m00(.in(lsc_g00), .w(lsc_ix), .out(g00_ix_c));
Mult_LUT1 u_m01(.in(lsc_g01), .w(lsc_dx), .out(g01_dx_c));
Mult_LUT1 u_m10(.in(lsc_g10), .w(lsc_ix), .out(g10_ix_c));
Mult_LUT1 u_m11(.in(lsc_g11), .w(lsc_dx), .out(g11_dx_c));

Mult_LUT2 u_m_top(.in(lsc2_G_top), .w(lsc2_iy), .out(g_top_iy_c));
Mult_LUT2 u_m_bot(.in(lsc2_G_bot), .w(lsc2_dy), .out(g_bot_dy_c));

wire [16:0] Gxy = (g_top_iy_c + g_bot_dy_c + 32768) >> 16;

wire [28:0] lsc4_shift_add  = lsc4_reg + 512;
wire [18:0] lsc4_shifted    = lsc4_shift_add >> 10;
wire [11:0] lsc4_clamp      = (lsc4_shifted > 4095) ? 4095 : lsc4_shifted[11:0];

// DPC
wire [3:0] dy_m2 = (lsc_read_y < 'd2)  ? ('d2 - lsc_read_y) : (lsc_read_y - 'd2);
wire [3:0] dx_m2 = (lsc_read_x < 'd2)  ? ('d2 - lsc_read_x) : (lsc_read_x - 'd2);
wire [3:0] dy_m1 = (lsc_read_y == 'd0) ? 'd1 : (lsc_read_y - 'd1);
wire [3:0] dx_m1 = (lsc_read_x == 'd0) ? 'd1 : (lsc_read_x - 'd1); 
wire [3:0] dy_0 = lsc_read_y;
wire [3:0] dx_0 = lsc_read_x;
wire [3:0] dy_p1 = (lsc_read_y == 'd15) ? 'd14 : (lsc_read_y + 'd1);
wire [3:0] dx_p1 = (lsc_read_x == 'd15) ? 'd14 : (lsc_read_x + 'd1);
wire [3:0] dy_p2 = (lsc_read_y > 'd13)  ? ('d28 - lsc_read_y) : (lsc_read_y + 'd2);
wire [3:0] dx_p2 = (lsc_read_x > 'd13)  ? ('d28 - lsc_read_x) : (lsc_read_x + 'd2);

wire [11:0] med_h_c, med_v_c, med_dpc1_c, med_dpc2_c;

wire [12:0] sub_h0   = {1'b0, dpc2_H0}   - {1'b0, dpc2_med_H};
wire [12:0] sub_h1   = {1'b0, dpc2_H1}   - {1'b0, dpc2_med_H};
wire [12:0] sub_h2   = {1'b0, dpc2_H2}   - {1'b0, dpc2_med_H};
wire [12:0] sub_h3   = {1'b0, dpc2_H3}   - {1'b0, dpc2_med_H};
wire [12:0] sub_v0   = {1'b0, dpc2_V0}   - {1'b0, dpc2_med_V};
wire [12:0] sub_v1   = {1'b0, dpc2_V1}   - {1'b0, dpc2_med_V};
wire [12:0] sub_v2   = {1'b0, dpc2_V2}   - {1'b0, dpc2_med_V};
wire [12:0] sub_v3   = {1'b0, dpc2_V3}   - {1'b0, dpc2_med_V};
wire [12:0] sub_d1_0 = {1'b0, dpc2_D1_0} - {1'b0, dpc2_med_D1};
wire [12:0] sub_d1_1 = {1'b0, dpc2_D1_1} - {1'b0, dpc2_med_D1};
wire [12:0] sub_d1_2 = {1'b0, dpc2_D1_2} - {1'b0, dpc2_med_D1};
wire [12:0] sub_d1_3 = {1'b0, dpc2_D1_3} - {1'b0, dpc2_med_D1};
wire [12:0] sub_d2_0 = {1'b0, dpc2_D2_0} - {1'b0, dpc2_med_D2};
wire [12:0] sub_d2_1 = {1'b0, dpc2_D2_1} - {1'b0, dpc2_med_D2};
wire [12:0] sub_d2_2 = {1'b0, dpc2_D2_2} - {1'b0, dpc2_med_D2};
wire [12:0] sub_d2_3 = {1'b0, dpc2_D2_3} - {1'b0, dpc2_med_D2};

wire [11:0] abs_h0   = sub_h0[12]   ? -sub_h0[11:0]   : sub_h0[11:0];
wire [11:0] abs_h1   = sub_h1[12]   ? -sub_h1[11:0]   : sub_h1[11:0];
wire [11:0] abs_h2   = sub_h2[12]   ? -sub_h2[11:0]   : sub_h2[11:0];
wire [11:0] abs_h3   = sub_h3[12]   ? -sub_h3[11:0]   : sub_h3[11:0];
wire [11:0] abs_v0   = sub_v0[12]   ? -sub_v0[11:0]   : sub_v0[11:0];
wire [11:0] abs_v1   = sub_v1[12]   ? -sub_v1[11:0]   : sub_v1[11:0];
wire [11:0] abs_v2   = sub_v2[12]   ? -sub_v2[11:0]   : sub_v2[11:0];
wire [11:0] abs_v3   = sub_v3[12]   ? -sub_v3[11:0]   : sub_v3[11:0];
wire [11:0] abs_d1_0 = sub_d1_0[12] ? -sub_d1_0[11:0] : sub_d1_0[11:0];
wire [11:0] abs_d1_1 = sub_d1_1[12] ? -sub_d1_1[11:0] : sub_d1_1[11:0];
wire [11:0] abs_d1_2 = sub_d1_2[12] ? -sub_d1_2[11:0] : sub_d1_2[11:0];
wire [11:0] abs_d1_3 = sub_d1_3[12] ? -sub_d1_3[11:0] : sub_d1_3[11:0];
wire [11:0] abs_d2_0 = sub_d2_0[12] ? -sub_d2_0[11:0] : sub_d2_0[11:0];
wire [11:0] abs_d2_1 = sub_d2_1[12] ? -sub_d2_1[11:0] : sub_d2_1[11:0];
wire [11:0] abs_d2_2 = sub_d2_2[12] ? -sub_d2_2[11:0] : sub_d2_2[11:0];
wire [11:0] abs_d2_3 = sub_d2_3[12] ? -sub_d2_3[11:0] : sub_d2_3[11:0];

wire [13:0] sad_h_c = abs_h0 + abs_h1 + abs_h2 + abs_h3;
wire [13:0] sad_v_c = abs_v0 + abs_v1 + abs_v2 + abs_v3;
wire [13:0] sad_dpc1_c = abs_d1_0 + abs_d1_1 + abs_d1_2 + abs_d1_3;
wire [13:0] sad_dpc2_c = abs_d2_0 + abs_d2_1 + abs_d2_2 + abs_d2_3;

wire h_min  = (dpc3_sad_H <= dpc3_sad_V) && (dpc3_sad_H <= dpc3_sad_D1) && (dpc3_sad_H <= dpc3_sad_D2);
wire v_min  = (!h_min) && (dpc3_sad_V <= dpc3_sad_D1) && (dpc3_sad_V <= dpc3_sad_D2);
wire dpc1_min = (!h_min) && (!v_min) && (dpc3_sad_D1 <= dpc3_sad_D2);

wire [11:0] target_c =  h_min    ? dpc3_med_H  : 
                        v_min    ? dpc3_med_V  : 
                        dpc1_min ? dpc3_med_D1 : dpc3_med_D2;

wire [11:0] p_diff = (dpc4_pc > dpc4_target) ? (dpc4_pc - dpc4_target) : (dpc4_target - dpc4_pc);
wire [11:0] dpc_out_c = (p_diff > 'd320) ? dpc4_target : dpc4_pc;

wire [3:0] oy_0  = dpc_read_y;
wire [3:0] ox_0  = dpc_read_x;
wire [3:0] oy_p1 = (dpc_read_y == 'd15) ? 'd14 : (dpc_read_y + 'd1);
wire [3:0] ox_p1 = (dpc_read_x == 'd15) ? 'd14 : (dpc_read_x + 'd1);
wire [3:0] oy_m1 = (dpc_read_y == 'd0)  ? 'd1  : (dpc_read_y - 'd1);
wire [3:0] ox_m1 = (dpc_read_x == 'd0)  ? 'd1  : (dpc_read_x - 'd1);

Calc_Median u_med_h (.a(dpc1_H0), .b(dpc1_H1), .c(dpc1_H2), .d(dpc1_H3), .med(med_h_c));
Calc_Median u_med_v (.a(dpc1_V0), .b(dpc1_V1), .c(dpc1_V2), .d(dpc1_V3), .med(med_v_c));
Calc_Median u_med_d1(.a(dpc1_D1_0), .b(dpc1_D1_1), .c(dpc1_D1_2), .d(dpc1_D1_3), .med(med_dpc1_c));
Calc_Median u_med_d2(.a(dpc1_D2_0), .b(dpc1_D2_1), .c(dpc1_D2_2), .d(dpc1_D2_3), .med(med_dpc2_c));

wire m_is_r  = ((out1_count[7:4] % 'd2) == 'd0 && (out1_count[3:0] % 'd2 == 'd0));
wire m_is_gr = ((out1_count[7:4] % 'd2) == 'd0 && (out1_count[3:0] % 'd2 == 'd1));
wire m_is_gb = ((out1_count[7:4] % 'd2) == 'd1 && (out1_count[3:0] % 'd2 == 'd0));
wire m_is_b  = ((out1_count[7:4] % 'd2) == 'd1 && (out1_count[3:0] % 'd2 == 'd1));

always @(*) begin
    if (m_is_r) begin
        dm_r_c = out1_c;
        dm_g_c = ({2'b0, out1_n}  + {2'b0, out1_s}  + {2'b0, out1_e}  + {2'b0, out1_w})  >> 2;
        dm_b_c = ({2'b0, out1_nw} + {2'b0, out1_ne} + {2'b0, out1_sw} + {2'b0, out1_se}) >> 2;
    end else if (m_is_b) begin
        dm_r_c = ({2'b0, out1_nw} + {2'b0, out1_ne} + {2'b0, out1_sw} + {2'b0, out1_se}) >> 2;
        dm_g_c = ({2'b0, out1_n}  + {2'b0, out1_s}  + {2'b0, out1_e}  + {2'b0, out1_w})  >> 2;
        dm_b_c = out1_c;
    end else if (m_is_gr) begin
        dm_r_c = ({1'b0, out1_w} + {1'b0, out1_e}) >> 1;
        dm_g_c = out1_c;
        dm_b_c = ({1'b0, out1_n} + {1'b0, out1_s}) >> 1;
    end else begin
        dm_r_c = ({1'b0, out1_n} + {1'b0, out1_s}) >> 1;
        dm_g_c = out1_c;
        dm_b_c = ({1'b0, out1_w} + {1'b0, out1_e}) >> 1;
    end
end

wire signed [25:0] shift_r = out4_r_calc >>> 10;
wire signed [25:0] shift_g = out4_g_calc >>> 10;
wire signed [25:0] shift_b = out4_b_calc >>> 10;

wire [11:0] final_r = (shift_r < 0) ? 12'd0 : (shift_r > 4095) ? 12'd4095 : shift_r[11:0];
wire [11:0] final_g = (shift_g < 0) ? 12'd0 : (shift_g > 4095) ? 12'd4095 : shift_g[11:0];
wire [11:0] final_b = (shift_b < 0) ? 12'd0 : (shift_b > 4095) ? 12'd4095 : shift_b[11:0];

wire dpc_valid_in = (state == DPC_ST && !dpc_gen_done);
wire out_valid_in = (state == DATA_OUT && !out_gen_done);

wire LSC_done = lsc5_valid && (lsc5_count == 'd255) && (state == DATA_IN);
wire DPC_done = dpc4_valid && (dpc4_count == 'd255) && (state == DPC_ST);
wire out_done = out4_valid && (out4_count == 'd255) && (state == DATA_OUT);

// FSM
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end
    else begin
        state <= next_state;
    end
end

always @(*) begin
    case (state)
        IDLE    :   next_state = in_valid ? DATA_IN     : IDLE;
        DATA_IN :   next_state = LSC_done ? DPC_ST      : DATA_IN;
        DPC_ST  :   next_state = DPC_done ? DATA_OUT    : DPC_ST;
        DATA_OUT:   next_state = out_done ? IDLE        : DATA_OUT;
        default :   next_state = IDLE;
    endcase
end

// param buffer
always @(posedge clk) begin
    if (param_valid) begin
        if (p_ch == 2'b00)      param_buffer_R[p_y][p_x]  <= param_gain;
        else if (p_ch == 2'b01) param_buffer_Gr[p_y][p_x] <= param_gain;
        else if (p_ch == 2'b10) param_buffer_Gb[p_y][p_x] <= param_gain;
        else if (p_ch == 2'b11) param_buffer_B[p_y][p_x]  <= param_gain;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        p_x <= 'd0; 
    end
    else if (param_valid) begin
        p_x <= (p_x == 'd5) ? 'd0 : (p_x + 'd1);
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        p_y <= 'd0; 
    end
    else if (param_valid & (p_x == 'd5)) begin
        p_y <= (p_y == 'd5) ? 'd0 : (p_y + 'd1);
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        p_ch <= 'd0; 
    end
    else if (param_valid & (p_x == 'd5) & (p_y == 'd5)) begin
        p_ch <= (p_ch == 'd3) ? 'd0 : (p_ch + 'd1);
    end
end

// input regs
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        in_count <= 'd0;
    end
    else if (in_valid) begin
        in_count <= in_count + 'd1;
    end
    else if (state == IDLE) begin
        in_count <= 'd0;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin 
        in_reg          <= 'd0; 
        in_valid_reg    <= 'd0; 
        in_count_reg    <= 'd0; 
    end
    else begin 
        in_reg          <= in; 
        in_valid_reg    <= in_valid; 
        in_count_reg    <= in_valid ? in_count : in_count_reg; 
    end
end

// BLC pipeline
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin 
        blc_valid_reg <= 'd0; 
        blc_count       <= 'd0; 
        blc_count       <= 'd0;
    end
    else begin
        blc_valid_reg <= in_valid_reg; 
        blc_reg       <= blc_c;
        blc_count       <= in_count_reg; 
    end
end

// LSC pipeline
// stage 1: memory acces, g00, g01, g10, g11 and calculate ix, iy, dx, dy
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin 
        lsc_g00 <= 'd0; 
        lsc_g01 <= 'd0; 
        lsc_g10 <= 'd0; 
        lsc_g11 <= 'd0;
    end
    else begin
        lsc_g00 <= g00; 
        lsc_g01 <= g01; 
        lsc_g10 <= g10; 
        lsc_g11 <= g11;
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin 
        lsc_ix  <= 'd0; 
        lsc_iy  <= 'd0; 
        lsc_dx  <= 'd0; 
        lsc_dy  <= 'd0;
    end
    else begin
        lsc_ix  <= ix; 
        lsc_iy  <= iy; 
        lsc_dx  <= dx; 
        lsc_dy  <= dy;
    end
end

// bypassing
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin 
        lsc_valid_reg   <= 'd0; 
        lsc_count       <= 'd0; 
        lsc_reg         <= 'd0;
    end
    else begin
        lsc_valid_reg   <= blc_valid_reg; 
        lsc_count       <= blc_count; 
        lsc_reg         <= blc_reg;
    end
end

// stage 2: calculate g00*ix + g01*dx and g10*ix + g11*dx
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin 
        lsc2_iy     <= 'd0;
        lsc2_dy     <= 'd0;
        lsc2_G_top  <= 'd0;
        lsc2_G_bot  <= 'd0;
    end
    else begin
        lsc2_iy     <= lsc_iy; 
        lsc2_dy     <= lsc_dy;
        lsc2_G_top  <= g00_ix_c + g01_dx_c;
        lsc2_G_bot  <= g10_ix_c + g11_dx_c;
    end
end

// stage 3: calculate Gxy = (g00*ix + g01*dx) * iy + (g10*ix + g11*dx) * dy
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin 
        lsc3_valid  <= 'd0; 
        lsc3_count  <= 'd0; 
        lsc3_reg    <= 'd0;
        lsc3_Gxy    <= 'd0;
    end
    else begin
        lsc3_valid  <= lsc_valid_reg; 
        lsc3_count  <= lsc_count; 
        lsc3_reg    <= lsc_reg;
        lsc3_Gxy    <= Gxy;
    end
end

// stage 4: calculate Pxy * Gxy
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin 
        lsc4_valid <= 'd0; 
        lsc4_count <= 'd0; 
        lsc4_reg  <= 'd0; 
    end
    else begin
        lsc4_valid <= lsc3_valid; 
        lsc4_count <= lsc3_count;
        lsc4_reg  <= lsc3_reg * lsc3_Gxy;
    end
end

// stage 5: clamp
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin 
        lsc5_valid    <= 'd0; 
        lsc5_count    <= 'd0; 
        lsc5_reg      <= 'd0; 
    end
    else begin
        lsc5_valid    <= lsc4_valid; 
        lsc5_count    <= lsc4_count; 
        lsc5_reg      <= lsc4_clamp;
    end
end

// stage 6: store into memory
always @(posedge clk) begin
    if (lsc5_valid && state == DATA_IN) begin
        lsc_buf[lsc_write_y][lsc_write_x] <= lsc5_reg;
    end
end

// DPC Control
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin 
        dpc_gen_done <= 'd0; 
    end 
    else if (state == DPC_ST) begin
        if (!dpc_gen_done & dpc_gen_count == 'd255) begin
            dpc_gen_done <= 'd1; 
        end
    end 
    else begin 
        dpc_gen_done <= 'd0; 
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin 
        dpc_gen_count <= 'd0; 
    end 
    else if (state == DPC_ST) begin
        if (!dpc_gen_done) begin 
            dpc_gen_count <= dpc_gen_count + 'd1; 
        end
    end 
    else begin 
        dpc_gen_count <= 'd0; 
    end
end

// DPC pipeline
// stage 1: memory access
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin 
        dpc1_valid <= 'd0; 
        dpc1_count <= 'd0; 
    end
    else begin
        dpc1_valid <= dpc_valid_in; 
        dpc1_count <= dpc_gen_count; 
    end
end

always @(posedge clk) begin
    dpc1_pc   <= lsc_buf[dy_0][dx_0];
    dpc1_H0   <= lsc_buf[dy_0][dx_m2];  dpc1_H1   <= lsc_buf[dy_0][dx_m1];  dpc1_H2   <= lsc_buf[dy_0][dx_p1];  dpc1_H3   <= lsc_buf[dy_0][dx_p2];
    dpc1_V0   <= lsc_buf[dy_m2][dx_0];  dpc1_V1   <= lsc_buf[dy_m1][dx_0];  dpc1_V2   <= lsc_buf[dy_p1][dx_0];  dpc1_V3   <= lsc_buf[dy_p2][dx_0];
    dpc1_D1_0 <= lsc_buf[dy_m2][dx_m2]; dpc1_D1_1 <= lsc_buf[dy_m1][dx_m1]; dpc1_D1_2 <= lsc_buf[dy_p1][dx_p1]; dpc1_D1_3 <= lsc_buf[dy_p2][dx_p2];
    dpc1_D2_0 <= lsc_buf[dy_m2][dx_p2]; dpc1_D2_1 <= lsc_buf[dy_m1][dx_p1]; dpc1_D2_2 <= lsc_buf[dy_p1][dx_m1]; dpc1_D2_3 <= lsc_buf[dy_p2][dx_m2];
end


// stage 2: calculate median
always @(posedge clk) begin
    dpc2_med_H  <= med_h_c; 
    dpc2_med_V  <= med_v_c; 
    dpc2_med_D1 <= med_dpc1_c; 
    dpc2_med_D2 <= med_dpc2_c;
end

// stage 2: bypassing
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin 
        dpc2_valid <= 'd0; 
        dpc2_count <= 'd0; 
    end
    else begin
        dpc2_valid <= dpc1_valid; dpc2_count <= dpc1_count; 
        dpc2_pc <= dpc1_pc;
        dpc2_H0 <= dpc1_H0; dpc2_H1 <= dpc1_H1; dpc2_H2 <= dpc1_H2; dpc2_H3 <= dpc1_H3;
        dpc2_V0 <= dpc1_V0; dpc2_V1 <= dpc1_V1; dpc2_V2 <= dpc1_V2; dpc2_V3 <= dpc1_V3;
        dpc2_D1_0 <= dpc1_D1_0; dpc2_D1_1 <= dpc1_D1_1; dpc2_D1_2 <= dpc1_D1_2; dpc2_D1_3 <= dpc1_D1_3;
        dpc2_D2_0 <= dpc1_D2_0; dpc2_D2_1 <= dpc1_D2_1; dpc2_D2_2 <= dpc1_D2_2; dpc2_D2_3 <= dpc1_D2_3;
    end
end

// stage 3: calculate
always @(posedge clk) begin
    dpc3_sad_H  <= sad_h_c;
    dpc3_sad_V  <= sad_v_c; 
    dpc3_sad_D1 <= sad_dpc1_c; 
    dpc3_sad_D2 <= sad_dpc2_c;
end

// stage 3: bypassing
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin 
        dpc3_valid <= 'd0; 
        dpc3_count <= 'd0; 
    end
    else begin
        dpc3_valid  <= dpc2_valid; 
        dpc3_count  <= dpc2_count; 
        dpc3_pc     <= dpc2_pc;
        dpc3_med_H  <= dpc2_med_H; 
        dpc3_med_V  <= dpc2_med_V; 
        dpc3_med_D1 <= dpc2_med_D1; 
        dpc3_med_D2 <= dpc2_med_D2;
    end
end

// stage 4: calculate target
always @(posedge clk) begin
    dpc4_target <= target_c; 
end

// stage 4: bypassing
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin 
        dpc4_valid  <= 'd0; 
        dpc4_count  <= 'd0; 
    end
    else begin 
        dpc4_valid  <= dpc3_valid; 
        dpc4_count  <= dpc3_count; 
        dpc4_pc     <= dpc3_pc;  
    end
end

// stage 5: store into memory
always @(posedge clk) begin
    if (dpc4_valid && state == DPC_ST) begin
        dpc_buf[dpc_write_y][dpc_write_x] <= dpc_out_c;
    end
end

// Output Control
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin 
        out_gen_done <= 'd0; 
    end 
    else if (state == DATA_OUT) begin
        if (!out_gen_done && out_gen_count == 255) begin 
            out_gen_done <= 'd1; 
        end
    end 
    else begin 
        out_gen_done <= 'd0; 
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin 
        out_gen_count <= 'd0; 
    end 
    else if (state == DATA_OUT) begin
        if (!out_gen_done) begin 
            out_gen_count <= out_gen_count + 'd1;
        end
    end 
    else begin 
        out_gen_count <= 'd0; 
    end
end

// Output pipeline (DM + CCM)
// state 1: memory access
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin 
        out1_valid <= 'd0; 
        out1_count <= 'd0; 
    end
    else begin
        out1_valid <= out_valid_in; 
        out1_count <= out_gen_count;
        out1_c  <= dpc_buf[oy_0][ox_0];
        out1_n  <= dpc_buf[oy_m1][ox_0];  
        out1_s  <= dpc_buf[oy_p1][ox_0];
        out1_w  <= dpc_buf[oy_0][ox_m1];  
        out1_e  <= dpc_buf[oy_0][ox_p1];
        out1_nw <= dpc_buf[oy_m1][ox_m1]; 
        out1_ne <= dpc_buf[oy_m1][ox_p1];
        out1_sw <= dpc_buf[oy_p1][ox_m1]; 
        out1_se <= dpc_buf[oy_p1][ox_p1];
    end
end

// state 2: calculate DM
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin 
        out2_valid <= 'd0; 
        out2_count <= 'd0; 
        s_dm_r <= 'd0; 
        s_dm_g <= 'd0; 
        s_dm_b <= 'd0; 
    end
    else begin
        out2_valid <= out1_valid; 
        out2_count <= out1_count;
        s_dm_r <= {13'b0, dm_r_c};
        s_dm_g <= {13'b0, dm_g_c};
        s_dm_b <= {13'b0, dm_b_c};
    end
end

// state 3: calculate 1100*RGB and 50*RGB
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin 
        out3_valid <= 'd0; 
        out3_count <= 'd0; 
        end
    else begin
        out3_valid <= out2_valid; 
        out3_count <= out2_count;
        out3_R11 <= {s_dm_r, 10'b0} + {s_dm_r, 6'b0} + {s_dm_r, 3'b0} + {s_dm_r, 2'b0}; // 1024+64+8+4=110
        out3_R50 <= {s_dm_r, 5'b0}  + {s_dm_r, 4'b0} + {s_dm_r, 1'b0};                  // 32+16+2=50
        out3_G11 <= {s_dm_g, 10'b0} + {s_dm_g, 6'b0} + {s_dm_g, 3'b0} + {s_dm_g, 2'b0};
        out3_G50 <= {s_dm_g, 5'b0}  + {s_dm_g, 4'b0} + {s_dm_g, 1'b0};
        out3_B11 <= {s_dm_b, 10'b0} + {s_dm_b, 6'b0} + {s_dm_b, 3'b0} + {s_dm_b, 2'b0};
        out3_B50 <= {s_dm_b, 5'b0}  + {s_dm_b, 4'b0} + {s_dm_b, 1'b0};
    end
end

// state 4: Calculate Matrxi Multiplication
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin 
        out4_valid <= 'd0; 
        out4_count <= 'd0; 
        end
    else begin
        out4_valid <= out3_valid; 
        out4_count <= out3_count;
        out4_r_calc <= out3_R11 - out3_G50 - out3_B50 + 512;
        out4_g_calc <= -out3_R50 + out3_G11 - out3_B50 + 512;
        out4_b_calc <= -out3_R50 - out3_G50 + out3_B11 + 512;
    end
end

// state 5: Output
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_valid <= 'd0; 
        r_out <= 'd0;
        g_out <= 'd0; 
        b_out <= 'd0;
    end else begin
        out_valid <= out4_valid;
        r_out <= out4_valid ? final_r : 0;
        g_out <= out4_valid ? final_g : 0;
        b_out <= out4_valid ? final_b : 0;
    end
end

endmodule


// LUT Mult
module Mult_LUT1 (
    input  [11:0] in,
    input  [8:0] w,
    output reg [20:0] out
);
    always @(*) begin
        if (w == 256)      out = {in, 8'b0};
        else if (w == 171) out = {in, 7'b0} + {in, 5'b0} + {in, 3'b0} + {in, 1'b0} + in;
        else if (w == 85)  out = {in, 6'b0} + {in, 4'b0} + {in, 2'b0} + in;
        else               out = 0;
    end
endmodule

module Mult_LUT2 (
    input  [21:0] in,
    input  [8:0] w,
    output reg [30:0] out
);
    always @(*) begin
        if (w == 256)      out = {in, 8'b0};
        else if (w == 171) out = {in, 7'b0} + {in, 5'b0} + {in, 3'b0} + {in, 1'b0} + in;
        else if (w == 85)  out = {in, 6'b0} + {in, 4'b0} + {in, 2'b0} + in;
        else               out = 0;
    end
endmodule


module Calc_Median (
    input  [11:0] a, b, c, d,
    output [11:0] med
);

// Stage 1
wire [11:0] ab_min = (a < b) ? a : b;
wire [11:0] ab_max = (a < b) ? b : a;
wire [11:0] cd_min = (c < d) ? c : d;
wire [11:0] cd_max = (c < d) ? d : c;

// Stage 2
wire [11:0] low_min  = (ab_min < cd_min) ? ab_min : cd_min;
wire [11:0] mid1     = (ab_min < cd_min) ? cd_min : ab_min;
wire [11:0] mid2     = (ab_max < cd_max) ? ab_max : cd_max;
wire [11:0] high_max = (ab_max < cd_max) ? cd_max : ab_max;

// Stage 3
wire [12:0] mid_sum = {1'b0, mid1} + {1'b0, mid2};
assign med = mid_sum >> 1;

endmodule