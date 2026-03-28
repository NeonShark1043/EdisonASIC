`timescale 1ns / 1ps
module tb_morse_decoder();
    parameter BIT_WIDTH = 12;
    parameter CLK_PERIOD = 10;
    parameter HYST_LIM = 15;
    parameter DOT_LIM = 10;
    parameter DASH_LIM = DOT_LIM * 3;
    parameter HOLD_MAX = 5;
    parameter SHORT_GAP_LIM = 10;
    parameter LONG_GAP_LIM = 70;

    logic clk, nrst;
    logic push_button, blank_button, seg_mode;
    wire start, calibrate; // Declare as "wire" for continuous assignment logics (passed signals between modules)
    logic comp_in, sah_en, data_ready;
    logic [BIT_WIDTH-1:0] dac_out, adc_out, light_diff;
    logic light_on, char_ready;
    logic [7:0] ascii_char;

    soc_button #(HOLD_MAX) u_button (.*);
    sar_adc_controller #(BIT_WIDTH, 4) u_adc (.*);
    light_processor #(BIT_WIDTH, 16, HYST_LIM) u_processor (.*);
    // morse_fsm #(.DOT_MAX(DOT_LIM + 5), .GAP_LIMIT(LONG_GAP_LIM + 5)) u_decoder (.fsm_enable(start), .*);
    morse_decoder #(1_000_000, 10, DOT_LIM, LONG_GAP_LIM - 5) u_decoder (.*);

    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_morse_decoder);
    end

    // Simulate Analog/Digital Handshake for one ADC Sample
    task simulate_adc_cycle(input [BIT_WIDTH-1:0] target_analog_value);
        // The ADC FSM will cycle through bits and mock the comparator response based on the bit guess
        while(!data_ready) begin // Stop when it hits DONE
            @(posedge clk);
            comp_in = (target_analog_value >= dac_out); // Binary Search Logic
            //if(u_adc.current_state == 3'b011 && target_analog_value == 12'd900) $display("[ADC] DAC: %b (%d) | Target: %b (%d)", dac_out, dac_out, target_analog_value, target_analog_value); // Print during COMPARE
        end
        @(posedge clk); // Allow data_ready to pulse
    endtask

    task send_morse(input int num_ticks);
        // Wait for FSM to enter MARK state
        while(u_decoder.current_state != 3'b001) simulate_adc_cycle(12'd2500);
        // while(!light_on) simulate_adc_cycle(12'd3000);
        $display("[SIM] Sending Light Pulse. Target: %0d", num_ticks);

        // Continue providing ADC samples until the mark_counter hits the goal
        while(32'(u_decoder.mark_counter) < num_ticks) begin
            simulate_adc_cycle(12'd2500); // 2500 is "LIGHT ON" (> 1000 baseline)
        end
    endtask

    // Send Silence (Gap)
    task send_gap(input int num_ticks);
        // Provide a few "LIGHT OFF" cycles to let FSM move MARK -> CLASSIFY -> GAP
        while(u_decoder.current_state != 3'b011) simulate_adc_cycle(12'd900);
        // while(light_on) simulate_adc_cycle(12'd900);
        $display("[SIM] Sending Gap. Target: %0d", num_ticks);

        while(32'(u_decoder.gap_counter) < num_ticks && u_decoder.current_state == 3'b011) begin
            simulate_adc_cycle(12'd1000); // 1000 is "LIGHT OFF"
        end
    endtask

    // Result Monitoring
    always @(posedge char_ready) begin
        $display("[DECODER]: Character Received '%c'", (ascii_char == 0) ? "?" : ascii_char);
    end

    initial begin
        nrst = 0; comp_in = 0; push_button = 0; blank_button = 0;
        #(CLK_PERIOD * 10) nrst = 1;

        // Kickstarting SoC
        $display("Starting System-on-Chip Edison...");
        push_button = 1; repeat(HOLD_MAX * 3) @(posedge clk);
        if(start) $display("[BUTTON]: Start signal logic detected and maintained.");
        else $display("[BUTTON]: Start signal did not pulse.");
        push_button = 0; repeat(2) @(posedge clk);

        // Setting Threshold for Processor
        $display("Starting Auto-Calibration...");
        blank_button = 1; repeat(HOLD_MAX) @(posedge clk); // Turn on calibrate mode
        if(calibrate) repeat(40) simulate_adc_cycle(12'd1000); // Ambient Room Light
        blank_button = 0; repeat(5) @(posedge clk);
        blank_button = 1; repeat(HOLD_MAX) @(posedge clk); // Turn off calibrate mode
        blank_button = 0; repeat(5) @(posedge clk);
        if(!calibrate) $display("Threshold Set: %d", u_processor.threshold_set);

        $display("Test Level 2 - Character 'E' (.)");
        send_morse(DOT_LIM); // Requires one Dot - 10 ticks (100 ms)
        send_gap(LONG_GAP_LIM); // Long Gap - 70 ticks (700 ms)

        $display("Test Level 2 - Character 'T' (-)");
        send_morse(DASH_LIM); // Requires one Dash - 30 ticks (300 ms)
        send_gap(LONG_GAP_LIM);

        $display("Test Level 3 - Character 'A' (.-)");
        send_morse(DOT_LIM);
        send_gap(SHORT_GAP_LIM); // Short Gap - 10 ticks (100 ms)
        send_morse(DASH_LIM);
        send_gap(LONG_GAP_LIM);

        $display("Test Level 4 - Character 'K' (-.-)");
        send_morse(DASH_LIM);
        send_gap(SHORT_GAP_LIM);
        send_morse(DOT_LIM);
        send_gap(SHORT_GAP_LIM);
        send_morse(DASH_LIM);
        send_gap(LONG_GAP_LIM);

        $display("Test Level 5 - Character 'P' (.--.)");
        send_morse(DOT_LIM);
        send_gap(SHORT_GAP_LIM);
        send_morse(DASH_LIM);
        send_gap(SHORT_GAP_LIM);
        send_morse(DASH_LIM);
        send_gap(SHORT_GAP_LIM);
        send_morse(DOT_LIM);
        send_gap(LONG_GAP_LIM);

        $display("Test Level 6 - Number (8) (---..)");
        send_morse(DASH_LIM);
        send_gap(SHORT_GAP_LIM);
        send_morse(DASH_LIM);
        send_gap(SHORT_GAP_LIM);
        send_morse(DASH_LIM);
        send_gap(SHORT_GAP_LIM);
        send_morse(DOT_LIM);
        send_gap(SHORT_GAP_LIM);
        send_morse(DOT_LIM);
        send_gap(LONG_GAP_LIM);

        $display("Test Boundary - NULL Characters (.-.-)");
        send_morse(DOT_LIM);
        send_gap(SHORT_GAP_LIM);
        send_morse(DASH_LIM);
        send_gap(SHORT_GAP_LIM);
        send_morse(DOT_LIM);
        send_gap(SHORT_GAP_LIM);
        send_morse(DASH_LIM);
        send_gap(LONG_GAP_LIM);

        // Shutdown SoC
        $display("Shutting Down System-on-Chip Edison...");
        push_button = 1; repeat(HOLD_MAX * 3) @(posedge clk);
        if(!start) $display("[BUTTON]: Start signal logic remained low successfully.");
        else $display("[BUTTON]: Start signal is still active.");
        push_button = 0; repeat(2) @(posedge clk);

        $display("--- All Morse Tests Completed ---");
        $finish;
    end
endmodule