`timescale 1ns/1ps

module peak_detector_tb;

    localparam integer NUM_SAMPLES = 1000;
    localparam integer SAMPLE_RATE = 100;
    localparam [31:0] SAMPLE_ADDR    = 32'h10000300;
    localparam [31:0] THRESHOLD_ADDR = 32'h10000304;
    localparam [31:0] START_ADDR     = 32'h10000308;
    localparam [31:0] PEAK_ADDR      = 32'h1000030C;
    localparam [31:0] RR_ADDR        = 32'h10000310;
    localparam [31:0] BPM_ADDR       = 32'h10000314;

    reg clk = 0;
    reg resetn = 0;
    reg wr_en = 0;
    reg rd_en = 0;
    reg [31:0] addr = 0;
    reg [31:0] wdata = 0;
    wire [31:0] rdata;

    reg [31:0] ecg_samples [0:NUM_SAMPLES-1];
    reg [31:0] read_value;
    integer i;
    integer detected_count;

    peak_detector #(.SAMPLE_RATE(SAMPLE_RATE)) dut (
        .clk(clk),
        .resetn(resetn),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .addr(addr),
        .wdata(wdata),
        .rdata(rdata)
    );

    always #5 clk = ~clk;

    task write_reg;
        input [31:0] a;
        input [31:0] d;
        begin
            @(negedge clk);
            addr = a;
            wdata = d;
            wr_en = 1;
            @(negedge clk);
            wr_en = 0;
            addr = 0;
            wdata = 0;
        end
    endtask

    task read_reg;
        input [31:0] a;
        output [31:0] d;
        begin
            @(negedge clk);
            addr = a;
            rd_en = 1;
            #1 d = rdata;
            @(negedge clk);
            rd_en = 0;
            addr = 0;
        end
    endtask

    initial begin
        $display("==========================================");
        $display(" Standalone ECG Peak Detector Test");
        $display(" Sample rate = %0d Hz; expected BPM = 75", SAMPLE_RATE);
        $display(" Threshold = 320 (four-sample FIR sum)");
        $display("==========================================");

        $readmemh("TB/synthetic_fir_samples.mem", ecg_samples);

        repeat (4) @(negedge clk);
        resetn = 1;

        write_reg(THRESHOLD_ADDR, 32'd320);
        detected_count = 0;

        for (i = 0; i < NUM_SAMPLES; i = i + 1) begin
            write_reg(SAMPLE_ADDR, ecg_samples[i]);
            write_reg(START_ADDR, 32'd1);

            if (dut.peak_detected) begin
                detected_count = detected_count + 1;
                $display("Peak %0d at sample index %0d, FIR value=%0d",
                         detected_count, i, ecg_samples[i]);
            end
        end

        read_reg(RR_ADDR, read_value);
        $display("Final RR interval = %0d samples (expected 80)", read_value);

        read_reg(BPM_ADDR, read_value);
        $display("Calculated BPM = %0d (expected 75)", read_value);

        $display("Detected peaks = %0d (expected 13)", detected_count);

        if (read_value == 75 && detected_count == 13) begin
            $display("PEAK DETECTOR TEST: PASS");
        end else begin
            $display("PEAK DETECTOR TEST: FAIL");
        end

        $display("NOTE: synthetic signal validation only; not medical use.");
        $finish;
    end

endmodule
