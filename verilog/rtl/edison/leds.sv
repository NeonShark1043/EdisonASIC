`default_nettype none
module led
(
    input  logic clk, n_rst,
    input  logic [11:0] light_diff,   
    output logic [9:0] led
);

always_comb begin
    if      (light_diff >= 12'd100) led = 10'b1111111111;
    else if (light_diff >= 12'd90)  led = 10'b0111111111;
    else if (light_diff >= 12'd80)  led = 10'b0011111111;
    else if (light_diff >= 12'd70)  led = 10'b0001111111;
    else if (light_diff >= 12'd60)  led = 10'b0000111111;
    else if (light_diff >= 12'd50)  led = 10'b0000011111;
    else if (light_diff >= 12'd40)  led = 10'b0000001111;
    else if (light_diff >= 12'd30)  led = 10'b0000000111;
    else if (light_diff >= 12'd20)  led = 10'b0000000011;
    else if (light_diff >= 12'd10)  led = 10'b0000000001;
    else                            led = 10'b0000000000;
end

endmodule
