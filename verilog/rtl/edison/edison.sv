module edison #(
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
    input logic clk, nrst, // Switch from hz100 to clk (?)
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
    logic start, calibrate, seg_mode;
    logic [BIT_WIDTH-1:0] dac_out, adc_out, light_diff;
    logic data_ready, char_ready, sah_en, light_on;
    logic [SSD_WIDTH-1:0] ascii_char;
    logic [BCD_WIDTH-1:0] seg_ones, seg_tens, seg_hundreds, seg_thousands;
    logic [SSD_WIDTH-1:0] seg_digits [SSD_WIDTH-1:0];

    soc_button #(HOLD_MAX) u_button (.push_button(pb[0]), .blank_button(pb[1]), .*);
    sar_adc_controller #(BIT_WIDTH, HOLD_MAX) u_adc (.comp_in(pb[2]), .*);
    light_processor #(BIT_WIDTH, AVG_WINDOW, 50) u_processor (.*);
    led_bar_driver u_led (.led({left, right[1:0]}), .*); // Mapping 10 LEDs
    morse_decoder #(CLK_FREQ, 10, DOT_MAX, GAP_MAX, SPACE_MAX) u_decoder (.*);
    lux_converter #(BIT_WIDTH, BCD_WIDTH, AVG_WINDOW) u_converter (.*);
    seven_segment_display #(BIT_WIDTH, BCD_WIDTH, SSD_WIDTH) u_seven (.*);
endmodule
