module fmap_addr_generator #(
    parameter ADDR_WIDTH = 32
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   start,
    input  wire [ADDR_WIDTH-1:0]  base_ifm_bram_addr,

    output reg [ADDR_WIDTH-1:0]   out_address,
    output reg                    valid_out
);

    localparam NUM_LAYERS  = 32;
    localparam NUM_ROWS    = 20; 
    localparam NUM_FILTERS = 64;

    localparam S_IDLE     = 0;
    localparam S_LAYER    = 1;
    localparam S_SKIPROW  = 2;
    localparam S_OUTF     = 3;
    localparam S_COUNT    = 4;
    localparam S_CHK      = 5;
    localparam S_PROC     = 6;
    localparam S_NEXT     = 7;
    localparam S_DONE     = 8;

    reg [3:0] state;

    reg [5:0] input_layer_cnt; 
    reg [4:0] skip_row_cnt;    
    reg [5:0] out_f_cnt;       
    reg [1:0] count_val;       

    wire skiprow_limit = (skip_row_cnt >= (NUM_ROWS - 4)); // e.g. 16

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            state           <= S_IDLE;
            input_layer_cnt <= 0;
            skip_row_cnt    <= 0;
            out_f_cnt       <= 0;
            count_val       <= 0;
            out_address     <= 0;
            valid_out       <= 0;
        end else begin
            valid_out <= 0; 

            case(state)
            S_IDLE: begin
                if(start) begin
                    input_layer_cnt <= 0;
                    skip_row_cnt    <= 0;
                    out_f_cnt       <= 0;
                    count_val       <= 0;
                    state           <= S_LAYER;
                end
            end

            S_LAYER: begin
                if(input_layer_cnt >= NUM_LAYERS) begin
                    state <= S_DONE;
                end else begin
                    skip_row_cnt <= 0;
                    state        <= S_SKIPROW;
                end
            end

            S_SKIPROW: begin
                if(skiprow_limit) begin
                    input_layer_cnt <= input_layer_cnt + 1;
                    state           <= S_LAYER;
                end else begin
                    out_f_cnt <= 0;
                    state     <= S_OUTF;
                end
            end

            S_OUTF: begin
                if(out_f_cnt >= NUM_FILTERS) begin
                    skip_row_cnt <= skip_row_cnt + 3;
                    state        <= S_SKIPROW;
                end else begin
                    count_val <= 0;
                    state     <= S_COUNT;
                end
            end

            S_COUNT: begin
                if(count_val >= 4) begin
                    out_f_cnt <= out_f_cnt + 1;
                    state     <= S_OUTF;
                end else begin
                    state <= S_CHK;
                end
            end

            S_CHK: begin
                // only produce addresses on count_val=1,2,3
                if(count_val >= 1 && count_val < 4) begin
                    out_address <= base_ifm_bram_addr
                                 + (out_f_cnt * 16)
                                 + skip_row_cnt
                                 + count_val
                                 - 1;
                    valid_out <= 1'b1;
                end
                state <= S_PROC;
            end

            S_PROC: begin
                state <= S_NEXT;
            end

            S_NEXT: begin
                count_val <= count_val + 1;
                state     <= S_COUNT;
            end

            S_DONE: begin
                // remain done
            end

            endcase
        end
    end

endmodule