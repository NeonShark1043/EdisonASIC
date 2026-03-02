// Simulates the analog environment by providing a "mock" comparator signal based on a target analog value
module tb_sar_adc();
    parameter BIT_WIDTH = 12;
    parameter CLK_PERIOD = 10;

    logic clk, nrst;
    logic start, comp_in;
    logic sah_en, data_ready;
    logic [BIT_WIDTH-1:0] dac_out;
    logic [BIT_WIDTH-1:0] adc_out;

    // Testbench Variables - Target Value to Simulate
    logic [BIT_WIDTH-1:0] target_analog_value;

    // Instantiate Design Under Test (DUT)
    sar_adc_controller #(
        .BIT_WIDTH(12),
        .WAIT_CYCLES(2) // Shortened for Faster Simulation
    ) dut (.*);

    // Clock Generation (100 MHz)
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Mock Analog Comparator Logic
    assign comp_in = (dac_out <= target_analog_value);

    // Monitor Task: Displays FSM behavior in a tabular format
    task display_table_header();
        $display("\nTime | Index | DAC Guess | Comp Result | SAR Reg (Bin)");
        $display("-----|-------|-----------|-------------|-----------------");
    endtask

    initial begin
        $dumpfile("waveform_adc.vcd");
        $dumpvars(0, tb_sar_adc);
    end

    initial begin
        clk = 0;
        nrst = 0;
        target_analog_value = 12'b000;

        #(CLK_PERIOD * 2) nrst = 1;
        #(CLK_PERIOD * 2) start = 1; // Begin Continuous Conversion

        // Test Loop - 3 Randomized Conversions
        repeat(3) begin
            // Randomize the "Physical Light Level"
            target_analog_value = 12'($urandom_range(0, 4095));
            $display("\n--- Starting Conversion for Target: %d (%b) ---", target_analog_value, target_analog_value);
            display_table_header();

            // Monitor the SAR Logic until data_ready is Pulsed
            while(!data_ready) begin
                @(posedge clk);
                // Only display during the CHECK state where the bit decision is finalized
                if(dut.current_state == 4) begin
                    $display("%-4t | %-5d | %-9d | %-11b | %b", $time, dut.bit_index, dac_out, comp_in, dut.sar_reg);
                end
            end

            // Result Verification
            if(adc_out == target_analog_value) begin
                $display(">>> SUCCESS: ADC matched Target (%d)\n", adc_out);
            end else begin
                $display(">>> FAILURE: ADC Result %d != Target %d (Diff: %d)\n", adc_out, target_analog_value, (target_analog_value - adc_out));
            end

            @(posedge clk); // Wait for DONE to clear or loop
        end
        
        #(CLK_PERIOD * 9) start = 0;
        #(CLK_PERIOD * 9) $finish;
    end
endmodule