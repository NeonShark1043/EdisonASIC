module edge_detect (
    input  logic clk,
    input  logic reset,
    input  logic signal_in,
    output logic rising_edge,
    output logic falling_edge
);


logic signal_d;
logic signal_e;


always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
        signal_d <= 0;
        signal_e <= 0;
    end else begin
        signal_d <= signal_in;
        signal_e <= signal_d;
    end
end


assign rising_edge  =  signal_d & ~signal_e;
assign falling_edge = ~signal_d &  signal_e;


endmodule
