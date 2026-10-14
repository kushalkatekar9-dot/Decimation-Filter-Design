`timescale 1ns / 1fs

module cic_fir_top #(
    parameter integer N = 3,
    parameter integer R = 2048,
    parameter integer M = 1,
    parameter integer IN_W  = 2,
    parameter integer OUT_W = 20,
    parameter integer ACC_W = N * $clog2(R * M) + IN_W
)(
    input  wire clk,
    input  wire reset,
    input  wire enable,
    input  wire signed [IN_W-1:0]  din,
    output wire signed [OUT_W-1:0] dout,
    output wire outready
);
    wire signed [ACC_W-1:0] cdata;
    wire cvalid;

    cic_core #(.N(N), .R(R), .M(M), .IN_W(IN_W), .ACC_W(ACC_W)) u_cic (
        .clk(clk), .reset(reset), .enable(enable), .din(din),
        .dout(cdata), .dvalid(cvalid)
    );

    fir_comp #(.IN_W(ACC_W), .OUT_W(OUT_W)) u_fir (
        .clk(clk), .reset(reset),
        .valid_in(cvalid), .din(cdata),
        .dout(dout), .outready(outready)
    );
endmodule
