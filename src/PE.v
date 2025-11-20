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


module PE(CLK,A,B,N,SR_INs,SR_INc,SM_IN,SM2_IN,FF_IN,E_IN,E_OUT,SR_OUTs,SR_OUTc,SM_OUT,SM2_OUT,FF_OUT,A_OUT,N_OUT);
parameter K = 1024; // operand full size
parameter W = 16; // word size
parameter IDLE = 2'b00;
parameter TASK_X = 2'b01;
parameter TASK_Y = 2'b10;
parameter STALL = 2'b11;

parameter stallDelay = 1;

input CLK,E_IN;
input  [W-1 : 0] A,N,SR_INs,SR_INc;
input  [1 : 0] SM2_IN,SM_IN;
input  [2*W-5 : 0] B;// (W-3+1)*2
input  FF_IN;
//input [31:0]index;
output reg E_OUT;
output reg [W-1 : 0] SR_OUTs,SR_OUTc,A_OUT,N_OUT;
output reg [1: 0] SM2_OUT,SM_OUT;
output reg FF_OUT;

//control unit reg
reg [1:0] state;//,next_state;
reg init;
reg [clogb2(W/2-1)-1: 0] i2;
reg [clogb2(K/W): 0] j;

//internal storage
reg [1:0] q [0 : W/2-2];
reg [1:0] Ca_s [0 : W/2-2];
reg [1:0] Ca_c [0 : W/2-2];
reg [1:0] Cb_s [0 : W/2-2];
reg [1:0] Cb_c [0 : W/2-2];

//input wires
wire [W-1 : 0] w_SRs_in,w_SRc_in;
wire [1:0] w_SM_in,w_B1,w_B2,w_Ca_sin,w_Ca_cin,w_Cb_sin,w_Cb_cin,w_q;
wire w_FF_in;
//output wires
wire [1:0] w_Ca_sout,w_Ca_cout,w_Cb_sout,w_Cb_cout,w_SM_out,w_q_out;
wire [W-1 : 0] w_SRs_out,w_SRc_out;
wire w_FF_out;

//MUXs
wire [1:0] MUX_B1_in[0 : W/2-2];
wire [1:0] MUX_B2_in[0 : W/2-2];

//============================= CODE START ========================================
function integer clogb2;
input [31:0] value;
integer i;
begin
	clogb2 = 0;
	for(i = 0; 2**i < value; i = i + 1)
		clogb2 = i + 1;
end
endfunction
//---------------------------------------------------
genvar l;
generate
	for (l = 0; l <= W/2-2; l = l+1) begin : MUX_INPUTS
		assign MUX_B1_in[l] = B[2*l +: 2];
		assign MUX_B2_in[l] = B[2*(l+W/2-1) +: 2];
	end
endgenerate 

assign w_SRs_in = (init)? SR_INs : SR_OUTs;
assign w_SRc_in = (init)? SR_INc : SR_OUTc;
assign w_SM_in = (init)? SM2_IN : SM_IN;
assign w_B1 = MUX_B1_in[i2];
assign w_B2 = MUX_B2_in[i2];
assign w_FF_in = (init)? FF_IN : FF_OUT;
assign w_q = (state == TASK_X)? w_q_out : q[i2];
assign w_Ca_sin = (state == TASK_X)? 2'b00 : Ca_s[i2];
assign w_Ca_cin = (state == TASK_X)? 2'b00 : Ca_c[i2];
assign w_Cb_sin = (state == TASK_X)? 2'b00 : Cb_s[i2];
assign w_Cb_cin = (state == TASK_X)? 2'b00 : Cb_c[i2];

task_Y ty (w_SRs_in,w_SRc_in,w_SM_in,A,w_B1,w_B2,N,w_FF_in,w_q,w_Ca_sin,w_Ca_cin,w_Cb_sin,w_Cb_cin,w_Ca_sout,w_Ca_cout,w_Cb_sout,w_Cb_cout,w_SRs_out,w_SRc_out,w_SM_out,w_FF_out,w_q_out);

//w_Ca_sout,w_Ca_cout,w_Cb_sout,w_Cb_cout,  w_SRs_out,w_SRc_out,w_SM_out,w_FF_out,w_q_out);

////state register
//always @(posedge CLK)begin
//	if(!E_IN) state <= IDLE;
//	else state <= next_state;
//end

////next state function
//always @(state or E_IN or i2 or j)begin
//	case(state)
//	IDLE: begin
////		if(E_IN) next_state <= TASK_X;
////		else next_state <= IDLE;
//		next_state <= TASK_X;
//	end
//	
//	TASK_X: begin
//		if(i2 == W/2-2) next_state <= TASK_Y;
//		else next_state <= TASK_X;
//	end
//	
//	TASK_Y: begin
//		if(i2 == W/2-2)begin
//			if(j == 1) next_state <= IDLE;
//			else next_state <= TASK_Y;
//		end else next_state <= TASK_Y;
//	end
//	default : next_state <= IDLE;
//	endcase
//end

// datapath
always @(posedge CLK)begin
	if(!E_IN) begin
		E_OUT <= 0;
		SR_OUTs <= 0;
		SR_OUTc <= 0;
		A_OUT <= 0;
		N_OUT <= 0;
		SM2_OUT <= 0;
		SM_OUT <= 0;
		FF_OUT <= 0;
		i2 <= 0;
		j <= K/W;
		init <= 1'b1;
		state <= TASK_X;
	end else begin
	case(state)
		IDLE:begin
			i2 <= 0;
			j <= K/W;
			init <= 1'b1;
			state <= TASK_X;
		end
			
		TASK_X:begin						
			SR_OUTs <= 	w_SRs_out;
			SR_OUTc <=  w_SRc_out;
			//SM2_OUT <= w_SM_out;
			SM_OUT <= w_SM_out;
			FF_OUT <= w_FF_out;
			q[i2] <= w_q_out;
			Ca_s[i2] <= w_Ca_sout;
			Ca_c[i2] <= w_Ca_cout;
			Cb_s[i2] <= w_Cb_sout;
			Cb_c[i2] <= w_Cb_cout;
					
			if(i2 == W/2-2) begin
				init <= 1'b1;
				i2 <= 0;
				SM2_OUT <= w_SM_out;
				A_OUT <= A;//pass curr word to the next PE
				N_OUT <= N;//pass curr word to the next PE
				E_OUT <= 1'b1;//enable next PE
				state <= TASK_Y;
			end 
			else begin
				init <= 1'b0;
				i2 <= i2+1;
				A_OUT <= A_OUT;
				N_OUT <= N_OUT;
				state <= TASK_X;
			end	
		end//task_x
			
		TASK_Y:begin
			SR_OUTs <= 	w_SRs_out;
			SR_OUTc <=  w_SRc_out;
		//	SM2_OUT <= w_SM_out;
//			if(j == 1) SM_OUT <=0;
//			else SM_OUT <= w_SM_out;
			SM_OUT <= w_SM_out;
			FF_OUT <= w_FF_out;
			q[i2] <= q[i2];
			Ca_s[i2] <= w_Ca_sout;
			Ca_c[i2] <= w_Ca_cout;
			Cb_s[i2] <= w_Cb_sout;
			Cb_c[i2] <= w_Cb_cout;
					
			if(i2 == W/2-2) begin
				init <= 1'b1;
				i2 <= 0;
//				if(j == 1) SM2_OUT <=0;
//				else SM2_OUT <= w_SM_out;
				SM2_OUT <= w_SM_out;
				A_OUT <= A;//pass curr word to the next PE
				N_OUT <= N;//pass curr word to the next PE
				if(j == 1)begin 
					j <= K/W;
					state <= (stallDelay) ? STALL : TASK_X;//IDLE;
				end else begin
					state <= TASK_Y;
					j <= j-1;
				end
			end 
			else begin
				init <= 1'b0;
				i2 <= i2+1;
				A_OUT <= A_OUT;
				N_OUT <= N_OUT;
				state <= TASK_Y;
			end	
		end//task_y
		
		STALL: begin
//			A_OUT <= A_OUT;
//			N_OUT <= N_OUT;
//			SR_OUTs <= 	SR_OUTs;
//			SR_OUTc <=  SR_OUTc;
//			SM_OUT <= SM_OUT;
//			FF_OUT <= FF_OUT;
//			q[i2] <= q[i2];
//			Ca_s[i2] <= Ca_s[i2];
//			Ca_c[i2] <= Ca_c[i2];
//			Cb_s[i2] <= Cb_s[i2];
//			Cb_c[i2] <= Cb_c[i2];

			if(i2 == W/2-2) begin
				i2 <= 0;
				state <= TASK_X;
			end
			else begin
				i2 <= i2 +1;
				state <= STALL;
			end
		end//stall
		default : state <= IDLE;
		endcase
	end
end//always


endmodule
