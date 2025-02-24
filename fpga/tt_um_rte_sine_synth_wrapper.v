/*
 * tt_um_rte_sine_synth_wrapper.v
 *
 * Wrapper for Arty A7 board around the
 * TinyTapeout project tt_um_rte_sine_synth.v
 *
 * What this wrapper adds:
 *
 * (1) Divide-by-2 on the clock to match the TinyTapeout
 *     development board running at 50MHz
 * (2) Inverter on the reset pin
 * (3) Simplify the bidirectional I/O as outputs only.
 *
 */

`include "../src/tt_um_rte_sine_synth.v"

module tt_um_rte_sine_synth_wrapper (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    output wire [7:0] uio_out,  // IOs: Output path
    input  wire       clk,      // clock
    input  wire       rst_n     // reset - low to reset
);

    reg clk2;

    // Instantiate the synth project

    tt_um_rte_sine_synth synth (
	.ui_in(ui_in),		// 8-bit input
	.uo_out(uo_out),	// 8-bit output
	.uio_in(8'h00),		// unused
	.uio_out(uio_out),	// used as outputs only
	.uio_oe(),		// unused
	.clk(clk2),		// halved clock
	.rst_n(rst_n)		// inverted reset
    );

    // Invert reset to project, and halve the clock

    always @(posedge clk) begin
	if (rst_n) begin
	    clk2 <= ~clk2;
	end else begin
	    clk2 <= 0;
	end
    end

endmodule;

