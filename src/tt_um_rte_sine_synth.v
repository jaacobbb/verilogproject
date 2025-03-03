/*
 * tt_um_sine_synth.v
 *
 * User module with a sine-wave synthesizer
 * synthesizer produces 8-bit outputs for 8 notes C, D, E, F, G, A, B, C
 * in the A=880Hz octave.  Each input bit plays one note.
 * Assumes an input clock of 50MHz.  A 25MHz clock produces output one
 * octave lower.
 *
 * Author: Tim Edwards <tim@opencircuitdesign.com>
 */

`default_nettype none

module tt_um_rte_sine_synth (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // Slowest note is 523.25 Hz;  from input clock of 50MHz this is
    // a count of 95557;  however, the output will be generated at
    // 1/64 intervals, so each interval count is 1493.  This requires
    // an 11-bit counter (counts to up to 2048).

    reg rst_n_i;
    reg [10:0] event_count;	// Divides 50MHz clock into events
    reg [1:0] qtr_count;	// Counts 1/4 phases	
    reg [3:0] phase_count;	// Counts 1/64 phases (1/16 of 1/4)
    reg [3:0] phase_check;	// Phase or reversed phase

    reg [10:0] phase_limit;	// Max count value for the given note
    reg [7:0] last_input;	// Last input value received
    reg [4:0] delta;		// Output value delta -13 to +13 (-16 to +15)
    reg [7:0] out_val;		// Output value

    // Synchronized reset
    always @(posedge clk or negedge rst_n) begin
	if (~rst_n) begin
	    rst_n_i <= 1'b0;
	end else begin
	    rst_n_i <= 1'b1;
	end
    end

    // Counts
    always @(posedge clk or negedge rst_n_i) begin
	if (~rst_n_i) begin
	    event_count <= 0;
	    qtr_count <= 0;
	    phase_count <= 0;
	end else begin
	    if (event_count >= phase_limit) begin
		event_count <= 0;
		if (phase_count == 15) begin
		    phase_count <= 0;
		    if (qtr_count == 3) begin
			qtr_count <= 0;
		    end else begin
			qtr_count <= qtr_count + 1;
		    end
		end else begin
		    phase_count <= phase_count + 1;
		end
	    end else begin
		event_count <= event_count + 1;
	    end
	end
    end

    // Inputs
    always @(posedge clk or negedge rst_n) begin
	if (~rst_n) begin
	    phase_limit <= 0;
	    last_input <= 0;
	end else if (~rst_n_i) begin
	    last_input <= ui_in;
	end else begin
	    if (ui_in[0] == 1 && last_input[0] == 0)
		phase_limit <= 11'd1493;	// Play C 523.25 Hz
	    else if (ui_in[1] == 1 && last_input[1] == 0)
		phase_limit <= 11'd1330;	// Play D 587.33 Hz
	    else if (ui_in[2] == 1 && last_input[2] == 0)
		phase_limit <= 11'd1185;	// Play E 659.25 Hz
	    else if (ui_in[3] == 1 && last_input[3] == 0)
		phase_limit <= 11'd1119;	// Play F 698.46 Hz
	    else if (ui_in[4] == 1 && last_input[4] == 0)
		phase_limit <= 11'd997;		// Play G 783.99 Hz
	    else if (ui_in[5] == 1 && last_input[5] == 0)
		phase_limit <= 11'd888;		// Play A 880.00 Hz
	    else if (ui_in[6] == 1 && last_input[6] == 0)
		phase_limit <= 11'd791;		// Play B 987.77 Hz
	    else if (ui_in[7] == 1 && last_input[7] == 0)
		phase_limit <= 11'd747;		// Play C 1046.5 Hz
	    else if (ui_in == 0)
		phase_limit <= 0;		// Stop playing
	
	    last_input <= ui_in;
	end
    end

    // Output value
    always @(posedge clk or negedge rst_n) begin
	if (~rst_n) begin
	    delta <= 0;
	    out_val <= 128;
	    phase_check <= 0;
	end else begin
	    /* There is lots of time to do things, so work in three steps:
	     *
	     * Step 1:  Determine the phase value from the phase count.
	     * 		The phase reverses every quarter.
	     * Step 2:  Determine the delta output based on the phsae.
	     * Step 3:  Add the delta output on the waveform upswing and
	     * 		subtract it on the waveform downswing.
	     *
	     * The use of deltas means we only have to hard-code nine
	     * small values to produce a sine wave.
	     */

	    if (event_count == 0) begin
		if (qtr_count == 0 || qtr_count == 2) begin
		    // Forward count
		    phase_check <= phase_count;
		end else begin
		    // Backward count
		    phase_check <= 15 - phase_count;
		end
	    end else if (event_count == 1) begin
		if (phase_check == 0)
		    delta <= 13;
		else if (phase_check == 2)
		    delta <= 12;
		else if (phase_check == 5)
		    delta <= 11;
		else if (phase_check == 7)
		    delta <= 10;
		else if (phase_check == 9)
		    delta <= 8;
		else if (phase_check == 10)
		    delta <= 7;
		else if (phase_check == 12)
		    delta <= 5;
		else if (phase_check == 13)
		    delta <= 4;
		else if (phase_check == 15)
		    delta <= 1;
	
	    end else if (event_count == 2) begin
		if (qtr_count == 0 || qtr_count == 3) begin
		    out_val <= out_val + delta;
		end else begin
		    out_val <= out_val - delta;
		end
	    end
	end
    end
  
    assign uo_out  = out_val;

    // Bidirectional lines are unused;  set them to zero.
    assign uio_out = 8'h00;
    assign uio_oe  = 8'h00;

    // avoid linter warning about unused pins:
    wire _unused_pins = ena;

endmodule  // tt_um_rte_sine_synth
