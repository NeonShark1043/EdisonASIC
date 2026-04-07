/* SoC Button Controls
1) Kickstart SoC: Hold Push Button
2) Zero Processing Thresholds: Hold Blank Button
3) Toggle Output Mode: Hold Blank and Press Push
4) Shutdown SoC: Hold Push Button again
*/

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

    edge_detector push_edge (
        .nrst(nrst),
        .signal_in(push_button),
        .rising_edge(push_rise),
        .falling_edge(push_fall),
        .*
    );

    assign calibrate = blank_button;

    // Note: It would be physically hard to accurately press both buttons and detect their rising edges at the same clock cycle
    // Hence, Toggle Output Mode when one button is PRESSED while the other is HELD
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) seg_mode <= 0;
        else if(blank_button && push_rise) seg_mode <= ~seg_mode;
    end

    // State Encoding
    typedef enum logic [1:0] {
        IDLE = 2'b00,
        HOLD = 2'b01,
        RESTART = 2'b10,
        RELEASE = 2'b11
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
            else if(hold_counter >= 4'(HOLD_MAX)) next_state = RESTART;
            RESTART: next_state = RELEASE;
            RELEASE: if(!push_button) next_state = IDLE; // Wait for release to prevent re-triggering
            default: next_state = IDLE;
        endcase
    end

    // Control Path Logic
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) begin
            hold_counter <= '0; start <= 0;
        end else begin
            case(current_state)
                IDLE: hold_counter <= '0;
                HOLD: hold_counter <= hold_counter + 1'b1;
                RESTART: begin
                    start <= ~start; // Turn ON if OFF, turn OFF if ON
                    // Note: Remove resetting start in other states because start must stay on HIGH
                    // So that the FSMs can conduct their continuous operations, else they would reset numerous times.
                    hold_counter <= '0;
                end
                RELEASE: hold_counter <= '0;
                default: begin
                    hold_counter <= '0; 
                    start <= 0;
                end
            endcase
        end
    end

endmodule