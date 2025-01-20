/////////////////////////////////////////////////////////
// top_scheduler.sv
/////////////////////////////////////////////////////////

module top_scheduler #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 128,
    parameter ACC_WIDTH  = 16,
    parameter Q_IN       = 5,
    parameter Q_W        = 8
)(
    input  wire                   clk,
    input  wire                   rst,
    input  wire                   start_global,
    input  wire [ADDR_WIDTH-1:0]  base_ifm_addr,
    input  wire [ADDR_WIDTH-1:0]  base_ofm_addr,
    input  wire [ADDR_WIDTH-1:0]  base_filter_addr
);

    wire [ADDR_WIDTH-1:0] in_input_addr;
    wire [ADDR_WIDTH-1:0] in_output_addr;
    wire                  valid_inout;

    assign in_input_addr  = base_ifm_addr;   // or 0
    assign in_output_addr = base_ofm_addr;   // or 0
    assign valid_inout    = start_global;    // or tie to 1 if always valid

    //----------------------------------------------------
    // 2) filter_addr_generator
    //----------------------------------------------------
    wire [ADDR_WIDTH-1:0] filter_address;
    wire                  valid_filter_addr;
    wire                  filter_start_out;

    filter_addr_generator #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_filter_addr_gen (
        .clk              (clk),
        .rst              (rst),
        .start            (valid_inout), 
        .base_filter_addr (base_filter_addr),
        .filter_address   (filter_address),
        .valid_out        (valid_filter_addr),
        .filter_start_out (filter_start_out)
    );

    //----------------------------------------------------
    // 3) fmap_addr_generator
    //----------------------------------------------------
    wire [ADDR_WIDTH-1:0] out_address;
    wire                  valid_out_addr;

    fmap_addr_generator #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_fmap_addr_gen (
        .clk               (clk),
        .rst               (rst),
        .start             (valid_filter_addr),
        .base_ifm_bram_addr(base_ifm_addr),
        .out_address       (out_address),
        .valid_out         (valid_out_addr)
    );

    //----------------------------------------------------
    // 4) data_distributor
    //    This module outputs addresses for input/filter BRAMs
    //----------------------------------------------------
    wire [ADDR_WIDTH-1:0] agg_queue_in_addr;
    wire                  agg_queue_push;
    wire                  pe_cluster_start;
    wire [6*Q_IN -1:0]    dist_data;
    wire [3*Q_W  -1:0]    dist_filter;

    wire [ADDR_WIDTH-1:0] input_bram_addr_wire;
    wire [ADDR_WIDTH-1:0] filter_bram_addr_wire;

    wire [127:0] input_bram_rdata;
    wire [31:0]  filter_bram_rdata;

    data_distributor #(
        .ADDR_WIDTH      (ADDR_WIDTH),
        .INPUT_LINE_WIDTH(128),
        .FILTER_LINE_WIDTH(32),
        .Q_IN(Q_IN),
        .Q_W(Q_W)
    ) u_data_dist (
        .clk              (clk),
        .rst              (rst),

        // 1) from "inout_addr_generator" (or just pass base addresses)
        .in_input_addr    (in_input_addr),
        .in_output_addr   (in_output_addr),
        .valid_inout      (valid_inout),

        // 2) from "filter_addr_generator"
        .filter_addr      (filter_address),
        .valid_filter     (valid_filter_addr),
        .filter_start_out (filter_start_out),

        // 3) from "fmap_addr_generator"
        .out_address      (out_address),
        .valid_out_addr   (valid_out_addr),

        // BRAM interfaces
        .input_bram_addr   (input_bram_addr_wire),  // <= WIRE, not reg
        .input_bram_rdata  (input_bram_rdata),
        .filter_bram_addr  (filter_bram_addr_wire), // <= WIRE, not reg
        .filter_bram_rdata (filter_bram_rdata),

        // aggregator queue
        .agg_queue_addr    (agg_queue_in_addr),
        .agg_queue_push    (agg_queue_push),

        // PE cluster signals
        .pe_cluster_start  (pe_cluster_start),
        .dist_data         (dist_data),
        .dist_filter       (dist_filter)
    );

    //----------------------------------------------------
    // 5) Example BRAMs (stub or real)
    //----------------------------------------------------
    wire [9:0] input_bram_addra_wire = input_bram_addr_wire[9:0];
    wire [9:0] filter_bram_addra_wire = filter_bram_addr_wire[9:0];
    wire [9:0] output_bram_addr_a_wire = output_bram_addr_a[9:0];
    wire [9:0] output_bram_addr_b_wire = output_bram_addr_b[9:0];

    // Input BRAM (128 bits wide)
    mem_input_bram u_input_bram (
        .clka  (clk),
        .ena   (1'b1),
        .wea   (1'b0),                   // wea is 1-bit vector
        .addra (input_bram_addra_wire),  // 10-bit address
        .dina  (128'b0),
        .douta (input_bram_rdata),
        .clkb  (1'b0),
        .rstb  (1'b0),
        .enb   (1'b0),
        .regceb(1'b0),
        .web   (1'b0),                    // web is 1-bit vector
        .addrb (10'b0),
        .dinb  (128'b0),
        .doutb (/* unused */)
    );

    // Filter BRAM (32 bits wide)
    mem_filter_bram u_filter_bram (
        .clka  (clk),
        .ena   (1'b1),
        .wea   (1'b0),                   // wea is 1-bit vector
        .addra (filter_bram_addra_wire), // 10-bit address
        .dina  (32'b0),
        .douta (filter_bram_rdata),
        // Port B tied off
        .clkb  (1'b0),
        .rstb  (1'b0),
        .enb   (1'b0),
        .regceb(1'b0),
        .web   (1'b0),                    // web is 1-bit vector
        .addrb (10'b0),
        .dinb  (32'b0),
        .doutb (/* unused */)
    );

    // Output BRAM (dual-port)
    reg  [ADDR_WIDTH-1:0] output_bram_addr_a;
    reg  [ADDR_WIDTH-1:0] output_bram_addr_b;
    reg                   output_bram_we_b;
    reg  [DATA_WIDTH-1:0] output_bram_wdata_b;
    wire [DATA_WIDTH-1:0] output_bram_rdata_a;

    mem_output_bram u_output_bram (
        // Port A
        .clka   (clk),                             // Clock for Port A
        .ena    (1'b1),                            // Enable for Port A
        .wea    (1'b0),                            // Write enable for Port A (1-bit vector)
        .addra  (output_bram_addr_a_wire),         // 10-bit address for Port A
        .dina   (DATA_WIDTH'b0),                   // 128-bit data input for Port A
        .douta  (output_bram_rdata_a),             // 128-bit data output for Port A

        // Port B
        .clkb   (clk),                             // Clock for Port B
        .rstb   (1'b0),                            // Reset for Port B
        .enb    (1'b1),                            // Enable for Port B
        .regceb (1'b0),                            // Register Clock Enable for Port B
        .web    (output_bram_we_b),                // Write enable for Port B (1-bit vector)
        .addrb  (output_bram_addr_b_wire),         // 10-bit address for Port B
        .dinb   (output_bram_wdata_b),             // 128-bit data input for Port B
        .doutb  (/* unuse */)                     // 128-bit data output for Port B
    );

    //----------------------------------------------------
    // 6) Aggregator queue
    //----------------------------------------------------
    wire [ADDR_WIDTH-1:0] agg_q_out_addr;
    wire                  agg_q_empty;

    output_address_queue #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .Q_DEPTH   (16)
    ) u_agg_queue (
        .clk      (clk),
        .rst      (rst),
        .in_addr  (agg_queue_in_addr),
        .push     (agg_queue_push),
        .out_addr (agg_q_out_addr),
        .pop      (/* wired from aggregator below */ aggregator_dual_port_inst.queue_pop),
        .empty    (agg_q_empty)
    );

    //----------------------------------------------------
    // 7) PE Cluster
    //----------------------------------------------------
    wire [5:0] cluster_finished;
    wire [6*ACC_WIDTH-1:0] cluster_out;

    PE_Cluster #(
        .IN_WIDTH(Q_IN),
        .W_WIDTH(Q_W),
        .ACC_WIDTH(ACC_WIDTH)
    ) u_pe_cluster (
        .clk             (clk),
        .rst             (rst),
        .start           (pe_cluster_start),
        .data_port1      (dist_data[ 4: 0]),
        .data_port2      (dist_data[ 9: 5]),
        .data_port3      (dist_data[14:10]),
        .data_port4      (dist_data[19:15]),
        .data_port5      (dist_data[24:20]),
        .data_port6      (dist_data[29:25]),
        .filter_port     (dist_filter),
        .cluster_out     (cluster_out),
        .cluster_finished(cluster_finished)
    );

    //----------------------------------------------------
    // 8) Aggregator (dual port)
    //----------------------------------------------------
    wire aggregator_finished;

    aggregator_dual_port #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH (ACC_WIDTH)
    ) aggregator_dual_port_inst (
        .clk                (clk),
        .rst                (rst),
        .cluster_finished   (cluster_finished),
        .cluster_out        (cluster_out),
        // queue
        .queue_empty        (agg_q_empty),
        .queue_pop          (/* driven internally */),
        .queue_addr         (agg_q_out_addr),
        .bram_addr_a        (output_bram_addr_a),          // 32-bit, but BRAM expects 10-bit
        .bram_rdata_a       (output_bram_rdata_a),
        .bram_addr_b        (output_bram_addr_b),          // 32-bit, but BRAM expects 10-bit
        .bram_we_b          (output_bram_we_b),
        .bram_wdata_b       (output_bram_wdata_b),
        .aggregator_finished(aggregator_finished)
    );


endmodule