/*
 * tt_um_rte_sine_synth.v
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

// Include the PWM module by Michale Bell
`include "pwm.v"

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
    reg [8:0] event_count;	// Divides 50MHz clock into events
    reg [1:0] qtr_count;	// Counts 1/4 phases	
    reg [5:0] phase_count;	// Counts 1/256 phases (1/64 of 1/4)
    reg [5:0] phase_check;	// Phase or reversed phase

    reg [10:0] next_limit;	// Max count value for the next note
    reg [10:0] phase_limit;	// Max count value for the current note
    reg [7:0] last_input;	// Last input value received
    reg [7:0] new_input;	// New input value received
    reg [4:0] delta;		// Output value delta -12 to +12 (-16 to +15)
    reg [9:0] out_val;		// Output value (lowest two bits dropped)

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
	    phase_limit <= 0;
	end else begin
	    if (event_count == 0) begin
		event_count <= phase_limit;
		if (phase_count == 63) begin
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
		event_count <= event_count - 1;
	    end

	    // Only change notes at zero phase.
	    if (event_count == 0 && phase_count == 63 && qtr_count == 3)
		phase_limit <= next_limit;
	end
    end

    // Inputs
    always @(posedge clk or negedge rst_n) begin
	if (~rst_n) begin
	    next_limit <= 0;
	    last_input <= 0;
	    new_input <= 0;
	end else if (~rst_n_i) begin
	    last_input <= new_input;
	    new_input <= ui_in;
	end else begin
	    if (new_input[0] == 1 && last_input[0] == 0)
		next_limit <= 11'd373;		// Play C 523.25 Hz
	    else if (new_input[1] == 1 && last_input[1] == 0)
		next_limit <= 11'd333;		// Play D 587.33 Hz
	    else if (new_input[2] == 1 && last_input[2] == 0)
		next_limit <= 11'd296;		// Play E 659.25 Hz
	    else if (new_input[3] == 1 && last_input[3] == 0)
		next_limit <= 11'd280;		// Play F 698.46 Hz
	    else if (new_input[4] == 1 && last_input[4] == 0)
		next_limit <= 11'd249;		// Play G 783.99 Hz
	    else if (new_input[5] == 1 && last_input[5] == 0)
		next_limit <= 11'd222;		// Play A 880.00 Hz
	    else if (new_input[6] == 1 && last_input[6] == 0)
		next_limit <= 11'd198;		// Play B 987.77 Hz
	    else if (new_input[7] == 1 && last_input[7] == 0)
		next_limit <= 11'd187;		// Play C 1046.5 Hz
	    else if (new_input == 0)
		next_limit <= 0;		// Stop playing
	
	    last_input <= new_input;
	    new_input <= ui_in;

	end
    end

    // Output value
    always @(posedge clk or negedge rst_n) begin
	if (~rst_n) begin
	    delta <= 12;
	    out_val <= 505;	/* 511 - (delta / 2) */
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
	     *
	     * Deltas are determined by (using octave notation):
	     * Example for 64 samples per quarter cycle:
	     * 	x1 = [0.5:63.5] 	# Align phase to a half-integer
	     *  x2 = x1 * (90 / 64) 	# Convert to phase between 0 and 90 degrees
	     *  y2 = sin(pi * x2 / 180) # Get the sine values
	     *  y3 = y2 * 512		# Convert to 10 bit
	     *  rdelta = y3(2:64) - y3(1:63)
	     *  delta = floor(rdelta)
	     *
	     *  delta-delta encoding:  Enumerate the positions at which the
	     *  delta value decreases or increase by one.  This is possible
	     *  since the sine wave is smooth and monotonic over a quarter
	     *  cycle.
	     *
	     *  Out of 64 positions on a quarter cycle, delta starts at 12
	     *  and decrements at positions:  12, 20, 26, 31, 35, 39, 43,
	     *  47, 50, 54, 57, 60
	     */

	    if (event_count == 4) begin
		if (qtr_count == 0 || qtr_count == 2) begin
		    // Forward count
		    phase_check <= phase_count;
		end else begin
		    // Backward count
		    phase_check <= 63 - phase_count;
		end
	    end else if (event_count == 3) begin
		if (phase_check == 0)
		    delta <= 12;
		else if (phase_check == 12)
		    delta <= 11;
		else if (phase_check == 20)
		    delta <= 10;
		else if (phase_check == 26)
		    delta <= 9;
		else if (phase_check == 31)
		    delta <= 8;
		else if (phase_check == 35)
		    delta <= 7;
		else if (phase_check == 39)
		    delta <= 6;
		else if (phase_check == 43)
		    delta <= 5;
		else if (phase_check == 47)
		    delta <= 4;
		else if (phase_check == 50)
		    delta <= 3;
		else if (phase_check == 54)
		    delta <= 2;
		else if (phase_check == 57)
		    delta <= 1;
		else if (phase_check == 60)
		    delta <= 0;
	
	    end else if (event_count == 2) begin
		if (qtr_count == 0 || qtr_count == 3) begin
		    out_val <= out_val + delta;
		end else begin
		    out_val <= out_val - delta;
		end
	    end
	end
    end
  
    assign uo_out  = out_val[9:2];	/* Drop the lowest two bits */

    // All but the uppermost bidirectional lines are unused;  set them to zero.
    assign uio_out[6:0] = 7'h00;
    // The uppermost bidirectional bit is configured as an output
    assign uio_oe  = 8'h80;

    // avoid linter warning about unused pins:
    wire _unused_pins = ena;

    // Instantiate the PWM module
    pwm_audio pwm (
	.clk(clk),
	.rst_n(rst_n),
	.sample(out_val),
	.pwm(uio_out[7])
    );

endmodule  // tt_um_rte_sine_synth
