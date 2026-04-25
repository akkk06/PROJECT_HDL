module control ( input clk, 
					  input reset, 
					  input [7:0] datain, 
					  input datavalid, 
					  input lastbyte, 
					  input core_ready, 
					  output reg readydata, 
					  output wire [0:511] block, 
					  output reg core_reset,
					  output reg done );

	localparam IDLE      = 3'd0,
				  RCV_DATA  = 3'd1,
              PAD_80    = 3'd2,
              PAD_00    = 3'd3,
              PAD_LEN   = 3'd4,
              WAIT_CORE = 3'd5,
              FINISH    = 3'd6,
		LOAD_CORE = 3'd7;
	reg [2:0] state, next_state, return_state;
	reg [63:0] totalbit;
	reg [5:0]  bytecnt;
	reg [0:511] buffer;
	assign block = buffer;
	
	always @(posedge clk or posedge reset) begin
		if (reset) state <= IDLE;
		else state <= next_state;
	end
	
	always @(*) begin
		next_state = state;
		readydata = 1'b0;
		core_reset = 1'b0;
		done = 1'b0;
		
		case (state)
			IDLE: begin
				readydata = 1'b0;
				if (datavalid) next_state = RCV_DATA;
			end
			
			RCV_DATA: begin
            readydata = 1'b1;
            if (datavalid) begin
					if (bytecnt == 6'd63) begin
                   next_state = LOAD_CORE;
                   if (lastbyte) return_state = PAD_80;
                   else return_state = RCV_DATA;
               end 
					else if (lastbyte) begin
                   next_state = PAD_80;
					end
            end
         end

         PAD_80: begin 
				if (bytecnt == 6'd63) begin
					next_state = LOAD_CORE;
               return_state = PAD_00;
            end 
				else begin
               next_state = PAD_00;
            end
         end

         PAD_00: begin 
             if (bytecnt == 6'd63) begin
                next_state = LOAD_CORE;
                return_state = PAD_00;
             end 
				 else if (bytecnt == 6'd55) begin
                next_state = PAD_LEN;
             end
         end

         PAD_LEN: begin
				 if (bytecnt == 6'd63) begin
					 next_state = LOAD_CORE;
                return_state = FINISH; 
             end
         end

			LOAD_CORE: begin
             readydata = 1'b0;
             core_reset = 1'b1; 
             next_state = WAIT_CORE; 
         end

         WAIT_CORE: begin
             readydata = 1'b0;
             core_reset = 1'b0; 
             if (core_ready) begin
					next_state = return_state; 
             end
         end

         FINISH: begin
             done = 1'b1;
         end
        endcase
    end

    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            totalbit <= 64'd0;
            bytecnt <= 6'd0;
            buffer <= 512'b0;
            //block <= 512'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (datavalid) begin
                        buffer[bytecnt*8 +: 8] <= datain;
                        totalbit <= totalbit + 8;
                        bytecnt <= bytecnt + 1;
                    end
                end

                RCV_DATA: begin
                    if (datavalid) begin
                        buffer[bytecnt*8 +: 8] <= datain;
                        totalbit <= totalbit + 8;
                        bytecnt <= bytecnt + 1;
                    end
                end

                PAD_80: begin
                    buffer[bytecnt*8 +: 8] <= 8'h80;
                    bytecnt <= bytecnt + 1;
                end

                PAD_00: begin
                    buffer[bytecnt*8 +: 8] <= 8'h00;
                    bytecnt <= bytecnt + 1;
                end

                PAD_LEN: begin
                    case (bytecnt)
                        6'd56: buffer[448 +: 8] <= totalbit[56 +: 8];
                        6'd57: buffer[456 +: 8] <= totalbit[48 +: 8];
                        6'd58: buffer[464 +: 8] <= totalbit[40 +: 8];
                        6'd59: buffer[472 +: 8] <= totalbit[32 +: 8];
                        6'd60: buffer[480 +: 8] <= totalbit[24 +: 8];
                        6'd61: buffer[488 +: 8] <= totalbit[16 +: 8];
                        6'd62: buffer[496 +: 8] <= totalbit[8  +: 8];
                        6'd63: buffer[504 +: 8] <= totalbit[0  +: 8];
                    endcase
                    bytecnt <= bytecnt + 1;
                end

                WAIT_CORE: begin
                    //block <= buffer; 
                    if (core_ready) begin
                        bytecnt <= 6'd0; 
                        buffer <= 512'b0; 
                    end
                end
            endcase
        end
    end
	
endmodule
