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

module IWBR4MM(CLK,E_IN,X,Y,M,S);

parameter K =1024; // number sizes
parameter W = 16; // word size
parameter K2 =1024.0; // number sizes in real
parameter W2 = 16.0; // word size in real
parameter TOTAL = $rtoi($ceil((K2/2)/(W2/2 -1)) -1); //total # of processing elements I1
parameter PE_NO = TOTAL+1; // # of processing elements ... optimal = TOTAL+1
//parameter P = PE_NO; //optimal = PE_NO
parameter LAMDA = $rtoi($ceil((K2/2)/(PE_NO*(W2/2 -1))));
parameter zCtrLimit = (PE_NO == TOTAL+1) ? (LAMDA*PE_NO+1)*(W/2-1) : (PE_NO+(LAMDA-1)*(K/W+1+storageDelay)+1)*(W/2-1);
																							//(LAMDA*(K/W+1+storageDelay)-1)*(W/2-1);
parameter storageDelay = (K/W+1 == PE_NO) ? 1 : 0;

//states
parameter I_IDLE = 2'b00,READ = 2'b01, I_WAIT = 2'b10, I_STOP = 2'b11;
parameter O_IDLE = 2'b00,SAVE = 2'b01, O_WAIT = 2'b10, O_DELAY = 2'b11;

input CLK,E_IN;
input [W-1:0]X,M; 
input [2*W-5 : 0]Y;
output [W-1 : 0] S; // K+1 bits with the carry

//storage regs
reg [K+W-1 : 0] s_A;
reg [K+W-1 : 0] s_N;
reg [K+W-1 : 0] s_SR_s;
reg [K+W-1 : 0] s_SR_c;
reg [K+W-1 : 0] s_SM;
reg [2*(K/W+1)-1 : 0] s_SM2[0:1];
reg  [0 : K/W] s_FF; 

reg [1:0] I_state,O_state;
reg init,e;
reg [clogb2(LAMDA)-1: 0] lamdaCtr[0 : PE_NO-1]; //select
reg [clogb2(zCtrLimit): 0]zCtr;
reg zEnable;
reg [clogb2(W/2-1)-1 : 0]I_delay,O_delay,delay,m_sel;// count 0 - W/2-2
reg [clogb2((K/W +1 +storageDelay)*(W/2-1)-1)-1: 0] j[0 : PE_NO-1];
reg [W-1 : 0] A_temp,N_temp;
reg [2*(PE_NO*LAMDA+1)*(W/2-1) : 0] B;// (W-3+1)*2  .. K+W-1
reg [W-1 : 0] SR_temp;
reg [clogb2(K/W+1)-1 : 0]I_j,O_j, I_sel, I_sel2;
reg [clogb2(LAMDA)-1: 0] I_lamda,O_lamda;
reg [clogb2(K/W+1)-1: 0] sel;
reg stallReg = storageDelay;

wire [W-1 : 0] A [0 : PE_NO];
wire [W-1  : 0] N [0 : PE_NO];
wire [2*W-5 : 0] B_w[0 : PE_NO-1];
wire [W-1  : 0] SR_s [0 : PE_NO];
wire [W-1 : 0] SR_c [0 : PE_NO];
wire [1 : 0] SM [0 : PE_NO];
wire [1 : 0] SM2 [0 : PE_NO+1];
wire  [ PE_NO: 0]E; //enable signal
wire  [W-1 : 0] Stemp; 
wire  FF[ 0: PE_NO]; //FF for saving carry
//MUXes
wire [2*W-5 : 0] MUX_IN [0 : PE_NO-1][0 : LAMDA-1];
wire [W-1 : 0] mux_A[0 : K/W];
wire [W-1 : 0] mux_N[0 : K/W];
wire [W-1 : 0] mux_SRs[0 : K/W];
wire [W-1 : 0] mux_SRc[0 : K/W];
wire [W-1 : 0] mux_SM[0 : K/W];
wire [1 : 0] mux_SM20[0 : K/W];
wire [1 : 0] mux_SM21[0 : K/W];
wire mux_FF[0 : K/W];
wire [W-1 : 0] mx_A, mx_N, mx_SR_s, mx_SR_c;
wire [1:0] mx_SM;
wire [1:0] mx_SM2[0:1];
wire mx_FF;

wire [W-1 : 0] zmx_SR_s, zmx_SR_c, zmx_SM;
wire [1:0] zmx_SM2;
wire zmx_FF;
wire [W-1 : 0] zmux_SRs[0 : K/W];
wire [W-1 : 0] zmux_SRc[0 : K/W];
wire [W-1 : 0] zmux_SM[0 : K/W];
wire [1 : 0] zmux_SM2[0 : K/W];
wire zmux_FF[0 : K/W];
//integer i = 0;
integer n = 0;
integer m = 0;
//integer m2 = 0;

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

always @(posedge CLK  )	begin
	if(!E_IN) begin 
					init <= 1;
				I_delay <= 0;
				m_sel <= 0;
				delay <=0;
				sel <= 0;
				for(m = 0; m <= PE_NO-1; m = m+1)begin
					lamdaCtr[m] <= 0;
					j[m] <= 0;
				end
				zCtr <= 0;
				e <= 0;
				zEnable <= 0;
				s_SR_s <= 0;
				s_SR_c <= 0;
				s_SM <= 0;
				s_SM2[0] <= 0;
				s_SM2[1] <= 0;
				s_FF <= 0;
				s_A <= 0;
				s_N <= 0;
				I_j <= 0;
				I_sel <= 0;
				I_sel2 <= 0;
				A_temp <= 0;
				N_temp <= 0;
				I_lamda <= 0;
				B <= 0;
				stallReg <= storageDelay;
		I_state <= READ;
		O_state <= O_IDLE;
	end 
	else begin
		//I_case
			case(I_state)
			I_IDLE:begin
				init <= 1;
				I_delay <= 0;
				I_lamda <= 0;
				I_state <= READ;
			end			
			READ:begin
				A_temp <= X;
				N_temp <= M;
				B[I_j*(2*W-4) +: 2*W-4] <= (I_lamda == 0) ? Y : B[I_j*(2*W-4) +: 2*W-4] ;
				//compute sr
				e <= 1;
				I_j <= I_j + 1;
//				I_sel <= (I_sel == K/W) ? 0 : I_sel + 1'b1;
				I_delay <= I_delay + 1;
				init <= (I_lamda == 0) ? 1 : 0;
				I_state <= I_WAIT;
			end
			
			I_WAIT:begin
				I_delay <= I_delay +1;
				if(I_delay == W/2-2)begin
					I_delay <= 0;
					//I_sel <= (I_sel == K/W) ? 0 : I_sel + 1'b1;
					I_state <= READ;
					if(I_j == K/W+1+storageDelay)begin//prepare for next lamda
						I_j <= 0;
//						I_state <= READ;
						if(I_lamda == LAMDA-1) begin//finished one MM process
							//I_state <= I_STOP;//read state .. set regs to default first
							//init <= 1;
							I_lamda <= 0;
							//I_state <= READ;
						end else begin 
						//	init <= 0;
							//I_state <= READ;
							I_lamda <= I_lamda +1;
							end
					end //if(I_j 
//					else begin 
//						//I_delay <= 0;
//						I_state <= READ;
//					end
				end //if(I_delay
				else I_state <= I_WAIT;
			end
			
			I_STOP: begin
//				//if(E_IN)begin
//					if(zCtr == zCtrLimit)begin
//						zEnable <= 1;
////						if(I_j == K/W+1)I_state <= I_IDLE;
////						else begin 
////							I_j <= I_j+1;
////							I_state <= I_STOP;
////						end
//					end
//					else begin
//						zCtr <= zCtr +1;
//					end
//					I_state <= I_STOP;
//
////					I_state <= I_STOP;
////				end else I_state <= I_IDLE;
			end
			default: I_state <= I_IDLE;
		endcase

		//O_case ================================================================
			case(O_state)
			O_IDLE:begin
				O_delay <= 0;
				O_j <= 0;
				O_lamda <= 0;
				if(E[PE_NO])begin
				// O_state <= SAVE;
					s_SR_s[O_j*W +: W] <= SR_s[PE_NO];
					s_SR_c[O_j*W +: W] <= SR_c[PE_NO];
					s_A[O_j*W +: W] <= A[PE_NO];
					s_N[O_j*W +: W] <= N[PE_NO];
					s_FF[O_j] <= FF[PE_NO];
					s_SM2[0][2*O_j +: 2] <= SM2[PE_NO];
					if(O_j!= 0)begin
						s_SM2[1][2*(O_j-1) +: 2] <= SM2[PE_NO+1];
						s_SM[W*O_j-2 +: 2] <= SM[PE_NO];
					end
					
					O_delay <= O_delay +1;
					O_state <= O_WAIT;
				end
				else O_state <= O_IDLE;
			end

			SAVE:begin
				s_SR_s[O_j*W +: W] <= SR_s[PE_NO];
				s_SR_c[O_j*W +: W] <= SR_c[PE_NO];
				s_A[O_j*W +: W] <= A[PE_NO];
				s_N[O_j*W +: W] <= N[PE_NO];
				s_FF[O_j] <= FF[PE_NO];
				s_SM2[0][2*O_j +: 2] <= SM2[PE_NO];
				if(O_j!= 0)begin
					s_SM2[1][2*(O_j-1) +: 2] <= SM2[PE_NO+1];
					s_SM[W*O_j-2 +: 2] <= SM[PE_NO];
				end
				
				O_delay <= O_delay +1;
				O_state <= O_WAIT;
			end
			
			O_WAIT:begin
				s_SM[W*O_j+2*O_delay +: 2] <= SM[PE_NO];
				O_delay <= O_delay +1;

				if(O_delay == W/2-2)begin 
					O_delay <= 0;
					O_j <= O_j +1;
					if(O_j == K/W)begin
						O_j <= 0;
						O_state <= (storageDelay) ? O_DELAY : SAVE;
						if(O_lamda == LAMDA-1)begin//prepare for next MM process
							O_lamda <= 0;
						//	O_state <= SAVE;
						end
						else begin
						//	O_state <= O_DELAY; //prepare for next lamda iteration
							O_lamda <= O_lamda +1;
						end
					end
					else O_state <= SAVE;
				end
				else O_state <= O_WAIT;
			end
			O_DELAY:begin
				if(O_delay == W/2-2)begin 
					O_delay <= 0;
					O_state <= SAVE;
				end else begin
					O_delay <= O_delay +1;
					O_state <= O_DELAY;
				end
			end
			default: O_state <= O_IDLE;
		endcase

		// counter for multiplier MUX
			for(n = 0; n <= PE_NO-1; n = n+1)begin
				if(E[n])begin
					if(j[n] < (K/W +1 +storageDelay)*(W/2-1)-1 )begin
						j[n] <= j[n]+1;
					end
					else begin
						if(lamdaCtr[n] < LAMDA-1)begin
							lamdaCtr[n] <= lamdaCtr[n] +1;
							j[n] <= 0;
						end
					end
				end
			end
		//if(zEnable && I_j <K/W+1) I_j <= I_j +1;
			if(E[0])begin
				if(zCtr < zCtrLimit)begin //LAMDA*(K/W+1)*(W/2-1)+2
					zCtr <= zCtr+1;
				end
				else begin
					zEnable <= 1;
				end
			end

			if (zEnable)begin
				if(delay == W/2-2)begin
					delay <= 0;
					sel <= (sel == K/W) ? 0 : sel+1'b1;
				end else delay <= delay + 1'b1;
			end 
			
			m_sel <= I_delay;
			I_sel2 <= I_sel;
			
			if(m_sel == W/2-2)begin
				if(I_sel == K/W)begin
					if(stallReg)begin
						I_sel <= I_sel;
						stallReg <= 0;
					end else begin
						I_sel <= 0;
						stallReg <= storageDelay;
					end
				end
				else I_sel <= I_sel + 1'b1;
			end
	end
end
assign SR_s[0] = (init) ? {W-2{A_temp[0]}} & B[W-3 : 0] : mx_SR_s; //SR_temp;
assign SR_c[0] = (init) ? 0 : mx_SR_c; //0;
assign SM[0] = (init) ? 0 : mx_SM; //0;
assign SM2[0] = (init) ? 0 : mx_SM2[0]; //0;
assign SM2[1] = (init) ? 0 : mx_SM2[1]; //0; lamdaCtr[1]==0
assign FF[0] = (init) ? 0 : mx_FF; //0;	
assign A[0] = (init) ? A_temp : mx_A;
assign N[0] = (init) ? N_temp : mx_N;
assign E[0] = e;	

//muxs of multiplier B
genvar p,l;
generate
	for (p = 0; p <= PE_NO-1; p = p+1) begin : MUX
		assign B_w[p] = MUX_IN[p][lamdaCtr[p]];
		for (l = 0; l <= LAMDA-1; l = l+1) begin : MUX_INPUTS
			assign MUX_IN[p][l] = B[(l*PE_NO+p+2)*(W-2)-1 -: 2*(W-2)];
		end
	end
endgenerate 

genvar ii;
generate
		for (ii = 0; ii <= K/W; ii = ii+1) begin : MUX_INPUTS
			assign mux_A [ii] = s_A[ii*W +: W];
			assign mux_N [ii] = s_N[ii*W +: W];
			assign mux_SRs[ii] = s_SR_s[ii*W +: W];
			assign mux_SRc[ii] = s_SR_c[ii*W +: W];
			assign mux_SM[ii] = s_SM[ii*W +: W];//,SM2[2*ii +: 2]};
			assign mux_FF[ii] = s_FF[ii];
			assign mux_SM20[ii] = s_SM2[0][2*ii +: 2];
			assign mux_SM21[ii] = s_SM2[1][2*ii +: 2];
			
			assign zmux_SRs[ii] = s_SR_s[ii*W +: W];
			assign zmux_SRc[ii] = s_SR_c[ii*W +: W];
			assign zmux_SM[ii] = s_SM[ii*W +: W];//,SM2[2*ii +: 2]};
			assign zmux_FF[ii] = s_FF[ii];
			assign zmux_SM2[ii] = s_SM2[0][2*ii +: 2];

		end
endgenerate

assign mx_SR_s = mux_SRs[I_sel];
assign mx_SR_c = mux_SRc[I_sel];
assign mx_SM = mux_SM[I_sel][2*m_sel +: 2];
assign mx_FF = mux_FF[I_sel];
assign mx_SM2[0] = mux_SM20[I_sel];
assign mx_SM2[1] = mux_SM21[I_sel2];
assign mx_A = mux_A[I_sel];
assign mx_N = mux_N[I_sel];

//PEZ MUXes
assign zmx_SR_s = zmux_SRs[sel];
assign zmx_SR_c = zmux_SRc[sel];
assign zmx_SM = zmux_SM[sel];
assign zmx_FF = zmux_FF[sel];
assign zmx_SM2 = zmux_SM2[sel];


genvar index; // = #of PE (i.e i1)
generate
for (index = 0; index <= PE_NO-1; index = index+1) begin : PE
	PE pe (CLK,A[index],B_w[index],N[index],SR_s[index],SR_c[index],SM[index],SM2[index],FF[index],E[index],E[index+1],SR_s[index+1],SR_c[index+1],SM[index+1],SM2[index+2],FF[index+1],A[index+1],N[index+1]);
//module PE(CLK,A,B,N,SR_INs,SR_INc,SM_IN,SM2_IN,FF_IN,E_IN,E_OUT,SR_OUTs,SR_OUTc,SM_OUT,SM2_OUT,FF_OUT,A_OUT,N_OUT);
//B[(index+2)*(W-2)-1 -: 2*(W-2)]
end //for
endgenerate 

//module PEz(CLK,SR,SM,E_IN,S_OUT);
	PEz pez (CLK,zmx_SR_s,zmx_SR_c,zmx_SM,zmx_SM2,zmx_FF,zEnable,Stemp);//E[PE_NO]
	assign S = Stemp;


endmodule

