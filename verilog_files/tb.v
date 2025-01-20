`timescale 1ns / 1ps

module top_scheduler_tb;

    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 128;
    parameter ACC_WIDTH  = 16;
    parameter Q_IN       = 5;
    parameter Q_W        = 8;

    reg clk;
    reg rst;
    reg start_global;
    reg [ADDR_WIDTH-1:0] base_ifm_addr;
    reg [ADDR_WIDTH-1:0] base_ofm_addr;
    reg [ADDR_WIDTH-1:0] base_filter_addr;

    wire [DATA_WIDTH-1:0] input_bram_rdata;
    wire [31:0]           filter_bram_rdata;
    wire [DATA_WIDTH-1:0] output_bram_rdata_a;

    top_scheduler #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .Q_IN(Q_IN),
        .Q_W(Q_W)
    ) uut (
        .clk(clk),
        .rst(rst),
        .start_global(start_global),
        .base_ifm_addr(base_ifm_addr),
        .base_ofm_addr(base_ofm_addr),
        .base_filter_addr(base_filter_addr)
    );

    // Clock Generation: 100MHz clock (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst = 1;
        start_global = 0;
        base_ifm_addr = 0;
        base_ofm_addr = 0;
        base_filter_addr = 0;

        $display("Simulation Start");

        #20;
        rst = 0;
        $display("Reset De-asserted at time %0t", $time);

        #20;

        start_global = 1;
        $display("start_global asserted at time %0t", $time);

        base_ifm_addr = 32'h0000_0000;
        base_ofm_addr = 32'h0000_0000;
        base_filter_addr = 32'h0000_0000;
        $display("Base Addresses Set at time %0t", $time);

        #1000;

        start_global = 0;
        $display("start_global de-asserted at time %0t", $time);

        #500;

        $display("Simulation End at time %0t", $time);
        $finish;
    end

    initial begin
        $monitor("Time=%0t | clk=%b | rst=%b | start_global=%b | base_ifm_addr=0x%h | base_ofm_addr=0x%h | base_filter_addr=0x%h",
                 $time, clk, rst, start_global, base_ifm_addr, base_ofm_addr, base_filter_addr);
    end

    initial begin
        $dumpfile("top_scheduler_tb.vcd");
        $dumpvars(0, top_scheduler_tb);
    end


endmodule