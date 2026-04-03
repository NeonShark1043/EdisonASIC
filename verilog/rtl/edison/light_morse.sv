`timescale 1ns / 1ps
module morse_decoder #(
    parameter CLK_FREQ = 100000000, // 100 MHz SoC Clock - all counters reset every 1,000,000 cycles
    parameter TICK_MS = 10, // 1 tick = 10 ms resolution for counters
    parameter DOT_MAX = 20, // < 200 ms is a dot (.) and > 210 ms is a dash (_)
    parameter GAP_MAX = 60, // > 600 ms of silence trigges DECODE
    parameter SPACE_MAX = 140 // // > 1400 ms for letter space
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
    logic [7:0] morse_tree [0:63];
    initial begin
        for (int i = 0; i < 64; i++) morse_tree[i] = '0;
        // Level 0 & 1
        morse_tree[0] = 8'h00; // Null
        morse_tree[1] = 8'h00; // Root (Start here)

        // Level 2 (1 Symbol)
        morse_tree[2] = 8'h45; // E (.)
        morse_tree[3] = 8'h54; // T (-)

        // Level 3 (2 Symbols)
        morse_tree[4] = 8'h49; // I (..)
        morse_tree[5] = 8'h41; // A (.-)
        morse_tree[6] = 8'h4E; // N (-.)
        morse_tree[7] = 8'h4D; // M (--)

        // Level 4 (3 Symbols)
        morse_tree[8] = 8'h53; // S (...)
        morse_tree[9] = 8'h55; // U (..-)
        morse_tree[10] = 8'h52; // R (.-.)
        morse_tree[11] = 8'h57; // W (.--)
        morse_tree[12] = 8'h44; // D (-..)
        morse_tree[13] = 8'h4B; // K (-.-)
        morse_tree[14] = 8'h47; // G (--.)
        morse_tree[15] = 8'h4F; // O (---)

        // Level 5 (4 Symbols)
        morse_tree[16] = 8'h48; // H (....)
        morse_tree[17] = 8'h56; // V (...-)
        morse_tree[18] = 8'h46; // F (..-.)
        morse_tree[19] = 8'h00; // Null (..--)
        morse_tree[20] = 8'h4C; // L (.-..)
        morse_tree[21] = 8'h00; // Null (.-.-)
        morse_tree[22] = 8'h50; // P (.--.)
        morse_tree[23] = 8'h4A; // J (.---)
        morse_tree[24] = 8'h42; // B (-...)
        morse_tree[25] = 8'h58; // X (-..-)
        morse_tree[26] = 8'h43; // C (-.-.)
        morse_tree[27] = 8'h59; // Y (-.--)
        morse_tree[28] = 8'h5A; // Z (--..)
        morse_tree[29] = 8'h51; // Q (--.-)
        morse_tree[30] = 8'h00; // Null (---.)
        morse_tree[31] = 8'h00; // Null (----)

        // Level 6 (5 Symbols - Numbers)
        morse_tree[32] = 8'h35; // 5 (.....)
        morse_tree[33] = 8'h34; // 4 (....-)
        morse_tree[35] = 8'h33; // 3 (...--)
        morse_tree[39] = 8'h32; // 2 (..---)
        morse_tree[47] = 8'h31; // 1 (.----)
        morse_tree[48] = 8'h36; // 6 (-....)
        morse_tree[56] = 8'h37; // 7 (--...)
        morse_tree[60] = 8'h38; // 8 (---..)
        morse_tree[62] = 8'h39; // 9 (----.)
        morse_tree[63] = 8'h30; // 0 (-----)

        morse_tree[34] = 8'h00; // Null (...-.)
        morse_tree[36] = 8'h00; // Null (..-..)
        morse_tree[37] = 8'h00; // Null (..-.-)
        morse_tree[38] = 8'h00; // Null (..-..)
        morse_tree[40] = 8'h00; // Null (.-...)
        morse_tree[41] = 8'h00; // Null (.-..-)
        morse_tree[42] = 8'h00; // Null (.-.-.)
        morse_tree[43] = 8'h00; // Null (.-.--)
        morse_tree[44] = 8'h00; // Null (.--..)
        morse_tree[45] = 8'h00; // Null (.--.-)
        morse_tree[46] = 8'h00; // Null (.---.)
        morse_tree[49] = 8'h00; // Null (-...-)
        morse_tree[50] = 8'h00; // Null (-..-.)
        morse_tree[51] = 8'h00; // Null (-..--)
        morse_tree[52] = 8'h00; // Null (-.-..)
        morse_tree[53] = 8'h00; // Null (-.-.-)
        morse_tree[54] = 8'h00; // Null (-.--.)
        morse_tree[55] = 8'h00; // Null (-.---)
        morse_tree[57] = 8'h00; // Null (--..-)
        morse_tree[58] = 8'h00; // Null (--.-.)
        morse_tree[59] = 8'h00; // Null (--.--)
        morse_tree[61] = 8'h00; // Null (---.-)
    end

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
                    ascii_char <= morse_tree[tree_index];
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