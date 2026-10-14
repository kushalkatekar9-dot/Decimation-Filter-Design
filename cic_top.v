`timescale 1ns / 1fs

module cic_core #(
    parameter integer N = 3,
    parameter integer R = 2048,
    parameter integer M = 1,
    parameter integer IN_W  = 2,
    parameter integer ACC_W = N * $clog2(R * M) + IN_W
)(
    input  wire clk,
    input  wire reset,     
    input  wire enable,
    input  wire signed [IN_W-1:0]   din,
    output wire signed [ACC_W-1:0]  dout,      
    output wire dvalid     
);
    //integrators 
    reg signed [ACC_W-1:0] integ [0:N-1];
    reg [$clog2(R)-1:0] cnt;
    reg dec_valid;
    reg signed [ACC_W-1:0] dec_data;
    integer k;

    always @(posedge clk) begin
        if (reset) begin
            cnt       <= {$clog2(R){1'b0}};
            dec_valid <= 1'b0;
            dec_data  <= {ACC_W{1'b0}};
            for (k = 0; k < N; k = k + 1)
                integ[k] <= {ACC_W{1'b0}};
        end else begin
            dec_valid <= 1'b0;
            if (enable) begin
                integ[0] <= integ[0] + $signed({{(ACC_W-IN_W){din[IN_W-1]}}, din});
                for (k = 1; k < N; k = k + 1)
                    integ[k] <= integ[k] + integ[k-1];

                if (cnt == R-1) begin        
                    cnt       <= {$clog2(R){1'b0}};
                    dec_valid <= 1'b1;
                    dec_data  <= integ[N-1];
                end else begin
                    cnt <= cnt + 1'b1;
                end
            end
        end
    end

    // comb section
    wire cv [0:N];
    wire signed [ACC_W-1:0] cd [0:N];
    assign cv[0] = dec_valid;
    assign cd[0] = dec_data;

    genvar g;
    generate
        for (g = 0; g < N; g = g + 1) begin : GEN_COMB
            cic_comb #(.W(ACC_W), .M(M)) u_comb (
                .clk(clk), .reset(reset),
                .valid_in(cv[g]),   .din(cd[g]),
                .valid_out(cv[g+1]), .dout(cd[g+1])
            );
        end
    endgenerate

    assign dout   = cd[N];
    assign dvalid = cv[N];
endmodule


module cic_top #(
    parameter integer N = 3,
    parameter integer R = 2048,
    parameter integer M = 1,
    parameter integer IN_W  = 2,
    parameter integer OUT_W = 20,
    parameter integer GAIN_K= 7,
    parameter integer ACC_W = N * $clog2(R * M) + IN_W,
    parameter integer SHIFT = N * $clog2(R * M) - OUT_W + 2
)(
    input  wire clk,
    input  wire reset,
    input  wire enable,
    input  wire signed [IN_W-1:0]  din,
    output reg  signed [OUT_W-1:0] dout,
    output reg outready
);
    wire signed [ACC_W-1:0] cdata;
    wire cvalid;

    cic_core #(.N(N), .R(R), .M(M), .IN_W(IN_W), .ACC_W(ACC_W)) u_core (
        .clk(clk), .reset(reset), .enable(enable), .din(din),
        .dout(cdata), .dvalid(cvalid)
    );

    localparam integer GAIN_W = $clog2(GAIN_K + 1) + 1;
    localparam integer PROD_W = ACC_W + GAIN_W;

    localparam signed [PROD_W-1:0] GAIN_CONST  = GAIN_K;
    localparam signed [PROD_W-1:0] RND  = {{(PROD_W-1){1'b0}}, 1'b1} << (SHIFT-1);
    localparam signed [PROD_W-1:0] MAXV =  ({{(PROD_W-1){1'b0}}, 1'b1} << (OUT_W-1)) - 1;
    localparam signed [PROD_W-1:0] MINV = -({{(PROD_W-1){1'b0}}, 1'b1} << (OUT_W-1));

    wire signed [PROD_W-1:0] comb_ext = cdata;               // sign-extend
    wire signed [PROD_W-1:0] prod = comb_ext * GAIN_CONST;
    wire signed [PROD_W-1:0] scaled = (prod + RND) >>> SHIFT;

    always @(posedge clk) begin
        if (reset) begin
            dout     <= {OUT_W{1'b0}};
            outready <= 1'b0;
        end else begin
            outready <= cvalid;
            if (cvalid) begin
                if (scaled > MAXV)      dout <= MAXV[OUT_W-1:0];
                else if (scaled < MINV) dout <= MINV[OUT_W-1:0];
                else                    dout <= scaled[OUT_W-1:0];
            end
        end
    end
endmodule

module cic_comb #(
    parameter integer W = 35,
    parameter integer M = 1
)(
    input  wire clk,
    input  wire reset,
    input  wire valid_in,
    input  wire signed [W-1:0]  din,
    output reg valid_out,
    output reg signed [W-1:0]  dout
);
    reg signed [W-1:0] dly [0:M-1];
    integer i;

    always @(posedge clk) begin
        if (reset) begin
            valid_out <= 1'b0;
            dout      <= {W{1'b0}};
            for (i = 0; i < M; i = i + 1)
                dly[i] <= {W{1'b0}};
        end else begin
            valid_out <= valid_in;
            if (valid_in) begin
                dout   <= din - dly[M-1];
                dly[0] <= din;
                for (i = 1; i < M; i = i + 1)
                    dly[i] <= dly[i-1];
            end
        end
    end
endmodule
