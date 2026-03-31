module tb_dd_lux();
    parameter BIT_WIDTH = 12;
    parameter BCD_WIDTH = 4;
    parameter CLK_PERIOD = 10;
    parameter HOLD_MAX = 10;
    parameter AVG_WINDOW = 16;

    logic clk, nrst;
    wire start;
    logic push_button, blank_button, calibrate, seg_mode;
    logic comp_in, sah_en, data_ready;
    logic [BIT_WIDTH-1:0] dac_out, adc_out;
    logic [BCD_WIDTH-1:0] seg_ones, seg_tens, seg_hundreds, seg_thousands;

    soc_button #(HOLD_MAX) u_button (.*);
    sar_adc_controller #(BIT_WIDTH, 4) u_adc (.*);
    lux_converter #(BIT_WIDTH, BCD_WIDTH, AVG_WINDOW) u_lux (.*);

    // Clock Generation
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    task restart_button(input int start_check); 
        // Call the first time to set start HIGH, call the second time to set start LOW
        push_button = 1; repeat(HOLD_MAX * 3) @(posedge clk);
        if(start_check == 1) begin
            if(start) $display("[BUTTON]: Start signal logic detected and maintained.");
            else $display("[BUTTON]: Start signal did not pulse.");
        end else begin
            if(!start) $display("[BUTTON]: Start signal logic remained low successfully.");
            else $display("[BUTTON]: Start signal is still active.");
        end
        push_button = 0; repeat(2) @(posedge clk);
    endtask

    task simulate_adc_cycle(input [BIT_WIDTH-1:0] target_analog_value);
        // The ADC FSM will cycle through bits and mock the comparator response based on the bit guess
        while(!data_ready) begin
            @(posedge clk);
            comp_in = (target_analog_value >= dac_out); // Binary Search Logic
        end
        @(posedge clk); // Allow data_ready to pulse
        // $display("[ADC] Completed Output %d", adc_out);
    endtask

    task test_light_level(input [BIT_WIDTH-1:0] target_analog_value);
        $display("[ADC] Received Input %d", target_analog_value);
        repeat(AVG_WINDOW * 2) begin
            simulate_adc_cycle(target_analog_value);
            // $display("[LUX] Sum Accumulation: %d", u_lux.sum_acc);
        end
        $display("[LUX] Average Accumulation: %d", u_lux.avg_acc);
        $display("Segment Display: [%d%d%d%d] Lux\n", seg_thousands, seg_hundreds, seg_tens, seg_ones);
    endtask

    task reset_signals();
        nrst = 0;
        #(CLK_PERIOD);
        nrst = 1;
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_dd_lux);
        reset_signals();

        restart_button(1);
        $display("Test Case 1: Steady Light");
        test_light_level(12'd2000); // 2000 * (312 / 128) = 4875 Lux expected
        reset_signals();

        restart_button(1);
        $display("Test Case 2: Dark Environment");
        test_light_level(12'd40); // ~97 (97.5) Lux expected - floor down
        reset_signals();

        restart_button(1);
        $display("Test Case 3: Fluctuating Light");
        repeat(AVG_WINDOW / 2) begin
            simulate_adc_cycle(12'd500); // 1218 Lux
            simulate_adc_cycle(12'd750); // 1828 Lux
        end
        $display("Segment Display: [%d%d%d%d] Lux (Averaged)\n", seg_thousands, seg_hundreds, seg_tens, seg_ones);
        reset_signals();

        restart_button(1);
        $display("Test Case 4: Max Brightness");
        test_light_level(12'hFFF); // adc_out 4095 - (expect 9999) - result: 9997 is the closest we got

        restart_button(0);
        $finish;
    end
endmodule