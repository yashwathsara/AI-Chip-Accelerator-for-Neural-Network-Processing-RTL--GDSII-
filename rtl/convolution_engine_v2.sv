`timescale 1ns / 1ps

module convolution_engine_v2 #(
    parameter DATA_WIDTH   = 8,
    parameter MAX_KERNEL   = 5,
    parameter MAX_CHANNELS = 3,
    parameter IMAGE_SIZE   = 64
)(
    input  wire clk,
    input  wire reset,

    // AXI-Stream input
    input  wire                  s_axis_tvalid,
    output wire                  s_axis_tready,
    input  wire [DATA_WIDTH*MAX_CHANNELS-1:0] s_axis_tdata,
    input  wire                  s_axis_tlast,

    // Kernel stream (flattened)
    input  wire                  s_kernel_tvalid,
    output wire                  s_kernel_tready,
    input  wire [DATA_WIDTH*MAX_CHANNELS*MAX_KERNEL*MAX_KERNEL-1:0] s_kernel_tdata,

    // AXI-Stream output
    output reg                   m_axis_tvalid,
    input  wire                  m_axis_tready,
    output reg  [DATA_WIDTH-1:0] m_axis_tdata,
    output reg                   m_axis_tlast
);

    // --------------------------------------------------
    // FSM
    // --------------------------------------------------
    localparam IDLE        = 3'd0;
    localparam LOAD_KERNEL = 3'd1;
    localparam LOAD_INPUT  = 3'd2;
    localparam MAC         = 3'd3;
    localparam OUTPUT      = 3'd4;

    reg [2:0] state;

    // --------------------------------------------------
    // Memories (NO reset!)
    // --------------------------------------------------
    reg signed [DATA_WIDTH-1:0] kernel [0:MAX_CHANNELS*MAX_KERNEL*MAX_KERNEL-1];
    reg signed [DATA_WIDTH-1:0] image_mem [0:IMAGE_SIZE*IMAGE_SIZE*MAX_CHANNELS-1];

    // --------------------------------------------------
    // Counters
    // --------------------------------------------------
    reg [7:0] pixel_idx;
    reg [7:0] kernel_idx;
    reg [15:0] img_wr_ptr;

    // --------------------------------------------------
    // MAC datapath
    // --------------------------------------------------
    reg signed [DATA_WIDTH-1:0] pixel_reg;
    reg signed [DATA_WIDTH-1:0] weight_reg;
    reg signed [2*DATA_WIDTH:0] acc;

    wire signed [2*DATA_WIDTH-1:0] mult_res;
    assign mult_res = pixel_reg * weight_reg;

    // --------------------------------------------------
    // Handshake
    // --------------------------------------------------
    assign s_axis_tready  = (state == LOAD_INPUT);
    assign s_kernel_tready = (state == LOAD_KERNEL);

    // --------------------------------------------------
    // Sequential logic (SYNCHRONOUS RESET ONLY)
    // --------------------------------------------------
    always @(posedge clk) begin
        if (reset) begin
            state         <= IDLE;
            pixel_idx     <= 0;
            kernel_idx    <= 0;
            img_wr_ptr    <= 0;
            acc           <= 0;
            m_axis_tvalid <= 1'b0;
            m_axis_tdata  <= {DATA_WIDTH{1'b0}};
            m_axis_tlast  <= 1'b0;
        end else begin
            case (state)

                // ----------------------------
                IDLE: begin
                    m_axis_tvalid <= 1'b0;
                    if (s_kernel_tvalid) begin
                        kernel_idx <= 0;
                        state <= LOAD_KERNEL;
                    end
                end

                // ----------------------------
                LOAD_KERNEL: begin
                    if (s_kernel_tvalid) begin
                        kernel[kernel_idx] <=
                            s_kernel_tdata[kernel_idx*DATA_WIDTH +: DATA_WIDTH];

                        if (kernel_idx == MAX_CHANNELS*MAX_KERNEL*MAX_KERNEL-1) begin
                            kernel_idx <= 0;
                            img_wr_ptr <= 0;
                            state <= LOAD_INPUT;
                        end else begin
                            kernel_idx <= kernel_idx + 1;
                        end
                    end
                end

                // ----------------------------
                LOAD_INPUT: begin
                    if (s_axis_tvalid) begin
                        image_mem[img_wr_ptr] <=
                            s_axis_tdata[DATA_WIDTH-1:0];

                        img_wr_ptr <= img_wr_ptr + 1;

                        if (s_axis_tlast) begin
                            pixel_idx  <= 0;
                            kernel_idx <= 0;
                            acc        <= 0;
                            state      <= MAC;
                        end
                    end
                end

                // ----------------------------
                MAC: begin
                    pixel_reg  <= image_mem[pixel_idx];
                    weight_reg <= kernel[kernel_idx];
                    acc        <= acc + mult_res;

                    if (kernel_idx == MAX_CHANNELS*MAX_KERNEL*MAX_KERNEL-1) begin
                        kernel_idx <= 0;
                        state <= OUTPUT;
                    end else begin
                        kernel_idx <= kernel_idx + 1;
                    end
                end

                // ----------------------------
                OUTPUT: begin
                    if (m_axis_tready) begin
                        m_axis_tdata  <= acc[DATA_WIDTH-1:0];
                        m_axis_tvalid <= 1'b1;
                        m_axis_tlast  <= 1'b1;
                        acc           <= 0;
                        state         <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

