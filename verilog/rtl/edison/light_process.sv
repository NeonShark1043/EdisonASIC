module light_processor #(
    parameter BIT_WIDTH = 12,
    parameter AVG_WINDOW = 16, // How many ADC samples are combined to create a single Moving - Must be a power of 2
    parameter HYSTERESIS_THRESHOLD = 50 // Buffer to prevent flickering
)(
    input logic clk,
    input logic nrst,
    input logic [BIT_WIDTH-1:0] adc_out, // Raw value from SAR ADC
    input logic data_ready, // Pulse from SAR ADC
    input logic calibrate, // Trigger to "lock in" the ambient light
    output logic [BIT_WIDTH-1:0] light_diff, // Light difference from thresholds
    output logic [BIT_WIDTH-1:0] light_led, // Light difference for PWM
    output logic light_on // Clean bit for Morse FSM
);

    // Internal Registers
    logic [BIT_WIDTH+3:0] avg_acc; // Accumulator for 16 samples
    logic [BIT_WIDTH-1:0] threshold_set; // Ambient baseline light level
    logic [BIT_WIDTH-1:0] filtered_val;
    logic [3:0] sample_num, hys_counter; // Acts as "waiting room" for light

    // Moving Average Filter
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) begin
            avg_acc <= '0;
            sample_num <= '0;
            filtered_val <= '0;
        end else if(data_ready) begin
            if(sample_num == 4'(AVG_WINDOW - 1)) begin
                filtered_val <= BIT_WIDTH'(avg_acc >> 4); // Divide by 16 (truncate 16-bit shift result to 12 bits)
                avg_acc <= {4'b0, adc_out}; // Reset with current sample
                sample_num <= '0;
            end else begin
                avg_acc <= avg_acc + {4'b0, adc_out}; // Zero-extend 12-bit adc_out to 16-bit for the addition
                sample_num <= sample_num + 1;
            end
        end
    end

    // Auto-Calibration
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) begin
            threshold_set <= '0;
        end else if(calibrate && data_ready) begin
            // Update the threshold with the current filtered average
            threshold_set <= filtered_val;
        end
    end

    // Difference Calculation - Calculates the light magnitude above baseline
    assign light_diff = (filtered_val > threshold_set) ? (filtered_val - threshold_set) : '0;
    assign light_led = (filtered_val > 100) ? (filtered_val - 100) : (100 - filtered_val); // might want to change "100" value for light_led choice

    // Hysteresis Debouncing (for light_on)
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) begin
            light_on <= 0;
            hys_counter <= '0;
        end else begin
            // If signal is significantly above threshold (where error margin is disregarded), increment hys_counter
            // When hys_counter hits the limit (8), that is when light turns on
            if(light_diff > BIT_WIDTH'(HYSTERESIS_THRESHOLD)) begin
                if(hys_counter < 4'd8) hys_counter <= hys_counter + 4'd1;
                else light_on <= 1;
            end
            // If signal drops (below hyst threshold or base + hyst threshold), immediately decrement
            else begin
                if(hys_counter > 4'd0) hys_counter <= hys_counter - 4'd2; // Steeper "drop-off" to punish fluctuations
                else light_on <= 0;
            end
        end
    end
endmodule