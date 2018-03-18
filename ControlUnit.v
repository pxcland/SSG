/*  ControlUnit.v - Control unit which controls the receiving of commands from the databus,
    Used to update wavetable memory and register unit.
    
    Copyright 2018 Patrick Cland
    www.setsunasoft.com */

`timescale 1ns / 1ps
module ControlUnit(CLK, RST, CE, BusControl, Data, BUSY, BR, WavetableSample, WavetableAddress, WavetableWE, ToneValue, ToneWE, Status, StatusWE);
    input CLK, RST;
    input CE;
    input[1:0] BusControl;
    input[7:0] Data;
    output reg BUSY;
    output reg BR;
    output reg[5:0] WavetableSample;
    output reg[7:0] WavetableAddress;
    output reg WavetableWE;
    output reg[11:0] ToneValue;
    output reg[3:0] ToneWE;
    output reg[7:0] Status;
    output reg[7:0] StatusWE;
    
    //Internally convert Bus Control signals of 11 to 00.
    wire[1:0] BC;
    assign BC = (BusControl == 2'b11 ? 2'b00 : BusControl);
    
    //Registers to store data from bus line
    reg[5:0] WavetableSample_reg;
    reg[7:0] WavetableAddress_reg;
    
    reg[3:0] ToneUpper_reg;
    reg[7:0] ToneLower_reg;
    reg[1:0] ToneRegSelect_reg;
    
    reg[3:0] StatusRegSelect_reg;
    reg[1:0] StatusCode_reg;
    
    //State machine definitions
    reg[3:0] State;
    parameter IDLE_INITIAL          = 4'b0000;
    parameter BYTE_1_PROCESS        = 4'b0001;
    parameter ADDR_BYTE_2_WAIT_IDLE = 4'b0010;
    parameter ADDR_BYTE_2_PROCESS   = 4'b0011;
    parameter ADDR_WRITE_BACK       = 4'b0100;
    parameter ADDR_COMPLETE_IDLE    = 4'b0101;
    
    parameter TONE_BYTE_2_WAIT_IDLE = 4'b0110;
    parameter TONE_BYTE_2_PROCESS   = 4'b0111;
    parameter TONE_WRITE_BACK       = 4'b1000;
    parameter TONE_COMPLETE_IDLE    = 4'b1001;
    
    parameter STATUS_WRITE_BACK     = 4'b1010;
    parameter STATUS_COMPLETE_IDLE  = 4'b1011;
    
    parameter INVALID_STATE         = 4'b1100;
    
    parameter CHIP_DISABLED         = 4'b1111;
    
    //Status codes
    parameter CHANNEL_OFF   = 4'b00;
    parameter CHANNEL_ON    = 4'b01;
    parameter SET_TO_WAVE   = 4'b10;
    parameter SET_TO_NOISE  = 4'b11;
    
    //Bus Control codes
    parameter IDLE  = 2'b00;
    parameter BYTE1 = 2'b01;
    parameter BYTE2 = 2'b10;
    
    //Request instruction codes
    parameter REQ_ADDR      = 2'b1x;
    parameter REQ_TONE      = 2'b01;
    parameter REQ_STATUS    = 2'b00;
    
    //function to generate write enable signals for status register
    function [7:0] MakeStatusWE;
        input[1:0] StatusCode;
        input[3:0] StatusRegSelect;
        
        
        //Reg select is in the format of R3 R2 R1 R0
        case(StatusCode)
            CHANNEL_OFF:    MakeStatusWE = {StatusRegSelect[3], 1'b0, StatusRegSelect[2], 1'b0, StatusRegSelect[1], 1'b0, StatusRegSelect[0], 1'b0};
            CHANNEL_ON:     MakeStatusWE = {StatusRegSelect[3], 1'b0, StatusRegSelect[2], 1'b0, StatusRegSelect[1], 1'b0, StatusRegSelect[0], 1'b0};
            SET_TO_WAVE:    MakeStatusWE = {1'b0, StatusRegSelect[3], 1'b0, StatusRegSelect[2], 1'b0, StatusRegSelect[1], 1'b0, StatusRegSelect[0]};
            SET_TO_NOISE:   MakeStatusWE = {1'b0, StatusRegSelect[3], 1'b0, StatusRegSelect[2], 1'b0, StatusRegSelect[1], 1'b0, StatusRegSelect[0]};
        endcase
    endfunction
    
    //function to create status output for updating status register
    //The output is in effect ANDed with the StatusWE bitmask to determine how each register is affected.
    //Therefore, the bits for noise for off/on, and the bits for off/on for noise requests don't really matter what they are.
    function [7:0] MakeStatusOutput;
        input[1:0] StatusCode;
        
        //Status output follows format: OnOff3 Noise3 OnOff2 Noise2 OnOff1 Noise1 OnOff0 Noise0
        //Write enable follows the same format.
        case(StatusCode)
            CHANNEL_OFF:    MakeStatusOutput = 8'b00000000;
            CHANNEL_ON:     MakeStatusOutput = 8'b11111111;
            SET_TO_WAVE:    MakeStatusOutput = 8'b00000000;
            SET_TO_NOISE:   MakeStatusOutput = 8'b11111111;
        endcase
    endfunction
    
    //function to create 4-bit output representing WE of register from packed 2-bit format
    function [3:0] MakeToneWE;
        input[1:0] ToneRegSelect;
        case(ToneRegSelect)
            2'b00: MakeToneWE = 4'b0001;
            2'b01: MakeToneWE = 4'b0010;
            2'b10: MakeToneWE = 4'b0100;
            2'b11: MakeToneWE = 4'b1000;
        endcase
    endfunction
    
    //Logic to advance state machine
    always @ (posedge CLK or negedge RST) begin
        if(!RST) begin
            State <= CHIP_DISABLED; //When we are reset, disable any requests
            WavetableSample_reg     <= 6'd0;
            WavetableAddress_reg    <= 8'd0;
            ToneUpper_reg           <= 4'd0;
            ToneLower_reg           <= 8'd0;
            ToneRegSelect_reg       <= 2'd0;
            StatusRegSelect_reg     <= 4'd0;
            StatusCode_reg          <= 2'd0;
        end else begin
            //Only allow advancement of state machine while chip is enabled!
            if(CE) begin
                case(State)
                    //If the chip was previously disabled, move to the initial idle state to allow processing of requests
                    CHIP_DISABLED: State <= IDLE_INITIAL;
                    //When in the invalid state, BC=00 allows to begin receiving requests again
                    INVALID_STATE: State <= (BC == IDLE ? IDLE_INITIAL : INVALID_STATE);
                    //When in the initial idle state, after receiving BYTE1 (BC=01) allows advancement to processing the request
                    IDLE_INITIAL: begin
                        if(BC == IDLE) State <= IDLE_INITIAL;
                        else if(BC == BYTE1) begin //Sample data once BC has been asserted BYTE1 as it should be ready. For all cases.
                            State <= BYTE_1_PROCESS;
                            WavetableSample_reg <= Data[5:0];
                            ToneRegSelect_reg <= Data[5:4];
                            ToneUpper_reg <= Data[3:0];
                            StatusRegSelect_reg <= Data[5:2];
                            StatusCode_reg <= Data[1:0];
                        end
                        else State <= INVALID_STATE;
                    end
                    //Based off the type of request, go to each respective state
                    BYTE_1_PROCESS: begin
                        casex(Data[7:6])
                            REQ_ADDR:   State <= ADDR_BYTE_2_WAIT_IDLE;
                            REQ_TONE:   State <= TONE_BYTE_2_WAIT_IDLE;
                            REQ_STATUS: State <= STATUS_WRITE_BACK;
                        endcase
                    end
                    //========================================================================================================================
                    //==============================================   ADDRESS STATES   ======================================================
                    //========================================================================================================================
                    //Be idle until BC=10, where the address data is sampled
                    ADDR_BYTE_2_WAIT_IDLE: begin
                        if(BC == BYTE1) State <= ADDR_BYTE_2_WAIT_IDLE;
                        else if(BC == BYTE2) begin //Sample data once BC has been asserted BYTE2 as is it should be ready
                            State <= ADDR_BYTE_2_PROCESS;
                            WavetableAddress_reg <= Data[7:0];
                        end
                        else State <= INVALID_STATE;
                    end
                    //Process the second byte and immediately go to writeback stage
                    ADDR_BYTE_2_PROCESS: State <= ADDR_WRITE_BACK;
                    //After write back stage immediately go to complete idle state
                    ADDR_WRITE_BACK: State <= ADDR_COMPLETE_IDLE;
                    //Only go back to initial idle state on BC=00. If BC=01, go to invalid state, if BC=10, stay in idle state
                    ADDR_COMPLETE_IDLE: begin
                        if(BC == IDLE) State <= IDLE_INITIAL;
                        else if(BC == BYTE1) State <= INVALID_STATE;
                        else State <= ADDR_COMPLETE_IDLE;
                    end
                    //========================================================================================================================
                    //==============================================   TONE    STATES   ======================================================
                    //========================================================================================================================
                    //Be idle until BC=10, where the tone data is sampled
                    TONE_BYTE_2_WAIT_IDLE: begin
                        if(BC == BYTE1) State <= TONE_BYTE_2_WAIT_IDLE;
                        else if(BC == BYTE2) begin //sample data once BC has been asserted as it should be ready
                            State <= TONE_BYTE_2_PROCESS;
                            ToneLower_reg <= Data[7:0];
                        end
                        else State <= INVALID_STATE;
                    end
                    //Process the second byte and immediately go to writeback stage
                    TONE_BYTE_2_PROCESS: State <= TONE_WRITE_BACK;
                    //After write back stage immediately go to complete idle state
                    TONE_WRITE_BACK: State <= TONE_COMPLETE_IDLE;
                    //Only go back to initial idle state on BC=00. If BC=01, go to invalid state, if BC=10, stay in idle state
                    TONE_COMPLETE_IDLE: begin
                        if(BC == IDLE) State <= IDLE_INITIAL;
                        else if(BC == BYTE1) State <= INVALID_STATE;
                        else State <= TONE_COMPLETE_IDLE;
                    end
                    //========================================================================================================================
                    //==============================================   STATUS  STATES   ======================================================
                    //========================================================================================================================
                    //After write backs tage immediately go to complete idle state
                    STATUS_WRITE_BACK: State <= STATUS_COMPLETE_IDLE;
                    //Only go back to initial idle state on BC=00. 01 stay in same state, 10 go to invalid state
                    STATUS_COMPLETE_IDLE: begin
                        if(BC == IDLE) State <= IDLE_INITIAL;
                        else if(BC == BYTE2) State <= INVALID_STATE;
                        else State <= STATUS_COMPLETE_IDLE;
                    end
                    //Default case, just go to invalid state
                    default: State <= INVALID_STATE;
                endcase
            //If CE is disabled, force it to this specific state and don't allow it to change
            end else begin
                State <= CHIP_DISABLED;
            end
        end
    end
    
    
    //State machine state outputs
    always @ (*) begin
        case(State)
            //Address
            IDLE_INITIAL:           begin BUSY = 1'b0; BR = 1'b0; WavetableWE = 1'b0; ToneWE = 4'b0000; StatusWE = 8'b00000000; end
            BYTE_1_PROCESS:         begin BUSY = 1'b1; BR = 1'b0; WavetableWE = 1'b0; ToneWE = 4'b0000; StatusWE = 8'b00000000; end
            ADDR_BYTE_2_WAIT_IDLE:  begin BUSY = 1'b0; BR = 1'b0; WavetableWE = 1'b0; ToneWE = 4'b0000; StatusWE = 8'b00000000; end
            ADDR_BYTE_2_PROCESS:    begin BUSY = 1'b1; BR = 1'b0; WavetableWE = 1'b0; ToneWE = 4'b0000; StatusWE = 8'b00000000; end  
            ADDR_WRITE_BACK:        begin BUSY = 1'b1; BR = 1'b0; WavetableWE = 1'b1; ToneWE = 4'b0000; StatusWE = 8'b00000000; end
            ADDR_COMPLETE_IDLE:     begin BUSY = 1'b0; BR = 1'b0; WavetableWE = 1'b0; ToneWE = 4'b0000; StatusWE = 8'b00000000; end
            //Tone
            TONE_BYTE_2_WAIT_IDLE:  begin BUSY = 1'b0; BR = 1'b0; WavetableWE = 1'b0; ToneWE = 4'b0000; StatusWE = 8'b00000000; end
            TONE_BYTE_2_PROCESS:    begin BUSY = 1'b1; BR = 1'b0; WavetableWE = 1'b0; ToneWE = 4'b0000; StatusWE = 8'b00000000; end
            TONE_WRITE_BACK:        begin BUSY = 1'b1; BR = 1'b0; WavetableWE = 1'b0; ToneWE = MakeToneWE(ToneRegSelect_reg); StatusWE = 8'b00000000; end
            TONE_COMPLETE_IDLE:     begin BUSY = 1'b0; BR = 1'b0; WavetableWE = 1'b0; ToneWE = 4'b0000; StatusWE = 8'b00000000; end
            //Status    
            STATUS_WRITE_BACK:      begin BUSY = 1'b1; BR = 1'b0; WavetableWE = 1'b0; ToneWE = 4'b0000; StatusWE = MakeStatusWE(StatusCode_reg, StatusRegSelect_reg); end
            STATUS_COMPLETE_IDLE:   begin BUSY = 1'b0; BR = 1'b0; WavetableWE = 1'b0; ToneWE = 4'b0000; StatusWE = 8'b00000000; end
                
            INVALID_STATE:          begin BUSY = 1'b0; BR = 1'b1; WavetableWE = 1'b0; ToneWE = 4'b0000; StatusWE = 8'b00000000; end
            CHIP_DISABLED:          begin BUSY = 1'b0; BR = 1'b0; WavetableWE = 1'b0; ToneWE = 4'b0000; StatusWE = 8'b00000000; end
            //Shouldn't ever really be accessed, but required nonetheless.
            default:                begin BUSY = 1'b0; BR = 1'b1; WavetableWE = 1'b0; ToneWE = 4'b0000; StatusWE = 8'b00000000; end
        endcase
        //Assign outputs
        WavetableSample = WavetableSample_reg;
        WavetableAddress = WavetableAddress_reg;
        ToneValue = {ToneUpper_reg, ToneLower_reg};
        Status = MakeStatusOutput(StatusCode_reg);
    end
    
endmodule
