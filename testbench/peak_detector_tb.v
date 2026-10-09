`timescale 1ns/1ps

module peak_detector_tb;

reg clk;
reg resetn;

reg        wr_en;
reg        rd_en;
reg [31:0] addr;
reg [31:0] wdata;

wire [31:0] rdata;


peak_detector dut (
    .clk(clk),
    .resetn(resetn),
    .wr_en(wr_en),
    .rd_en(rd_en),
    .addr(addr),
    .wdata(wdata),
    .rdata(rdata)
);


// Clock: 10 ns
always #5 clk = ~clk;


initial begin

    clk     = 0;
    resetn  = 0;
    wr_en   = 0;
    rd_en   = 0;
    addr    = 0;
    wdata   = 0;

    #20;
    resetn = 1;


    // ------------------------------------------------
    // Set threshold = 100
    // ------------------------------------------------

    @(negedge clk);
    wr_en = 1;
    addr  = 32'h10000304;
    wdata = 32'd100;

    @(negedge clk);
    wr_en = 0;


    // ------------------------------------------------
    // FIRST PEAK
    // Sample = 285
    // ------------------------------------------------

    @(negedge clk);
    wr_en = 1;
    addr  = 32'h10000300;
    wdata = 32'd285;

    @(negedge clk);
    wr_en = 0;


    // Start detection
    @(negedge clk);
    wr_en = 1;
    addr  = 32'h10000308;
    wdata = 32'd1;

    @(negedge clk);
    wr_en = 0;


    // ------------------------------------------------
    // Wait 5 sample cycles
    // ------------------------------------------------

    repeat(5)
        @(negedge clk);


    // ------------------------------------------------
    // SECOND PEAK
    // Sample = 300
    // ------------------------------------------------

    @(negedge clk);
    wr_en = 1;
    addr  = 32'h10000300;
    wdata = 32'd300;

    @(negedge clk);
    wr_en = 0;


    // Start detection
    @(negedge clk);
    wr_en = 1;
    addr  = 32'h10000308;
    wdata = 32'd1;

    @(negedge clk);
    wr_en = 0;


    // ------------------------------------------------
    // Read peak result
    // ------------------------------------------------

    @(negedge clk);
    rd_en = 1;
    addr  = 32'h1000030C;

    #1;

    $display("PEAK RESULT = %h", rdata);

    rd_en = 0;


    // ------------------------------------------------
    // Read R-R interval
    // ------------------------------------------------

    @(negedge clk);
    rd_en = 1;
    addr  = 32'h10000310;

    #1;

    $display("RR INTERVAL = %0d CLOCK CYCLES", rdata);

    rd_en = 0;


    #20;

    $finish;

end

endmodule