/**
 * diagnosticsSyncMem
 * Joshua Vasquez
 * November 5, 2014 and updated Sept 11, 2015
 */

/**
 * \brief data can be written to memory concurrently and read back
 *        one-byte-at-a-time.
*/
module diagnosticsSyncMem( input logic freezeData, clk,
                           input logic [15:0] encoder_count,
                           input logic [31:0] time_per_tick,
                           input logic [15:0] raw_velocity,
                           input logic [15:0] filtered_velocity,
                           input logic [15:0] output_gain,
                           input logic [15:0] torque_vector_pos,
                           input logic [15:0] electrical_angle_ticks,
                           input logic [7:0] memAddress,
                          output logic [7:0] memData);

    logic [7:0] mem [0:15];

    // freeze changing encoder data on the fetch signal so that it can be
    // clocked out while it isn't changing
    always_ff @ (posedge clk)
    begin
        mem[0] <= freezeData ? mem[0] : encoder_count[15:8];
        mem[1] <= freezeData ? mem[1] : encoder_count[7:0];
        mem[2] <= freezeData ? mem[2] : time_per_tick[31:24];
        mem[3] <= freezeData ? mem[3] : time_per_tick[23:16];
        mem[4] <= freezeData ? mem[4] : time_per_tick[15:8];
        mem[5] <= freezeData ? mem[5] : time_per_tick[7:0];
        mem[6] <= freezeData ? mem[6] : raw_velocity[15:8];
        mem[7] <= freezeData ? mem[7] : raw_velocity[7:0];
        mem[8] <= freezeData ? mem[8] : filtered_velocity[15:8];
        mem[9] <= freezeData ? mem[9] : filtered_velocity[7:0];
        mem[10] <= freezeData ? mem[10] : output_gain[15:8];
        mem[11] <= freezeData ? mem[11] : output_gain[7:0];
        mem[12] <= freezeData ? mem[12] : torque_vector_pos[15:8];
        mem[13] <= freezeData ? mem[13] : torque_vector_pos[7:0];
        mem[14] <= freezeData ? mem[14] : electrical_angle_ticks[15:8];
        mem[15] <= freezeData ? mem[15] : electrical_angle_ticks[7:0];
/*
        mem[16] <= freezeData ? mem[16] : pwm_phase_a[15:8];
        mem[17] <= freezeData ? mem[17] : pwm_phase_a[7:0];
        mem[18] <= freezeData ? mem[18] : pwm_phase_b[15:8];
        mem[19] <= freezeData ? mem[19] : pwm_phase_b[7:0];
        mem[20] <= freezeData ? mem[20] : pwm_phase_c[15:8];
        mem[21] <= freezeData ? mem[21] : pwm_phase_c[7:0];
*/
    end

    // Implement reading from memory.
    assign memData = mem[memAddress];

endmodule
