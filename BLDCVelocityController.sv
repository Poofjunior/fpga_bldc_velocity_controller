module BLDCVelocityController(
        input logic clk, reset,
        input logic mosi, sck, cs,
       output logic miso,
        input logic signed [15:0] desired_velocity,
        input logic encoder_a, encoder_b,
       output logic pwm_phase_a, pwm_phase_b, pwm_phase_c);

logic encoder_change;
logic encoder_direction; // unused

logic controller_override;
logic control_loop_pulse;
logic filter_pulse;
logic commutation_enable;

logic [10:0] input_mod_1170;

logic signed [11:0] output_gain;
logic signed [11:0] output_gain_mux_out;
logic signed [15:0] filtered_velocity;

logic [31:0] encoder_count;
logic [31:0] time_per_tick;
logic [12:0] torque_vector_pos;
logic [15:0] raw_velocity;
logic signed [15:0] signed_velocity;
logic signed [15:0] velocity_with_slow_cutoff;

logic reset_encoder_count;
logic apply_initial_commutation;

/// diagnostics-related logic
logic [7:0] address_out;
logic [7:0] spi_data_to_send;
logic set_new_data;
logic clear_new_data_flag;

logic sign; // sign of velocity.

/// TODO: add synchronizer to asynchronous encoder inputs.
QuadratureEncoder encoder_instance(.clk(clk), .reset(reset),
                                   .sig_a(encoder_a), .sig_b(encoder_b),
                                   .encoder_count(encoder_count),
                                   .state_change(encoder_change),
                                   .direction(encoder_direction));


TickTimer tick_timer_instance(.clk(clk), .reset(reset),
                              .state_change(encoder_change),
                              .signIn(encoder_direction),
                              .time_per_tick(time_per_tick),
                              .signOut(sign));


motor_control_unit control_unit_instance(
                        .clk(clk),
                        .reset(reset),
                        .reset_encoder_count(reset_encoder_count),
                        .apply_initial_commutation(apply_initial_commutation),
                        .controller_override(controller_override),
                        .control_loop_pulse(control_loop_pulse),
                        .filter_pulse(filter_pulse),
                        .commutation_enable(commutation_enable));


TickTimeToVelocityLookup velocity_lut(.time_per_tick(time_per_tick[13:0]),
                                      .velocity(raw_velocity));

assign signed_velocity = (sign) ?
                             ~raw_velocity + 'b1: // invert the bits and add 1
                             raw_velocity;
assign velocity_with_slow_cutoff = (time_per_tick > 1023) ?
                                        16'b0 :
                                        signed_velocity;


//iirFilter iir_filter_instance(
//            .clk(clk), .reset(reset), .enable(filter_pulse),
//            .raw_signed_velocity(velocity_mux_out),
//            .filtered_velocity(filtered_velocity));
//
//
//PIController pi_controller_instance(
//                .clk(clk),
//                .reset(reset),
//                .enable(control_loop_pulse),
//                .desired_velocity(desired_velocity),
//                .actual_velocity(filtered_velocity),
//                .kp(10), .ki(0),
//                .output_gain(output_gain));
//
//
/////FIXME: output is wrong in the RTL.  Wat.
///*
//assign output_gain_mux_out = (controller_override) ?
//                                1'b1:
//                                output_gain;
//*/
//parameter [11:0] fixed_gain = 12'h7FF;
//always_comb
//begin
//    integer i;
//    for (i = 0; i < 12; i = i + 1)
//    begin
//        output_gain_mux_out[i] = (controller_override) ?
//                                    fixed_gain[i] :
//                                    output_gain[i];
//    end
//end
//
//
////assign output_gain_mux_out = output_gain;
//
//torque_vector_pos advance_angle_generator( .encoder_ticks(encoder_count[12:0]),
//                                           .direction(output_gain[11]),
//                                           .torque_vector_pos(torque_vector_pos));
//
//
//fastModulo1170 fast_module_1170_instance(
//                    .clk(clk), .reset(reset),
//                    .encoder_input(torque_vector_pos),
//                    .input_mod_1170(input_mod_1170));
//
//
//motorCommutation motor_commutation_instance(
//                    .clk(clk), .reset(reset), .enable(commutation_enable),
//                    .gain(output_gain_mux_out),
//                    .torque_vector_position(input_mod_1170),
//                    .pwm_phase_a(pwm_phase_a),
//                    .pwm_phase_b(pwm_phase_b),
//                    .pwm_phase_c(pwm_phase_c));

spi_slave_interface #(.DATA_WIDTH(8))
            spi_slave_inst(.clk(clk),
                           .cs(cs), .sck(sck), .mosi(mosi),
                           .miso(miso),
                           .clear_new_data_flag(clear_new_data_flag),
                           .synced_new_data_flag(clear_new_data_flag), // clear data as soon as we get it.
                           .address_out(address_out),
                           .write_enable(), // unused.
                           .data_to_send(spi_data_to_send),
                           .synced_data_received()); // unused

diagnosticsSyncMem diagnostics_mem(.freezeData(~cs), .clk(clk),
                                   .encoder_count(encoder_count[15:0]),
                                   .time_per_tick(time_per_tick),
                                   .raw_velocity(velocity_with_slow_cutoff),
                                   //.filtered_velocity(filtered_velocity),
                                   //.output_gain({4'b0000, output_gain}),
                                   //.torque_vector_pos({3'b000, torque_vector_pos}),
                                   //.electrical_angle_ticks({4'b0000, input_mod_1170}),
                                   //.memAddress(address_out),
                                   .memData(spi_data_to_send));
endmodule
