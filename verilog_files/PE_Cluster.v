module PE_Cluster #(
    parameter IN_WIDTH  = 5,
    parameter W_WIDTH   = 8,
    parameter ACC_WIDTH = 16
)(
    input  wire                              clk,
    input  wire                              rst,
    input  wire                              start,
    
    input  wire [IN_WIDTH-1:0]              data_port1,   
    input  wire [IN_WIDTH-1:0]              data_port2,   
    input  wire [IN_WIDTH-1:0]              data_port3,   
    input  wire [IN_WIDTH-1:0]              data_port4,   
    input  wire [IN_WIDTH-1:0]              data_port5,   
    input  wire [IN_WIDTH-1:0]              data_port6,   
    
    // One 3-wide filter port (24 bits = 3×8)
    input  wire [3*W_WIDTH -1:0]            filter_port,  
    
    // Outputs
    output reg  [6*ACC_WIDTH-1:0]           cluster_out,
    output reg  [5:0]                       cluster_finished  
);

    // We do not have separate partial sums in this design, so each PE’s partial input is zero
    wire [ACC_WIDTH-1:0] partial_in = {ACC_WIDTH{1'b0}};

    wire [ACC_WIDTH-1:0] array_out [0:5];
    wire [0:5]           array_fin;

    // Zero-pad each data_port up to 15 bits => (5 bits data + 10 bits of zeros)
    PE_Array_3x3 #(.IN_WIDTH(IN_WIDTH), .W_WIDTH(W_WIDTH), .ACC_WIDTH(ACC_WIDTH)) u_array1 (
        .clk         (clk),
        .rst         (rst),
        .start_global(start),
        .in_data_9   ({data_port1, 10'b0}),   // 5 bits data + 10 bits zero => 15 bits total
        .in_filter_9 (filter_port),           // 3×8 = 24 bits
        .in_partial_9(partial_in),            // zero partial
        .out_data_9  (array_out[0]),
        .finished_9  (array_fin[0])
    );

    PE_Array_3x3 #(.IN_WIDTH(IN_WIDTH), .W_WIDTH(W_WIDTH), .ACC_WIDTH(ACC_WIDTH)) u_array2 (
        .clk         (clk),
        .rst         (rst),
        .start_global(start),
        .in_data_9   ({data_port2, 10'b0}),
        .in_filter_9 (filter_port),
        .in_partial_9(partial_in),
        .out_data_9  (array_out[1]),
        .finished_9  (array_fin[1])
    );

    PE_Array_3x3 #(.IN_WIDTH(IN_WIDTH), .W_WIDTH(W_WIDTH), .ACC_WIDTH(ACC_WIDTH)) u_array3 (
        .clk         (clk),
        .rst         (rst),
        .start_global(start),
        .in_data_9   ({data_port3, 10'b0}),
        .in_filter_9 (filter_port),
        .in_partial_9(partial_in),
        .out_data_9  (array_out[2]),
        .finished_9  (array_fin[2])
    );

    PE_Array_3x3 #(.IN_WIDTH(IN_WIDTH), .W_WIDTH(W_WIDTH), .ACC_WIDTH(ACC_WIDTH)) u_array4 (
        .clk         (clk),
        .rst         (rst),
        .start_global(start),
        .in_data_9   ({data_port4, 10'b0}),
        .in_filter_9 (filter_port),
        .in_partial_9(partial_in),
        .out_data_9  (array_out[3]),
        .finished_9  (array_fin[3])
    );

    PE_Array_3x3 #(.IN_WIDTH(IN_WIDTH), .W_WIDTH(W_WIDTH), .ACC_WIDTH(ACC_WIDTH)) u_array5 (
        .clk         (clk),
        .rst         (rst),
        .start_global(start),
        .in_data_9   ({data_port5, 10'b0}),
        .in_filter_9 (filter_port),
        .in_partial_9(partial_in),
        .out_data_9  (array_out[4]),
        .finished_9  (array_fin[4])
    );

    PE_Array_3x3 #(.IN_WIDTH(IN_WIDTH), .W_WIDTH(W_WIDTH), .ACC_WIDTH(ACC_WIDTH)) u_array6 (
        .clk         (clk),
        .rst         (rst),
        .start_global(start),
        .in_data_9   ({data_port6, 10'b0}),
        .in_filter_9 (filter_port),
        .in_partial_9(partial_in),
        .out_data_9  (array_out[5]),
        .finished_9  (array_fin[5])
    );

    // Combine results
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            cluster_finished <= 6'b000000;
            cluster_out      <= {6*ACC_WIDTH{1'b0}};
        end else begin
            if(|array_fin) begin
                cluster_finished <= 6'b111111;  
                cluster_out      <= {
                                      array_out[5],
                                      array_out[4],
                                      array_out[3],
                                      array_out[2],
                                      array_out[1],
                                      array_out[0]
                                     };
            end else begin
                cluster_finished <= 6'b000000;
                cluster_out      <= {6*ACC_WIDTH{1'b0}};
            end
        end
    end

endmodule