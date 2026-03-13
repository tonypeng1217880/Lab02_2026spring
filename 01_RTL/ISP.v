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
localparam IDLE       = 2'd0;
localparam LOAD_PARAM = 2'd1;
localparam DATA_IN    = 2'd2; // 原本的 STREAM_BLC，改為收資料狀態
localparam DATA_OUT   = 2'd3; // 新增輸出狀態，確保不重疊

reg [1:0] curr_state, next_state; 
reg [7:0] out_cnt;
reg [7:0] param_cnt;                  
reg [3:0] row_cnt, col_cnt;
reg [11:0] blc_buffer [0:255];  
reg [6:0] b_offset;
reg [11:0] gain_mem [0:143];
reg [11:0] blc_in_r;
reg        blc_in_vld_r;

reg [11:0] blc_out_r;
reg        blc_out_vld_r;

always @(*) begin
    next_state=curr_state;
    case(curr_state) 

        IDLE: begin
            if (param_valid) next_state = LOAD_PARAM;
            else if (in_valid) next_state = DATA_IN;
        end

        LOAD_PARAM: begin
            if (param_cnt==8'd143) next_state = IDLE;
        end

        DATA_IN: begin
            // 等 256 個像素收完 (或是 row_cnt/col_cnt 數完)
            if (row_cnt == 4'd15 && col_cnt == 4'd15) next_state = DATA_OUT;
        end

        DATA_OUT: begin
            // 輸出 256 個週期後回 IDLE
            if (out_cnt == 8'd255) next_state = IDLE;
        end

        default: begin
            next_state = IDLE;
        end
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        curr_state <= IDLE;
    else
        curr_state <= next_state;
end


reg [7:0] pix_cnt;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        param_cnt <= 8'd0;
    end
    else if (curr_state != LOAD_PARAM) begin
        param_cnt <= 8'd0;
    end
    else if (param_valid) begin
        gain_mem[param_cnt] <= param_gain;
        param_cnt <= param_cnt + 8'd1;
    end
end
//------------------------------
//   BLC 
//------------------------------



// 1. 座標計數器：追蹤目前輸入像素在 16x16 矩陣中的位置
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        row_cnt <= 4'd0;
        col_cnt <= 4'd0;
    end
    else if (in_valid) begin
        if (col_cnt == 4'd15) begin
            col_cnt <= 4'd0;
            row_cnt <= row_cnt + 4'd1;
        end
        else begin
            col_cnt <= col_cnt + 4'd1;
        end
    end
    else if (curr_state == IDLE) begin // 每一幀開始前清零
        row_cnt <= 4'd0;
        col_cnt <= 4'd0;
    end
end

// 2. 顏色通道判斷與 Offset 選擇
always @(*) begin
    case ({row_cnt[0], col_cnt[0]})
        2'b00: b_offset = 7'd64; // R (Even row, Even col)
        2'b01: b_offset = 7'd48; // Gr (Even row, Odd col)
        2'b10: b_offset = 7'd52; // Gb (Odd row, Even col)
        2'b11: b_offset = 7'd72; // B (Odd row, Odd col)
        default: b_offset = 7'd0;
    endcase
end

// 3. 減法運算與數值截斷 (Saturation)
// 使用暫存器傳遞到下一階段 (Pipeline stage)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        blc_out_r <= 12'd0;
        blc_out_vld_r <= 1'b0;
    end
    else if (in_valid) begin
        blc_out_vld_r <= 1'b1;
        // 如果輸入小於 offset，結果須為 0 (max 運算)
        if (in > b_offset)
            blc_out_r <= in - b_offset;
        else
            blc_out_r <= 12'd0;
    end
    else begin
        blc_out_vld_r <= 1'b0;
        blc_out_r <= 12'd0;
    end
end




// 在 BLC 區塊新增寫入邏輯
always @(posedge clk) begin
    if (curr_state == DATA_IN && in_valid) begin
        // 使用 {row_cnt, col_cnt} 作為地址 (4-bit + 4-bit = 8-bit, 剛好 0~255)
        if (in > b_offset)
            blc_buffer[{row_cnt, col_cnt}] <= in - b_offset; 
        else
            blc_buffer[{row_cnt, col_cnt}] <= 12'd0; 
    end
end

// 在 Design 的最後部分加入輸出控制
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        out_valid <= 1'b0;
        {r_out, g_out, b_out} <= 36'd0;
        out_cnt <= 8'd0;
    end
    else if (next_state == DATA_OUT) begin // 使用 next_state 減少一週期延遲
        out_valid <= 1'b1;
        r_out <= blc_buffer[out_cnt];
        g_out <= blc_buffer[out_cnt];
        b_out <= blc_buffer[out_cnt];
        out_cnt <= out_cnt + 8'd1;
    end
    else begin
        out_valid <= 1'b0;
        {r_out, g_out, b_out} <= 36'd0; 
        out_cnt <= 8'd0;
    end
end


endmodule