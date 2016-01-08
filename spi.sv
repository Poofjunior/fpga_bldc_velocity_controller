/**
 * synthesizable spi peripheral
 * Joshua Vasquez
 * September 26 - October 8, 2014
 */

/**
 * \brief an spi slave module that both receives input values and clocks out
 *        output values according to SPI Mode0.
 * \details note that the dataToSend input is sampled whenever the setNewData
 *          signal is asserted.
 */
module spiSendReceive( input logic cs, sck, mosi, setNewData,
            input logic [7:0] dataToSend,
            output logic miso,
            output logic [7:0] dataReceived);

    logic [7:0] shiftReg;
    logic validClk;

    assign validClk = cs ? 1'b0   :
                           sck;

    always_ff @ (negedge validClk, posedge setNewData)
    begin
        if (setNewData)
        begin
            shiftReg[7] <= dataToSend[0];
            shiftReg[6] <= dataToSend[1];
            shiftReg[5] <= dataToSend[2];
            shiftReg[4] <= dataToSend[3];
            shiftReg[3] <= dataToSend[4];
            shiftReg[2] <= dataToSend[5];
            shiftReg[1] <= dataToSend[6];
            shiftReg[0] <= dataToSend[7];
        end
        else
        begin
        // Handle Output.
            shiftReg[7:0] <= (shiftReg[7:0] >> 1);
        end
    end
    
    always_ff @ (posedge validClk)
    begin
        // Handle Input.
            dataReceived[0] <= mosi;
            dataReceived[1] <= dataReceived[0];
            dataReceived[2] <= dataReceived[1];
            dataReceived[3] <= dataReceived[2];
            dataReceived[4] <= dataReceived[3];
            dataReceived[5] <= dataReceived[4];
            dataReceived[6] <= dataReceived[5];
            dataReceived[7] <= dataReceived[6];
      end

    assign miso = shiftReg[0];

endmodule



/**
 * \brief handles when data should be loaded into the spi module and parses
 *        the first byte received for both the starting address and 
 *        the read/write bit. Starting address is output on the addressOut 
 *        signal. If a write is being signaled by the master, 
 *        the dataCtrl module also asserts the writeEnable signal. Finally,
 *        the setNewData signal prevents new dat from being written to the
 *        spi output while data is being sent. 
 */
module dataCtrl(input logic cs, sck, 
                input logic [7:0]spiDataIn,
                output logic writeEnable,
                output logic setNewData,
                output logic [7:0] addressOut);

    logic [10:0] bitCount;
    logic byteOut;
    logic byteOutNegEdge;
    logic andOut;	// somewhat unecessary intermediate wire name.
    assign andOut = bitCount[2] & bitCount[1] & bitCount[0];

/// byteOut logic:   
      always_ff @ (posedge sck, posedge cs)
    begin
        if (cs)
        begin
            bitCount <= 5'b0000;
            byteOut <= 1'b1;
        end
    else
        begin
            bitCount <= bitCount + 5'b0001;
            byteOut <= andOut;
        end
    end

/// byteOutNegEdge logic: 
    always_ff @ (negedge sck, posedge cs)
    begin
        if (cs)
            byteOutNegEdge <= 1'b1;
        else
            byteOutNegEdge <= byteOut;
        end

    always_latch
    begin
        if (byteOutNegEdge)
        begin
            setNewData<= byteOut;
        end
    end


    logic lockBaseAddress;
    logic writeEnableIn;
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
  

 /// lockBaseAddress logic: 
    always_ff @ (posedge byteOutNegEdge, posedge cs)
    begin
        if (cs)
            lockBaseAddress <= 1'b0;
        else
            lockBaseAddress <= 1'b1;
    end

  logic byteOutCtrl;
  assign byteOutCtrl = byteOut & ~lockBaseAddress;
 
/// addressOut logic, setup for writeEnable logic: 
  always_ff @ (posedge byteOutNegEdge, posedge byteOutCtrl)
  begin
    if (byteOutCtrl)
    begin
        addressOut<= spiDataIn[6:0];
        writeEnableIn<= spiDataIn[7];
    end
    else
        addressOut <= addressOut + 8'b0000001;
  end
  
 /// writeEnable logic:
 always_ff @ (posedge byteOutNegEdge, posedge cs)
 begin
    if (cs)
        writeEnable <= 1'b0;
    else
        writeEnable <= writeEnableIn;
 end
  
endmodule
