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
    logic [6:0] bit_counter; // Counts up to 71
    logic [3:0] clk_counter;
    logic shift_rise, shift_fall;
    
    // Clock Divider for Serial Clock
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) begin
            clk_counter <= 0;
            shift_clock <= 0;
        end else begin
            if(clk_counter == (CLK_DIV / 2 - 1)) begin
                clk_counter <= 0;
                shift_clock <= ~shift_clock;
            end else begin
                clk_counter <= clk_counter + 1;
            end
        end
    end

    edge_detector shift_edge (
        .clk(clk), .nrst(nrst),
        .signal_in(shift_clock),
        .rising_edge(shift_rise),
        .falling_edge(shift_fall)
    );

    // Synchronous Shift Logic
    always_ff @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            shift_register <= '0;
            bit_counter <= 0;
            seri_ready <= 1;
            mosi <= 0;
        end else if(shift_rise) begin // Update logic only on system-clock aligned edge
            if(bit_counter == SPI_WIDTH - 1) begin
                shift_register <= flat_data; // Capture fresh data
                bit_counter <= 0;
                seri_ready <= 1; // Latch signal
                mosi <= flat_data[SPI_WIDTH-1]; // Prepare first bit for next cycle
            end else begin
                seri_ready <= 0;
                mosi <= shift_register[SPI_WIDTH-1];
                shift_register <= {shift_register[SPI_WIDTH-2:0], 1'b0};
                bit_counter <= bit_counter + 1;
            end
        end
    end
endmodule
