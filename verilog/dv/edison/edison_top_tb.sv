`timescale 1ns / 1ps
module tb_edison_top();
    parameter BIT_WIDTH = 12;
    parameter BCD_WIDTH = 4;
    parameter SSD_WIDTH = 8;
    parameter CLK_PERIOD = 10;
    parameter HYST_LIM = 15;
    parameter DOT_LIM = 5;
    parameter DASH_LIM = 350;
    parameter HOLD_MAX = 5;
    parameter SHORT_GAP_LIM = 10;
    parameter LONG_GAP_LIM = 300;
    parameter SPACE_LIM = 500;

    // Module Signals
    logic clk, nrst;
    logic [20:0] pb;
    logic [7:0] left, right;
    logic [7:0] ss7, ss6, ss5, ss4, ss3, ss2, ss1, ss0;
    logic red, green, blue;
    logic [7:0] txdata, rxdata;
    logic txclk, rxclk, txready, rxready;

    edison_top #(BIT_WIDTH, 4, 8, HOLD_MAX, 16, 1_000_000, 300, LONG_GAP_LIM, SPACE_LIM) u_edison (.*);

    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    task power_restart(); // Simulate holding Push button to turn the system ON/OFF
        $display("[BUTTON] Holding Push Button to Restart Power...");
        pb[0] = 1; repeat(HOLD_MAX + 20) @(posedge clk);
        pb[0] = 0; repeat(HOLD_MAX) @(posedge clk);
    endtask

    task toggle_mode(); // Simulate holding Blank and pressing Push to switch Output Mode
        $display("[BUTTON] Toggle Display Mode (Lux <--> Morse)...");
        pb[1] = 1; repeat(HOLD_MAX) @(posedge clk); // Hold Blank
        pb[0] = 1; repeat(HOLD_MAX / 2) @(posedge clk); // Press Push
        pb[0] = 0; repeat(HOLD_MAX / 2) @(posedge clk);
        pb[1] = 0; repeat(HOLD_MAX) @(posedge clk);
    endtask

    // Simulate Analog/Digital Handshake for one ADC Sample
    task simulate_adc_cycle(input [BIT_WIDTH-1:0] target_analog_value);
        // The ADC FSM will cycle through bits and mock the comparator response based on the bit guess
        while(!u_edison.data_ready) begin // Stop when it hits DONE
            @(posedge clk);
            pb[2] = (target_analog_value >= u_edison.u_adc.dac_out); // Binary Search Logic
        end
        @(posedge clk); // Allow data_ready to pulse
    endtask

    task send_pulse(input int num_ticks);
        // Wait for FSM to enter MARK state
        while(u_edison.u_decoder.current_state != 3'b001) simulate_adc_cycle(12'd3500);
        $display("[DECODER] Sending Light Pulse. Target: %0d", num_ticks);

        // Continue providing ADC samples until the mark_counter hits the goal
        // while loop && u_edison.u_decoder.current_state == 3'b001
        while(32'(u_edison.u_decoder.mark_counter) < num_ticks && u_edison.u_decoder.current_state == 3'b001) begin
            simulate_adc_cycle(12'd3500); // 3500 is "LIGHT ON" (> 1000 baseline)
        end
    endtask

    // Send Silence (Gap)
    task send_gap(input int num_ticks);
        // Provide a few "LIGHT OFF" cycles to let FSM move MARK -> CLASSIFY -> GAP
        while(u_edison.u_decoder.current_state != 3'b011) simulate_adc_cycle(12'd400);
        $display("[DECODER] Sending Gap. Target: %0d", num_ticks);

        while(32'(u_edison.u_decoder.gap_counter) < num_ticks && u_edison.u_decoder.current_state == 3'b011) begin
            simulate_adc_cycle(12'd400); // 1000 is "LIGHT OFF"
        end
    endtask

    task send_space();
        // Wait for FSM to enter SPACE state
        $display("[DECODER] Sending Light Space.");
        while(u_edison.char_ready && u_edison.ascii_char == 8'd32) begin
            simulate_adc_cycle(12'd400);
        end
    endtask

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

    task screen_display();
        $display("[SCREEN] ss7-ss0: %c || %c || %c || %c || %c || %c || %c || %c", reverse_decoder(ss7), reverse_decoder(ss6), reverse_decoder(ss5), reverse_decoder(ss4), reverse_decoder(ss3), reverse_decoder(ss2), reverse_decoder(ss1), reverse_decoder(ss0));
    endtask

    task state_debug();
        $display("[DECODER] Current State %0d; Mark Counter %0d; Gap Counter %0d; Tick En %d; Light On %d and Index %0d", u_edison.u_decoder.current_state, u_edison.u_decoder.mark_counter, u_edison.u_decoder.gap_counter, u_edison.u_decoder.tick_en, u_edison.light_on, u_edison.u_decoder.tree_index);
    endtask

    initial begin
        nrst = 0; pb = '0; rxdata = '0; rxready = 0;
        #(CLK_PERIOD * 10) nrst = 1;
        $display("---Initiating Edison Top Testbench---");

        $display("Test 1: Power On");
        power_restart();
        if(u_edison.start) $display("[BUTTON] >>> SUCCESS: System started.");
        else $display("[BUTTON] >>> FAIL: No start signal detected.");
        screen_display();

        $display("\nTest 2: Ambient Calibration");
        // self_calibrate(); // Turn on/off calibration
        pb[1] = 1; repeat(HOLD_MAX + 3) @(posedge clk);
        if(u_edison.calibrate) begin
            $display("[BUTTON] Turning Blanking...");
            repeat(100) simulate_adc_cycle(12'd1000); // Ambient light level (~2441 Lux)
        end
        pb[1] = 0; repeat(5) @(posedge clk);
        pb[1] = 1; repeat(HOLD_MAX + 3) @(posedge clk);
        pb[1] = 0; repeat(5) @(posedge clk);
        $display("[PROCESSOR] Threshold: %d || Light Diff: %d", u_edison.u_processor.threshold_set, u_edison.light_diff); // Expect light_diff near 0
        screen_display();

        $display("\nTest 3: Dynamic Lux Change");
        repeat(100) simulate_adc_cycle(12'd3000); // Bright light (~7324 Lux)
        repeat(HOLD_MAX) @(posedge clk); // Wait for conversion and averaging
        screen_display();

        $display("\nTest 4: Morse Mode Toggle");
        toggle_mode();
        if(u_edison.seg_mode == 1) $display("[BUTTON] >>> SUCCESS: Switched to Morse Mode");
        else if(u_edison.seg_mode == 0) $display("[BUTTON] >>> FAIL: Remained at Lux Mode");
        screen_display();

        $display("\nTest 5: Morse Decoding and Scrolling"); // Send "Edison SoC"
        u_edison.u_decoder.tree_index = 6'd1;
        send_pulse(DOT_LIM); send_gap(LONG_GAP_LIM); // E
        screen_display();

        send_pulse(DASH_LIM); send_gap(SHORT_GAP_LIM); send_pulse(DOT_LIM); send_gap(SHORT_GAP_LIM); send_pulse(DOT_LIM); send_gap(LONG_GAP_LIM); // D
        screen_display();

        send_pulse(DOT_LIM); send_gap(SHORT_GAP_LIM); send_pulse(DOT_LIM); send_gap(LONG_GAP_LIM); // I
        screen_display();

        send_pulse(DOT_LIM); send_gap(SHORT_GAP_LIM); send_pulse(DOT_LIM); send_gap(SHORT_GAP_LIM); send_pulse(DOT_LIM); send_gap(LONG_GAP_LIM); // S
        screen_display();

        send_pulse(DASH_LIM); send_gap(SHORT_GAP_LIM); send_pulse(DASH_LIM); send_gap(SHORT_GAP_LIM); send_pulse(DASH_LIM); send_gap(LONG_GAP_LIM); // O
        screen_display();

        send_pulse(DASH_LIM); send_gap(SHORT_GAP_LIM); send_pulse(DOT_LIM); send_gap(LONG_GAP_LIM); // N
        screen_display();

        send_gap(SPACE_LIM); screen_display(); // Blankspace (long inactivity)

        send_pulse(DOT_LIM); send_gap(SHORT_GAP_LIM); send_pulse(DOT_LIM); send_gap(SHORT_GAP_LIM); send_pulse(DOT_LIM); send_gap(LONG_GAP_LIM); // S
        screen_display();

        send_pulse(DASH_LIM); send_gap(SHORT_GAP_LIM); send_pulse(DASH_LIM); send_gap(SHORT_GAP_LIM); send_pulse(DASH_LIM); send_gap(LONG_GAP_LIM); // O
        screen_display();

        send_pulse(DASH_LIM); send_gap(SHORT_GAP_LIM); send_pulse(DOT_LIM); send_gap(SHORT_GAP_LIM); send_pulse(DASH_LIM); send_gap(SHORT_GAP_LIM); send_pulse(DOT_LIM); send_gap(LONG_GAP_LIM); // C
        screen_display();

        $display("\nTest 6: Power Shutdown");
        power_restart();
        if(!u_edison.start) $display("[BUTTON] >>> SUCCESS: System shut down.");
        else $display("[BUTTON] >>> FAIL: System still remains active.");

        $display("---Testbench Finished---");
        $finish;
    end
endmodule