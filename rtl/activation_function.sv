`timescale 1ns/1ps

// Activation function module (ASIC / Yosys safe)
module activation_function #(
    parameter int DATA_WIDTH = 8
)(
    input  logic                  clk,
    input  logic                  reset,

    input  logic                  s_axis_tvalid,
    output logic                  s_axis_tready,
    input  logic [DATA_WIDTH-1:0] s_axis_tdata,
    input  logic                  s_axis_tlast,

    input  logic [1:0]            activation_mode, // 0: RELU, 1: LEAKY_RELU, 2: TANH, 3: NONE

    output logic                  m_axis_tvalid,
    input  logic                  m_axis_tready,
    output logic [DATA_WIDTH-1:0] m_axis_tdata,
    output logic                  m_axis_tlast
);

    logic [DATA_WIDTH-1:0] activated_data;
    logic valid_reg;
    logic last_reg;

    // Handshake
    assign s_axis_tready = ~valid_reg | m_axis_tready;
    assign m_axis_tvalid = valid_reg;
    assign m_axis_tdata  = activated_data;
    assign m_axis_tlast  = last_reg;

    // Valid / last pipeline
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            valid_reg <= 1'b0;
            last_reg  <= 1'b0;
        end else if (s_axis_tvalid && s_axis_tready) begin
            valid_reg <= 1'b1;
            last_reg  <= s_axis_tlast;
        end else if (m_axis_tvalid && m_axis_tready) begin
            valid_reg <= 1'b0;
        end
    end

    // Activation compute
    always_ff @(posedge clk) begin
        if (s_axis_tvalid && s_axis_tready) begin
            case (activation_mode)
                2'b00: begin // RELU
                    activated_data <= s_axis_tdata[DATA_WIDTH-1] ? '0 : s_axis_tdata;
                end
                2'b01: begin // LEAKY RELU (≈0.1)
                    activated_data <= s_axis_tdata[DATA_WIDTH-1] ?
                                      ((s_axis_tdata * 13) >> 7) :
                                      s_axis_tdata;
                end
                2'b10: begin // TANH (approx)
                    activated_data <= tanh_lut(s_axis_tdata);
                end
                default: begin // NONE
                    activated_data <= s_axis_tdata;
                end
            endcase
        end
    end

    // -------------------------------
    // ASIC-safe TANH approximation
    // -------------------------------
    function logic [DATA_WIDTH-1:0] tanh_lut(input logic [DATA_WIDTH-1:0] x);
        logic [DATA_WIDTH-1:0] y;
        logic [3:0] msb;
        begin
            msb = x[DATA_WIDTH-1:DATA_WIDTH-4];
            case (msb)
                4'b0000: y = x;
                4'b0001: y = x >> 1;
                4'b0010: y = x >> 2;
                default: y = x[DATA_WIDTH-1] ? 8'd1 : 8'd127;
            endcase
            tanh_lut = y;
        end
    endfunction

endmodule

