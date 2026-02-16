module edge_detect (
    input  logic clk,
    input  logic reset,
    input  logic signal_in,
    output logic rising_edge,
    output logic falling_edge
);

logic signal_d;

always_ff @(posedge clk or posedge reset) begin
    if (reset)
        signal_d <= 0;
    else
        signal_d <= signal_in;
end

assign rising_edge  =  signal_in & ~signal_d;
assign falling_edge = ~signal_in &  signal_d;

endmodule