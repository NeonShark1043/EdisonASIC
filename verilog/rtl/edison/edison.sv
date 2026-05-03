`default_nettype none
module edison(
`ifdef USE_POWER_PINS
    inout VPWR,
    inout VGND,
`endif
    input wire clk,
    input wire nrst,
    input wire enable, // always 1 when the design is powered
    input  wire [7:0] ui_in, // Dedicated inputs
    output wire [7:0] uo_out, // Dedicated outputs
    input  wire [7:0] uio_in, // IOs: Input path
    output wire [7:0] uio_out, // IOs: Output path
    output wire [7:0] uio_oe // IOs: Enable path (active high: 0=input, 1=output)
);
    // Unused pins
    wire _unused = &{enable, ui_in[7:3], uio_in, 1'b0}; // list inputs to prevent synthesis warnings
    assign uo_out[7:3] = 5'b00000;
    assign uio_out = 8'b00000000;
    assign uio_oe = 8'b00000000;

    top_module #(
        .BIT_WIDTH(12),
        .BCD_WIDTH(4),
        .SSD_WIDTH(8),
        .SPI_WIDTH(74),
        .HOLD_MAX(10),
        .AVG_WINDOW(16),
        .CLK_FREQ(1_000_000), 
        .DOT_MAX(200),
        .GAP_MAX(300),
        .SPACE_MAX(500)
    ) core_inst (
        .clk(clk),
        .nrst(nrst),
        .push_button(ui_in[0]),
        .blank_button(ui_in[1]),
        .comp_in(ui_in[2]),
        .mosi(uo_out[0]),
        .shift_clock(uo_out[1]),
        .seri_ready(uo_out[2])
    );
endmodule
