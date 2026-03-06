`default_nettype none
`timescale 1ns / 1ps

module led_tb;
    logic clk;
    logic n_rst;
    logic [11:0] light_diff;
    logic [9:0] led;

    led dut (
        .light_diff(light_diff),
        .led(led)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100 MHz clock
    end

    initial begin
        $dumpfile("support/waves/edison/led.vcd");
        $dumpvars(0, led_tb);
        // Initialize inputs
        n_rst = 0;
        light_diff = 0;
        #10;
        n_rst = 1;

        // Test cases
        // Below 10: 0 LEDs
        light_diff = 12'd0;
        #10;
        if (led !== 10'b0000000000) $display("FAIL: light_diff=%d, led=%b (expected 0000000000)", light_diff, led);
        else $display("PASS: light_diff=%d, led=%b", light_diff, led);

        light_diff = 12'd9;
        #10;
        if (led !== 10'b0000000000) $display("FAIL: light_diff=%d, led=%b (expected 0000000000)", light_diff, led);
        else $display("PASS: light_diff=%d, led=%b", light_diff, led);

        // 10-19: 1 LED
        light_diff = 12'd10;
        #10;
        if (led !== 10'b0000000001) $display("FAIL: light_diff=%d, led=%b (expected 0000000001)", light_diff, led);
        else $display("PASS: light_diff=%d, led=%b", light_diff, led);

        light_diff = 12'd19;
        #10;
        if (led !== 10'b0000000001) $display("FAIL: light_diff=%d, led=%b (expected 0000000001)", light_diff, led);
        else $display("PASS: light_diff=%d, led=%b", light_diff, led);

        // 20-29: 2 LEDs
        light_diff = 12'd20;
        #10;
        if (led !== 10'b0000000011) $display("FAIL: light_diff=%d, led=%b (expected 0000000011)", light_diff, led);
        else $display("PASS: light_diff=%d, led=%b", light_diff, led);

        light_diff = 12'd29;
        #10;
        if (led !== 10'b0000000011) $display("FAIL: light_diff=%d, led=%b (expected 0000000011)", light_diff, led);
        else $display("PASS: light_diff=%d, led=%b", light_diff, led);

        // 30-39: 3 LEDs
        light_diff = 12'd30;
        #10;
        if (led !== 10'b0000000111) $display("FAIL: light_diff=%d, led=%b (expected 0000000111)", light_diff, led);
        else $display("PASS: light_diff=%d, led=%b", light_diff, led);

        light_diff = 12'd39;
        #10;
        if (led !== 10'b0000000111) $display("FAIL: light_diff=%d, led=%b (expected 0000000111)", light_diff, led);
        else $display("PASS: light_diff=%d, led=%b", light_diff, led);

        // 40-49: 4 LEDs
        light_diff = 12'd40;
        #10;
        if (led !== 10'b0000001111) $display("FAIL: light_diff=%d, led=%b (expected 0000001111)", light_diff, led);
        else $display("PASS: light_diff=%d, led=%b", light_diff, led);

        light_diff = 12'd49;
        #10;
        if (led !== 10'b0000001111) $display("FAIL: light_diff=%d, led=%b (expected 0000001111)", light_diff, led);
        else $display("PASS: light_diff=%d, led=%b", light_diff, led);

        // 50-59: 5 LEDs
        light_diff = 12'd50;
        #10;
        if (led !== 10'b0000011111) $display("FAIL: light_diff=%d, led=%b (expected 0000011111)", light_diff, led);
        else $display("PASS: light_diff=%d, led=%b", light_diff, led);

        light_diff = 12'd59;
        #10;
        if (led !== 10'b0000011111) $display("FAIL: light_diff=%d, led=%b (expected 0000011111)", light_diff, led);
        else $display("PASS: light_diff=%d, led=%b", light_diff, led);

        // 60-69: 6 LEDs
        light_diff = 12'd60;
        #10;
        if (led !== 10'b0000111111) $display("FAIL: light_diff=%d, led=%b (expected 0000111111)", light_diff, led);
        else $display("PASS: light_diff=%d, led=%b", light_diff, led);

        light_diff = 12'd69;
        #10;
        if (led !== 10'b0000111111) $display("FAIL: light_diff=%d, led=%b (expected 0000111111)", light_diff, led);
        else $display("PASS: light_diff=%d, led=%b", light_diff, led);

        // 70-79: 7 LEDs
        light_diff = 12'd70;
        #10;
        if (led !== 10'b0001111111) $display("FAIL: light_diff=%d, led=%b (expected 0001111111)", light_diff, led);
        else $display("PASS: light_diff=%d, led=%b", light_diff, led);

        light_diff = 12'd79;
        #10;
        if (led !== 10'b0001111111) $display("FAIL: light_diff=%d, led=%b (expected 0001111111)", light_diff, led);
        else $display("PASS: light_diff=%d, led=%b", light_diff, led);

        // 80-89: 8 LEDs
        light_diff = 12'd80;
        #10;
        if (led !== 10'b0011111111) $display("FAIL: light_diff=%d, led=%b (expected 0011111111)", light_diff, led);
        else $display("PASS: light_diff=%d, led=%b", light_diff, led);

        light_diff = 12'd89;
        #10;
        if (led !== 10'b0011111111) $display("FAIL: light_diff=%d, led=%b (expected 0011111111)", light_diff, led);
        else $display("PASS: light_diff=%d, led=%b", light_diff, led);

        // 90-99: 9 LEDs
        light_diff = 12'd90;
        #10;
        if (led !== 10'b0111111111) $display("FAIL: light_diff=%d, led=%b (expected 0111111111)", light_diff, led);
        else $display("PASS: light_diff=%d, led=%b", light_diff, led);

        light_diff = 12'd99;
        #10;
        if (led !== 10'b0111111111) $display("FAIL: light_diff=%d, led=%b (expected 0111111111)", light_diff, led);
        else $display("PASS: light_diff=%d, led=%b", light_diff, led);

        // 100+: 10 LEDs
        light_diff = 12'd100;
        #10;
        if (led !== 10'b1111111111) $display("FAIL: light_diff=%d, led=%b (expected 1111111111)", light_diff, led);
        else $display("PASS: light_diff=%d, led=%b", light_diff, led);

        light_diff = 12'd200;
        #10;
        if (led !== 10'b1111111111) $display("FAIL: light_diff=%d, led=%b (expected 1111111111)", light_diff, led);
        else $display("PASS: light_diff=%d, led=%b", light_diff, led);

        // Edge case: Max value
        light_diff = 12'd4095;
        #10;
        if (led !== 10'b1111111111) $display("FAIL: light_diff=%d, led=%b (expected 1111111111)", light_diff, led);
        else $display("PASS: light_diff=%d, led=%b", light_diff, led);

        // Finish simulation
        #10;
        $display("All tests completed.");
        $finish;
    end

endmodule
