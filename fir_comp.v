`timescale 1ns / 1fs

module fir_comp #(
    parameter integer IN_W = 35, 
    parameter integer DROP = 7,  
    parameter integer L = 6,     
    parameter integer CW = 19,   
    parameter integer OUT_W = 20,
    parameter integer SHIFT = 22,   
    parameter signed [L*CW-1:0] COEF = {
        -19'sd7553, 19'sd15908, -19'sd28297, 19'sd50848, -19'sd96584, 19'sd182004
    }                              
)(
    input  wire clk,
    input  wire reset,
    input  wire valid_in,
    input  wire signed [IN_W-1:0]    din,
    output reg  signed [OUT_W-1:0]   dout,
    output reg  outready
);
    localparam integer sample_width  = IN_W - DROP;
    localparam integer accu_width  = sample_width + CW + $clog2(L);
    localparam integer tap_width  = $clog2(L + 1);

    localparam signed [accu_width-1:0] RND  = {{(accu_width-1){1'b0}}, 1'b1} << (SHIFT-1);
    localparam signed [accu_width-1:0] MAXV =  ({{(accu_width-1){1'b0}}, 1'b1} << (OUT_W-1)) - 1;
    localparam signed [accu_width-1:0] MINV = -({{(accu_width-1){1'b0}}, 1'b1} << (OUT_W-1));

    reg signed [sample_width-1:0] dly [0:L-1];   // x[n], x[n-1], ...
    reg signed [accu_width-1:0] acc;
    reg [tap_width-1:0] t;
    reg busy, acc_done;
    integer j;

    wire signed [CW-1:0] coef_t = COEF[t*CW +: CW];
    wire signed [accu_width-1:0] scaled = (acc + RND) >>> SHIFT;

    always @(posedge clk) begin
        if (reset) begin
            for (j = 0; j < L; j = j + 1) dly[j] <= {sample_width{1'b0}};
            acc <= {accu_width{1'b0}};
            t <= {tap_width{1'b0}};
            busy <= 1'b0;
            acc_done <= 1'b0;
            dout <= {OUT_W{1'b0}};
            outready <= 1'b0;
        end else begin
            acc_done <= 1'b0;
            outready <= acc_done;

            if (valid_in) begin                     
                dly[0] <= din >>> DROP;
                for (j = 1; j < L; j = j + 1) dly[j] <= dly[j-1];
                acc <= {accu_width{1'b0}};
                t <= {tap_width{1'b0}};
                busy <= 1'b1;
            end else if (busy) begin                
                acc <= acc + coef_t * dly[t];
                if (t == L-1) begin
                    busy <= 1'b0;
                    acc_done <= 1'b1;
                end else begin
                    t <= t + 1'b1;
                end
            end

            if (acc_done) begin                    
                if (scaled > MAXV)      dout <= MAXV[OUT_W-1:0];
                else if (scaled < MINV) dout <= MINV[OUT_W-1:0];
                else                    dout <= scaled[OUT_W-1:0];
            end
        end
    end
endmodule
