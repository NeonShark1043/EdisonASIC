
module edge_detector (
    input logic clk,
    input logic nrst,
    input logic signal_in,
    output logic rising_edge,
    output logic falling_edge
);

    logic signal_d;
    logic signal_e;

    always_ff @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            signal_d <= 0;
            signal_e <= 0;
        end else begin
            signal_d <= signal_in;
            signal_e <= signal_d;
        end
    end

    assign rising_edge = signal_d & ~signal_e;
    assign falling_edge = ~signal_d &  signal_e;
endmodule
