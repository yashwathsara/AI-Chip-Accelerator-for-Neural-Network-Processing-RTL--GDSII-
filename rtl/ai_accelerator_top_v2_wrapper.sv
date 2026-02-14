`timescale 1ns/1ps

module ai_accelerator_top_v2_wrapper (
    input  wire clk,
    input  wire rst_n,

    // AXI-Stream INPUT
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire [23:0] s_axis_tdata,
    input  wire        s_axis_tlast,

    // AXI-Stream OUTPUT
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire [23:0] m_axis_tdata,
    output wire        m_axis_tlast,

    // Status (ONE bus)
    output wire [31:0] status
);

    wire valid_out;
    wire done;
    wire error;
    wire [7:0] debug_out;

    ai_accelerator_top_v2 core (
        .clk(clk),
        .rst_n(rst_n),

        .s_axis_input_tvalid(s_axis_tvalid),
        .s_axis_input_tready(s_axis_tready),
        .s_axis_input_tdata(s_axis_tdata),
        .s_axis_input_tlast(s_axis_tlast),

        .m_axis_output_tvalid(m_axis_tvalid),
        .m_axis_output_tready(m_axis_tready),
        .m_axis_output_tdata(m_axis_tdata),
        .m_axis_output_tlast(m_axis_tlast),

        .valid_out(valid_out),
        .done(done),
        .error(error),
        .debug_out(debug_out)
    );

    assign status = {
        21'd0,
        error,
        done,
        valid_out,
        debug_out
    };

endmodule

