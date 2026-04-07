module led_bar_driver(
    input  logic clk, nrst,
    input  logic [11:0] light_diff,   
    output logic [9:0] led_out
);
    always_comb begin
        if (light_diff >= 12'd100) led_out = 10'b1111111111;
        else if(light_diff >= 12'd90) led_out = 10'b0111111111;
        else if(light_diff >= 12'd80) led_out = 10'b0011111111;
        else if(light_diff >= 12'd70) led_out = 10'b0001111111;
        else if(light_diff >= 12'd60) led_out = 10'b0000111111;
        else if(light_diff >= 12'd50) led_out = 10'b0000011111;
        else if(light_diff >= 12'd40) led_out = 10'b0000001111;
        else if(light_diff >= 12'd30) led_out = 10'b0000000111;
        else if(light_diff >= 12'd20) led_out = 10'b0000000011;
        else if(light_diff >= 12'd10) led_out = 10'b0000000001;
        else led_out = 10'b0000000000;
    end
endmodule