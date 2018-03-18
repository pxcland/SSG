/*  SSG.v - Top level module, connects all internal components and adds the 4 output waves
    to generate final 8-bit output waveform.
    
    Copyright 2018 Patrick Cland
    www.setsunasoft.com */

`timescale 1ns / 1ps
module SSG(CLK, RST, CE, BusControl, Data, BUSY, BR, WaveOut);
    input CLK, RST;
    input CE;
    input[1:0] BusControl;
    input[7:0] Data;
    output BUSY, BR;
    output[7:0] WaveOut;
    
    wire[5:0] WavetableSample;
    wire[7:0] WavetableAddress;
    wire WavetableWE;
    wire[11:0] ToneValue;
    wire[3:0] ToneWE;
    wire[7:0] Status;
    wire[7:0] StatusWE;
    
    wire[23:0] WavetableIndices;
    wire[23:0] Waveforms;
    
    wire[7:0] ChannelStatus;
    
    wire[5:0] Noise;
    
    wire[5:0] Channel0;
    wire[5:0] Channel1;
    wire[5:0] Channel2;
    wire[5:0] Channel3;
    
    
    ControlUnit C0( .CLK(CLK), .RST(RST), .CE(CE), .BusControl(BusControl), .Data(Data), .BUSY(BUSY), .BR(BR),
                    .WavetableSample(WavetableSample), .WavetableAddress(WavetableAddress), .WavetableWE(WavetableWE),
                    .ToneValue(ToneValue), .ToneWE(ToneWE), .Status(Status), .StatusWE(StatusWE));
                    
    RegisterUnit R0(    .CLK(CLK), .RST(RST), .ToneValue(ToneValue), .ToneWE(ToneWE), .Status(Status), .StatusWE(StatusWE),
                        .ChannelStatus(ChannelStatus), .WavetableIndices(WavetableIndices));
    
    WavetableRAM W0(    .CLK(CLK), .WE(WavetableWE), .Address(WavetableAddress), .Data(WavetableSample), .Indices(WavetableIndices),
                        .Waveforms(Waveforms));
                        
    NoiseGenerator N0(  .CLK(CLK), .RST(RST), .Output(Noise));
    
    OutputMultiplexer O0(   .Waveforms(Waveforms), .Noise(Noise), .Status(ChannelStatus),
                            .Channel0(Channel0), .Channel1(Channel1), .Channel2(Channel2), .Channel3(Channel3));
                            
    assign WaveOut = Channel0 + Channel1 + Channel2 + Channel3;
    
endmodule
