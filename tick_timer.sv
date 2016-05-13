/**
 * tickTimer.sv
 * Joshua Vasquez
 * April 15, 2015
 */

module TickTimer ( input logic clk, reset,
                   input logic state_change,
                   input logic signIn,
                  output logic [31:0] time_per_tick,
                  output logic signOut);

/// Default initial value to approximate a velocity of zero
parameter MAX_TIME = 'hFFFFFFFF;

    logic [31:0] micros;        /// microsecond timer
    logic [31:0] currTickTime;  /// current time
    logic [31:0] lastTickTime;  /// timestamp as of last recorded tick

    microsTimer microsTimerInst( .clk(clk), .reset(reset),
                                 .micros(micros));

    always_ff @ (posedge clk, posedge reset)
    begin
        if (reset)
        begin
            currTickTime <= MAX_TIME;
            lastTickTime <= MAX_TIME;
            time_per_tick <= MAX_TIME;
        end
        else
        begin
            currTickTime <= micros;
            signOut <= signIn;

/// update new time-per-tick each time the encoder state machine changes.
            if (state_change)
            begin
                lastTickTime <= currTickTime;
                time_per_tick <= currTickTime - lastTickTime;
            end
            else
            begin
                lastTickTime <= lastTickTime;
                time_per_tick <= time_per_tick;
            end
        end
    end

endmodule



module microsTimer #(TICKS_PER_MICROSECOND = 50)
                    (input logic clk, reset,
                     output logic [31:0] micros);

    logic [5:0] mhzCount;

    logic mhzReset, mhzCountReset;

/// logic for resetting the counter that triggers once per microsecond
    assign mhzCountReset = (mhzCount == TICKS_PER_MICROSECOND);

/// logic for resetting everything
    assign mhzReset = reset | mhzCountReset;

/// Increment mhz clock
    always_ff @ (posedge clk)
    begin
        if (mhzReset)
        begin
            mhzCount <= 6'b0;
        end
        else
        begin
            mhzCount <= mhzCount + 6'b1;
        end
    end

/// Increment microsecond count.
    always_ff @ (posedge clk, posedge reset)
    begin
        if (reset)
        begin
            micros <= 'b0;
        end
        else
        begin
            micros <= mhzCountReset ?
                            micros + 'b1 :
                            micros;
        end
    end
endmodule
