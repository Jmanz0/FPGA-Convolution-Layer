module output_address_queue #(
    parameter ADDR_WIDTH = 32,
    parameter Q_DEPTH    = 16
)(
    input  wire                     clk,
    input  wire                     rst,
    input  wire [ADDR_WIDTH-1:0]    in_addr,
    input  wire                     push,
    output reg  [ADDR_WIDTH-1:0]    out_addr,
    input  wire                     pop,
    output wire                     empty
);
    reg [ADDR_WIDTH-1:0] mem [0:Q_DEPTH-1];
    reg [3:0] wr_ptr, rd_ptr, count;

    assign empty = (count == 0);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_ptr   <= 0;
            rd_ptr   <= 0;
            count    <= 0;
            out_addr <= 0;
        end else begin
            // Enqueue
            if (push && (count < Q_DEPTH)) begin
                mem[wr_ptr] <= in_addr;
                wr_ptr      <= wr_ptr + 1;
                count       <= count + 1;
            end

            // Dequeue
            if (pop && !empty) begin
                out_addr <= mem[rd_ptr];
                rd_ptr   <= rd_ptr + 1;
                count    <= count - 1;
            end
        end
    end

endmodule