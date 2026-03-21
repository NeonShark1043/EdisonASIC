`timescale 1ns / 1ps
module tb_soc_button();
    parameter CLK_PERIOD = 10;
    parameter HOLD_MAX = 5; // Smaller for faster simulation

    logic clk, nrst;
    logic push_button, blank_button;
    logic start, calibrate, seg_mode;

    soc_button #(.HOLD_MAX(HOLD_MAX)) u_button (.*);

    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_soc_button);
        nrst = 0; push_button = 0; blank_button = 0;
        #(CLK_PERIOD * 2) nrst = 1;

        $display("Test Case 1: Testing Start Pulse");
        push_button = 1;
        repeat(HOLD_MAX * 3) @(posedge clk); // Wait for long
        if(start) $display("  [PASS]: Start signal logic reached and maintained.");
        else $display("  [FAIL]: Start signal did not pulse.");
        
        push_button = 0; repeat(2) @(posedge clk);

        $display("Test Case 2: Testing Calibration Rising Edge");
        blank_button = 1;
        @(posedge clk);
        if(calibrate) $display("  [PASS]: Calibrate signal pulsed.");
        else $display("  [FAIL]: Calibrate signal missed.");
        
        blank_button = 0; repeat(5) @(posedge clk);

        $display("Test Case 3.1: Morse Mode Toggle (Hold Blank, Tap Push)");
        push_button = 0;
        blank_button = 1;
        repeat(10) @(posedge clk);
        
        push_button = 1; // Trigger toggle seg_mode to 1
        repeat(3) @(posedge clk);
        push_button = 0;
        blank_button = 0;

        repeat(2) @(posedge clk); // Signal start must still stay on HIGH (only PRESS not HOLD)
        if(seg_mode == 1 && start) $display("  [PASS]: seg_mode toggled to Morse.");
        else $display("  [FAIL]: seg_mode or start failed.");

        $display("Test Case 3.2: Lux Mode Toggle (Hold Blank, Tap Push)");
        push_button = 0;
        blank_button = 1;
        repeat(10) @(posedge clk);
        
        push_button = 1; // Trigger toggle seg_mode to 0
        repeat(3) @(posedge clk);
        push_button = 0;
        blank_button = 0;
        repeat(2) @(posedge clk); // Signal start must still stay on HIGH (only PRESS not HOLD)
        if(seg_mode == 0 && start) $display("  [PASS]: seg_mode toggled to Lux.");
        else $display("  [FAIL]: seg_mode or start failed.");

        $display("Test Case 4: Shutdown Start Pulse");
        push_button = 1;
        repeat(HOLD_MAX * 2) @(posedge clk);
        if(start) $display("  [FAIL]: Start still remains active.");
        else $display("  [PASS]: Start switched to low successfully.");

        push_button = 0; repeat(2) @(posedge clk);

        $display("Test Case 5: Testing Short Press");
        push_button = 1;
        repeat(HOLD_MAX - 2) @(posedge clk);
        push_button = 0; @(posedge clk);
        if(start) $display("  [FAIL]: Start pulsed on short press.");
        else $display("  [PASS]: Start remained low as expected.");

        $display("--- All Test Cases Completed ---");
        $finish;
    end
endmodule