module light_process_tb();
    parameter BIT_WIDTH = 12;
    parameter CLK_PERIOD = 10;

    logic clk, nrst;
    logic start, comp_in, calibrate;
    logic sah_en, data_ready, light_on;
    logic [BIT_WIDTH-1:0] dac_out, adc_out, light_diff, light_led;

    // Module Instantiations
    sar_adc_controller #(.BIT_WIDTH, 4) u_adc (.*);
    light_processor #(.BIT_WIDTH, 16, 50) u_processor (.*);

    // Clock Generation
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Helper Task: Simulates the Analog/Digital handshake for one ADC sample
    task simulate_adc_cycle(input [BIT_WIDTH-1:0] target_analog_value);
        start = 1;
        #(CLK_PERIOD);
        start = 0;
        // The ADC FSM will cycle through bits and mock the comparator response based on the bit guess
        while(!data_ready) begin
            @(posedge clk);
            comp_in = (target_analog_value >= dac_out); // Binary Search Logic
        end
        @(posedge clk); // Allow data_ready to pulse
    endtask

    task display_status(input logic expect_on); // Output Monitoring and Verification Task
        #(CLK_PERIOD);
        $display("Time: %0t | Threshold: %d | Light_On: %b | Light_Diff: %d | Result: %s", 
                  $time, u_processor.threshold_set, light_on, light_diff, (light_on === expect_on) ? "SUCCESS" : "FAIL");
    endtask

    task reset_signals();
        nrst = 0;
        #(CLK_PERIOD);
        nrst = 1;
    endtask

    initial begin
    $dumpfile("support/waves/edison/light_process.vcd");
    $dumpvars(0, light_process_tb);
        nrst = 0; start = 0; comp_in = 0; calibrate = 0;
        #(CLK_PERIOD * 5) nrst = 1;

        $display("\n--- CALIBRATE OFF ---"); // threshold_set = 0
        $display("Test Case 1: Steady Light");
        repeat(20) simulate_adc_cycle(12'd500);
        display_status(1);

        reset_signals();
        $display("Test Case 2: Fluctuating Light Failing Hysteresis");
        repeat(5) begin // Oscillate 540 <-> 510. Diff is 40-10 vs 50 hyst threshold
            simulate_adc_cycle(12'd60);
            simulate_adc_cycle(12'd20);
        end
        display_status(0); // Expected: hys_counter never hits 8 so light_on should be 0

        reset_signals();
        $display("Test Case 3: Fluctuating Light Passing Hysteresis");
        repeat(10) begin // Oscillate 600 <-> 560. Diff is 100-60 vs 50 hyst threshold
            simulate_adc_cycle(12'd600);
            simulate_adc_cycle(12'd560);
        end
        display_status(1); // Expected: hys counter accumulates more "high" hits than "low" drops, eventually saturating at 8

        reset_signals();
        $display("\n--- CALIBRATE ON ---");
        $display("Test Case 4: Raising Threshold Failing Updated Threshold");
        calibrate = 1;
        repeat(20) simulate_adc_cycle(12'd1000);
        calibrate = 0;
        repeat(5) simulate_adc_cycle(12'd970);
        display_status(0);

        reset_signals();
        $display("Test Case 5: Fluctuating Light Passing Updated Threshold");
        calibrate = 1;
        repeat(20) begin // Update threshold even during fluctuations - will settle ~2000
            simulate_adc_cycle(12'd2050);
            simulate_adc_cycle(12'd1950);
        end
        calibrate = 0;
        repeat(35) simulate_adc_cycle(12'd2100); // Test with signal clearly above baseline
        display_status(1);

        reset_signals();
        $display("Test Case 6: Fluctuating Light Failing Updated Threshold");
        calibrate = 1;
        repeat(20) begin // Update threshold even during fluctuations - will settle ~3000
            simulate_adc_cycle(12'd3080);
            simulate_adc_cycle(12'd2920);
        end
        calibrate = 0;
        repeat(25) simulate_adc_cycle(12'd3030); // Test with signal slightly above baseline but within hysteresis
        display_status(0);

        $display("\nAll Test Cases Completed!");
        $finish;
    end
endmodule