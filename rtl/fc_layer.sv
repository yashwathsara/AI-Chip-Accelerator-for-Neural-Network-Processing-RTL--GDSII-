`timescale 1ns/1ps

module fc_layer #(
    parameter int INPUT_SIZE  = 128,
    parameter int OUTPUT_SIZE = 64,
    parameter int DATA_WIDTH  = 8
)(
    input  logic clk,
    input  logic reset,

    // Control
    input  logic start,
    output logic done,

    // Flattened inputs
    input  logic signed [INPUT_SIZE*DATA_WIDTH-1:0]               input_data_flat,
    input  logic signed [OUTPUT_SIZE*INPUT_SIZE*DATA_WIDTH-1:0]   weights_flat,
    input  logic signed [OUTPUT_SIZE*DATA_WIDTH-1:0]              bias_flat,

    // Flattened outputs
    output logic signed [OUTPUT_SIZE*DATA_WIDTH-1:0]              output_data_flat
);

    // ------------------------------------------------------------
    // Internal storage
    // ------------------------------------------------------------
    logic signed [DATA_WIDTH-1:0] input_data  [0:INPUT_SIZE-1];
    logic signed [DATA_WIDTH-1:0] weights     [0:OUTPUT_SIZE-1][0:INPUT_SIZE-1];
    logic signed [DATA_WIDTH-1:0] bias        [0:OUTPUT_SIZE-1];
    logic signed [DATA_WIDTH-1:0] output_data [0:OUTPUT_SIZE-1];

    logic signed [2*DATA_WIDTH-1:0] acc [0:OUTPUT_SIZE-1];

    integer in_idx;
    integer out_idx;

    // ------------------------------------------------------------
    // FSM
    // ------------------------------------------------------------
    typedef enum logic [1:0] {
        IDLE,
        COMPUTE,
        COMPLETE,
        WAIT_DONE
    } state_t;

    state_t state, next_state;

    // ------------------------------------------------------------
    // UNPACK INPUT DATA (GENERATE – ASIC SAFE)
    // ------------------------------------------------------------
    genvar i, j;
    generate
        for (i = 0; i < INPUT_SIZE; i = i + 1) begin : UNPACK_INPUT
            assign input_data[i] =
                input_data_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH];
        end
    endgenerate

    generate
        for (i = 0; i < OUTPUT_SIZE; i = i + 1) begin : UNPACK_BIAS
            assign bias[i] =
                bias_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH];
        end
    endgenerate

    generate
        for (i = 0; i < OUTPUT_SIZE; i = i + 1) begin : UNPACK_W_ROW
            for (j = 0; j < INPUT_SIZE; j = j + 1) begin : UNPACK_W_COL
                localparam int FLAT_INDEX = i*INPUT_SIZE + j;
                assign weights[i][j] =
                    weights_flat[(FLAT_INDEX+1)*DATA_WIDTH-1 -: DATA_WIDTH];
            end
        end
    endgenerate

    // ------------------------------------------------------------
    // FSM STATE REG
    // ------------------------------------------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end

    // ------------------------------------------------------------
    // FSM NEXT STATE
    // ------------------------------------------------------------
    always_comb begin
        case (state)
            IDLE:       next_state = start ? COMPUTE : IDLE;
            COMPUTE:    next_state = (in_idx == INPUT_SIZE) ? COMPLETE : COMPUTE;
            COMPLETE:   next_state = WAIT_DONE;
            WAIT_DONE:  next_state = start ? WAIT_DONE : IDLE;
            default:    next_state = IDLE;
        endcase
    end

    // ------------------------------------------------------------
    // MAIN COMPUTATION
    // ------------------------------------------------------------
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            in_idx <= 0;
            done   <= 0;

            for (out_idx = 0; out_idx < OUTPUT_SIZE; out_idx = out_idx + 1) begin
                acc[out_idx]        <= '0;
                output_data[out_idx] <= '0;
            end
        end
        else begin
            case (state)

                IDLE: begin
                    in_idx <= 0;
                    done   <= 0;
                    for (out_idx = 0; out_idx < OUTPUT_SIZE; out_idx = out_idx + 1)
                        acc[out_idx] <= bias[out_idx];
                end

                COMPUTE: begin
                    for (out_idx = 0; out_idx < OUTPUT_SIZE; out_idx = out_idx + 1)
                        acc[out_idx] <= acc[out_idx] +
                                        weights[out_idx][in_idx] *
                                        input_data[in_idx];
                    in_idx <= in_idx + 1;
                end

                COMPLETE: begin
                    for (out_idx = 0; out_idx < OUTPUT_SIZE; out_idx = out_idx + 1) begin
                        if (acc[out_idx] > $signed((1 << (DATA_WIDTH-1)) - 1))
                            output_data[out_idx] <= $signed((1 << (DATA_WIDTH-1)) - 1);
                        else if (acc[out_idx] < $signed(-(1 << (DATA_WIDTH-1))))
                            output_data[out_idx] <= $signed(-(1 << (DATA_WIDTH-1)));
                        else
                            output_data[out_idx] <= acc[out_idx][DATA_WIDTH-1:0];
                    end
                    done <= 1;
                end

                WAIT_DONE: begin
                    done <= 0;
                end

            endcase
        end
    end

    // ------------------------------------------------------------
    // PACK OUTPUT
    // ------------------------------------------------------------
    generate
        for (i = 0; i < OUTPUT_SIZE; i = i + 1) begin : PACK_OUTPUT
            assign output_data_flat[(i+1)*DATA_WIDTH-1 -: DATA_WIDTH] =
                   output_data[i];
        end
    endgenerate

endmodule

