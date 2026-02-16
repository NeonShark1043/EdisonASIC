module pwm
(
    input logic clk, n_rst,
    output logic led
);
    
logic [7:0] counter, counter_n;

always_ff @(posedge clk, negedge n_rst) begin
    if (!n_rst) begin
        counter <= 0;
    end else begin
        counter <= counter_n;
    end
end

always_comb begin
    if (counter < 100) begin
        counter_n = counter +1;
    end else begin
        counter_n = 0;
    end
end

assign led=(counter<20) ? 1:0;

endmodule
