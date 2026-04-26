module control ( 
    input clk, 
    input reset, 
    input [7:0] datain, 
    input datavalid, 
    input lastbyte, 
    input core_ready, 
    output reg readydata, 
    output wire [0:511] block, 
    output reg core_reset,
    output reg done 
);

    // ??nh ngh?a các tr?ng thái c?a FSM
    localparam IDLE      = 3'd0,
               RCV_DATA  = 3'd1,
               PAD_80    = 3'd2,
               PAD_00    = 3'd3,
               PAD_LEN   = 3'd4,
               WAIT_CORE = 3'd5,
               FINISH    = 3'd6,
               LOAD_CORE = 3'd7;

    reg [2:0]  state, next_state, return_state;
    reg [63:0] totalbit;
    reg [5:0]  bytecnt;
    
    // Khai báo m?ng 2D 64 bytes thay vì m?ng 1D 512 bit ?? tránh Quartus t?ng h?p ng??c Endianness
    (* ramstyle = "logic" *) reg [7:0] buffer_arr [0:63];
    integer i;

    // Ép Quartus ph?i n?i dây tu?n t? t? Byte 0 ??n Byte 63 m?t cách t?nh (Static Explicit Concatenation)
    assign block = {buffer_arr[0], buffer_arr[1], buffer_arr[2], buffer_arr[3], 
                    buffer_arr[4], buffer_arr[5], buffer_arr[6], buffer_arr[7], 
                    buffer_arr[8], buffer_arr[9], buffer_arr[10], buffer_arr[11], 
                    buffer_arr[12], buffer_arr[13], buffer_arr[14], buffer_arr[15], 
                    buffer_arr[16], buffer_arr[17], buffer_arr[18], buffer_arr[19], 
                    buffer_arr[20], buffer_arr[21], buffer_arr[22], buffer_arr[23], 
                    buffer_arr[24], buffer_arr[25], buffer_arr[26], buffer_arr[27], 
                    buffer_arr[28], buffer_arr[29], buffer_arr[30], buffer_arr[31],
                    buffer_arr[32], buffer_arr[33], buffer_arr[34], buffer_arr[35], 
                    buffer_arr[36], buffer_arr[37], buffer_arr[38], buffer_arr[39], 
                    buffer_arr[40], buffer_arr[41], buffer_arr[42], buffer_arr[43], 
                    buffer_arr[44], buffer_arr[45], buffer_arr[46], buffer_arr[47],
                    buffer_arr[48], buffer_arr[49], buffer_arr[50], buffer_arr[51], 
                    buffer_arr[52], buffer_arr[53], buffer_arr[54], buffer_arr[55], 
                    buffer_arr[56], buffer_arr[57], buffer_arr[58], buffer_arr[59], 
                    buffer_arr[60], buffer_arr[61], buffer_arr[62], buffer_arr[63]};

    // 1. Kh?i ?i?u khi?n tr?ng thái (Sequential Logic)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            return_state <= IDLE;
        end else begin
            state <= next_state;
            
            if (state == RCV_DATA && datavalid && bytecnt == 6'd63) begin
                if (lastbyte) return_state <= PAD_80;
                else return_state <= RCV_DATA;
            end 
            else if (state == PAD_80 && bytecnt == 6'd63) return_state <= PAD_00;
            else if (state == PAD_00 && bytecnt == 6'd63) return_state <= PAD_00;
            else if (state == PAD_LEN && bytecnt == 6'd63) return_state <= FINISH;
        end
    end

    // 2. Kh?i chuy?n tr?ng thái ti?p theo (Combinational Logic)
    always @(*) begin
        next_state = state;
        readydata = 1'b0;
        done = 1'b0;

        case (state)
            IDLE:      if (datavalid) next_state = RCV_DATA;
            RCV_DATA: begin
                readydata = 1'b1;
                if (datavalid) begin
                    if (bytecnt == 6'd63) next_state = LOAD_CORE;
                    else if (lastbyte)    next_state = PAD_80;
                end
            end
            PAD_80:    if (bytecnt == 6'd63) next_state = LOAD_CORE; else next_state = PAD_00;
            PAD_00: begin 
                if (bytecnt == 6'd63)      next_state = LOAD_CORE;
                else if (bytecnt == 6'd55) next_state = PAD_LEN;
            end
            PAD_LEN:   if (bytecnt == 6'd63) next_state = LOAD_CORE;
            LOAD_CORE: next_state = WAIT_CORE;
            WAIT_CORE: if (core_ready) next_state = return_state;
            FINISH:    done = 1'b1;
            default:   next_state = IDLE;
        endcase
    end

    // 3. Kh?i t?o tín hi?u core_reset ??ng b?
    always @(posedge clk or posedge reset) begin
        if (reset) core_reset <= 1'b0;
        else begin
            if (next_state == LOAD_CORE) core_reset <= 1'b1;
            else                         core_reset <= 1'b0;
        end
    end

    // 4. Kh?i x? lý d? li?u (Datapath)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            totalbit <= 64'd0;
            bytecnt <= 6'd0;
            for (i = 0; i < 64; i = i + 1) buffer_arr[i] <= 8'h00;
        end else begin
            case (state)
                IDLE: begin
                    if (datavalid) begin
                        buffer_arr[bytecnt] <= datain;
                        totalbit <= totalbit + 8;
                        bytecnt <= bytecnt + 1;
                    end
                end

                RCV_DATA: begin
                    if (datavalid) begin
                        buffer_arr[bytecnt] <= datain;
                        totalbit <= totalbit + 8;
                        bytecnt <= bytecnt + 1;
                    end
                end

                PAD_80: begin
                    buffer_arr[bytecnt] <= 8'h80;
                    bytecnt <= bytecnt + 1;
                end

                PAD_00: begin
                    buffer_arr[bytecnt] <= 8'h00;
                    bytecnt <= bytecnt + 1;
                end

                PAD_LEN: begin
                    case (bytecnt)
                        6'd56: buffer_arr[56] <= totalbit[63:56];
                        6'd57: buffer_arr[57] <= totalbit[55:48];
                        6'd58: buffer_arr[58] <= totalbit[47:40];
                        6'd59: buffer_arr[59] <= totalbit[39:32];
                        6'd60: buffer_arr[60] <= totalbit[31:24];
                        6'd61: buffer_arr[61] <= totalbit[23:16];
                        6'd62: buffer_arr[62] <= totalbit[15:8];
                        6'd63: buffer_arr[63] <= totalbit[7:0];
                    endcase
                    bytecnt <= bytecnt + 1;
                end

                WAIT_CORE: begin
                    if (core_ready) begin
                        bytecnt <= 6'd0;
                        for (i = 0; i < 64; i = i + 1) buffer_arr[i] <= 8'h00;
                    end
                end
            endcase
        end
    end
endmodule
