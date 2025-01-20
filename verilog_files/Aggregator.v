module aggregator_dual_port #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 128,
    parameter ACC_WIDTH  = 16
)(
    input  wire                     clk,
    input  wire                     rst,

    // From cluster
    input  wire [5:0]               cluster_finished,  // 6 bits: each bit says if a PE is done
    input  wire [6*ACC_WIDTH-1:0]   cluster_out,       // 6 × ACC_WIDTH

    // Address queue
    input  wire                     queue_empty,
    output wire                     queue_pop,       // Must be driven from internal reg
    input  wire [ADDR_WIDTH-1:0]    queue_addr,

    // Dual-Port BRAM Interface
    output reg  [ADDR_WIDTH-1:0]    bram_addr_a,
    input  wire [DATA_WIDTH-1:0]    bram_rdata_a,

    output reg  [ADDR_WIDTH-1:0]    bram_addr_b,
    output reg                      bram_we_b,
    output reg  [DATA_WIDTH-1:0]    bram_wdata_b,

    // Aggregator done
    output reg                      aggregator_finished
);

    // Slice out each partial sum
    wire [ACC_WIDTH-1:0] sum [0:5];
    genvar i;
    generate
        for (i = 0; i < 6; i = i + 1) begin : SUM_GEN
            assign sum[i] = cluster_out[i*ACC_WIDTH +: ACC_WIDTH];
        end
    endgenerate

    reg queue_pop_r;
    assign queue_pop = queue_pop_r;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            bram_addr_a         <= 0;
            bram_addr_b         <= 0;
            bram_we_b           <= 0;
            bram_wdata_b        <= 0;
            aggregator_finished <= 0;
            queue_pop_r         <= 0;
        end else begin
            // If *any* PE in the cluster is finished and queue not empty => aggregate
            if ((|cluster_finished) && !queue_empty) begin
                queue_pop_r       <= 1;  // pop an address
                bram_addr_a       <= queue_addr;
                bram_addr_b       <= queue_addr;

                // Example partial-sum accumulation in the first 6 × 16 bits
                bram_wdata_b[ 0 +: 16] <= bram_rdata_a[ 0 +: 16] + sum[0];
                bram_wdata_b[16 +: 16] <= bram_rdata_a[16 +: 16] + sum[1];
                bram_wdata_b[32 +: 16] <= bram_rdata_a[32 +: 16] + sum[2];
                bram_wdata_b[48 +: 16] <= bram_rdata_a[48 +: 16] + sum[3];
                bram_wdata_b[64 +: 16] <= bram_rdata_a[64 +: 16] + sum[4];
                bram_wdata_b[80 +: 16] <= bram_rdata_a[80 +: 16] + sum[5];

                // Keep the remaining 32 bits the same
                bram_wdata_b[96 +: 32] <= bram_rdata_a[96 +: 32];

                bram_we_b           <= 1;
                aggregator_finished <= 1;
            end else begin
                queue_pop_r         <= 0;
                bram_we_b           <= 0;
                aggregator_finished <= 0;
            end
        end
    end

endmodule