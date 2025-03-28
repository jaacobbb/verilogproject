`timescale 1ns / 1ps

module adder_tb;

    // Testbench signals
    reg  [3:0] a;
    reg  [3:0] b;
    wire [4:0] sum;

    // Instantiate the adder
    adder uut (
        .a(a),
        .b(b),
        .sum(sum)
    );

    initial begin
        // Display header
        $display("Time\t a\t b\t sum");
        $monitor("%0dns\t %b\t %b\t %b", $time, a, b, sum);

        // Test cases
        a = 4'b0000; b = 4'b0000; #10;
        a = 4'b0001; b = 4'b0010; #10;
        a = 4'b0111; b = 4'b0001; #10;
        a = 4'b1111; b = 4'b0001; #10;
        a = 4'b1010; b = 4'b0101; #10;

        $finish;
    end

endmodule
