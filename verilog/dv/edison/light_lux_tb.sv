module tb_dd_lux();
    parameter BIT_WIDTH = 12;
    parameter CLK_PERIOD = 10;
    parameter AVG_WINDOW = 16;

    logic clk, nrst;
    logic start, comp_in;
    logic sah_en, data_ready;
    logic [BIT_WIDTH-1:0] dac_out, adc_out;
    logic [3:0] seg_ones, seg_tens, seg_hundreds, seg_thousands;

    sar_adc_controller #(.BIT_WIDTH, 4) u_adc (.*);
    lux_converter #(.BIT_WIDTH, .AVG_WINDOW) u_lux (.*);

    // Clock Generation
    initial clk = 0;
    always #(CLK_PERIOD / 2) clk = ~clk;

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

    task test_light_level(input [BIT_WIDTH-1:0] target_analog_value);
        $display("Input ADC %d", target_analog_value);
        repeat(AVG_WINDOW * 2) begin
            simulate_adc_cycle(target_analog_value);
        end
        $display("Segment Display: [%d%d%d%d] Lux\n", seg_thousands, seg_hundreds, seg_tens, seg_ones);
    endtask

    task reset_signals();
        nrst = 0;
        #(CLK_PERIOD);
        nrst = 1;
    endtask

    initial begin
        nrst = 0; start = 0; comp_in = 0;
        #(CLK_PERIOD * 5) nrst = 1;
        @(posedge clk);

        $display("Test Case 1: Steady Light");
        test_light_level(12'd2000); // 2000 * (312 / 128) = 4875 Lux expected
        reset_signals();

        $display("Test Case 2: Dark Environment");
        test_light_level(12'd40); // ~97 (97.5) Lux expected - floor down
        reset_signals();

        $display("Test Case 3: Fluctuating Light");
        repeat(AVG_WINDOW / 2) begin
            simulate_adc_cycle(12'd500); // 1218 Lux
            simulate_adc_cycle(12'd750); // 1828 Lux
        end
        $display("Segment Display: [%d%d%d%d] Lux (Averaged)\n", seg_thousands, seg_hundreds, seg_tens, seg_ones);
        reset_signals();

        $display("Test Case 4: Max Brightness");
        test_light_level(12'hFFF); // adc_out 4095 - (expect 9999)
        reset_signals(); // result: only 9981 :(((

        $display("\nAll Test Cases Completed!");
        $finish;
    end
endmodule