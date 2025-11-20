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

module CSA_6(a,b,d,e,ca,cb,s,c);
parameter K = 1024; // operand full size
parameter W = 16; // word size

input [W-1 : 0] a,b,d;//W bits
input [W : 0] e;//W+1
input [1 : 0] ca,cb;//W+1
output [W+1 : 0] s,c; //W+2
wire [W : 0] s_w[0 : 2];
wire [W : 0] c_w[0 : 1];
wire [W+1 : 0] cw;

  assign s_w[0] = a ^ b ^ d;
  assign c_w[0] = {(((a ^ b) & d) | (a & b)),1'b0};

  assign s_w[1] = e ^ ca ^ cb;
  assign c_w[1] = {(((e ^ ca) & cb) | (e & ca)),1'b0}; 

  assign s_w[2] = s_w[0] ^ c_w[0] ^ s_w[1];
  assign cw = {(((s_w[0] ^ c_w[0]) & s_w[1]) | (s_w[0] & c_w[0])),1'b0};
 
  assign s = s_w[2] ^ cw ^ c_w[1];
  assign c = {(((s_w[2] ^ cw) & c_w[1]) | (s_w[2] & cw)),1'b0};


endmodule
