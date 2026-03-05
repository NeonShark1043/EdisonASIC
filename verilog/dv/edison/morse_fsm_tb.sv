module tb_morse_fsm();
    parameter DOT_MAX    = 10;
    parameter GAP_LIMIT  = 30;
    parameter CLK_PERIOD = 10;

    logic        clk, nrst;
    logic        fsm_enable, light_on;
    logic [15:0] gap_counter;
    logic [7:0]  ascii_char;
    logic        char_ready;

    // Module Instantiation
    morse_fsm #(.DOT_MAX(DOT_MAX), .GAP_LIMIT(GAP_LIMIT)) u_morse (.*);

    // Clock Generation
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Gap Counter — driven by TB to mimic teammate's Next State Logic
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst)         gap_counter <= '0;
        else if(light_on) gap_counter <= '0;
        else              gap_counter <= gap_counter + 1;
    end

    // Helper Task: Send a dot (light on for less than DOT_MAX cycles)
    task send_dot();
        light_on = 1;
        repeat(DOT_MAX / 2) @(posedge clk);
        light_on = 0;
        @(posedge clk);
    endtask

    // Helper Task: Send a dash (light on for more than DOT_MAX cycles)
    task send_dash();
        light_on = 1;
        repeat(DOT_MAX * 2) @(posedge clk);
        light_on = 0;
        @(posedge clk);
    endtask

    // Helper Task: Trigger inter-character gap
    task send_char_gap();
        light_on = 0;
        repeat(GAP_LIMIT + 5) @(posedge clk);
    endtask

    // Output Monitoring and Verification Task
    task display_status(input logic [7:0] expected_char);
        integer timeout;
        timeout = 0;
        while(!char_ready && timeout < 200) begin
            @(posedge clk);
            timeout = timeout + 1;
        end
        $display("Time: %0t | Expected: %s | ascii_char: %s | char_ready: %b | Result: %s",
                  $time, expected_char, ascii_char, char_ready,
                  (char_ready && ascii_char === expected_char) ? "SUCCESS" : "FAIL");
    endtask

    task reset_signals();
        nrst       = 0;
        light_on   = 0;
        fsm_enable = 0;
        #(CLK_PERIOD);
        nrst = 1;
        #(CLK_PERIOD);
    endtask

    initial begin
        nrst = 0; fsm_enable = 0; light_on = 0;
        #(CLK_PERIOD * 5) nrst = 1;

        $display("\n--- FSM DISABLED ---");
        $display("Test Case 1: FSM does not decode while fsm_enable = 0");
        fsm_enable = 0;
        send_dot();
        send_char_gap();
        $display("Time: %0t | char_ready: %b | Result: %s",
                  $time, char_ready, (char_ready === 0) ? "SUCCESS" : "FAIL");
        reset_signals();

        $display("\n--- SINGLE SYMBOL DECODING ---");
        $display("Test Case 2: Decode E (dot)");
        fsm_enable = 1;
        send_dot();
        send_char_gap();
        display_status("E");
        reset_signals();

        $display("Test Case 3: Decode T (dash)");
        fsm_enable = 1;
        send_dash();
        send_char_gap();
        display_status("T");
        reset_signals();

        $display("\n--- TWO SYMBOL DECODING ---");
        $display("Test Case 4: Decode A (dot dash)");
        fsm_enable = 1;
        send_dot(); send_dash();
        send_char_gap();
        display_status("A");
        reset_signals();

        $display("Test Case 5: Decode N (dash dot)");
        fsm_enable = 1;
        send_dash(); send_dot();
        send_char_gap();
        display_status("N");
        reset_signals();

        $display("Test Case 6: Decode W (dot dash dash)");
        fsm_enable = 1;
        send_dot(); send_dash(); send_dash();
        send_char_gap();
        display_status("W");
        reset_signals();

        $display("\n--- THREE SYMBOL DECODING ---");
        $display("Test Case 7: Decode S (dot dot dot)");
        fsm_enable = 1;
        send_dot(); send_dot(); send_dot();
        send_char_gap();
        display_status("S");
        reset_signals();

        $display("Test Case 8: Decode O (dash dash dash)");
        fsm_enable = 1;
        send_dash(); send_dash(); send_dash();
        send_char_gap();
        display_status("O");
        reset_signals();

        $display("Test Case 9: Decode D (dash dot dot)");
        fsm_enable = 1;
        send_dash(); send_dot(); send_dot();
        send_char_gap();
        display_status("D");
        reset_signals();

        $display("\n--- EDGE CASES ---");
        $display("Test Case 10: char_ready pulses for one cycle only");
        fsm_enable = 1;
        send_dot();
        send_char_gap();
        // Wait until char_ready goes high then check it falls next cycle
        while(!char_ready) @(posedge clk);
        @(posedge clk);
        $display("Time: %0t | char_ready after one cycle: %b | Result: %s",
                  $time, char_ready, (char_ready === 0) ? "SUCCESS" : "FAIL");
        reset_signals();

        $display("Test Case 11: Back-to-back decode S then O (SOS)");
        fsm_enable = 1;
        send_dot(); send_dot(); send_dot();
        send_char_gap();
        display_status("S");
        send_dash(); send_dash(); send_dash();
        send_char_gap();
        display_status("O");
        reset_signals();

        $display("\nAll Test Cases Completed!");
        $finish;
    end
endmodule