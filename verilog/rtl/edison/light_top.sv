`timescale 1ns / 1ps
module edison_top #(
    parameter BIT_WIDTH = 12, // For digital readings of light in ADC
    parameter BCD_WIDTH = 4, // For each digit under BCD form in Lux Converter and 7-Segment
    parameter SSD_WIDTH = 8, // For each eight of 7-Segment Display
    parameter HOLD_MAX = 10, // Time requirement for button hold and register wait
    parameter AVG_WINDOW = 16, // The number of samples to average over in Light Processing
    parameter CLK_FREQ = 1_000_000, // Clock frequency for Morse Decoder
    parameter DOT_MAX = 20, // Time duration for Morse Code dot (<= 20) and dash (> 20)
    parameter GAP_MAX = 60, // Time duration for Morse Code short gap (<= 60) and long gap (>= 60)
    parameter SPACE_MAX = 140
)(
    input logic hz100, reset, // Switch from hz100 to clk (?)
    input logic [20:0] pb, // Physical Inputs => pb[0]: Push, pb[1]: Blank, pb[2]: Comp_in
    output logic [SSD_WIDTH-1:0] left, right, // Logic vectors hard-wired to physical LED
    output logic [SSD_WIDTH-1:0] ss7, ss6, ss5, ss4, ss3, ss2, ss1, ss0,
    output logic red, green, blue,

    // UART Ports
    output logic [SSD_WIDTH-1:0] txdata,
    input logic [SSD_WIDTH-1:0] rxdata,
    output logic txclk, rxclk,
    input logic txready, rxready
);
    // Internal Wires
    logic clk, nrst;
    logic start, calibrate, seg_mode;
    logic [BIT_WIDTH-1:0] dac_out, adc_out, light_diff;
    logic data_ready, char_ready, sah_en, light_on;
    logic [SSD_WIDTH-1:0] ascii_char;
    logic [BCD_WIDTH-1:0] seg_ones, seg_tens, seg_hundreds, seg_thousands;
    logic [SSD_WIDTH-1:0] seg_digits [SSD_WIDTH-1:0];

    soc_button #(HOLD_MAX) u_button (.push_button(pb[0]), .blank_button(pb[1]), .*);
    sar_adc_controller #(BIT_WIDTH, HOLD_MAX) u_adc (.comp_in(pb[2]), .*);
    light_processor #(BIT_WIDTH, AVG_WINDOW, 50) u_processor (.*);
    led u_led (.n_rst(nrst), .led({left, right[1:0]}), .*); // Mapping 10 LEDs
    morse_decoder #(CLK_FREQ, 10, DOT_MAX, GAP_MAX, SPACE_MAX) u_decoder (.*);
    lux_converter #(BIT_WIDTH, BCD_WIDTH, AVG_WINDOW) u_converter (.*);

    // assign txdata = ascii_char; Not so sure about this
    // assign txready = char_ready;

    assign clk = hz100;
    assign nrst = !reset;

    logic [SSD_WIDTH-1:0] scroll_buffer [5:0]; // Buffer from ss1 through ss6 in Morse Mode
    logic [SSD_WIDTH-1:0] num_buffer; // Buffer for numbers in Morse Mode
    // Scrolling Morse Logic - Move characters from right to left (ss0 to ss4)
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) begin
            for(int i = 0; i < 6; i++) scroll_buffer[i] <= 8'd32;
            num_buffer <= 8'd127;
        end else if(char_ready) begin
            if(ascii_char >= 8'd48 && ascii_char <= 8'd57) begin // Numerical Morse
                num_buffer <= ascii_char;
            end else begin // Character Morse
                scroll_buffer[5] <= scroll_buffer[4];
                scroll_buffer[4] <= scroll_buffer[3];
                scroll_buffer[3] <= scroll_buffer[2];
                scroll_buffer[2] <= scroll_buffer[1];
                scroll_buffer[1] <= scroll_buffer[0];
                scroll_buffer[0] <= ascii_char; // New character enters from rightmost
            end
        end
    end

    always_comb begin
        for(int i = 0; i < 8; i++) seg_digits[i] = 8'd32; // Default all to blank
        if(seg_mode == 0) begin // Lux (L) Mode (Static): Show "L" on left, value on right
            seg_digits[7] = 8'd76; // L
            // Add 48 to convert raw BCD (0-9) to ASCII ('0'-'9')
            seg_digits[3] = 8'd48 + {4'b0, seg_thousands};
            seg_digits[2] = 8'd48 + {4'b0, seg_hundreds};
            seg_digits[1] = 8'd48 + {4'b0, seg_tens};
            seg_digits[0] = 8'd48 + {4'b0, seg_ones};
        end else if(seg_mode == 1) begin // Morse (M) Mode (Dynamic): Show "M" on left, numbers on right, and scrolling characters from right to left
            seg_digits[7] = 8'd77; // M
            seg_digits[6] = scroll_buffer[5];
            seg_digits[5] = scroll_buffer[4];
            seg_digits[4] = scroll_buffer[3];
            seg_digits[3] = scroll_buffer[2];
            seg_digits[2] = scroll_buffer[1];
            seg_digits[1] = scroll_buffer[0];
            seg_digits[0] = num_buffer;
        end
    end

    // Drive Displays
    assign ss0 = {1'b0, seven_seg(seg_digits[0])};
    assign ss1 = {1'b0, seven_seg(seg_digits[1])};
    assign ss2 = {1'b0, seven_seg(seg_digits[2])};
    assign ss3 = {1'b0, seven_seg(seg_digits[3])};
    assign ss4 = {1'b0, seven_seg(seg_digits[4])};
    assign ss5 = {1'b0, seven_seg(seg_digits[5])};
    assign ss6 = {1'b0, seven_seg(seg_digits[6])};
    assign ss7 = {1'b0, seven_seg(seg_digits[7])};

    // Extended Decoder Function
    function automatic [6:0] seven_seg(input [7:0] alphanum);
        case(alphanum) // Modified for ASCII-compatible with Morse Decoder
            8'd48: seven_seg = 7'b0111111; // 0
            8'd49: seven_seg = 7'b0000110; // 1
            8'd50: seven_seg = 7'b1011011; // 2
            8'd51: seven_seg = 7'b1001111; // 3
            8'd52: seven_seg = 7'b1100110; // 4
            8'd53: seven_seg = 7'b1101101; // 5
            8'd54: seven_seg = 7'b1111101; // 6
            8'd55: seven_seg = 7'b0000111; // 7
            8'd56: seven_seg = 7'b1111111; // 8
            8'd57: seven_seg = 7'b1101111; // 9
            8'd65: seven_seg = 7'b1110111; // A
            8'd66: seven_seg = 7'b1111100; // B
            8'd67: seven_seg = 7'b0111001; // C
            8'd68: seven_seg = 7'b1011110; // D
            8'd69: seven_seg = 7'b1111001; // E
            8'd70: seven_seg = 7'b1110001; // F
            8'd71: seven_seg = 7'b0111101; // G
            8'd72: seven_seg = 7'b1110100; // H
            8'd73: seven_seg = 7'b0110000; // I
            8'd74: seven_seg = 7'b0011110; // J
            8'd75: seven_seg = 7'b1110101; // K
            8'd76: seven_seg = 7'b0111000; // L
            8'd77: seven_seg = 7'b0010101; // M
            8'd78: seven_seg = 7'b0110111; // N
            8'd79: seven_seg = 7'b0111111; // O
            8'd80: seven_seg = 7'b1110011; // P
            8'd81: seven_seg = 7'b1100111; // Q
            8'd82: seven_seg = 7'b0110011; // R
            8'd83: seven_seg = 7'b1101101; // S
            8'd84: seven_seg = 7'b1111000; // T
            8'd85: seven_seg = 7'b0111110; // U
            8'd86: seven_seg = 7'b0101110; // V
            8'd87: seven_seg = 7'b0101010; // W
            8'd88: seven_seg = 7'b1110110; // X
            8'd89: seven_seg = 7'b1101110; // Y
            8'd90: seven_seg = 7'b1001011; // Z
            8'd32: seven_seg = 7'b0000000; // Blankspace
            default: seven_seg = 7'b1010011; // ? - for NULL characters
        endcase
    endfunction
endmodule