`default_nettype none

// PWM audio output.
// The output is high for sample clocks out of every 1023 clocks.
// This means a sample of 0 is always off, a sample of 1023 is always on.
//
// Written by Michael Bell for TinyTapeout
//
// Compatible with the TinyTapeout audio PMOD

module pwm_audio (
    input wire clk,
    input wire rst_n,

    input wire [9:0] sample,

    output reg pwm
);

    reg [9:0] count;

    always @(posedge clk) begin
        if (!rst_n) count <= 0;
        else begin
            // PWM output high for sample clocks out of every 1023 clocks
            pwm <= count < sample;

            // Wrap the counter every 1023 clocks
            count <= count + 1;
            if (count == 10'h3fe) count <= 0;
        end
    end

endmodule
