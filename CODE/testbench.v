`timescale 1ns / 1ps

module tb_project;

    // Khai báo các tín hi?u k?t n?i v?i module
    reg [0:511] message;
    reg clk;
    reg reset;
    wire ready;
    wire [255:0] result;

    // Các bi?n dùng ?? x? lý File I/O
    integer fd_in, fd_out; 
    integer scan_status;

    // Instantiate module c?n test (Device Under Test - DUT)
    project uut (
        .message(message),
        .clk(clk),
        .reset(reset),
        .ready(ready),
        .result(result)
    );

    // T?o xung clock v?i chu k? 10ns
    always #5 clk = ~clk;

    initial begin
        // 1. M? file ?? ??c và ghi
        // ??m b?o file "input.txt" n?m cùng th? m?c v?i project/file mô ph?ng c?a b?n
        fd_in = $fopen("input.txt", "r");
        
        if (fd_in == 0) begin
            $display("L?I: Không th? m? file input.txt. Vui lòng ki?m tra l?i ???ng d?n!");
            $finish;
        end
        
        fd_out = $fopen("output.txt", "w");

        // Kh?i t?o tr?ng thái ban ??u
        clk = 0;
        reset = 1;
        message = 512'b0;

        // ??i 20ns r?i nh? reset ?? h? th?ng ?n ??nh
        #20;
        reset = 0;

        $display("--- Bat dau qua trinh doc file va mo phong ---");

        // 2. ??c l?n l??t t?ng dòng cho ??n khi k?t thúc file (End Of File)
        while (!$feof(fd_in)) begin
            // ??c m?t chu?i Hex t? file và gán vào bi?n message
            scan_status = $fscanf(fd_in, "%h\n", message);
            
            // N?u ??c thành công 1 giá tr?
            if (scan_status == 1) begin
                $display("Dang xu ly message: %h...", message[0:127]); // In ra 1 ph?n ?? theo dõi
                
                // C?p xung reset ?? module b?t ??u b?m block m?i
                reset = 1; 
                #10; 
                reset = 0;
                
                // Ch? ??n khi c? ready b?t lên báo hi?u b?m xong
                wait(ready == 1'b1);
                #10; // ??i thêm 1 chu k? ?? d? li?u xu?t ra ?n ??nh
                
                // Ghi k?t qu? 256-bit d?ng Hex vào file output.txt
                $fdisplay(fd_out, "%h", result);
            end
        end

        // 3. ?óng file và k?t thúc mô ph?ng
        $display("--- Hoan thanh! Kiem tra ket qua tai file output.txt ---");
        $fclose(fd_in);
        $fclose(fd_out);
        
        #50;
        $finish;
    end

endmodule