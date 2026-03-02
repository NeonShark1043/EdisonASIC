module seven_segment_decoder (
    input  [3:0] bin,        // 4-bit binary input
    output reg [6:0] seg     
);

always @(*) begin
    case (bin)

        // Numbers
        6'd0:  seg = 7'b1000000; // 0
        6'd1:  seg = 7'b1111001; // 1
        6'd2:  seg = 7'b0100100; // 2
        6'd3:  seg = 7'b0110000; // 3
        6'd4:  seg = 7'b0011001; // 4
        6'd5:  seg = 7'b0010010; // 5
        6'd6:  seg = 7'b0000010; // 6
        6'd7:  seg = 7'b1111000; // 7
        6'd8:  seg = 7'b0000000; // 8
        6'd9:  seg = 7'b0010000; // 9
        6'd10: seg = 7'b0001000; // A
        6'd11: seg = 7'b0000011; // B 
        6'd12: seg = 7'b1000110; // C
        6'd13: seg = 7'b0100001; // D 
        6'd14: seg = 7'b0000110; // E
        6'd15: seg = 7'b0001110; // F

        default: seg = 7'b1111111; // blank
    endcase
end

endmodule