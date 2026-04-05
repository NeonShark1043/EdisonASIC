`timescale 1ns / 1ps
module edison_top_tb();
    parameter BIT_WIDTH = 12;
    parameter BCD_WIDTH = 4;
    parameter SSD_WIDTH = 8;
    parameter CLK_PERIOD = 10;
    parameter HYST_LIM = 15;
    parameter DOT_LIM = 5;
    parameter DASH_LIM = 140;
    parameter HOLD_MAX = 5;
    parameter SHORT_GAP_LIM = 10;
    parameter LONG_GAP_LIM = 140;

    logic clk, nrst;
    logic push_button, blank_button, seg_mode;
    wire start, calibrate; // Declare as "wire" for continuous assignment logics (passed signals between modules)
    logic comp_in, sah_en, data_ready;
    logic [BIT_WIDTH-1:0] dac_out, adc_out, light_diff;
    logic light_on, char_ready;
    logic [7:0] ascii_char;
    logic [BCD_WIDTH-1:0] seg_ones, seg_tens, seg_hundreds, seg_thousands;
    logic [SSD_WIDTH-1:0] ss7, ss6, ss5, ss4, ss3, ss2, ss1, ss0;

    /*logic [BIT_WIDTH-1:0] target_comparator;
    assign comp_in = (target_comparator >= dac_out);*/

    soc_button #(HOLD_MAX) u_button (.*);
    sar_adc_controller #(BIT_WIDTH, 4) u_adc (.*);
    light_processor #(BIT_WIDTH, 16, HYST_LIM) u_processor (.*);
    lux_converter #(BIT_WIDTH, BCD_WIDTH, 16) u_lux (.*);
    morse_decoder #(3_125, 10, 130, LONG_GAP_LIM - 5, LONG_GAP_LIM + 50) u_decoder (.*);
    seven_segment_display #(BIT_WIDTH, BCD_WIDTH, SSD_WIDTH) u_seven (.*);

    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, edison_top_tb);
    end

    // Simulate Analog/Digital Handshake for one ADC Sample
    task simulate_adc_cycle(input [BIT_WIDTH-1:0] target_analog_value);
        // The ADC FSM will cycle through bits and mock the comparator response based on the bit guess
        //target_comparator = target_analog_value;
        while(!data_ready) begin // Stop when it hits DONE
            @(posedge clk);
            comp_in = (target_analog_value >= dac_out); // Binary Search Logicer
        end
        @(posedge clk); // Allow data_ready to pulse
    endtask

    task send_morse(input int num_ticks);
        // Wait for FSM to enter MARK state
        while(u_decoder.current_state != 3'b001) simulate_adc_cycle(12'd2500);
        // while(!light_on) simulate_adc_cycle(12'd3000);
        $display("[SIM] Sending Light Pulse. Target: %0d", num_ticks);

        // Continue providing ADC samples until the mark_counter hits the goal
        while(32'(u_decoder.mark_counter) < num_ticks && u_decoder.current_state == 3'b001) begin
            simulate_adc_cycle(12'd2500); // 2500 is "LIGHT ON" (> 1000 baseline)
            state_debug();
        end
    endtask

    // Send Silence (Gap)
    task send_gap(input int num_ticks);
        // Provide a few "LIGHT OFF" cycles to let FSM move MARK -> CLASSIFY -> GAP
        while(u_decoder.current_state != 3'b011) begin
            simulate_adc_cycle(12'd900);
        end
        // while(light_on) simulate_adc_cycle(12'd900);
        $display("[SIM] Sending Gap. Target: %0d", num_ticks);

        while(32'(u_decoder.gap_counter) < num_ticks && u_decoder.current_state == 3'b011) begin
            simulate_adc_cycle(12'd1000); // 1000 is "LIGHT OFF"
            // state_debug();
        end
    endtask

    // Result Monitoring
    always @(posedge char_ready) begin
        $display("[DECODER]: Character Received '%c'", (ascii_char == 0) ? "?" : ascii_char);
        $display("[SCREEN] ss7-ss0: %c || %c || %c || %c || %c || %c || %c || %c", reverse_decoder(ss7), reverse_decoder(ss6), reverse_decoder(ss5), reverse_decoder(ss4), reverse_decoder(ss3), reverse_decoder(ss2), reverse_decoder(ss1), reverse_decoder(ss0));
    end

    function byte reverse_decoder(input [7:0] seg); // Takes the 7-segment bit pattern and returns a displayable character
        case(seg[6:0]) // Only care about the lower 7 bits (a-g)
            7'b0111111: return "O"; // Or "0"
            7'b0000110: return "1";
            7'b1011011: return "2";
            7'b1001111: return "3";
            7'b1100110: return "4";
            7'b1101101: return "5"; // Or "S"
            7'b1111101: return "6";
            7'b0000111: return "7";
            7'b1111111: return "8";
            7'b1101111: return "9";
            7'b1110111: return "A";
            7'b1111100: return "B";
            7'b0111001: return "C";
            7'b1011110: return "D";
            7'b1111001: return "E";
            7'b1110001: return "F";
            7'b0111101: return "G";
            7'b1110100: return "H";
            7'b0110000: return "I";
            7'b0011110: return "J";
            7'b1110101: return "K";
            7'b0111000: return "L";
            7'b0010101: return "M";
            7'b0110111: return "N";
            7'b1110011: return "P";
            7'b1100111: return "Q";
            7'b0110011: return "R";
            7'b1111000: return "T";
            7'b0111110: return "U";
            7'b0101110: return "V";
            7'b0101010: return "W";
            7'b1110110: return "X";
            7'b1101110: return "Y";
            7'b1001011: return "Z";
            7'b0000000: return " "; // Blank
            default: return "?"; // NULL
        endcase
    endfunction

    task state_debug();
        $display("[DECODER] Current State %0d; Mark Counter %0d; Gap Counter %0d; Hyst Counter %0d; Tick En %d; Light On %d and Index %0d", u_decoder.current_state, u_decoder.mark_counter, u_decoder.gap_counter, u_processor.hys_counter, u_decoder.tick_en, light_on, u_decoder.tree_index);
    endtask

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
        blank_button = 1; @(posedge clk); // Turn on calibrate mode
        if(calibrate) repeat(40) simulate_adc_cycle(12'd1000); // Ambient Room Light
        blank_button = 0; repeat(5) @(posedge clk);
        blank_button = 1; @(posedge clk); // Turn off calibrate mode
        blank_button = 0; repeat(5) @(posedge clk);
        if(!calibrate) $display("Threshold Set: %d", u_processor.threshold_set);

        // Toggle Output Mode
        $display("[BUTTON] Toggle Display Mode (Lux <--> Morse)...");
        blank_button = 1; repeat(HOLD_MAX) @(posedge clk); // Hold Blank
        push_button = 1; repeat(HOLD_MAX / 2) @(posedge clk); // Press Push
        push_button = 0; repeat(HOLD_MAX / 2) @(posedge clk);
        blank_button = 0; repeat(HOLD_MAX) @(posedge clk);
        $display("[SCREEN] ss7-ss0: %c || %c || %c || %c || %c || %c || %c || %c", reverse_decoder(ss7), reverse_decoder(ss6), reverse_decoder(ss5), reverse_decoder(ss4), reverse_decoder(ss3), reverse_decoder(ss2), reverse_decoder(ss1), reverse_decoder(ss0));

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