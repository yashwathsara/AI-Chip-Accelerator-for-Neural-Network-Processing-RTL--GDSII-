`timescale 1ns/1ps

module ai_accelerator_top_v2 #(
    parameter DATA_WIDTH = 8,
    parameter IMAGE_SIZE = 64,

    // ASIC-safe demo sizes
    parameter ASIC_INPUT_SIZE  = 16,
    parameter ASIC_OUTPUT_SIZE = 8,

    parameter OUTPUT_SELECT = 0
)(
    input  logic clk,
    input  logic rst_n,

    // AXI-Stream input (image pixels)
    input  logic                    s_axis_input_tvalid,
    output logic                    s_axis_input_tready,
    input  logic [3*DATA_WIDTH-1:0] s_axis_input_tdata,
    input  logic                    s_axis_input_tlast,

    // AXI-Stream output (final result)
    output logic                    m_axis_output_tvalid,
    input  logic                    m_axis_output_tready,
    output logic [3*DATA_WIDTH-1:0] m_axis_output_tdata,
    output logic                    m_axis_output_tlast,

    // Kernel stream (3 × 5 × 5 = 600 bits, FLAT)
    input  logic        s_kernel_tvalid,
    output logic        s_kernel_tready,
    input  logic [599:0] s_kernel_tdata,

    // Status
    output logic                    valid_out,
    output logic                    done,
    output logic [DATA_WIDTH-1:0]   processed_data,
    output logic [7:0]              debug_out,
    output logic                    error
);

    // --------------------------------------------------
    // Reset synchronizer
    // --------------------------------------------------
    logic sync_reset;

    clock_reset_manager reset_mgr (
        .clk(clk),
        .async_reset(~rst_n),
        .sync_reset(sync_reset)
    );

    // --------------------------------------------------
    // Pipeline signals
    // --------------------------------------------------
    logic [3*DATA_WIDTH-1:0] preproc_data;
    logic preproc_valid;
    logic preproc_ready;

    logic conv_valid;
    logic conv_last;
    logic [DATA_WIDTH-1:0] conv_out;

    logic act_valid;
    logic [DATA_WIDTH-1:0] act_out;

    logic pool_valid;
    logic [DATA_WIDTH-1:0] pool_out;

    logic fc_valid;

    // --------------------------------------------------
    // Pre-processing
    // --------------------------------------------------
    image_preprocessing preproc (
        .clk(clk),
        .rst_n(~sync_reset),
        .enable(1'b1),
        .frame_start(~rst_n),
        .s_axis_tdata(s_axis_input_tdata),
        .s_axis_tvalid(s_axis_input_tvalid),
        .s_axis_tready(s_axis_input_tready),
        .m_axis_tdata(preproc_data),
        .m_axis_tvalid(preproc_valid),
        .m_axis_tready(preproc_ready)
    );

    // --------------------------------------------------
    // Convolution Engine v2 (ASIC SAFE)
    // --------------------------------------------------
    convolution_engine_v2 conv (
        .clk(clk),
        .reset(sync_reset),

        .s_axis_tvalid(preproc_valid),
        .s_axis_tready(preproc_ready),
        .s_axis_tdata(preproc_data),
        .s_axis_tlast(s_axis_input_tlast),

        // FLAT kernel input (no unpacking in top)
        .s_kernel_tvalid(s_kernel_tvalid),
        .s_kernel_tready(s_kernel_tready),
        .s_kernel_tdata(s_kernel_tdata),

        .m_axis_tvalid(conv_valid),
        .m_axis_tready(1'b1),
        .m_axis_tdata(conv_out),
        .m_axis_tlast(conv_last)
    );

    // --------------------------------------------------
    // Activation
    // --------------------------------------------------
    activation_function act_fn (
        .clk(clk),
        .reset(sync_reset),
        .s_axis_tvalid(conv_valid),
        .s_axis_tdata(conv_out),
        .m_axis_tvalid(act_valid),
        .m_axis_tdata(act_out)
    );

    // --------------------------------------------------
    // Pooling
    // --------------------------------------------------
    pooling_unit pool (
        .clk(clk),
        .reset(sync_reset),
        .s_axis_tvalid(act_valid),
        .s_axis_tdata(act_out),
        .m_axis_tvalid(pool_valid),
        .m_axis_tdata(pool_out)
    );

    // --------------------------------------------------
    // Fully Connected Layer
    // --------------------------------------------------
    fc_layer #(
        .INPUT_SIZE(ASIC_INPUT_SIZE),
        .OUTPUT_SIZE(ASIC_OUTPUT_SIZE),
        .DATA_WIDTH(DATA_WIDTH)
    ) fc (
        .clk(clk),
        .reset(sync_reset),
        .start(pool_valid),
        .done(fc_valid),
        .input_data_flat(),
        .weights_flat(),
        .bias_flat(),
        .output_data_flat()
    );

    // --------------------------------------------------
    // Output logic
    // --------------------------------------------------
    assign processed_data       = pool_out;
    assign m_axis_output_tdata  = {3{processed_data}};
    assign m_axis_output_tvalid = fc_valid;
    assign m_axis_output_tlast  = fc_valid & m_axis_output_tready;

    assign valid_out = fc_valid;
    assign done      = fc_valid & m_axis_output_tready;
    assign error     = 1'b0;

    assign debug_out = {
        fc_valid,
        pool_valid,
        act_valid,
        conv_valid,
        preproc_valid,
        3'b000
    };

endmodule

