module tb_morse_fsm();
    parameter DOT_MAX   = 10;
    parameter GAP_LIMIT = 30;
    parameter CLK_PERIOD = 10;
 
    logic       clk, nrst;
    logic       fsm_enable, light_on;
    logic [7:0] ascii_char;
    logic       char_ready;
 
    // Module Instantiation
    morse_fsm #(.DOT_MAX(DOT_MAX), .GAP_LIMIT(GAP_LIMIT)) u_morse (.*);
 
    // Clock Generation
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;
 
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
 
    // Helper Task: Hold light off long enough to trigger inter-character gap
    task send_char_gap();
        light_on = 0;
        repeat(GAP_LIMIT + 10) @(posedge clk);
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
 
    // GTKWave Dump
    initial begin
        $dumpfile("tb_morse_fsm.vcd");
        $dumpvars(0, tb_morse_fsm);
    end
 
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
 
        $display("\n--- THREE SYMBOL DECODING ---");
        $display("Test Case 6: Decode S (dot dot dot)");
        fsm_enable = 1;
        send_dot(); send_dot(); send_dot();
        send_char_gap();
        display_status("S");
        reset_signals();
 
        $display("Test Case 7: Decode O (dash dash dash)");
        fsm_enable = 1;
        send_dash(); send_dash(); send_dash();
        send_char_gap();
        display_status("O");
        reset_signals();
 
        $display("Test Case 8: Decode D (dash dot dot)");
        fsm_enable = 1;
        send_dash(); send_dot(); send_dot();
        send_char_gap();
        display_status("D");
        reset_signals();
 
        $display("\n--- NUMBER DECODING ---");
        $display("Test Case 9: Decode 5 (dot dot dot dot dot)");
        fsm_enable = 1;
        send_dot(); send_dot(); send_dot(); send_dot(); send_dot();
        send_char_gap();
        display_status("5");
        reset_signals();
 
        $display("Test Case 10: Decode 0 (dash dash dash dash dash)");
        fsm_enable = 1;
        send_dash(); send_dash(); send_dash(); send_dash(); send_dash();
        send_char_gap();
        display_status("0");
        reset_signals();
 
        $display("Test Case 11: Decode 1 (dot dash dash dash dash)");
        fsm_enable = 1;
        send_dot(); send_dash(); send_dash(); send_dash(); send_dash();
        send_char_gap();
        display_status("1");
        reset_signals();
 
        $display("\n--- EDGE CASES ---");
        $display("Test Case 12: char_ready pulses for one cycle only");
        fsm_enable = 1;
        send_dot();
        send_char_gap();
        while(!char_ready) @(posedge clk);
        @(posedge clk);
        $display("Time: %0t | char_ready after one cycle: %b | Result: %s",
                  $time, char_ready, (char_ready === 0) ? "SUCCESS" : "FAIL");
        reset_signals();
 
        $display("Test Case 13: Null node returns 8'h00 (dot dot dash dash)");
        fsm_enable = 1;
        send_dot(); send_dot(); send_dash(); send_dash();
        send_char_gap();
        $display("Time: %0t | Expected: NULL | ascii_char: 8'h%0h | char_ready: %b | Result: %s",
                  $time, ascii_char, char_ready,
                  (char_ready && ascii_char === 8'h00) ? "SUCCESS" : "FAIL");
        reset_signals();
 
        $display("Test Case 14: Back-to-back decode S then O (SOS)");
        fsm_enable = 1;
        send_dot(); send_dot(); send_dot();
        send_char_gap();
        display_status("S");
        send_dash(); send_dash(); send_dash();
        send_char_gap();
        display_status("O");
        reset_signals();
 
        $display("Test Case 15: fsm_enable goes LOW mid-sequence resets FSM");
        fsm_enable = 1;
        send_dot(); send_dot(); // halfway through S
        fsm_enable = 0;         // disable mid-sequence
        send_char_gap();
        $display("Time: %0t | char_ready: %b | Result: %s",
                  $time, char_ready, (char_ready === 0) ? "SUCCESS" : "FAIL");
        reset_signals();
 
        $display("\nAll Test Cases Completed!");
        $finish;
    end
endmodule