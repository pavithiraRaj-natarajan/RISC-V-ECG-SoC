
module soc (
    input wire clk,
    input wire resetn,
    output wire ser_tx,
    input wire ser_rx
);

    // ==========================================
    // MEMORY BUS
    // ==========================================
    wire        mem_valid;
    wire        mem_instr;
    wire        mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    wire [31:0] mem_rdata;

    // Look-ahead memory bus
    wire        mem_la_read;
    wire        mem_la_write;
    wire [31:0] mem_la_addr;
    wire [31:0] mem_la_wdata;
    wire [3:0]  mem_la_wstrb;

    // PCPI interface
    wire        pcpi_valid;
    wire [31:0] pcpi_insn;
    wire [31:0] pcpi_rs1;
    wire [31:0] pcpi_rs2;

    wire        pcpi_wr;
    wire [31:0] pcpi_rd;
    wire        pcpi_wait;
    wire        pcpi_ready;

    assign pcpi_wr    = 1'b0;
    assign pcpi_rd    = 32'd0;
    assign pcpi_wait  = 1'b0;
    assign pcpi_ready = 1'b0;

    // IRQ and trace
    wire [31:0] irq;
    wire [31:0] eoi;
    wire        trap;
    wire        trace_valid;
    wire [35:0] trace_data;

    assign irq = 32'd0;

    // ==========================================
    // PICORV32 CPU
    // ==========================================
    picorv32 cpu (
        .clk(clk),
        .resetn(resetn),

        .mem_valid(mem_valid),
        .mem_instr(mem_instr),
        .mem_ready(mem_ready),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata),

        .mem_la_read(mem_la_read),
        .mem_la_write(mem_la_write),
        .mem_la_addr(mem_la_addr),
        .mem_la_wdata(mem_la_wdata),
        .mem_la_wstrb(mem_la_wstrb),

        .pcpi_valid(pcpi_valid),
        .pcpi_insn(pcpi_insn),
        .pcpi_rs1(pcpi_rs1),
        .pcpi_rs2(pcpi_rs2),

        .pcpi_wr(pcpi_wr),
        .pcpi_rd(pcpi_rd),
        .pcpi_wait(pcpi_wait),
        .pcpi_ready(pcpi_ready),

        .irq(irq),
        .eoi(eoi),
        .trap(trap),

        .trace_valid(trace_valid),
        .trace_data(trace_data)
    );

    // ==========================================
    // ADDRESS DECODING
    // ==========================================
    wire rom_select;
    wire ram_select;
    wire uart_select;
    wire fir_select;
    wire peak_select;

    assign rom_select =
        mem_valid &&
        (mem_addr < 32'h00000400);

    assign ram_select =
        mem_valid &&
        (mem_addr >= 32'h00001000) &&
        (mem_addr < 32'h00001400);

    assign uart_select =
        mem_valid &&
        (mem_addr >= 32'h10000000) &&
        (mem_addr < 32'h1000000C);

    assign fir_select =
        mem_valid &&
        (mem_addr >= 32'h10000200) &&
        (mem_addr < 32'h10000228);

    assign peak_select =
        mem_valid &&
        (mem_addr >= 32'h10000300) &&
        (mem_addr < 32'h10000318);

    // ==========================================
    // ROM
    // ==========================================
    wire [31:0] rom_rdata;

    rom rom_inst (
        .clk(clk),
        .addr(mem_addr),
        .rdata(rom_rdata)
    );

    // ==========================================
    // RAM
    // ==========================================
    wire [31:0] ram_rdata;

    ram ram_inst (
        .clk(clk),
        .we(ram_select && (|mem_wstrb)),
        .addr(mem_addr),
        .wdata(mem_wdata),
        .wstrb(mem_wstrb),
        .rdata(ram_rdata)
    );

    // ==========================================
    // UART
    // ==========================================
    wire [31:0] uart_rdata;
    wire        uart_wait;
    wire [31:0] uart_div_do;
    wire [31:0] uart_dat_do;
    wire        uart_rx_valid;

    simpleuart uart_inst (
        .clk(clk),
        .resetn(resetn),

        .ser_tx(ser_tx),
        .ser_rx(ser_rx),

        .reg_div_we(
            uart_select &&
            (mem_addr == 32'h10000004)
            ? mem_wstrb : 4'b0000
        ),
        .reg_div_di(mem_wdata),
        .reg_div_do(uart_div_do),

        .reg_dat_we(
            uart_select &&
            (mem_addr == 32'h10000000) &&
            (|mem_wstrb)
        ),

        .reg_dat_re(
            uart_select &&
            (mem_addr == 32'h10000000) &&
            (mem_wstrb == 4'b0000) &&
            mem_valid &&
            mem_ready
        ),

        .reg_dat_di(mem_wdata),
        .reg_dat_do(uart_dat_do),
        .reg_dat_wait(uart_wait),
        .reg_dat_valid(uart_rx_valid)
    );

    wire [31:0] uart_status;

    assign uart_status = {31'b0, uart_rx_valid};

    assign uart_rdata =
        (mem_addr == 32'h10000004) ? uart_div_do :
        (mem_addr == 32'h10000000) ? uart_dat_do :
        (mem_addr == 32'h10000008) ? uart_status :
        32'd0;

    // ==========================================
    // FIR ACCELERATOR
    // ==========================================
    wire [31:0] fir_rdata;

    fir_accel fir_inst (
        .clk(clk),
        .resetn(resetn),

        .wr_en(fir_select && (|mem_wstrb)),
        .rd_en(fir_select && (mem_wstrb == 4'b0000)),

        .addr(mem_addr),
        .wdata(mem_wdata),
        .rdata(fir_rdata)
    );

    // ==========================================
    // PEAK DETECTOR
    // ==========================================
    wire [31:0] peak_rdata;

    peak_detector peak_inst (
        .clk(clk),
        .resetn(resetn),

        .wr_en(peak_select && (|mem_wstrb)),
        .rd_en(peak_select && (mem_wstrb == 4'b0000)),

        .addr(mem_addr),
        .wdata(mem_wdata),
        .rdata(peak_rdata)
    );

    // ==========================================
    // READ-DATA MULTIPLEXER
    // ==========================================
    assign mem_rdata =
        rom_select  ? rom_rdata  :
        ram_select  ? ram_rdata  :
        uart_select ? uart_rdata :
        fir_select  ? fir_rdata  :
        peak_select ? peak_rdata :
        32'd0;

    // ==========================================
    // MEMORY READY
    // ==========================================
    // Hold UART data writes until the transmitter is idle.
    assign mem_ready =
        mem_valid &&
        (
            rom_select ||
            ram_select ||
            (uart_select && !uart_wait) ||
            fir_select ||
            peak_select
        );

endmodule
