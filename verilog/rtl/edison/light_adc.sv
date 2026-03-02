module sar_adc_controller #(
    parameter BIT_WIDTH = 12,
    parameter WAIT_CYCLES = 4 // Settling time for analog components
)(
    input logic clk,
    input logic nrst,
    input logic start, // Trigger conversion
    input logic comp_in, // From physical Comparator
    output logic sah_en, // To Sample & Hold Switch
    output logic [BIT_WIDTH-1:0] dac_out, // To R-2R Ladder (7-bit?)
    output logic [BIT_WIDTH-1:0] adc_out, // Final stable reading
    output logic data_ready
);

    // State Encoding
    typedef enum logic [2:0]{
        IDLE = 3'b000,
        SAMPLE = 3'b001,
        TEST = 3'b010,
        COMPARE = 3'b011,
        CHECK = 3'b100,
        NEXT = 3'b101,
        DONE = 3'b111
    } state_t;

    state_t current_state, next_state;

    // Internal Registers
    logic [BIT_WIDTH-1:0] sar_reg;
    logic [3:0] bit_index, wait_counter;

    // State Transition Logic
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) current_state <= IDLE;
        else current_state <= next_state;
    end

    // Next State Logic
    always_comb begin
        next_state = current_state;
        case(current_state)
            IDLE: if(start) next_state = SAMPLE;
            SAMPLE: if(wait_counter == WAIT_CYCLES) next_state = TEST;
            TEST: next_state = COMPARE;
            COMPARE: if(wait_counter == WAIT_CYCLES) next_state = CHECK;
            CHECK: next_state = NEXT;
            NEXT: if(bit_index == 0) next_state = DONE;
            else next_state = TEST;
            DONE: if(start) next_state = SAMPLE;
            else next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Control Path Logic
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) begin
            sar_reg <= '0;
            bit_index <= BIT_WIDTH - 1;
            wait_counter <= '0;
            adc_out <= '0;
            data_ready <= 0;
            sah_en <= 0;
        end else begin
            case(current_state)
                IDLE: begin
                    data_ready <= 0;
                    wait_counter <= '0;
                    bit_index <= BIT_WIDTH - 1;
                    sar_reg <= '0;
                    sah_en <= 0;
                end

                SAMPLE: begin
                    data_ready <= 0;
                    sar_reg <= '0;
                    bit_index <= BIT_WIDTH - 1;
                    sah_en <= 1; // Close S&H Switch
                    wait_counter <= wait_counter + 1; // Wait to capture light voltage
                end

                TEST: begin
                    sah_en <= 0;
                    wait_counter <= '0; // Reset for reuse in the next state
                    sar_reg[bit_index] <= 1;
                end

                COMPARE: begin
                    wait_counter <= wait_counter + 1; // Wait for comparator input
                end

                CHECK: begin
                    if(comp_in == 0) sar_reg[bit_index] <= 0;
                end

                NEXT: begin
                    if(bit_index > 0) bit_index <= bit_index - 1;
                end

                DONE: begin
                    adc_out <= sar_reg;
                    data_ready <= 1;
                    wait_counter <= '0; // Reset for potential loop
                end

                default: begin
                    sar_reg <= '0;
                    bit_index <= BIT_WIDTH - 1;
                    wait_counter <= '0;
                end
            endcase
        end
    end

    assign dac_out = sar_reg;
endmodule