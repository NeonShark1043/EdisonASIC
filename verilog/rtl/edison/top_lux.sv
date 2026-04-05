`timescale 1ns / 1ps
module top_lux #(
    parameter BIT_WIDTH  = 12,
    parameter BCD_WIDTH  = 4,
    parameter HOLD_MAX   = 10,
    parameter AVG_WINDOW = 16
)(
    input  logic clk,
    input  logic nrst,
    input  logic push_button,
    input  logic blank_button,
    input  logic comp_in,
    output logic start,
    output logic sah_en,
    output logic [BIT_WIDTH-1:0] dac_out,
    output logic [BIT_WIDTH-1:0] adc_out,
    output logic data_ready,
    output logic [BCD_WIDTH-1:0] seg_ones,
    output logic [BCD_WIDTH-1:0] seg_tens,
    output logic [BCD_WIDTH-1:0] seg_hundreds,
    output logic [BCD_WIDTH-1:0] seg_thousands
);

    logic calibrate, seg_mode;

    soc_button #(HOLD_MAX) u_button (.*);
    sar_adc_controller #(BIT_WIDTH, 4) u_adc (.*);
    lux_converter #(BIT_WIDTH, BCD_WIDTH, AVG_WINDOW) u_lux (.*);

endmodule
