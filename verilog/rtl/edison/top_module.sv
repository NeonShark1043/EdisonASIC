
module top_module #( // Clean for synthesis
    parameter BIT_WIDTH = 12, // For digital readings of light in ADC
    parameter BCD_WIDTH = 4, // For each digit under BCD form in Lux Converter and 7-Segment
    parameter SSD_WIDTH = 8, // For each eight of 7-Segment Display
    parameter SPI_WIDTH = 74, // For serializer takes in total bits of top outputs
    parameter HOLD_MAX = 10, // Time requirement for button hold and register wait
    parameter AVG_WINDOW = 16, // (2) The number of samples to average over in Light Processing
    parameter CLK_FREQ = 1_000_000, // (1_000_000) Clock frequency for Morse Decoder
    parameter DOT_MAX = 200, // Time duration for Morse Code dot (<= 2000 ms) and dash (> 2000)
    parameter GAP_MAX = 300, // Time duration for Morse Code short (<= 3000) and long gap (>= 3000)
    parameter SPACE_MAX = 500 // Time duration to signify a whitespace between Morse characters
)(    
    // Analog Inputs
    input logic clk, nrst,
    input logic push_button,
    input logic blank_button,
    input logic comp_in,
    // Display Outputs
    output logic mosi,
    output logic shift_clock,
    output logic seri_ready
);
    // Internal Interconnects
    logic start, calibrate, seg_mode;
    logic [BIT_WIDTH-1:0] dac_out, adc_out, light_diff;
    logic data_ready, char_ready, sah_en, light_on;
    logic [7:0] ascii_char;
    logic [BCD_WIDTH-1:0] seg_ones, seg_tens, seg_hundreds, seg_thousands;
    logic [9:0] led_out; // Unified 8-bit LED bar
    logic [SSD_WIDTH-1:0] ss[7:0]; // ss7-ss0 for Seven Segment Display
    logic [SPI_WIDTH-1:0] flat_data;

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
        .led_out(led_out) 
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
        .start(start), .calibrate(calibrate),
        .seg_mode(seg_mode),
        .seg_ones(seg_ones),
        .seg_tens(seg_tens),
        .seg_hundreds(seg_hundreds),
        .seg_thousands(seg_thousands),
        .char_ready(char_ready),
        .ascii_char(ascii_char),
        .ss0(ss[0]), .ss1(ss[1]), .ss2(ss[2]), .ss3(ss[3]),
        .ss4(ss[4]), .ss5(ss[5]), .ss6(ss[6]), .ss7(ss[7])
    );

    // Flatten data for serialization: [LEDs][ss7][ss6]...[ss0]
    assign flat_data = {led_out, ss[7], ss[6], ss[5], ss[4], ss[3], ss[2], ss[1], ss[0]};
    // SPI Serializer
    spi_serializer #(SPI_WIDTH, 4) u_spi (
        .clk(clk), .nrst(nrst),
        .flat_data(flat_data),
        .mosi(mosi),
        .shift_clock(shift_clock),
        .seri_ready(seri_ready)
    );
endmodule
