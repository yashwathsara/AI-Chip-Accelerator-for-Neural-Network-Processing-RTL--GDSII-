`timescale 1ns / 1ps

//------------------------------------------------------------------------------
// Clock & Reset Manager
//------------------------------------------------------------------------------
// This module implements a synchronous reset generation mechanism along with
// a reset domain crossing synchronizer. It uses a two-stage synchronizer to
// safely bring the asynchronous reset signal into the clock domain and holds
// the synchronized reset for a fixed number of clock cycles defined by RESET_CYCLES.
//
// Parameters:
//   CLK_FREQ: Frequency of the input clock in Hertz (for documentation).
//   SYNC_STAGES: Number of synchronizer stages (typically 2 for robustness).
//   RESET_CYCLES: The number of clock cycles to hold the reset after the
//                 synchronizer deasserts (exact hold time).
//------------------------------------------------------------------------------
module clock_reset_manager #(
    parameter int CLK_FREQ     = 100_000_000,  // Example: 100 MHz
    parameter int SYNC_STAGES  = 2,            // Two-stage synchronizer
    parameter int RESET_CYCLES = 10            // Hold reset for exactly 10 cycles after synchronizer deasserts
)(
    input  logic clk,           // Stable clock
    input  logic async_reset,   // Asynchronous reset input (active high)
    output logic sync_reset     // Synchronized reset output (active high)
);

    // Internal signals:
    // reset_sync: Two-stage synchronizer for async_reset.
    // reset_delay_counter: Counts down the additional reset hold cycles.
    logic [SYNC_STAGES-1:0] reset_sync;
    logic [$clog2(RESET_CYCLES):0] reset_delay_counter;

    //------------------------------------------------------------------------------
    // Reset Domain Crossing: Two-Stage Synchronizer
    //------------------------------------------------------------------------------
    always_ff @(posedge clk or posedge async_reset) begin
        if (async_reset) begin
            reset_sync <= {SYNC_STAGES{1'b1}};
        end else begin
            reset_sync <= {reset_sync[SYNC_STAGES-2:0], 1'b0};
        end
    end

    //------------------------------------------------------------------------------
    // Synchronous Reset Delay: Hold the reset for exactly RESET_CYCLES cycles
    // after the synchronizer deasserts.
    //------------------------------------------------------------------------------
    always_ff @(posedge clk or posedge async_reset) begin
        if (async_reset) begin
            // Initialize counter to RESET_CYCLES - 1 so that it counts RESET_CYCLES cycles
            reset_delay_counter <= RESET_CYCLES - 1;
        end else if (reset_sync[SYNC_STAGES-1] == 1'b0 && reset_delay_counter != 0) begin
            reset_delay_counter <= reset_delay_counter - 1;
        end
    end

    //------------------------------------------------------------------------------
    // Generate Final Synchronized Reset:
    // The reset remains asserted as long as either the synchronizer indicates
    // reset is still asserted or the delay counter has not yet reached zero.
    //------------------------------------------------------------------------------
    assign sync_reset = reset_sync[SYNC_STAGES-1] || (reset_delay_counter != 0);

endmodule
