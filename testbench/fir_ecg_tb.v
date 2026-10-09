
`timescale 1ns/1ps

module fir_ecg_tb;

    reg clk = 0;
    reg resetn = 0;
    reg wr_en = 0;
    reg rd_en = 0;
    reg [31:0] addr = 0;
    reg [31:0] wdata = 0;
    wire [31:0] rdata;

    fir_accel dut (
        .clk(clk),
        .resetn(resetn),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .addr(addr),
        .wdata(wdata),
        .rdata(rdata)
    );

    always #5 clk = ~clk;  // 100 MHz test clock

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

    task process_sample;
        input [15:0] sample;
        reg [31:0] filtered;
        begin
            // Shift the previous samples through the four taps.
            write_reg(32'h1000020C, dut.x2);
            write_reg(32'h10000208, dut.x1);
            write_reg(32'h10000204, dut.x0);
            write_reg(32'h10000200, sample);

            // Start the FIR calculation.
            write_reg(32'h10000220, 32'd1);

            // Read the result.
            @(negedge clk);
            addr = 32'h10000224;
            rd_en = 1;
            #1 filtered = rdata;

            $display("Time=%0t ns | ECG input=%0d | FIR output=%0d",
                     $time, $signed(sample), $signed(filtered));

            @(negedge clk);
            rd_en = 0;
            addr = 0;
        end
    endtask

    initial begin
        $dumpfile("fir_ecg.vcd");
        $dumpvars(0, fir_ecg_tb);

        // Reset the accelerator.
        repeat (3) @(negedge clk);
        resetn = 1;

        // Example smoothing coefficients: all taps equal 1/4.
        write_reg(32'h10000210, 16'd1);
        write_reg(32'h10000214, 16'd1);
        write_reg(32'h10000218, 16'd1);
        write_reg(32'h1000021C, 16'd1);

        // Demonstration sample sequence, not real patient data.
        process_sample(16'd100);
        process_sample(16'd150);
        process_sample(16'd220);
        process_sample(16'd285);
        process_sample(16'd300);
        process_sample(16'd240);
        process_sample(16'd180);
        process_sample(16'd120);

        #20;
        $display("FIR ECG waveform test completed.");
        $finish;
    end

endmodule
