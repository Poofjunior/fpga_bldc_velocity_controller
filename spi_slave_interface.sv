/**
 * synthesizable spi peripheral
 * Joshua Vasquez
 * September 26 - October 8, 2014
 */

/**
 * \brief an spi slave module that both receives input values and clocks out
 *        output values according to SPI Mode0.
 * \details note that the dataToSend input is sampled whenever the set_new_data
 *          signal is asserted.
 */


module spi_slave_interface
#(parameter    DATA_WIDTH  =  16)
          ( input logic clk,
            input logic cs, sck, mosi,
           output logic miso,
            input logic clear_new_data_flag,
           output logic synced_new_data_flag,
           output logic [(DATA_WIDTH-1):0] address_out,
           output logic write_enable,
            input logic [(DATA_WIDTH-1):0] data_to_send,
           output logic [(DATA_WIDTH-1):0] synced_data_received);


logic new_data_flag;
logic [(DATA_WIDTH-1):0] shift_reg;
logic [(DATA_WIDTH-1):0] data_received;

logic valid_clk;

assign valid_clk = cs ? 1'b0   :
                       sck;

logic set_new_data;
spi_data_ctrl #(DATA_WIDTH) spi_data_ctrl_instance(
                                .cs(cs), .sck(sck),
                                .spi_data_in(data_received),
                                .write_enable(write_enable),
                                .set_new_data(set_new_data),
                                .address_out(address_out));


always_ff @ (negedge valid_clk, posedge set_new_data)
begin
    if (set_new_data)
    begin
        int i;
        for(i = 0; i < DATA_WIDTH; i++)
        begin
           shift_reg[DATA_WIDTH-(i+1)] <= data_to_send[i];
        end
    end
    else begin
    // Handle Output.
        shift_reg[(DATA_WIDTH-1):0] <= (shift_reg[(DATA_WIDTH-1):0] >> 1);
    end
end


always_ff @ (posedge valid_clk)
begin
    // Handle Input.
        data_received[(DATA_WIDTH-1):0] <=
                                    (data_received[(DATA_WIDTH-1):0] << 1);
        data_received[0] <= mosi;
end


assign miso = shift_reg[0];


// Handle external synchronization into output's clock domain.
synchronizer #(DATA_WIDTH) data_synchronizer(
                    .clk(clk),
                    .unsynced_data(data_received[DATA_WIDTH-1:0]),
                    .synced_data(synced_data_received[DATA_WIDTH-1:0]));

always_ff @ (posedge set_new_data, posedge clear_new_data_flag)
begin
    if (clear_new_data_flag)
    begin
        new_data_flag <= 'b0;
    end
    else begin
        new_data_flag <= 'b1;
    end
end



// Synchronize new_data output signal
synchronizer #(1) new_data_synchronizer(
                    .clk(clk),
                    .unsynced_data(new_data_flag),
                    //.unsynced_data(set_new_data),
                    .synced_data(synced_new_data_flag));
endmodule



module synchronizer
#(parameter    DATA_WIDTH  =  16)
    ( input logic clk,
      input logic [DATA_WIDTH - 1:0] unsynced_data,
     output logic [DATA_WIDTH - 1:0] synced_data);

logic [DATA_WIDTH - 1: 0] synchronizer;

always_ff @ (posedge clk)
begin
    synchronizer[DATA_WIDTH - 1:0] <= unsynced_data[DATA_WIDTH - 1:0];
    synced_data[DATA_WIDTH - 1:0] <= synchronizer[DATA_WIDTH - 1:0];
end

endmodule




/**
 * \brief handles when data should be loaded into the spi module and parses
 *        the first byte received for both the starting address and
 *        the read/write bit. Starting address is output on the address_out
 *        signal. If a write is being signaled by the master,
 *        the dataCtrl module also asserts the write_enable signal. Finally,
 *        the setNewData signal prevents new dat from being written to the
 *        spi output while data is being sent.
 */
module spi_data_ctrl
#(parameter DATA_WIDTH = 8)
               ( input logic cs, sck,
                 input logic [DATA_WIDTH-1:0] spi_data_in,
                output logic write_enable,
                output logic set_new_data,
                output logic [DATA_WIDTH-1:0] address_out);

logic [10:0] bitCount;
logic byteOut;          // indicates one byte has been received
logic byte_out_neg_edge;


/// byteOut logic:
always_ff @ (posedge sck, posedge cs)
begin
    if (cs)
    begin
        bitCount <= 'b0;
        byteOut <= 'b1;
    end
else
    begin
        bitCount <= bitCount + 'b1;
        // AND all the lower bits together.
        byteOut <= &bitCount[$clog2(DATA_WIDTH)-1:0];
        //byteOut <= byteOutTmp;

    end
end

/// byte_out_neg_edge logic:
always_ff @ (negedge sck, posedge cs)
begin
    if (cs)
        byte_out_neg_edge <= 'b1;
    else
        byte_out_neg_edge <= byteOut;
    end

always_latch
begin
    if (byte_out_neg_edge)
    begin
        set_new_data<= byteOut;
    end
end

logic lock_base_address;
logic write_enable_in;
logic [7:0] offset;

/// offset logic:
always_ff @ (posedge byteOut, posedge cs)
begin
  if (cs)
        offset <= -8'b00000001;
    else
        begin
            offset <= offset + 8'b00000001;
        end
end


 /// lock_base_address logic:
always_ff @ (posedge byte_out_neg_edge, posedge cs)
begin
    if (cs)
        lock_base_address <= 1'b0;
    else
        lock_base_address <= 1'b1;
end

logic byte_out_ctrl;
assign byte_out_ctrl = byteOut & ~lock_base_address;

/// address_out logic, setup for write_enable logic:
always_ff @ (posedge byte_out_neg_edge, posedge byte_out_ctrl)
begin
  if (byte_out_ctrl)
  begin
      address_out <= spi_data_in[DATA_WIDTH-2:0];
      write_enable_in <= spi_data_in[DATA_WIDTH-1];
  end
  else
      address_out <= address_out + 'b1;
end

/// write_enable logic:
always_ff @ (posedge byte_out_neg_edge, posedge cs)
begin
   if (cs)
       write_enable <= 1'b0;
   else
       write_enable <= write_enable_in;
end
endmodule
