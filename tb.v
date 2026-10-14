`timescale 1ns / 1fs

module cic_tb;
    localparam integer NSAMPLES = 4096026;
    reg data [0:NSAMPLES-1];
    reg clk;
    reg reset;
    reg enable;
    reg signed [1:0] bits;

    wire signed [19:0] cicout;
    wire outready;

    reg [8*256-1:0] input_file;
    reg [8*256-1:0] output_file;
    integer i;
    integer fd_out;
    integer output_count;
    integer ok;
    reg first_sample_pending;

`ifdef TASK2
    cic_fir_top #(
`else
    cic_top #(
`endif
        .N(3),
        .R(2048),
        .M(1),
        .IN_W(2),
        .OUT_W(20)
    ) cic (
        .clk(clk),
        .reset(reset),
        .enable(enable),
        .din(bits),
        .dout(cicout),
        .outready(outready)
    );

    initial clk = 1'b0;
    always #122.0703125 clk = ~clk;

    initial begin
        reset = 1'b1;
        enable = 1'b0;
        bits = 2'sd0;
        i = 0;
        output_count = 0;
        first_sample_pending = 1'b1;
        input_file = "hz500.mem";
        output_file = "cic_500.txt";

        ok = $value$plusargs("INPUT=%s", input_file);
        ok = $value$plusargs("OUTPUT=%s", output_file);

        $display("CIC testbench: input=%0s, output=%0s", input_file, output_file);
        $readmemh(input_file, data);

        bits = {1'b0, data[0]};
        i = 1;

        fd_out = $fopen(output_file, "w");
        if (fd_out == 0) begin
            $display("ERROR: Could not open output file %0s", output_file);
            $finish;
        end

        repeat (2) @(posedge clk);
        #1;
        reset = 1'b0;
        enable = 1'b1;
    end

    always @(negedge clk) begin
        if (!reset && enable) begin
            if (first_sample_pending) begin
                first_sample_pending = 1'b0;
            end else if (i < NSAMPLES) begin
                if ((i % 2) == 0)
                    bits = {1'b0, data[i]};
                else
                    bits = {2{data[i]}};
                i = i + 1;
            end else begin
                enable = 1'b0;
            end
        end
    end

    always @(posedge clk) begin
        if (!reset && outready) begin
            $fwrite(fd_out, "%0d\n", $signed(cicout));
            output_count = output_count + 1;
        end
    end

    initial begin
        wait (i == NSAMPLES);
        repeat (3) @(posedge clk);
        #1;
        $fclose(fd_out);
        $display("Simulation complete. CIC output samples written: %0d", output_count);
        if (output_count != (NSAMPLES / 2048))
            $display("WARNING: expected %0d outputs for R=2048.", NSAMPLES / 2048);
        $finish;
    end
endmodule
