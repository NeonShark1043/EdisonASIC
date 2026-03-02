module soc_button #(
    parameter WAIT_MAX = 10
)(
    input  logic       clk,
    input  logic       nrst,
    input  logic       soc_button,
    output logic       fsm_enable,
    output logic [3:0] wait_counter
);

    // State Encoding
    typedef enum logic [1:0] {
        IDLE    = 2'b00,
        WAITING = 2'b01,
        READY   = 2'b10
    } state_t;
    state_t current_state, next_state;

    // State Transition Logic
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) current_state <= IDLE;
        else current_state <= next_state;
    end

    // Next State Logic
    always_comb begin
        next_state = current_state;
        case(current_state)
            IDLE:    if(soc_button) next_state = WAITING;
            WAITING: if(!soc_button) next_state = IDLE;
                     else if(wait_counter >= WAIT_MAX) next_state = READY;
            READY:   if(!soc_button) next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Control Path Logic
    always_comb begin
        if(!nrst) begin
            wait_counter = '0;
            fsm_enable   = 0;
        end else begin
            case(current_state)
                IDLE: begin
                    wait_counter = '0;
                    fsm_enable   = 0;
                end
                WAITING: begin
                    wait_counter = wait_counter + 1;
                    fsm_enable   = 0;
                end
                READY: begin
                    fsm_enable = 1;
                end
                default: begin
                    wait_counter = '0;
                    fsm_enable   = 0;
                end
            endcase
        end
    end

endmodule