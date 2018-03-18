/*  WavetableRAM.v - Module for the 4 memory banks which are used to store the unique waveforms
    for each output channel.
    
    Copyright 2018 Patrick Cland
    www.setsunasoft.com */

`timescale 1ns / 1ps
module WavetableRAM(CLK, WE, Address, Data, Indices, Waveforms);
    input CLK;
    input WE;               //Allows overwriting of wavetable         
    input[7:0] Address;     //Address of wavetable to update with sample
    input[5:0] Data;        //Wavetable sample to update value at RAM[Address]
    input[23:0] Indices;    //Indices from phase accumulator packed in single vector {Index3, Index2, Index1, Index0}
    output[23:0] Waveforms; //Waveforms packed in single vector, {Waveform3, Waveform2, Waveform1, Waveform0}
    
    reg[3:0] BankWriteEnable;   //Write enable for memory bank only if Wavetable RAM WE is enabled
    wire[5:0] Index[0:3];       //Indices split up for each wavetable since verilog doesn't support 2D arrray inputs
    
    assign Index[0] = Indices[5:0];
    assign Index[1] = Indices[11:6];
    assign Index[2] = Indices[17:12];
    assign Index[3] = Indices[23:18];
    
    //Upper 2 bits determine which bank is written to
    always @ (Address[7:6] or WE) begin
        case(Address[7:6])
            2'b00: BankWriteEnable = 4'b0001 & {4{WE}};
            2'b01: BankWriteEnable = 4'b0010 & {4{WE}};
            2'b10: BankWriteEnable = 4'b0100 & {4{WE}};
            2'b11: BankWriteEnable = 4'b1000 & {4{WE}};
        endcase
    end
    
    MemoryBank Bank0(.CLK(CLK), .WE(BankWriteEnable[0]), .Address(Address[5:0]), .Index(Index[0]), .DataIn(Data), .DataOut(Waveforms[5:0]));
    MemoryBank Bank1(.CLK(CLK), .WE(BankWriteEnable[1]), .Address(Address[5:0]), .Index(Index[1]), .DataIn(Data), .DataOut(Waveforms[11:6]));
    MemoryBank Bank2(.CLK(CLK), .WE(BankWriteEnable[2]), .Address(Address[5:0]), .Index(Index[2]), .DataIn(Data), .DataOut(Waveforms[17:12]));
    MemoryBank Bank3(.CLK(CLK), .WE(BankWriteEnable[3]), .Address(Address[5:0]), .Index(Index[3]), .DataIn(Data), .DataOut(Waveforms[23:18]));

endmodule

module MemoryBank(CLK, WE, Address, DataIn, Index, DataOut);
    input CLK;
    input WE;
    input[5:0] Address;
    input[5:0] DataIn;
    input[5:0] Index;
    output[5:0] DataOut;
    
    reg[5:0] RAM[0:63];     //RAM to store wavetable samples
    
    always @ (posedge CLK) begin
        if(WE) begin
            RAM[Address] <= DataIn;
        end 
    end
    
    assign DataOut = RAM[Index];
endmodule