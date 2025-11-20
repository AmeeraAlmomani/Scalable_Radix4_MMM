`timescale 1ns / 1ps
// ============================================================================
// Copyright (c) 2025 Ameera Almomani
// 
// This software is licensed under the BSD 3-Clause License (https://opensource.org/license/bsd-3-clause)
//
// This source code is provided for academic and research purposes only.
// 
// Conditions of use:
// 1. You may use, modify, and distribute this code for *non-commercial* 
//    research and educational purposes, provided that proper credit is given.
// 2. Commercial use of this code is *not permitted* without prior written consent.
// 3. Any publication or work that uses this code (in whole or in part) must 
//    cite the following paper: https://doi.org/10.1109/OJCS.2025.3628878
// ============================================================================

module PEz(CLK,SR_s,SR_c,SM,SM2,FF,E_IN,S_OUT);

parameter K = 1024; // operand full size
parameter W = 16; // word size
parameter IDLE = 2'b00;
parameter SAVE = 2'b01;
parameter COMPUTE = 2'b10;

input CLK,E_IN;
input  [W-1 : 0] SR_s,SR_c,SM;
input [1 : 0] SM2;
input FF;
output [W-1: 0] S_OUT;

reg [W-1 : 0] S; 
reg C = 1'b0;
reg [W-5 : 0]SM_temp;
reg [1:0] current_state;
reg [clogb2(W/2-1)-1: 0] delay;
reg [clogb2(K/W)-1: 0] j;

wire [W-1: 0] w_temps,w_tempc;
wire [W: 0] w_temps2,w_tempc2;
wire s1,c1 ;
wire w_COUT;
wire [W-1: 0] w_S_temp,w_SM;

//------------------------------------------------------------
function integer clogb2;
input [31:0] value;
integer i;
begin
	clogb2 = 0;
	for(i = 0; 2**i < value; i = i + 1)
		clogb2 = i + 1;
end
endfunction
//----------------------------------------------------------------------

//assign w_SM = {SM,SM_temp,SM2};
assign w_SM = {SM[W-1:2],SM2};

assign s1 = FF ^ C;
assign c1 = FF & C;
assign w_temps = SR_s ^ SR_c ^ w_SM; 
assign w_tempc = (((SR_s ^ SR_c) & w_SM) | (SR_s & SR_c));

assign w_temps2 = {c1,s1} ^ w_temps ^ {w_tempc,1'b0};
assign w_tempc2 = ((({c1,s1} ^ w_temps) & {w_tempc,1'b0}) | ({c1,s1} & w_temps));

assign {w_COUT,w_S_temp} = w_temps2 + {w_tempc2,1'b0};
assign S_OUT = S;


always @(posedge CLK)begin
	if(!E_IN) begin
		C <= 0;
		delay <= 0;
		current_state <= COMPUTE;
	end
	else
		case(current_state)
			IDLE:begin
				C <= 0;
				delay <= 0;
				current_state <= SAVE;
			end
			
			SAVE:begin
				//SM_temp[2*delay +: 2] <= SM;
				delay <= delay+1;
				if(delay == W/2-3) current_state <= COMPUTE;
				else current_state <= SAVE;
			end
			
			COMPUTE:begin
				S <= w_S_temp;//register the sum
				C<=  w_COUT;
				delay <= 0;
				j <= j-1;
				if(j == 0) current_state <= IDLE;
				else current_state <= SAVE;
			end
			default: current_state <= IDLE;
		endcase
end//always


endmodule
