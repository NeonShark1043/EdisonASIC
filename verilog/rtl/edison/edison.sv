module edison #( // Clean for synthesis
    parameter BIT_WIDTH = 12, // For digital readings of light in ADC
    parameter BCD_WIDTH = 4, // For each digit under BCD form in Lux Converter and 7-Segment
    parameter SSD_WIDTH = 8, // For each eight of 7-Segment Display
    parameter SPI_WIDTH = 72, // For serializer takes in total bits of top outputs
    parameter HOLD_MAX = 10, // Time requirement for button hold and register wait
    parameter AVG_WINDOW = 16, // (2) The number of samples to average over in Light Processing
    parameter CLK_FREQ = 500, // (1_000_000) Clock frequency for Morse Decoder
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
    logic [SSD_WIDTH-1:0] led_out; // Unified 8-bit LED bar
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

module edge_detector (
    input logic clk,
    input logic nrst,
    input logic signal_in,
    output logic rising_edge,
    output logic falling_edge
);

    logic signal_d;
    logic signal_e;

    always_ff @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            signal_d <= 0;
            signal_e <= 0;
        end else begin
            signal_d <= signal_in;
            signal_e <= signal_d;
        end
    end

    assign rising_edge = signal_d & ~signal_e;
    assign falling_edge = ~signal_d &  signal_e;
endmodule

/* SoC Button Controls
1) Kickstart SoC: Hold Push Button
2) Zero Processing Thresholds: Press Blank Button
3) Toggle Output Mode: Hold Blank and Press Push
4) Shutdown SoC: Hold Push Button again
*/

module soc_button #(
    parameter HOLD_MAX = 10
)(
    input logic clk,
    input logic nrst,
    input logic push_button, // To output start
    input logic blank_button, // To output calibrate
    output logic start, // Trigger ADC FSM
    output logic calibrate, // Trigger Light Processor calibration
    output logic seg_mode // Output choices of displaying Lux (0) or Morse (1)
);
    logic [3:0] hold_counter;
    logic push_rise, push_fall;

    edge_detector push_edge (
        .nrst(nrst),
        .signal_in(push_button),
        .rising_edge(push_rise),
        .falling_edge(push_fall),
        .*
    );

    assign calibrate = blank_button;

    // Note: It would be physically hard to accurately press both buttons and detect their rising edges at the same clock cycle
    // Hence, Toggle Output Mode when one button is PRESSED while the other is HELD
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) seg_mode <= 0;
        else if(blank_button && push_rise) seg_mode <= ~seg_mode;
    end

    // State Encoding
    typedef enum logic [1:0] {
        IDLE = 2'b00,
        HOLD = 2'b01,
        RESTART = 2'b10,
        RELEASE = 2'b11
    } state_t;
    state_t current_state, next_state;

    // State Transition Logic
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic
    always_comb begin
        next_state = current_state;
        case(current_state)
            IDLE: if(push_button) next_state = HOLD;
            HOLD: if(!push_button) next_state = IDLE;
            else if(hold_counter >= 4'(HOLD_MAX)) next_state = RESTART;
            RESTART: next_state = RELEASE;
            RELEASE: if(!push_button) next_state = IDLE; // Wait for release to prevent re-triggering
            default: next_state = IDLE;
        endcase
    end

    // Control Path Logic
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) begin
            hold_counter <= '0; start <= 0;
        end else begin
            case(current_state)
                IDLE: hold_counter <= '0;
                HOLD: hold_counter <= hold_counter + 1'b1;
                RESTART: begin
                    start <= ~start; // Turn ON if OFF, turn OFF if ON
                    // Note: Remove resetting start in other states because start must stay on HIGH
                    // So that the FSMs can conduct their continuous operations, else they would reset numerous times.
                    hold_counter <= '0;
                end
                RELEASE: hold_counter <= '0;
                default: begin
                    hold_counter <= '0; 
                    start <= 0;
                end
            endcase
        end
    end

endmodule

module sar_adc_controller #(
    parameter BIT_WIDTH = 12,
    parameter WAIT_CYCLES = 4 // Settling time for analog components
)(
    input logic clk,
    input logic nrst,
    input logic start, // Trigger conversion
    input logic comp_in, // From physical Comparator
    output logic sah_en, // To Sample & Hold Switch
    output logic [BIT_WIDTH-1:0] dac_out, // To R-2R Ladder (7-bit?)
    output logic [BIT_WIDTH-1:0] adc_out, // Final stable reading
    output logic data_ready
);

    // State Encoding
    typedef enum logic [2:0]{
        IDLE = 3'b000,
        SAMPLE = 3'b001,
        TEST = 3'b010,
        COMPARE = 3'b011,
        CHECK = 3'b100,
        NEXT = 3'b101,
        DONE = 3'b111
    } state_t;

    state_t current_state, next_state;

    // Internal Registers
    logic [BIT_WIDTH-1:0] sar_reg;
    logic [3:0] bit_index, wait_counter;

    // State Transition Logic
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) current_state <= IDLE;
        else current_state <= next_state;
    end

    // Next State Logic
    always_comb begin
        next_state = current_state;
        case(current_state)
            IDLE: if(start) next_state = SAMPLE;
            SAMPLE: if(wait_counter == WAIT_CYCLES) next_state = TEST;
            TEST: next_state = COMPARE;
            COMPARE: if(wait_counter == WAIT_CYCLES) next_state = CHECK;
            CHECK: next_state = NEXT;
            NEXT: if(bit_index == 0) next_state = DONE;
            else next_state = TEST;
            DONE: if(start) next_state = SAMPLE;
            else next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Control Path Logic
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) begin
            sar_reg <= '0;
            bit_index <= BIT_WIDTH - 1;
            wait_counter <= '0;
            adc_out <= '0;
            data_ready <= 0;
            sah_en <= 0;
        end else begin
            case(current_state)
                IDLE: begin
                    data_ready <= 0;
                    wait_counter <= '0;
                    bit_index <= BIT_WIDTH - 1;
                    sar_reg <= '0;
                    sah_en <= 0;
                end

                SAMPLE: begin
                    data_ready <= 0;
                    sar_reg <= '0;
                    bit_index <= BIT_WIDTH - 1;
                    sah_en <= 1; // Close S&H Switch
                    wait_counter <= wait_counter + 1; // Wait to capture light voltage
                end

                TEST: begin
                    sah_en <= 0;
                    wait_counter <= '0; // Reset for reuse in the next state
                    sar_reg[bit_index] <= 1;
                end

                COMPARE: begin
                    wait_counter <= wait_counter + 1; // Wait for comparator input
                end

                CHECK: begin
                    if(comp_in == 0) sar_reg[bit_index] <= 0;
                end

                NEXT: begin
                    if(bit_index > 0) bit_index <= bit_index - 1;
                end

                DONE: begin
                    adc_out <= sar_reg;
                    data_ready <= 1;
                    wait_counter <= '0; // Reset for potential loop
                end

                default: begin
                    sar_reg <= '0;
                    bit_index <= BIT_WIDTH - 1;
                    wait_counter <= '0;
                end
            endcase
        end
    end

    assign dac_out = sar_reg;
endmodule

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
    output logic light_on // Clean bit for Morse FSM
);

    // Internal Registers
    logic [BIT_WIDTH+3:0] sum_acc; // Accumulator for 16 samples
    logic [BIT_WIDTH-1:0] threshold_set; // Ambient baseline light level
    logic [BIT_WIDTH-1:0] avg_acc;
    logic [3:0] sample_num;
    logic [7:0] hys_counter; // Acts as "waiting room" for light

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

    // Auto-Calibration
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) begin
            threshold_set <= 12'd50; // Set to 50 by default
        end else if(calibrate && data_ready) begin
            // Update the threshold with the current filtered average
            threshold_set <= avg_acc;
        end
    end

    // Difference Calculation - Calculates the light magnitude above baseline
    assign light_diff = (avg_acc > threshold_set) ? (avg_acc - threshold_set) : '0;

    // Hysteresis Debouncing (for light_on)
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) begin
            light_on <= 0;
            hys_counter <= '0;
        end else begin
            // If signal is significantly above threshold (where error margin is disregarded), increment hys_counter
            if(light_diff > BIT_WIDTH'(HYSTERESIS_THRESHOLD)) begin
                if(hys_counter < 8'd255) hys_counter <= hys_counter + 8'd5;
                // When hys_counter hits the limit (50), that is when light turns on
                else light_on <= 1;
            end else begin // If signal drops (below hyst threshold or base + hyst threshold), immediately decrement
                if(hys_counter > 8'd0) hys_counter <= hys_counter - 8'd1;
                else light_on <= 0;
            end
        end
    end
endmodule

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

module morse_decoder #(
    parameter CLK_FREQ = 100000000, // 100 MHz SoC Clock - all counters reset every 1,000,000 cycles
    parameter TICK_MS = 10, // 1 tick = 10 ms resolution for counters
    parameter DOT_MAX = 200, // < 2000 ms is a dot (.) and > 2100 ms is a dash (_)
    parameter GAP_MAX = 300, // > 3000 ms of silence trigges DECODE
    parameter SPACE_MAX = 500 // // > 5000 ms for letter space
)(
    input logic clk,
    input logic nrst,
    input logic start,
    input logic light_on, // From Light Processing Module
    output logic [7:0] ascii_char, // Decoded Characters
    output logic char_ready // Pulse when character is ready
);

    // State Encoding
    typedef enum logic [2:0] {
        IDLE = 3'b000,
        MARK = 3'b001, // Measuring Light Pulse (Dot/Dash)
        CLASSIFY = 3'b010, // Determining if the Light Pulse is a Dot or Dash
        GAP = 3'b011, // Measuring silence between pulses
        DECODE = 3'b100, // Matching sequences to ASCII
        READY = 3'b101, // Pulsing Output
        SPACE = 3'b110 // Detecting Word Gaps
    } state_t;

    state_t current_state, next_state;

    // Registers
    logic [31:0] tick_counter; // Track how much "real time" has passed relative to the clock frequency (e.g. set 10 ticks in tb = 100 ms)
    logic [5:0] tree_index; // Current position in the binary tree
    logic [15:0] mark_counter, gap_counter;
    logic tick_en; // HIGH for exactly one clock cycle every time the tick_counter reaches its target. This creates a periodic "heartbeat" (every 10ms) that the rest of FSM uses to increment the duration counters (mark_counter and gap_counter)

    // Tree Memory - 63 entries to cover up to 5 levels of Morse (A-Z, 0-9)
    logic [7:0] morse_tree [0:63];
    initial begin
        for (int i = 0; i < 64; i++) morse_tree[i] = '0;
        // Level 0 & 1
        morse_tree[0] = 8'h00; // Null
        morse_tree[1] = 8'h00; // Root (Start here)

        // Level 2 (1 Symbol)
        morse_tree[2] = 8'h45; // E (.)
        morse_tree[3] = 8'h54; // T (-)

        // Level 3 (2 Symbols)
        morse_tree[4] = 8'h49; // I (..)
        morse_tree[5] = 8'h41; // A (.-)
        morse_tree[6] = 8'h4E; // N (-.)
        morse_tree[7] = 8'h4D; // M (--)

        // Level 4 (3 Symbols)
        morse_tree[8] = 8'h53; // S (...)
        morse_tree[9] = 8'h55; // U (..-)
        morse_tree[10] = 8'h52; // R (.-.)
        morse_tree[11] = 8'h57; // W (.--)
        morse_tree[12] = 8'h44; // D (-..)
        morse_tree[13] = 8'h4B; // K (-.-)
        morse_tree[14] = 8'h47; // G (--.)
        morse_tree[15] = 8'h4F; // O (---)

        // Level 5 (4 Symbols)
        morse_tree[16] = 8'h48; // H (....)
        morse_tree[17] = 8'h56; // V (...-)
        morse_tree[18] = 8'h46; // F (..-.)
        morse_tree[19] = 8'h00; // Null (..--)
        morse_tree[20] = 8'h4C; // L (.-..)
        morse_tree[21] = 8'h00; // Null (.-.-)
        morse_tree[22] = 8'h50; // P (.--.)
        morse_tree[23] = 8'h4A; // J (.---)
        morse_tree[24] = 8'h42; // B (-...)
        morse_tree[25] = 8'h58; // X (-..-)
        morse_tree[26] = 8'h43; // C (-.-.)
        morse_tree[27] = 8'h59; // Y (-.--)
        morse_tree[28] = 8'h5A; // Z (--..)
        morse_tree[29] = 8'h51; // Q (--.-)
        morse_tree[30] = 8'h00; // Null (---.)
        morse_tree[31] = 8'h00; // Null (----)

        // Level 6 (5 Symbols - Numbers)
        morse_tree[32] = 8'h35; // 5 (.....)
        morse_tree[33] = 8'h34; // 4 (....-)
        morse_tree[35] = 8'h33; // 3 (...--)
        morse_tree[39] = 8'h32; // 2 (..---)
        morse_tree[47] = 8'h31; // 1 (.----)
        morse_tree[48] = 8'h36; // 6 (-....)
        morse_tree[56] = 8'h37; // 7 (--...)
        morse_tree[60] = 8'h38; // 8 (---..)
        morse_tree[62] = 8'h39; // 9 (----.)
        morse_tree[63] = 8'h30; // 0 (-----)

        morse_tree[34] = 8'h00; // Null (...-.)
        morse_tree[36] = 8'h00; // Null (..-..)
        morse_tree[37] = 8'h00; // Null (..-.-)
        morse_tree[38] = 8'h00; // Null (..-..)
        morse_tree[40] = 8'h00; // Null (.-...)
        morse_tree[41] = 8'h00; // Null (.-..-)
        morse_tree[42] = 8'h00; // Null (.-.-.)
        morse_tree[43] = 8'h00; // Null (.-.--)
        morse_tree[44] = 8'h00; // Null (.--..)
        morse_tree[45] = 8'h00; // Null (.--.-)
        morse_tree[46] = 8'h00; // Null (.---.)
        morse_tree[49] = 8'h00; // Null (-...-)
        morse_tree[50] = 8'h00; // Null (-..-.)
        morse_tree[51] = 8'h00; // Null (-..--)
        morse_tree[52] = 8'h00; // Null (-.-..)
        morse_tree[53] = 8'h00; // Null (-.-.-)
        morse_tree[54] = 8'h00; // Null (-.--.)
        morse_tree[55] = 8'h00; // Null (-.---)
        morse_tree[57] = 8'h00; // Null (--..-)
        morse_tree[58] = 8'h00; // Null (--.-.)
        morse_tree[59] = 8'h00; // Null (--.--)
        morse_tree[61] = 8'h00; // Null (---.-)
    end

    // 10 ms Tick Generator - mark/gap counters increment every 10 ms instead of 10 ns
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) begin
            tick_counter <= 0;
            tick_en <= 0;
        end else if(tick_counter == (CLK_FREQ / 100) - 1) begin
            tick_counter <= 0;
            tick_en <= 1;
        end else begin
            tick_counter <= tick_counter + 1;
            tick_en <= 0;
        end
    end

    // State Transitions
    always_ff @(posedge clk or negedge nrst) begin
        if (!nrst) current_state <= IDLE;
        else current_state <= next_state;
    end

    always_comb begin
        next_state = current_state;
        if(!start) next_state = IDLE;
        case(current_state)
            IDLE: if(light_on) next_state = MARK;
            else if(32'(gap_counter) >= SPACE_MAX) next_state = SPACE;
            MARK: if(!light_on && mark_counter > 0) next_state = CLASSIFY;
            else next_state = MARK;
            CLASSIFY: next_state = GAP;
            GAP: if(light_on) next_state = MARK;
            else if(32'(gap_counter) >= GAP_MAX) next_state = DECODE;
            DECODE: next_state = READY;
            READY: next_state = IDLE;
            SPACE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Tree Traversal Logic
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) begin
            tree_index <= 6'd1; // Start at Root
            mark_counter <= 0; gap_counter <= 0;
            ascii_char <= 0; char_ready <= 0;
        end else begin
            case(current_state)
                IDLE: begin
                    char_ready <= 0;
                    tree_index <= 6'd1;
                    mark_counter <= 0;
                    if(tick_en) gap_counter <= gap_counter + 1;
                end

                MARK: begin
                    if(tick_en) mark_counter <= mark_counter + 1;
                    gap_counter <= 0;
                end

                CLASSIFY: begin
                    // Move Left for Dot, Right for Dash
                    if(mark_counter > 0) begin
                        if(32'(mark_counter) <= DOT_MAX)
                            tree_index <= tree_index << 1; // Left: index * 2
                        else
                            tree_index <= (tree_index << 1) + 1; // Right: index * 2 + 1
                    end
                    mark_counter <= 0;
                end

                GAP: begin
                    mark_counter <= 0;
                    if(tick_en) gap_counter <= gap_counter + 1;
                end

                DECODE: begin
                    ascii_char <= morse_tree[tree_index];
                    gap_counter <= 0;
                end

                READY: begin
                    char_ready <= 1;
                end

                SPACE: begin
                    ascii_char <= 8'd32; // ASCII for Blankspace
                    char_ready <= 1;
                    gap_counter <= 0; // Reset to prevent double spacing
                end

                default: begin
                    tree_index <= 6'd1;
                    mark_counter <= 16'd0;
                    char_ready <= 0;
                end
            endcase
        end
    end
endmodule

module led_bar_driver(
    input logic clk, nrst,
    input logic [11:0] light_diff,   
    output logic [9:0] led_out
);
    always_comb begin
        if (light_diff >= 12'd100) led_out = 10'b1111111111;
        else if(light_diff >= 12'd90) led_out = 10'b0111111111;
        else if(light_diff >= 12'd80) led_out = 10'b0011111111;
        else if(light_diff >= 12'd70) led_out = 10'b0001111111;
        else if(light_diff >= 12'd60) led_out = 10'b0000111111;
        else if(light_diff >= 12'd50) led_out = 10'b0000011111;
        else if(light_diff >= 12'd40) led_out = 10'b0000001111;
        else if(light_diff >= 12'd30) led_out = 10'b0000000111;
        else if(light_diff >= 12'd20) led_out = 10'b0000000011;
        else if(light_diff >= 12'd10) led_out = 10'b0000000001;
        else led_out = 10'b0000000000;
    end
endmodule

module seven_segment_display #(
    parameter BIT_WIDTH = 12, // For digital readings of light in ADC
    parameter BCD_WIDTH = 4, // For each digit under BCD form in Lux Converter and 7-Segment
    parameter SSD_WIDTH = 8 // For each eight of 7-Segment Display
)(
    input logic clk, nrst,
    input logic start, calibrate, seg_mode,
    input logic [BCD_WIDTH-1:0] seg_ones, seg_tens, seg_hundreds, seg_thousands,
    input logic char_ready,
    input logic [7:0] ascii_char,
    output logic [SSD_WIDTH-1:0] ss7, ss6, ss5, ss4, ss3, ss2, ss1, ss0
);
    // Internal Wires
    logic [SSD_WIDTH-1:0] seg_digits [SSD_WIDTH-1:0];
    logic [SSD_WIDTH-1:0] scroll_buffer [5:0]; // Buffer from ss1 through ss6 in Morse Mode
    logic [SSD_WIDTH-1:0] num_buffer; // Buffer for numbers in Morse Mode

    // Scrolling Morse Logic - Move characters from right to left (ss0 to ss4)
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) begin
            for(int i = 0; i < 6; i++) scroll_buffer[i] <= 8'd32;
            num_buffer <= 8'd127;
        end else if(char_ready) begin
            if(ascii_char >= 8'd48 && ascii_char <= 8'd57) begin // Numerical Morse
                num_buffer <= ascii_char;
            end else begin // Character Morse
                scroll_buffer[5] <= scroll_buffer[4];
                scroll_buffer[4] <= scroll_buffer[3];
                scroll_buffer[3] <= scroll_buffer[2];
                scroll_buffer[2] <= scroll_buffer[1];
                scroll_buffer[1] <= scroll_buffer[0];
                scroll_buffer[0] <= ascii_char; // New character enters from rightmost
            end
        end
    end

    always_comb begin
        for(int i = 0; i < 8; i++) seg_digits[i] = 8'd32; // Default all to blank
        if(start == 0) begin // "POWER OFF"
            seg_digits[7] = 8'd80;
            seg_digits[6] = 8'd79;
            seg_digits[5] = 8'd87;
            seg_digits[4] = 8'd69;
            seg_digits[3] = 8'd82;
            seg_digits[2] = 8'd79;
            seg_digits[1] = 8'd70;
            seg_digits[0] = 8'd70;
        end else begin
            if(seg_mode == 0) begin // Lux (L) Mode (Static): Show "L" on left, value on right
                seg_digits[7] = 8'd76; // L
                seg_digits[6] = (calibrate) ? 8'd66 : 8'd32;
                // Add 48 to convert raw BCD (0-9) to ASCII ('0'-'9')
                seg_digits[3] = 8'd48 + {4'b0, seg_thousands};
                seg_digits[2] = 8'd48 + {4'b0, seg_hundreds};
                seg_digits[1] = 8'd48 + {4'b0, seg_tens};
                seg_digits[0] = 8'd48 + {4'b0, seg_ones};
            end else if(seg_mode == 1) begin // Morse (M) Mode (Dynamic): Show "M" on left, numbers on right, and scrolling characters from right to left
                seg_digits[7] = 8'd77; // M
                seg_digits[6] = scroll_buffer[5];
                seg_digits[5] = scroll_buffer[4];
                seg_digits[4] = scroll_buffer[3];
                seg_digits[3] = scroll_buffer[2];
                seg_digits[2] = scroll_buffer[1];
                seg_digits[1] = scroll_buffer[0];
                seg_digits[0] = num_buffer;
            end
        end
    end

    // Drive Displays
    always_ff @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            {ss7, ss6, ss5, ss4, ss3, ss2, ss1, ss0} <= '0;
        end else begin
            ss0 <= {1'b0, seven_seg(seg_digits[0])};
            ss1 <= {1'b0, seven_seg(seg_digits[1])};
            ss2 <= {1'b0, seven_seg(seg_digits[2])};
            ss3 <= {1'b0, seven_seg(seg_digits[3])};
            ss4 <= {1'b0, seven_seg(seg_digits[4])};
            ss5 <= {1'b0, seven_seg(seg_digits[5])};
            ss6 <= {1'b0, seven_seg(seg_digits[6])};
            ss7 <= {1'b0, seven_seg(seg_digits[7])};
        end
    end

    // Extended Decoder Function
    function automatic [6:0] seven_seg(input [7:0] alphanum);
        case(alphanum) // Modified for ASCII-compatible with Morse Decoder
            8'd48: seven_seg = 7'b0111111; // 0
            8'd49: seven_seg = 7'b0000110; // 1
            8'd50: seven_seg = 7'b1011011; // 2
            8'd51: seven_seg = 7'b1001111; // 3
            8'd52: seven_seg = 7'b1100110; // 4
            8'd53: seven_seg = 7'b1101101; // 5
            8'd54: seven_seg = 7'b1111101; // 6
            8'd55: seven_seg = 7'b0000111; // 7
            8'd56: seven_seg = 7'b1111111; // 8
            8'd57: seven_seg = 7'b1101111; // 9
            8'd65: seven_seg = 7'b1110111; // A
            8'd66: seven_seg = 7'b1111100; // B
            8'd67: seven_seg = 7'b0111001; // C
            8'd68: seven_seg = 7'b1011110; // D
            8'd69: seven_seg = 7'b1111001; // E
            8'd70: seven_seg = 7'b1110001; // F
            8'd71: seven_seg = 7'b0111101; // G
            8'd72: seven_seg = 7'b1110100; // H
            8'd73: seven_seg = 7'b0110000; // I
            8'd74: seven_seg = 7'b0011110; // J
            8'd75: seven_seg = 7'b1110101; // K
            8'd76: seven_seg = 7'b0111000; // L
            8'd77: seven_seg = 7'b0010101; // M
            8'd78: seven_seg = 7'b0110111; // N
            8'd79: seven_seg = 7'b0111111; // O
            8'd80: seven_seg = 7'b1110011; // P
            8'd81: seven_seg = 7'b1100111; // Q
            8'd82: seven_seg = 7'b0110011; // R
            8'd83: seven_seg = 7'b1101101; // S
            8'd84: seven_seg = 7'b1111000; // T
            8'd85: seven_seg = 7'b0111110; // U
            8'd86: seven_seg = 7'b0101110; // V
            8'd87: seven_seg = 7'b0101010; // W
            8'd88: seven_seg = 7'b1110110; // X
            8'd89: seven_seg = 7'b1101110; // Y
            8'd90: seven_seg = 7'b1001011; // Z
            8'd32: seven_seg = 7'b0000000; // Blankspace
            default: seven_seg = 7'b1010011; // ? - for NULL characters
        endcase
    endfunction
endmodule

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
    logic [6:0] bit_counter; // Counts 0 to 71
    logic [3:0] clk_counter;
    
    // Clock Divider for Serial Clock
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) begin
            clk_counter <= 0;
            shift_clock <= 0;
        end else begin
            if(clk_counter == (CLK_DIV/2 - 1)) begin
                clk_counter <= 0;
                shift_clock <= ~shift_clock;
            end else begin
                clk_counter <= clk_counter + 1;
            end
        end
    end

    // Shift Logic
    always_ff @(posedge shift_clock or negedge nrst) begin
        if(!nrst) begin
            shift_register <= '0;
            bit_counter <= 0;
            seri_ready <= 1;
            mosi <= 0;
        end else begin
            if(bit_counter == SPI_WIDTH - 1) begin
                shift_register <= flat_data; // Capture flesh data and reset
                bit_counter <= 0;
                seri_ready <= 1; // Latch pulse
            end else begin
                seri_ready <= 0;
                mosi <= shift_register[SPI_WIDTH-1]; // MSB first
                shift_register <= {shift_register[SPI_WIDTH-2:0], 1'b0};
                bit_counter <= bit_counter + 1;
            end
        end
    end
endmodule
