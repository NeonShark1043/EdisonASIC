
'timescale 1ns/ 1ps

module top(
    input clk
    output led);
    
reg [7:0] counter =0;
always@(posedge clk)begin
    if (counter < 100)counter <=counter +1;
    else counter <=0;
end
assign led=(counter<20) ? 1:0;
end module