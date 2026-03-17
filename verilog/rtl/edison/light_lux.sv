module lux_converter#(
    parameter BIT_WIDTH = 12,
    parameter AVG_WINDOW = 16 // How many ADC samples are combined to create a single Moving - Must be a power of 2
)(
    input logic clk,
    input logic nrst,
    input logic [BIT_WIDTH-1:0] adc_out, // Raw 12-bit value (voltage reading)
    input logic data_ready,
    output logic [3:0] seg_ones, // Decimal 1s place
    output logic [3:0] seg_tens, // Decimal 10s place
    output logic [3:0] seg_hundreds, // Decimal 100s place
    output logic [3:0] seg_thousands // Decimal 1000s place
);
    logic [BIT_WIDTH+3:0] sum_acc;
    logic [3:0] sample_num;
    logic [BIT_WIDTH-1:0] avg_acc;
    logic [BIT_WIDTH+11:0] lux_value; // 23-bit to prevent overflow during the multiplication step (312!)
    logic [BIT_WIDTH+1:0] lux_display; // Lux value after shift

    // Moving Average Filter (same method implemented in Light Processor)
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) begin
            avg_acc <= '0;
            sample_num <= '0;
            sum_acc <= '0;
        end else if(data_ready) begin
            if(sample_num == 4'(AVG_WINDOW - 1)) begin
                avg_acc <= BIT_WIDTH'(sum_acc >> 4); // Divide by 16 (truncate 16-bit shift result to 12 bits)
                sum_acc <= {4'b0, adc_out}; // Reset with current sample
                sample_num <= '0;
            end else begin
                sum_acc <= sum_acc + {4'b0, adc_out}; // Zero-extend 12-bit adc_out to 16-bit for the addition
                sample_num <= sample_num + 1;
            end
        end
    end

    always_comb begin
        // Assuming 4095 corresponds to 9999 Lux max
        // Lux = ADC * [V / (4095 * R * S)]
        // In schematics, set power supply 3.3V, photodiode sensivity 0.05µA/Lux, and thus feedback resistor 6.8kΩ
        // Therefore, Lux = ADC * 2.37 = ADC * (K / 2^Shift) = (ADC * K) >> Shift
        lux_value = 24'(avg_acc) * 24'd312;
        lux_display = 14'(lux_value >> 7); // 312 / 2^7 = 2.44
        // Binary to BCD (Binary Coded Decimal) or Decimal Split
        // Cast the 32-bit integer result to 4 bits to satisfy the linter
        seg_thousands = 4'((32'(lux_display) / 1000) % 10);
        seg_hundreds = 4'((32'(lux_display) / 100) % 10);
        seg_tens = 4'((32'(lux_display) / 10) % 10);
        seg_ones = 4'(32'(lux_display) % 10);
    end
endmodule