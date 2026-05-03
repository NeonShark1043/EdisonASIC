module morse_decoder #(
    parameter CLK_FREQ = 100000000, // 100 MHz SoC Clock - all counters reset every 1,000,000 cycles
    parameter TICK_MS = 10, // 1 tick = 10 ms resolution for counters
    parameter DOT_MAX = 200, // < 2000 ms is a dot (.) and > 2100 ms is a dash (_)
    parameter GAP_MAX = 300, // > 3000 ms of silence trigges DECODE
    parameter SPACE_MAX = 500 // // > 5000 ms for letter space
)(
    input logic clk,
    input logic nrst,
    input logic start,
    input logic light_on, // From Light Processing Module
    output logic [7:0] ascii_char, // Decoded Characters
    output logic char_ready // Pulse when character is ready
);

    // State Encoding
    typedef enum logic [2:0] {
        IDLE = 3'b000,
        MARK = 3'b001, // Measuring Light Pulse (Dot/Dash)
        CLASSIFY = 3'b010, // Determining if the Light Pulse is a Dot or Dash
        GAP = 3'b011, // Measuring silence between pulses
        DECODE = 3'b100, // Matching sequences to ASCII
        READY = 3'b101, // Pulsing Output
        SPACE = 3'b110 // Detecting Word Gaps
    } state_t;

    state_t current_state, next_state;

    // Registers
    logic [31:0] tick_counter; // Track how much "real time" has passed relative to the clock frequency (e.g. set 10 ticks in tb = 100 ms)
    logic [5:0] tree_index; // Current position in the binary tree
    logic [15:0] mark_counter, gap_counter;
    logic tick_en; // HIGH for exactly one clock cycle every time the tick_counter reaches its target. This creates a periodic "heartbeat" (every 10ms) that the rest of FSM uses to increment the duration counters (mark_counter and gap_counter)

    // Tree Memory - 63 entries to cover up to 5 levels of Morse (A-Z, 0-9)
    function automatic [7:0] morse_tree(input [5:0] index);
        case(index)
            // Level 2 (1 Symbol)
            6'd2: morse_tree = 8'h45; // E (.)
            6'd3: morse_tree = 8'h54; // T (-)
            // Level 3 (2 Symbols)
            6'd4: morse_tree = 8'h49; // I (..)
            6'd5: morse_tree = 8'h41; // A (.-)
            6'd6: morse_tree = 8'h4E; // N (-.)
            6'd7: morse_tree = 8'h4D; // M (--)
            // Level 4 (3 Symbols)
            6'd8: morse_tree = 8'h53; // S (...)
            6'd9: morse_tree = 8'h55; // U (..-)
            6'd10: morse_tree = 8'h52; // R (.-.)
            6'd11: morse_tree = 8'h57; // W (.--)
            6'd12: morse_tree = 8'h44; // D (-..)
            6'd13: morse_tree = 8'h4B; // K (-.-)
            6'd14: morse_tree = 8'h47; // G (--.)
            6'd15: morse_tree = 8'h4F; // O (---)
            // Level 5 (4 Symbols)
            6'd16: morse_tree = 8'h48; // H (....)
            6'd17: morse_tree = 8'h56; // V (...-)
            6'd18: morse_tree = 8'h46; // F (..-.)
            6'd20: morse_tree = 8'h4C; // L (.-..)
            6'd22: morse_tree = 8'h50; // P (.--.)
            6'd23: morse_tree = 8'h4A; // J (.---)
            6'd24: morse_tree = 8'h42; // B (-...)
            6'd25: morse_tree = 8'h58; // X (-..-)
            6'd26: morse_tree = 8'h43; // C (-.-.)
            6'd27: morse_tree = 8'h59; // Y (-.--)
            6'd28: morse_tree = 8'h5A; // Z (--..)
            6'd29: morse_tree = 8'h51; // Q (--.-)
            // Level 6 (5 Symbols - Numbers)
            6'd32: morse_tree = 8'h35; // 5 (.....)
            6'd33: morse_tree = 8'h34; // 4 (....-)
            6'd35: morse_tree = 8'h33; // 3 (...--)
            6'd39: morse_tree = 8'h32; // 2 (..---)
            6'd47: morse_tree = 8'h31; // 1 (.----)
            6'd48: morse_tree = 8'h36; // 6 (-....)
            6'd56: morse_tree = 8'h37; // 7 (--...)
            6'd60: morse_tree = 8'h38; // 8 (---..)
            6'd62: morse_tree = 8'h39; // 9 (----.)
            6'd63: morse_tree = 8'h30; // 0 (-----)
            default: morse_tree = 8'h00;
        endcase
    endfunction

    // 10 ms Tick Generator - mark/gap counters increment every 10 ms instead of 10 ns
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) begin
            tick_counter <= 0;
            tick_en <= 0;
        end else if(tick_counter == (CLK_FREQ / 100) - 1) begin
            tick_counter <= 0;
            tick_en <= 1;
        end else begin
            tick_counter <= tick_counter + 1;
            tick_en <= 0;
        end
    end

    // State Transitions
    always_ff @(posedge clk or negedge nrst) begin
        if (!nrst) current_state <= IDLE;
        else current_state <= next_state;
    end

    always_comb begin
        next_state = current_state;
        if(!start) next_state = IDLE;
        case(current_state)
            IDLE: if(light_on) next_state = MARK;
            else if(32'(gap_counter) >= SPACE_MAX) next_state = SPACE;
            MARK: if(!light_on && mark_counter > 0) next_state = CLASSIFY;
            else next_state = MARK;
            CLASSIFY: next_state = GAP;
            GAP: if(light_on) next_state = MARK;
            else if(32'(gap_counter) >= GAP_MAX) next_state = DECODE;
            DECODE: next_state = READY;
            READY: next_state = IDLE;
            SPACE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Tree Traversal Logic
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) begin
            tree_index <= 6'd1; // Start at Root
            mark_counter <= 0; gap_counter <= 0;
            ascii_char <= 0; char_ready <= 0;
        end else begin
            case(current_state)
                IDLE: begin
                    char_ready <= 0;
                    tree_index <= 6'd1;
                    mark_counter <= 0;
                    if(tick_en) gap_counter <= gap_counter + 1;
                end

                MARK: begin
                    if(tick_en) mark_counter <= mark_counter + 1;
                    gap_counter <= 0;
                end

                CLASSIFY: begin
                    // Move Left for Dot, Right for Dash
                    if(mark_counter > 0) begin
                        if(32'(mark_counter) <= DOT_MAX)
                            tree_index <= tree_index << 1; // Left: index * 2
                        else
                            tree_index <= (tree_index << 1) + 1; // Right: index * 2 + 1
                    end
                    mark_counter <= 0;
                end

                GAP: begin
                    mark_counter <= 0;
                    if(tick_en) gap_counter <= gap_counter + 1;
                end

                DECODE: begin
                    ascii_char <= morse_tree(tree_index);
                    gap_counter <= 0;
                end

                READY: begin
                    char_ready <= 1;
                end

                SPACE: begin
                    ascii_char <= 8'd32; // ASCII for Blankspace
                    char_ready <= 1;
                    gap_counter <= 0; // Reset to prevent double spacing
                end

                default: begin
                    tree_index <= 6'd1;
                    mark_counter <= 16'd0;
                    char_ready <= 0;
                end
            endcase
        end
    end
endmodule
