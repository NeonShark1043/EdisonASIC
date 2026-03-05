module seven_segment_decoder (
    input  logic [7:0] bin,
    output logic [6:0] seg
);

always_comb begin
    case (bin)
        8'd0:  seg = 7'b0111111; // 0
        8'd1:  seg = 7'b0000110; // 1
        8'd2:  seg = 7'b1011011; // 2
        8'd3:  seg = 7'b1001111; // 3
        8'd4:  seg = 7'b1100110; // 4
        8'd5:  seg = 7'b1101101; // 5
        8'd6:  seg = 7'b1111101; // 6
        8'd7:  seg = 7'b0000111; // 7
        8'd8:  seg = 7'b1111111; // 8
        8'd9:  seg = 7'b1101111; // 9
        8'd10: seg = 7'b1110111; // A
        8'd11: seg = 7'b1111100; // B
        8'd12: seg = 7'b0111001; // C
        8'd13: seg = 7'b1011110; // D
        8'd14: seg = 7'b1111001; // E
        8'd15: seg = 7'b1110001; // F
        8'd16: seg = 7'b0111110; // G
        8'd17: seg = 7'b1110100; // H
        8'd18: seg = 7'b0110000; // I
        8'd19: seg = 7'b0011110; // J
        8'd20: seg = 7'b1110101; // K
        8'd21: seg = 7'b0111000; // L
        8'd22: seg = 7'b0010101; // M 
        8'd23: seg = 7'b0110111; // N
        8'd24: seg = 7'b0111111; // O
        8'd25: seg = 7'b1110011; // P
        8'd26: seg = 7'b1100111; // Q
        8'd27: seg = 7'b0110011; // R
        8'd28: seg = 7'b1101101; // S
        8'd29: seg = 7'b1111000; // T
        8'd30: seg = 7'b0111110; // U
        8'd31: seg = 7'b0101110; // V
        8'd32: seg = 7'b0101010; // W 
        8'd33: seg = 7'b1110110; // X 
        8'd34: seg = 7'b1101110; // Y
        8'd35: seg = 7'b1001011; // Z 
        default: seg = 7'b1010011; // ?
    endcase
end
endmodule
