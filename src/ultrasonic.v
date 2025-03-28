module ultrasonic_motion_detector (
    input wire clk,            // System clock
    input wire rst,            // Reset
    input wire echo,           // Echo pin from sensor
    output reg trigger,        // Trigger pin to sensor
    output reg motion_detected // High when motion is detected
);

    parameter THRESHOLD = 100;   // Distance change threshold
    parameter MAX_COUNT = 20000; // Max count for timeout (~distance cap)

    reg [15:0] counter;
    reg [15:0] distance;
    reg [15:0] prev_distance;
    reg measuring;

    reg [15:0] trigger_timer;

    // Trigger pulse generator (10us)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            trigger <= 0;
            trigger_timer <= 0;
        end else if (trigger_timer == 0) begin
            trigger <= 1;
            trigger_timer <= 100; // Adjust to match 10us @ your clock freq
        end else if (trigger_timer == 1) begin
            trigger <= 0;
            trigger_timer <= MAX_COUNT;
        end else begin
            trigger_timer <= trigger_timer - 1;
        end
    end

    // Echo pulse measurement
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 0;
            distance <= 0;
            measuring <= 0;
            motion_detected <= 0;
            prev_distance <= 0;
        end else begin
            if (echo && !measuring) begin
                measuring <= 1;
                counter <= 0;
            end else if (measuring && echo) begin
                if (counter < MAX_COUNT)
                    counter <= counter + 1;
            end else if (measuring && !echo) begin
                measuring <= 0;
                distance <= counter;

                // Compare with previous measurement
                if ((counter > prev_distance && (counter - prev_distance) > THRESHOLD) ||
                    (prev_distance > counter && (prev_distance - counter) > THRESHOLD))
                    motion_detected <= 1;
                else
                    motion_detected <= 0;

                prev_distance <= counter;
            end
        end
    end

endmodule
