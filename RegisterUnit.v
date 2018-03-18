/*  RegisterUnit.v - Contains all the registers and phase accumulator which are used to generate
    the indices for the wavetable samples for output.
    
    Copyright 2018 Patrick Cland
    www.setsunasoft.com */

`timescale 1ns / 1ps
module RegisterUnit(CLK, RST, ToneValue, ToneWE, Status, StatusWE, ChannelStatus, WavetableIndices);
    input CLK, RST;
    input[11:0] ToneValue;
    input[3:0] ToneWE;
    input[7:0] Status;
    input[7:0] StatusWE;
    output[7:0] ChannelStatus;
    output[23:0] WavetableIndices;
    
    wire[11:0] DataOut[0:3];    //Output of tone register fed to phase accumulator
    ToneRegister TR0(CLK, RST, ToneWE[0], ToneValue, DataOut[0]);
    ToneRegister TR1(CLK, RST, ToneWE[1], ToneValue, DataOut[1]);
    ToneRegister TR2(CLK, RST, ToneWE[2], ToneValue, DataOut[2]);
    ToneRegister TR3(CLK, RST, ToneWE[3], ToneValue, DataOut[3]);

    wire Overflow[0:3]; //Output of phase accumulator, used to increment index register when phase accumulator overflows
    PhaseAccumulator PA0(CLK, RST, DataOut[0], Overflow[0]);
    PhaseAccumulator PA1(CLK, RST, DataOut[1], Overflow[1]);
    PhaseAccumulator PA2(CLK, RST, DataOut[2], Overflow[2]);
    PhaseAccumulator PA3(CLK, RST, DataOut[3], Overflow[3]);
    
    wire[5:0] Index[0:3]; //Output of index register used to directly index into wavetable memory
    IndexRegister IR0(CLK, RST, Overflow[0], Index[0]);
    IndexRegister IR1(CLK, RST, Overflow[1], Index[1]);
    IndexRegister IR2(CLK, RST, Overflow[2], Index[2]);
    IndexRegister IR3(CLK, RST, Overflow[3], Index[3]);
    
    assign WavetableIndices = {Index[3], Index[2], Index[1], Index[0]};
    
    StatusRegister SR0(CLK, RST, StatusWE[1:0], Status[1:0], ChannelStatus[1:0]);
    StatusRegister SR1(CLK, RST, StatusWE[3:2], Status[3:2], ChannelStatus[3:2]);
    StatusRegister SR2(CLK, RST, StatusWE[5:4], Status[5:4], ChannelStatus[5:4]);
    StatusRegister SR3(CLK, RST, StatusWE[7:6], Status[7:6], ChannelStatus[7:6]);
    
endmodule

module ToneRegister(CLK, RST, WE, DataIn, DataOut);
    input CLK, RST;
    input WE;
    input[11:0] DataIn;
    output reg[11:0] DataOut;
    
    always @ (posedge CLK or negedge RST) begin
        if(!RST) begin
            DataOut <= 12'd0;
        end else begin
            if(WE) DataOut <= DataIn;
            else DataOut <= DataOut;
        end
    end
endmodule

module StatusRegister(CLK, RST, WE, DataIn, DataOut);
    input CLK, RST;
    input[1:0] WE;
    input[1:0] DataIn;
    output reg[1:0] DataOut;

    always @ (posedge CLK or negedge RST) begin
        if(!RST) begin
            DataOut <= 2'd0;
        end else begin
            case(WE)
                2'b00: DataOut <= DataOut;
                2'b01: DataOut <= {DataOut[1], DataIn[0]};
                2'b10: DataOut <= {DataIn[1], DataOut[0]};
                2'b11: DataOut <= DataIn;
            endcase
        end
    end
endmodule

module IndexRegister(CLK, RST, Increment, Index);
    input CLK, RST;
    input Increment;
    output reg[5:0] Index;
    
    always @ (posedge CLK or negedge RST) begin
        if(!RST) begin
            Index <= 6'd0;
        end else begin
            if(Increment) Index <= Index + 6'd1;
            else Index <= Index;
        end
    end
endmodule

module PhaseAccumulator(CLK, RST, TuningWord, Overflow);
    input CLK, RST;
    input[11:0] TuningWord;
    output Overflow;
    
    reg CurrentMSB, PreviousMSB;
    reg[15:0] Phase;
    
    //Overflow happens when the MSB goes from a 1 to a 0
    //The greatest possible tuning word is 4095, so for a 16-bit accumulator
    //It can never overflow without the MSB becoming a 1.
    assign Overflow = (~CurrentMSB & PreviousMSB);
    
    always @ (posedge CLK or negedge RST) begin
        if(!RST) begin
            Phase <= 16'd0;
            CurrentMSB <= 1'b0;
            PreviousMSB <= 1'b0;
        end else begin
            Phase <= Phase + {4'b0000 + TuningWord};
            CurrentMSB <= Phase[15];
            PreviousMSB <= CurrentMSB;
        end
    end
endmodule