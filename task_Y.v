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

`include "CSA_6.v"
module task_Y(SRs_in,SRc_in,SM_in,A,B1,B2,N,FF_in,q,Ca_sin,Ca_cin,Cb_sin,Cb_cin,Ca_sout,Ca_cout,Cb_sout,Cb_cout,SRs_out,SRc_out,SM_out,FF_out,q_out);
parameter K = 1024; // operand full size
parameter W = 16; // word size

input [W-1 : 0] SRs_in,SRc_in,A,N;
input [1:0] SM_in,B1,B2,Ca_sin,Ca_cin,Cb_sin,Cb_cin,q;
input FF_in;

output [1:0] Ca_sout,Ca_cout,Cb_sout,Cb_cout,SM_out,q_out;
output [W-1 : 0] SRs_out,SRc_out;
output FF_out;
wire [W-1 : 0] s_w,c_w;
wire [W-1 : 0] sum_s,sum_c; 

CSA_6 csa6_1(SRc_in,{({A[0],A[0]} & B2),SRs_in[W-3:0]},{A[W-1 : 1] & {W-1{B1[0]}},SM_in[0]},{A[W-1 : 1] & {W-1{B1[1]}},SM_in[1],FF_in},Ca_sin,Ca_cin,{Ca_sout,s_w},{Ca_cout,c_w});
	assign q_out[0] = s_w[0];
	assign q_out[1] = (~N[1] & (s_w[0] ^ s_w[1] ^ c_w[1])) | (N[1] & (s_w[1] ^ c_w[1]));

CSA_6 csa6_2(s_w , c_w , {W{q[0]}} & N, {({W{q[1]}} & N),1'b0},Cb_sin,Cb_cin,{Cb_sout,sum_s}, {Cb_cout,sum_c}) ;

	assign {FF_out,SM_out} = sum_s[1:0] + sum_c[1:0]; // store the shifted value
	assign SRs_out = {2'b0,sum_s[W-1 : 2]}; // shift by 2 bits ... divide by 4
	assign SRc_out = {2'b0,sum_c[W-1 : 2]}; // shift by 2 bits ... divide by 4

endmodule
