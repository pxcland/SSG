/*  OutputMultiplexer.v - Controls which signals are ultimately added and output, depending on the
    status of each channel, whether it is on/off or should output a waveform or noise.
    
    Copyright 2018 Patrick Cland
    www.setsunasoft.com */

`timescale 1ns / 1ps
module OutputMultiplexer(Waveforms, Noise, Status, Channel0, Channel1, Channel2, Channel3);
    input[23:0] Waveforms;
    input[5:0] Noise;
    input[7:0] Status;
    output reg[5:0] Channel0;
    output reg[5:0] Channel1;
    output reg[5:0] Channel2;
    output reg[5:0] Channel3;
    
    always @ (*) begin
        casex(Status[1:0]) //Channel 0
            2'b0x: Channel0 = 6'b000000;     //If channel is off, doesn't matter if status is for noise or waveform
            2'b10: Channel0 = Waveforms[5:0];
            2'b11: Channel0 = Noise;
        endcase
        
        casex(Status[3:2]) //Channel 1
            2'b0x: Channel1 = 6'b000000;     
            2'b10: Channel1 = Waveforms[11:6];
            2'b11: Channel1 = Noise;
        endcase
        
        casex(Status[5:4]) //Channel 2
            2'b0x: Channel2 = 6'b000000;    
            2'b10: Channel2 = Waveforms[17:12];
            2'b11: Channel2 = Noise;
        endcase
        
        casex(Status[7:6]) //Channel 3
            2'b0x: Channel3 = 6'b000000;    
            2'b10: Channel3 = Waveforms[23:18];
            2'b11: Channel3 = Noise;
        endcase
    end
endmodule
