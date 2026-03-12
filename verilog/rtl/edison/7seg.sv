`default_nettype none

module top (
  input  logic hz100, reset,
  input  logic [20:0] pb,
  output logic [7:0] left, right,
  output logic [7:0] ss7, ss6, ss5, ss4, ss3, ss2, ss1, ss0,
  output logic red, green, blue,

  // UART ports
  output logic [7:0] txdata,
  input  logic [7:0] rxdata,
  output logic txclk, rxclk,
  input  logic txready, rxready
);
    logic [7:0] digits [7:0];
    always_comb begin
    // Initialize all to blank
    for (int i = 0; i < 8; i++) begin
        digits[i] = 8'd127; 
    end
    
    // Now you can assign values to your array elements
    digits[7] = 8'd21; 
  end
  // Drive all 8 displays (concatenating DP bit 0 + 7-segment pattern)
  assign ss0 = {1'b0, seven_seg(digits[0])};
  assign ss1 = {1'b0, seven_seg(digits[1])};
  assign ss2 = {1'b0, seven_seg(digits[2])};
  assign ss3 = {1'b0, seven_seg(digits[3])};
  assign ss4 = {1'b0, seven_seg(digits[4])};
  assign ss5 = {1'b0, seven_seg(digits[5])};
  assign ss6 = {1'b0, seven_seg(digits[6])};
  assign ss7 = {1'b0, seven_seg(digits[7])};

  // Extended Decoder Function (Inside the module)
  function automatic [6:0] seven_seg(input [7:0] bin);
    case (bin)
      8'd0:  seven_seg = 7'b0111111;
      8'd1:  seven_seg = 7'b0000110;
      8'd2:  seven_seg = 7'b1011011;
      8'd3:  seven_seg = 7'b1001111;
      8'd4:  seven_seg = 7'b1100110;
      8'd5:  seven_seg = 7'b1101101;
      8'd6:  seven_seg = 7'b1111101;
      8'd7:  seven_seg = 7'b0000111;
      8'd8:  seven_seg = 7'b1111111;
      8'd9:  seven_seg = 7'b1101111;
      8'd10: seven_seg = 7'b1110111; // A
      8'd11: seven_seg = 7'b1111100; // B
      8'd12: seven_seg = 7'b0111001; // C
      8'd13: seven_seg = 7'b1011110; // D
      8'd14: seven_seg = 7'b1111001; // E
      8'd15: seven_seg = 7'b1110001; // F
      8'd16: seven_seg = 7'b0111110; // G
      8'd17: seven_seg = 7'b1110100; // H
      8'd18: seven_seg = 7'b0110000; // I
      8'd19: seven_seg = 7'b0011110; // J
      8'd20: seven_seg = 7'b1110101; // K
      8'd21: seven_seg = 7'b0111000; // L
      8'd22: seven_seg = 7'b0010101; // M
      8'd23: seven_seg = 7'b0110111; // N
      8'd24: seven_seg = 7'b0111111; // O
      8'd25: seven_seg = 7'b1110011; // P
      8'd26: seven_seg = 7'b1100111; // Q
      8'd27: seven_seg = 7'b0110011; // R
      8'd28: seven_seg = 7'b1101101; // S
      8'd29: seven_seg = 7'b1111000; // T
      8'd30: seven_seg = 7'b0111110; // U
      8'd31: seven_seg = 7'b0101110; // V
      8'd32: seven_seg = 7'b0101010; // W
      8'd33: seven_seg = 7'b1110111; // X
      8'd34: seven_seg = 7'b1101110; // Y
      8'd35: seven_seg = 7'b1001011; // Z
      default: seven_seg = 7'b0000000;
    endcase
  endfunction

endmodule