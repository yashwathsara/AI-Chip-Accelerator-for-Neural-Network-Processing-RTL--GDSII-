`timescale 1ns / 1ps

module pooling_unit #(
    parameter int DATA_WIDTH = 8,
    parameter int KERNEL_SIZE = 2
)(
    input  logic                     clk,
    input  logic                     reset,
    input  logic                     s_axis_tvalid,
    output logic                     s_axis_tready,
    input  logic [DATA_WIDTH-1:0]    s_axis_tdata,
    input  logic                     s_axis_tlast,
    input  logic                     pool_type,
    output logic                     m_axis_tvalid,
    input  logic                     m_axis_tready,
    output logic [DATA_WIDTH-1:0]    m_axis_tdata,
    output logic                     m_axis_tlast
);

    (* ram_style = "block", keep = "true" *)
    logic [DATA_WIDTH-1:0] pool_window [0:KERNEL_SIZE*KERNEL_SIZE-1];
    logic [$clog2(KERNEL_SIZE*KERNEL_SIZE)-1:0] write_ptr;
    logic [$clog2(KERNEL_SIZE*KERNEL_SIZE):0] count;
    logic valid_reg, last_reg;
    logic [DATA_WIDTH-1:0] max_val, avg_val;
    logic [DATA_WIDTH+$clog2(KERNEL_SIZE*KERNEL_SIZE)-1:0] sum;

    assign s_axis_tready = (count < KERNEL_SIZE*KERNEL_SIZE);
    assign m_axis_tvalid = valid_reg;
    assign m_axis_tlast  = last_reg;

    always_comb begin
        max_val = pool_window[0];
        sum = '0;
        for (int j = 0; j < KERNEL_SIZE*KERNEL_SIZE; j++) begin
            if (pool_window[j] > max_val)
                max_val = pool_window[j];
            sum += pool_window[j];
        end
        avg_val = sum >> $clog2(KERNEL_SIZE*KERNEL_SIZE);
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            count     <= 0;
            write_ptr <= 0;
            valid_reg <= 0;
            last_reg  <= 0;
            m_axis_tdata <= 0;
            for (int i = 0; i < KERNEL_SIZE*KERNEL_SIZE; i++) begin
                pool_window[i] <= 0;
            end
        end else begin
            if (s_axis_tvalid && s_axis_tready) begin
                pool_window[write_ptr] <= s_axis_tdata;
                write_ptr <= write_ptr + 1;
                if (count == KERNEL_SIZE*KERNEL_SIZE - 1) begin
                    m_axis_tdata <= (pool_type == 0) ? max_val : avg_val;
                    valid_reg    <= 1;
                    last_reg     <= s_axis_tlast;
                    count        <= 0;
                    write_ptr    <= 0;
                end else begin
                    count     <= count + 1;
                    valid_reg <= 0;
                end
            end else if (m_axis_tvalid && m_axis_tready) begin
                valid_reg <= 0;
            end
        end
    end

endmodule