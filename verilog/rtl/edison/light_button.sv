`timescale 1ns / 1ps
module soc_button #(
    parameter HOLD_MAX = 10
)(
    input logic clk,
    input logic nrst,
    input logic push_button, // To output start
    input logic blank_button, // To output calibrate
    output logic start, // Trigger ADC FSM
    output logic calibrate, // Trigger Light Processor calibration
    output logic seg_mode // Output choices of displaying Lux (0) or Morse (1)
);
    logic [3:0] hold_counter;
    logic push_rise, push_fall;
    logic blank_rise, blank_fall;
    logic rst;

    edge_detect push_edge (
        .reset(!nrst),
        .signal_in(push_button),
        .rising_edge(push_rise),
        .falling_edge(push_fall),
        .*
    );

    edge_detect blank_edge (
        .reset(!nrst),
        .signal_in(blank_button),
        .rising_edge(blank_rise),
        .falling_edge(blank_fall),
        .*
    );

    assign calibrate = blank_rise;

    // Note: It would be physically hard to accurately press both buttons and detect their rising edges at the same clock cycle
    // Hence, Toggle Output Mode when one button is PRESSED while the other is HELD
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) seg_mode <= 0;
        else if((push_button && blank_rise) || (blank_button && push_rise)) seg_mode <= ~seg_mode;
    end

    // State Encoding
    typedef enum logic [1:0] {
        IDLE = 2'b00,
        HOLD = 2'b01,
        PULSE = 2'b10
    } state_t;
    state_t current_state, next_state;

    // State Transition Logic
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic
    always_comb begin
        next_state = current_state;
        case(current_state)
            IDLE: if(push_button) next_state = HOLD;
            HOLD: if(!push_button) next_state = IDLE;
            else if(hold_counter >= 4'(HOLD_MAX)) next_state = PULSE;
            PULSE: if(!push_button) next_state = IDLE; // Wait for release to prevent re-triggering
            default: next_state = IDLE;
        endcase
    end

    // Control Path Logic
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) begin
            hold_counter <= '0; start <= 0;
        end else begin
            case(current_state)
                IDLE: begin
                    hold_counter <= '0;
                    start <= 0;
                end
                HOLD: begin
                    if(hold_counter < 4'hF) hold_counter <= hold_counter + 1'b1;
                    start <= 0;
                end
                PULSE: begin
                    if(hold_counter != 4'hF) begin
                        start <= 1;
                        hold_counter <= 4'hF; // Check for max counter to pulse for only one cycle
                        // Else, start would stay high as long as the button is held (stuck in PULSE). This would cause the FSMs to reset numerous times
                    end else begin
                        start <= 0;
                    end
                end
                default: begin
                    hold_counter <= '0;
                    start <= 0;
                end
            endcase
        end
    end

endmodule