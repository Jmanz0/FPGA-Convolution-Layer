module PE_Array_3x3 #(
    parameter IN_WIDTH    = 5,
    parameter W_WIDTH     = 8,
    parameter ACC_WIDTH   = 15,
    parameter NUM_ROWS     = 3,
    parameter NUM_COLS     = 3
)(
    input  wire                        clk,
    input  wire                        rst,
    input  wire                        start_global,  // Global start signal affecting only PE (0,0)
    
    input  wire [5*IN_WIDTH -1:0]    in_data_9, // 5 is the size coming in
    input  wire [3*W_WIDTH  -1:0]    in_filter_9, // 3 is the size coming in
    
    output wire [3*IN_WIDTH -1:0]     out_data_9,
    output wire                      finished_9
);

    // Internal wires to handle start signal propagation
    wire [NUM_ROWS*NUM_COLS -1:0] start_pe;
    
    // Internal wires for filter and partial sum propagation
    wire [NUM_ROWS*NUM_COLS*W_WIDTH -1:0] internal_filters;
    wire [NUM_ROWS*NUM_COLS*ACC_WIDTH -1:0] internal_partials;
    
    genvar row, col, pe;
    generate
        for(row = 0; row < NUM_ROWS; row = row + 1) begin : ROW_GEN
            for(col = 0; col < NUM_COLS; col = col + 1) begin : COL_GEN
                localparam INDEX = row * NUM_COLS + col;
                
                if(row == 0 && col == 0) begin : PE00
                    // Only PE (0,0) is affected by start_global
                    assign start_pe[INDEX] = start_global;
                end else begin : PE_OTHER
                    wire start_from_left  = (col > 0) ? finished_9[INDEX-1] : 1'b0;
                    wire start_from_above = (row > 0) ? finished_9[INDEX-NUM_COLS] : 1'b0;
                    
                    assign start_pe[INDEX] = start_from_left || start_from_above;
                end
            end
        end
    endgenerate
    
    generate
        for(pe = 0; pe < NUM_ROWS*NUM_COLS; pe = pe + 1) begin : GEN_PE
            // Calculate row and column from pe index
            wire [31:0] current_row = pe / NUM_COLS;
            wire [31:0] current_col = pe % NUM_COLS;
            
            // Determine filter input
            wire [W_WIDTH-1:0] filter_in_0;
            wire [W_WIDTH-1:0] filter_in_1;
            wire [W_WIDTH-1:0] filter_in_2;
            
            if(current_col == 0) begin
                assign filter_in_0 = in_filter_9[pe*3*W_WIDTH +: W_WIDTH];
                assign filter_in_1 = in_filter_9[pe*3*W_WIDTH + W_WIDTH +: W_WIDTH];
                assign filter_in_2 = in_filter_9[pe*3*W_WIDTH + 2*W_WIDTH +: W_WIDTH];
            end else begin
                assign filter_in_0 = in_filter_9[pe*3*W_WIDTH +: W_WIDTH];
                assign filter_in_1 = in_filter_9[pe*3*W_WIDTH + W_WIDTH +: W_WIDTH];
                assign filter_in_2 = in_filter_9[pe*3*W_WIDTH + 2*W_WIDTH +: W_WIDTH];
            end
            
            wire [ACC_WIDTH-1:0] partial_in;
            if(current_row == 0) begin
                assign partial_in = in_partial_9[pe*ACC_WIDTH +: ACC_WIDTH];
            end else begin
                assign partial_in = out_data_9[(pe-NUM_COLS)*ACC_WIDTH +: ACC_WIDTH];
            end
            
            PE #(
                .WIN_SIZE(3),
                .IN_WIDTH(IN_WIDTH),
                .W_WIDTH(W_WIDTH),
                .ACC_WIDTH(ACC_WIDTH)
            ) u_pe (
                .clk       (clk),
                .rst       (rst),
                .start     (start_pe[pe]),
                .in_data   (in_data_9[ pe*3*IN_WIDTH +: 3*IN_WIDTH ]),
                .in_filter ({filter_in_2, filter_in_1, filter_in_0}),
                .in_partial(partial_in),
                .out_data  (out_data_9[ pe*ACC_WIDTH +: ACC_WIDTH ]),
                .finished  (finished_9[pe])
            );
        end
    endgenerate

endmodule