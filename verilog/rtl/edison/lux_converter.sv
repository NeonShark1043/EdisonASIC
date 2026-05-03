
module lux_converter #(
    parameter BIT_WIDTH = 12,
    parameter BCD_WIDTH = 4,
    parameter AVG_WINDOW = 16 // How many ADC samples are combined to create a single Moving - Must be a power of 2
)(
    input logic clk,
    input logic nrst,
    input logic [BIT_WIDTH-1:0] adc_out, // Raw 12-bit value (voltage reading)
    input logic data_ready,
    output logic [BCD_WIDTH-1:0] seg_ones, // Decimal 1s place
    output logic [BCD_WIDTH-1:0] seg_tens, // Decimal 10s place
    output logic [BCD_WIDTH-1:0] seg_hundreds, // Decimal 100s place
    output logic [BCD_WIDTH-1:0] seg_thousands // Decimal 1000s place
);
    logic [BIT_WIDTH+3:0] sum_acc;
    logic [BCD_WIDTH-1:0] sample_num;
    logic [BIT_WIDTH-1:0] avg_acc;
    logic [23:0] lux_value; // 24-bit to prevent overflow during the multiplication step (312!)
    logic [BIT_WIDTH+1:0] lux_display; // Lux value after shift
    logic [BIT_WIDTH+3:0] bcd_register;

    // Block Average Window
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
        /* Assuming 4095 corresponds to 9999 Lux max
        Lux = ADC * [V / (4095 * R * S)]
        In schematics, set power supply 3.3V, photodiode sensivity 0.05µA/Lux, and thus feedback resistor 6.8kΩ
        Therefore, Lux = ADC * 2.37 = ADC * (K / 2^Shift) = (ADC * K) >> Shift*/
        lux_value = (24'(avg_acc) << 9) + (24'(avg_acc) << 6) + (24'(avg_acc) << 5) + (24'(avg_acc) << 4) + 24'(avg_acc);
        lux_display = 14'(lux_value >> 8);
    end

    always_comb begin
        bcd_register = '0;
        for(int i = 13; i >= 0; i = i - 1) begin
            // Check each BCD nibble, add 3 if >= 5
            if(bcd_register[3:0] >= 5) bcd_register[3:0] = bcd_register[3:0] + 3;
            if(bcd_register[7:4] >= 5) bcd_register[7:4] = bcd_register[7:4] + 3;
            if(bcd_register[11:8] >= 5) bcd_register[11:8] = bcd_register[11:8] + 3;
            if(bcd_register[15:12] >= 5) bcd_register[15:12] = bcd_register[15:12] + 3;
            // Shift left by 1 bit to pull in the next bit of lux_display
            bcd_register = {bcd_register[14:0], lux_display[i]};
        end

        seg_thousands = bcd_register[15:12];
        seg_hundreds = bcd_register[11:8];
        seg_tens = bcd_register[7:4];
        seg_ones = bcd_register[3:0];
    end
endmodule
