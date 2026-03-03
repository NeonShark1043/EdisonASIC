module morse_fsm #(
    parameter DOT_MAX   = 500,
    parameter GAP_LIMIT = 1500
)(
    input  logic        clk,
    input  logic        nrst,
    input  logic        fsm_enable,
    input  logic        light_on,
    input  logic [15:0] gap_counter,
    output logic [7:0]  ascii_char,
    output logic        char_ready
);

    // State Encoding
    typedef enum logic [2:0] {
        IDLE     = 3'b000,
        MARK     = 3'b001,
        CLASSIFY = 3'b010,
        GAP      = 3'b011,
        DECODE   = 3'b100,
        READY    = 3'b101
    } state_t;
    state_t current_state, next_state;

    // Internal Registers
    logic [5:0]  tree_index;
    logic [15:0] mark_counter;

    // Morse Binary Tree ROM (index 1 = root, dot = 2*i, dash = 2*i+1)
    logic [7:0] morse_tree [0:63];
    initial begin
        for (int i = 0; i < 64; i++) morse_tree[i] = '0;
        morse_tree[2]  = "E";
        morse_tree[3]  = "T";
        morse_tree[4]  = "I";
        morse_tree[5]  = "A";
        morse_tree[6]  = "N";
        morse_tree[7]  = "M";
        morse_tree[8]  = "S";
        morse_tree[9]  = "U";
        morse_tree[10] = "R";
        morse_tree[11] = "W";
        morse_tree[12] = "D";
        morse_tree[13] = "K";
        morse_tree[14] = "G";
        morse_tree[15] = "O";
        morse_tree[16] = "H";
        morse_tree[17] = "V";
        morse_tree[18] = "F";
        morse_tree[20] = "L";
        morse_tree[22] = "P";
        morse_tree[23] = "J";
        morse_tree[24] = "B";
        morse_tree[25] = "X";
        morse_tree[26] = "C";
        morse_tree[27] = "Y";
        morse_tree[28] = "Z";
        morse_tree[29] = "Q";
    end

    // State Transition Logic
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) current_state <= IDLE;
        else current_state <= next_state;
    end

    // Next State Logic
    always_comb begin
        next_state = current_state;
        if(!fsm_enable) next_state = IDLE;
        else case(current_state)
            IDLE:     if(light_on) next_state = MARK;
            MARK:     if(!light_on) next_state = CLASSIFY;
            CLASSIFY: next_state = GAP;
            GAP:      if(light_on) next_state = MARK;
                      else if(gap_counter >= GAP_LIMIT) next_state = DECODE;
            DECODE:   next_state = READY;
            READY:    next_state = IDLE;
            default:  next_state = IDLE;
        endcase
    end

    // Control Path Logic
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) begin
            tree_index   <= 6'd1;
            mark_counter <= '0;
            ascii_char   <= '0;
            char_ready   <= 0;
        end else begin
            char_ready <= 0;
            case(current_state)
                IDLE: begin
                    tree_index   <= 6'd1;
                    mark_counter <= '0;
                end
                MARK: begin
                    mark_counter <= mark_counter + 1;
                end
                CLASSIFY: begin
                    mark_counter <= '0;
                    if(mark_counter <= DOT_MAX) tree_index <= tree_index << 1;
                    else                        tree_index <= (tree_index << 1) | 1;
                end
                DECODE: begin
                    ascii_char <= morse_tree[tree_index];
                end
                READY: begin
                    char_ready <= 1;
                end
                default: ;
            endcase
        end
    end
