module spi_serializer #(
    parameter SPI_WIDTH = 72,
    parameter CLK_DIV = 4 // Clock divider for serial stability
)(
    input logic clk, nrst,
    input logic [SPI_WIDTH-1:0] flat_data, // led_out and ss0-ss7 - 8-bit each
    output logic mosi, // Data bitstream
    output logic shift_clock,
    output logic seri_ready // Active-low signal to latch the data at the end of data transfer
);
    logic [SPI_WIDTH-1:0] shift_register;
    logic [6:0] bit_count; // Counts 0 to 71
    logic [3:0] clk_count;
    
    // Clock Divider for Serial Clock
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) begin
            clk_count <= 0;
            shift_clock <= 0;
        end else begin
            if(clk_count == (CLK_DIV/2 - 1)) begin
                clk_count <= 0;
                shift_clock <= ~shift_clock;
            end else begin
                clk_count <= clk_count + 1;
            end
        end
    end

    // Shift Logic
    always_ff @(posedge shift_clock or negedge nrst) begin
        if(!nrst) begin
            shift_register <= '0;
            bit_count <= 0;
            seri_ready <= 1;
            mosi <= 0;
        end else begin
            if(bit_count == SPI_WIDTH - 1) begin
                shift_register <= flat_data; // Capture flesh data and reset
                bit_count <= 0;
                seri_ready <= 1; // Latch pulse
            end else begin
                seri_ready <= 0;
                mosi <= shift_register[SPI_WIDTH-1]; // MSB first
                shift_register <= {shift_register[SPI_WIDTH-2:0], 1'b0};
                bit_count <= bit_count + 1;
            end
        end
    end
endmodule