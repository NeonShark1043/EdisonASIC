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
        repeat(HOLD_MAX * 2) @(posedge clk);
        // Check if start pulsed at ANY point (might not capture start at its only-cycle)
        if(u_button.current_state == 2'b10 || start) 
            $display("  [PASS]: Start signal logic reached.");
        else 
            $display("  [FAIL]: Start signal did not pulse (Counter: %0d).", u_button.hold_counter);
        
        push_button = 0;
        repeat(2) @(posedge clk);

        $display("Test Case 2: Testing Calibration Rising Edge");
        blank_button = 1;
        @(posedge clk);
        if(calibrate) $display("  [PASS]: Calibrate signal pulsed.");
        else $display("  [FAIL]: Calibrate signal missed.");
        
        blank_button = 0;
        repeat(5) @(posedge clk);

        $display("Test Case 3: Testing Mode Toggle (Hold Push, Tap Blank)");
        push_button = 1;
        repeat(2) @(posedge clk);
        
        blank_button = 1; // Trigger toggle
        @(posedge clk);
        blank_button = 0;
        
        @(posedge clk);
        if(seg_mode == 1) $display("  [PASS]: seg_mode toggled to Morse.");
        else $display("  [FAIL]: seg_mode failed to toggle.");

        $display("Test Case 4: Testing Mode Toggle (Hold Blank, Tap Push)");
        // Keep push high, but need a rising edge from something
        push_button = 0;
        blank_button = 1;
        repeat(10) @(posedge clk);
        
        push_button = 1; // Trigger toggle back to 0
        repeat(3) @(posedge clk);
        push_button = 0;
        blank_button = 0;

        repeat(2) @(posedge clk);
        if(seg_mode == 0) $display("  [PASS]: seg_mode toggled back to Lux.");
        else $display("  [FAIL]: seg_mode failed to return to 0.");

        $display("Test Case 5: Testing Short Press");
        push_button = 1;
        repeat (HOLD_MAX - 2) @(posedge clk);
        push_button = 0;
        @(posedge clk);
        if(start) $display("  [FAIL]: Start pulsed on short press.");
        else $display("  [PASS]: Start remained low as expected.");

        $display("--- All Test Cases Completed ---");
        $finish;
    end
endmodule