`timescale 1ns/1ps

module fir_tb;

    reg clk;
    reg resetn;

    reg        wr_en;
    reg        rd_en;
    reg [31:0] addr;
    reg [31:0] wdata;

    wire [31:0] rdata;

    fir_accel dut (
        .clk    (clk),
        .resetn (resetn),
        .wr_en  (wr_en),
        .rd_en  (rd_en),
        .addr   (addr),
        .wdata  (wdata),
        .rdata  (rdata)
    );

    always #5 clk = ~clk;

    task write_reg;
        input [31:0] address;
        input [31:0] data;

        begin
            @(posedge clk);

            addr  = address;
            wdata = data;
            wr_en = 1'b1;

            @(posedge clk);

            wr_en = 1'b0;
            addr  = 32'b0;
            wdata = 32'b0;
        end
    endtask

    task read_reg;
        input [31:0] address;

        begin
            @(posedge clk);

            addr  = address;
            rd_en = 1'b1;

            @(posedge clk);
            #1;

            $display(
                "FIR RESULT = %h (%0d)",
                rdata,
                rdata
            );

            rd_en = 1'b0;
            addr  = 32'b0;
        end
    endtask

    initial begin

        clk   = 1'b0;
        resetn = 1'b0;

        wr_en = 1'b0;
        rd_en = 1'b0;
        addr  = 32'b0;
        wdata = 32'b0;

        #20;

        resetn = 1'b1;

        // Samples
        write_reg(32'h10000200, 1);
        write_reg(32'h10000204, 2);
        write_reg(32'h10000208, 3);
        write_reg(32'h1000020C, 4);

        // Coefficients
        write_reg(32'h10000210, 1);
        write_reg(32'h10000214, 1);
        write_reg(32'h10000218, 1);
        write_reg(32'h1000021C, 1);

        // Start FIR calculation
        write_reg(32'h10000220, 0);

        // Read result
        read_reg(32'h10000224);

        #50;

        $finish;

    end

endmodule