module data_distributor #(
    parameter ADDR_WIDTH       = 32,
    parameter INPUT_LINE_WIDTH = 128, 
    parameter FILTER_LINE_WIDTH= 32,  
    parameter Q_IN             = 5,   
    parameter Q_W              = 8    
)(
    input  wire                     clk,
    input  wire                     rst,
    
    input  wire [ADDR_WIDTH-1:0]    in_input_addr,   
    input  wire [ADDR_WIDTH-1:0]    in_output_addr,  
    input  wire                     valid_inout,     

    input  wire [ADDR_WIDTH-1:0]    filter_addr,     
    input  wire                     valid_filter,    
    input  wire                     filter_start_out, 

    input  wire [ADDR_WIDTH-1:0]    out_address,     
    input  wire                     valid_out_addr,  

    output reg  [ADDR_WIDTH-1:0]    input_bram_addr,
    input  wire [INPUT_LINE_WIDTH-1:0]  input_bram_rdata,

    output reg  [ADDR_WIDTH-1:0]    filter_bram_addr,
    input  wire [FILTER_LINE_WIDTH-1:0] filter_bram_rdata,

    output reg  [ADDR_WIDTH-1:0]    agg_queue_addr,
    output reg                      agg_queue_push,

    output reg                      pe_cluster_start,
    output reg [6*Q_IN -1:0]        dist_data,     
    output reg [3*Q_W  -1:0]        dist_filter    
);

    
    reg [Q_IN-1:0] extended_ifm [0:17];
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            input_bram_addr  <= 0;
            filter_bram_addr <= 0;
            agg_queue_addr   <= 0;
            agg_queue_push   <= 0;
            pe_cluster_start <= 0;
            dist_data        <= 0;
            dist_filter      <= 0;
            for(i=0; i<18; i=i+1) extended_ifm[i] <= 0;

        end else begin
            
            agg_queue_push   <= 0;
            pe_cluster_start <= 0;
            dist_data        <= 0;
            dist_filter      <= 0;

            if(valid_inout) begin
                agg_queue_addr <= in_output_addr;
                agg_queue_push <= 1'b1;
            end

            if(valid_filter) begin
                filter_bram_addr <= filter_addr; 
                
                dist_filter[ 7:0 ]   <= filter_bram_rdata[ 7: 0]; 
                dist_filter[15:8 ]   <= filter_bram_rdata[15: 8];
                dist_filter[23:16]   <= filter_bram_rdata[23:16];
                
                if(filter_start_out) begin
                    pe_cluster_start <= 1'b1;
                end
            end
            
            if(valid_out_addr) begin
                input_bram_addr <= out_address;
                
                extended_ifm[0]  <= 5'b00000; 
                extended_ifm[17] <= 5'b00000;
                for(i=0; i<16; i=i+1) begin
                    extended_ifm[i+1] <= input_bram_rdata[i*Q_IN +: Q_IN];
                end
                
                dist_data[ 4: 0] <= extended_ifm[0];  
                dist_data[ 9: 5] <= extended_ifm[3];
                dist_data[14:10] <= extended_ifm[6];
                dist_data[19:15] <= extended_ifm[9];
                dist_data[24:20] <= extended_ifm[12];
                dist_data[29:25] <= extended_ifm[13];

                agg_queue_addr <= out_address;
                agg_queue_push <= 1'b1;
                
                pe_cluster_start <= 1'b1;
            end
        end
    end

endmodule