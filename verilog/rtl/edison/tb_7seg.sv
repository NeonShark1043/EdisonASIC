module tb_seven_segment_decoder;
    reg [7:0] bin;       
    wire [6:0] seg;      
    seven_segment_decoder dut (
        .bin(bin),
        .seg(seg)
    );
    function [6:0] expected_seg(input [7:0] b);
        begin
            case (b)
                8'd0:  expected_seg = 7'b0111111;
                8'd1:  expected_seg = 7'b0000110;
                8'd2:  expected_seg = 7'b1011011;
                8'd3:  expected_seg = 7'b1001111;
                8'd4:  expected_seg = 7'b1100110;
                8'd5:  expected_seg = 7'b1101101;
                8'd6:  expected_seg = 7'b1111101;
                8'd7:  expected_seg = 7'b0000111;
                8'd8:  expected_seg = 7'b1111111;
                8'd9:  expected_seg = 7'b1101111;
                8'd10: expected_seg = 7'b1110111; // A
                8'd11: expected_seg = 7'b1111100; // B
                8'd12: expected_seg = 7'b0111001; // C
                8'd13: expected_seg = 7'b1011110; // D
                8'd14: expected_seg = 7'b1111001; // E
                8'd15: expected_seg = 7'b1110001; // F
                8'd16: expected_seg = 7'b0111110; // G
                8'd17: expected_seg = 7'b1110100; // H
                8'd18: expected_seg = 7'b0110000; // I
                8'd19: expected_seg = 7'b0011110; // J
                8'd20: expected_seg = 7'b1110101; // K
                8'd21: expected_seg = 7'b0111000; // L
                8'd22: expected_seg = 7'b0010101; // M
                8'd23: expected_seg = 7'b0110111; // N
                8'd24: expected_seg = 7'b0111111; // O
                8'd25: expected_seg = 7'b1110011; // P
                8'd26: expected_seg = 7'b1100111; // Q
                8'd27: expected_seg = 7'b0110011; // R
                8'd28: expected_seg = 7'b1101101; // S
                8'd29: expected_seg = 7'b1111000; // T
                8'd30: expected_seg = 7'b0111110; // U
                8'd31: expected_seg = 7'b0101110; // V
                8'd32: expected_seg = 7'b0101010; // W
                8'd33: expected_seg = 7'b1110110; // X
                8'd34: expected_seg = 7'b1101110; // Y
                8'd35: expected_seg = 7'b1001011; // Z
                default: expected_seg = 7'b1010011; // ?
            endcase
        end
    endfunction

    reg [6:0] exp;
    integer i;
    initial begin
        $display("==========================================");
        $display("   SEVEN SEGMENT DECODER TESTBENCH");
        $display("   Testing 0-9 + A-Z");
        $display("==========================================");
        $display(" bin | Expected  Actual | STATUS");
        $display("------------------------------------------");

        for (i = 0; i < 256; i = i + 1) begin
            bin = i[7:0];
            #1; 
            exp = expected_seg(bin);
            if (seg === exp)
                $display(" %2d  | 7'h%2h   7'h%2h  | PASS", i, exp, seg);
            else
                $display(" %2d  | 7'h%2h   7'h%2h  | FAIL", i, exp, seg);
        end
        $display("------------------------------------------");
        $display("TEST FINISHED");
        $finish;
    end

endmodule
