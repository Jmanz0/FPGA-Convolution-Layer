module filter_addr_generator #(
    parameter ADDR_WIDTH = 32
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   start,              
    input  wire [ADDR_WIDTH-1:0]  base_filter_addr,

    output reg [ADDR_WIDTH-1:0]   filter_address,
    output reg                    valid_out,
    output reg                    filter_start_out
);

    localparam S_IDLE    = 0;
    localparam S_LAYER   = 1;
    localparam S_SKIPROW = 2;
    localparam S_OUTF    = 3;
    localparam S_COUNT   = 4;
    localparam S_VALID   = 5;
    localparam S_NEXT    = 6;
    localparam S_DONE    = 7;

    reg [3:0] state;

    reg [4:0] input_layer_cnt; 
    reg [4:0] skip_row_cnt;    
    reg [6:0] out_f_cnt;       
    reg [1:0] count_cnt;       

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            state            <= S_IDLE;
            input_layer_cnt  <= 0;
            skip_row_cnt     <= 0;
            out_f_cnt        <= 0;
            count_cnt        <= 0;
            filter_address   <= 0;
            valid_out        <= 0;
            filter_start_out <= 0;
        end else begin
            
            valid_out        <= 0;
            filter_start_out <= 0;

            case(state)
            S_IDLE: begin
                if(start) begin
                    input_layer_cnt <= 0;
                    skip_row_cnt    <= 0;
                    out_f_cnt       <= 0;
                    count_cnt       <= 0;
                    state           <= S_LAYER;
                end
            end

            S_LAYER: begin
                if(input_layer_cnt < 32) begin
                    skip_row_cnt <= 0;
                    state        <= S_SKIPROW;
                end else begin
                    state <= S_DONE;
                end
            end

            S_SKIPROW: begin
                if(skip_row_cnt >= 16) begin
                    input_layer_cnt <= input_layer_cnt + 1;
                    state           <= S_LAYER;
                end else begin
                    out_f_cnt <= 0;
                    state     <= S_OUTF;
                end
            end

            S_OUTF: begin
                if(out_f_cnt < 64) begin
                    count_cnt <= 0;
                    state     <= S_COUNT;
                end else begin
                    skip_row_cnt <= skip_row_cnt + 3;
                    state        <= S_SKIPROW;
                end
            end

            S_COUNT: begin
                if(count_cnt < 4) begin
                    state <= S_VALID;
                end else begin
                    
                    out_f_cnt <= out_f_cnt + 1;
                    state     <= S_OUTF;
                end
            end

            S_VALID: begin
                
                if(count_cnt < 3) begin
                    filter_address <= base_filter_addr
                                   + (out_f_cnt * 32 * 3)
                                   + (input_layer_cnt * 3)
                                   + count_cnt;
                    valid_out <= 1'b1;
                    
                    if(count_cnt == 1) begin
                        filter_start_out <= 1'b1;
                    end
                end
                state <= S_NEXT;
            end

            S_NEXT: begin
                count_cnt <= count_cnt + 1;
                state     <= S_COUNT;
            end

            S_DONE: begin
            end
            endcase
        end
    end

endmodule