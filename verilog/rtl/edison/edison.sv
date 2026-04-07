module edison #( // Clean for synthesis
    parameter BIT_WIDTH = 12, // For digital readings of light in ADC
    parameter BCD_WIDTH = 4, // For each digit under BCD form in Lux Converter and 7-Segment
    parameter SSD_WIDTH = 8, // For each eight of 7-Segment Display
    parameter HOLD_MAX = 10, // Time requirement for button hold and register wait
    parameter AVG_WINDOW = 16, // The number of samples to average over in Light Processing
    parameter CLK_FREQ = 1_000_000, // Clock frequency for Morse Decoder
    parameter DOT_MAX = 200, // Time duration for Morse Code dot (<= 20) and dash (> 20)
    parameter GAP_MAX = 300, // Time duration for Morse Code short gap (<= 60) and long gap (>= 60)
    parameter SPACE_MAX = 500
)(
    // Analog Inputs
    input logic clk, nrst,
    input logic push_button,
    input logic blank_button,
    input logic comp_in,
    
    // Display Outputs
    output logic [SSD_WIDTH-1:0] led_out, // Unified 8-bit LED bar
    output logic [SSD_WIDTH-1:0] ss7, ss6, ss5, ss4, ss3, ss2, ss1, ss0
);
    // Internal Interconnects
    logic start, calibrate, seg_mode;
    logic [BIT_WIDTH-1:0] dac_out, adc_out, light_diff;
    logic data_ready, char_ready, sah_en, light_on;
    logic [7:0] ascii_char;
    logic [BCD_WIDTH-1:0] seg_ones, seg_tens, seg_hundreds, seg_thousands;

    // Module Instantiations (Explicit Mapping)
    // Button Debouncer/Logic
    soc_button #(HOLD_MAX) u_button (
        .clk(clk), .nrst(nrst),
        .push_button(push_button),
        .blank_button(blank_button),
        .start(start),
        .calibrate(calibrate),
        .seg_mode(seg_mode)
    );

    // ADC Controller
    sar_adc_controller #(BIT_WIDTH, HOLD_MAX) u_adc (
        .clk(clk), .nrst(nrst),
        .comp_in(comp_in),
        .start(start),
        .sah_en(sah_en),
        .dac_out(dac_out),
        .adc_out(adc_out),
        .data_ready(data_ready)
    );

    // Digital Signal Processing for Light Data
    light_processor #(BIT_WIDTH, AVG_WINDOW, 50) u_processor (
        .clk(clk), .nrst(nrst),
        .adc_out(adc_out),
        .data_ready(data_ready),
        .calibrate(calibrate),
        .light_diff(light_diff),
        .light_on(light_on)
    );

    // LED Bar Driver
    led_bar_driver u_led (
        .clk(clk), .nrst(nrst),
        .light_diff(light_diff), 
        .led(led_out) 
    );

    // Morse Code Logic
    morse_decoder #(CLK_FREQ, 10, DOT_MAX, GAP_MAX, SPACE_MAX) u_decoder (
        .clk(clk), .nrst(nrst),
        .start(start),
        .light_on(light_on),
        .char_ready(char_ready),
        .ascii_char(ascii_char)
    );

    // BCD Logic for Lux
    lux_converter #(BIT_WIDTH, BCD_WIDTH, AVG_WINDOW) u_converter (
        .clk(clk), .nrst(nrst),
        .adc_out(adc_out),
        .data_ready(data_ready),
        .seg_ones(seg_ones),
        .seg_tens(seg_tens),
        .seg_hundreds(seg_hundreds),
        .seg_thousands(seg_thousands)
    );

    // Seven Segment Display Controller
    seven_segment_display #(BIT_WIDTH, BCD_WIDTH, SSD_WIDTH) u_seven (
        .clk(clk), .nrst(nrst),
        .seg_mode(seg_mode),
        .seg_ones(seg_ones),
        .seg_tens(seg_tens),
        .seg_hundreds(seg_hundreds),
        .seg_thousands(seg_thousands),
        .char_ready(char_ready),
        .ascii_char(ascii_char),
        .ss0(ss0), .ss1(ss1), .ss2(ss2), .ss3(ss3),
        .ss4(ss4), .ss5(ss5), .ss6(ss6), .ss7(ss7)
    );
endmodule