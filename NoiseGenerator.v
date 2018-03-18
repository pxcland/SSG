/*  NoiseGenerator.v - Pseudorandom noise generator using an LFSR.
    
    Copyright 2018 Patrick Cland
    www.setsunasoft.com */

`timescale 1ns / 1ps
module NoiseGenerator(CLK, RST, Output);
    input CLK, RST;
    output reg[5:0] Output;
    
    reg[15:0] ShiftRegister;
    wire Feedback = ShiftRegister[0] ^ ShiftRegister[3];
    
    always @ (posedge CLK or negedge RST) begin
        if(!RST) begin
            Output <= 6'd0;
            ShiftRegister <= 16'hF00F; //Any seed other than all zeroes is fine.
        end else begin
            ShiftRegister <= {Feedback, ShiftRegister[15:1]};
            Output <= (ShiftRegister[0] ? 6'd63 : 6'd0);
        end
    end
endmodule
