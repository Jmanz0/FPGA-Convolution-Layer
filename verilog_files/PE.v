module PE #(
    parameter WIN_SIZE  = 3,   
    parameter IN_WIDTH  = 5,   
    parameter W_WIDTH   = 8,   
    parameter ACC_WIDTH = 15   
)(
    input  wire                     clk,
    input  wire                     rst,
    input  wire                     start,

    input  wire [WIN_SIZE*IN_WIDTH -1:0] in_data,     // 3×IN_WIDTH bits
    input  wire [WIN_SIZE*W_WIDTH  -1:0] in_filter,   // 3×W_WIDTH bits
    input  wire [ACC_WIDTH-1:0]          in_partial,
    output reg  [ACC_WIDTH-1:0]          out_data,
    output reg                           finished
);

    localparam S_IDLE = 2'd0,
               S_MAC  = 2'd1,
               S_ACC  = 2'd2,
               S_DONE = 2'd3;

    reg [1:0] state;
    reg [1:0] iteration;  
    reg [ACC_WIDTH-1:0] mac_accum;

    // Slice the inputs
    wire [IN_WIDTH-1:0] d0 = in_data[0 +: IN_WIDTH];
    wire [IN_WIDTH-1:0] d1 = in_data[IN_WIDTH +: IN_WIDTH];
    wire [IN_WIDTH-1:0] d2 = in_data[2*IN_WIDTH +: IN_WIDTH];

    wire [W_WIDTH-1:0] w0 = in_filter[0 +: W_WIDTH];
    wire [W_WIDTH-1:0] w1 = in_filter[W_WIDTH +: W_WIDTH];
    wire [W_WIDTH-1:0] w2 = in_filter[2*W_WIDTH +: W_WIDTH];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= S_IDLE;
            out_data  <= 0;
            finished  <= 0;
            mac_accum <= 0;
            iteration <= 0;
        end else begin
            case(state)
            S_IDLE: begin
                finished  <= 0;
                iteration <= 0;
                mac_accum <= 0;
                if (start)
                    state <= S_MAC;
            end

            S_MAC: begin
                case (iteration)
                    2'd0: mac_accum <= mac_accum + (d0 * w0);
                    2'd1: mac_accum <= mac_accum + (d1 * w1);
                    2'd2: mac_accum <= mac_accum + (d2 * w2);
                endcase

                if (iteration == 2) begin
                    state <= S_ACC;
                end else begin
                    iteration <= iteration + 1;
                end
            end

            S_ACC: begin
                out_data <= mac_accum + in_partial;
                finished <= 1;
                state    <= S_DONE; 
            end

            S_DONE: begin
                if (!start) begin
                    state <= S_IDLE;
                end
            end

            endcase
        end
    end

endmodule