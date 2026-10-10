`timescale 1ns/1ps

module soc_tb;

    localparam integer SAMPLE_COUNT = 1000;
    localparam integer CLK_PERIOD = 10;
    localparam integer UART_BIT_PERIOD = 104170;

    reg clk;
    reg resetn;
    reg ser_rx;
    wire ser_tx;

    reg [31:0] ecg_samples [0:SAMPLE_COUNT-1];
    reg [7:0] uart_tx_byte;

    integer i;
    integer bit_index;
    integer uart_tx_bytes_received;
    integer uart_tx_errors;
    integer rx_samples_passed;
    integer rx_samples_failed;
    integer rx_observed_count;

    soc dut (
        .clk    (clk),
        .resetn (resetn),
        .ser_tx (ser_tx),
        .ser_rx (ser_rx)
    );

    // 100 MHz system clock
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // The file must be present at E:/pico/TB/synthetic_fir_samples.mem.
    // It contains the 1000 raw 8-bit synthetic ECG samples in hexadecimal.
    initial begin
        $readmemh("TB/synthetic_fir_samples.mem", ecg_samples);
    end

    // Reset and counters
    initial begin
        resetn = 1'b0;
        ser_rx = 1'b1;
        uart_tx_byte = 8'h00;

        uart_tx_bytes_received = 0;
        uart_tx_errors = 0;
        rx_samples_passed = 0;
        rx_samples_failed = 0;
        rx_observed_count = 0;

        $display("==================================================");
        $display(" PicoRV32 ECG SoC full-stream test");
        $display(" Clock: 100 MHz; UART: approximately 9600 baud");
        $display(" ECG input samples: %0d", SAMPLE_COUNT);
        $display(" Expected synthetic BPM: 75");
        $display("==================================================");

        repeat (10) @(posedge clk);
        #1 resetn = 1'b1;
        $display("[%0t ns] Reset released", $time);
    end

    // UART 8-N-1 stimulus; one input byte at a time.
    task uart_send_byte;
        input [7:0] data;
        integer tx_index;
        begin
            // Idle interval before the frame
            ser_rx = 1'b1;
            #(UART_BIT_PERIOD);

            // Start bit
            ser_rx = 1'b0;
            #(UART_BIT_PERIOD);

            // Data bits, least-significant bit first
            for (tx_index = 0; tx_index < 8; tx_index = tx_index + 1) begin
                ser_rx = data[tx_index];
                #(UART_BIT_PERIOD);
            end

            // Stop bit
            ser_rx = 1'b1;
            #(UART_BIT_PERIOD);
        end
    endtask

    // Count and validate all bytes accepted by the UART RX peripheral.
    always @(posedge dut.uart_inst.recv_buf_valid) begin
        if (resetn) begin
            if (rx_observed_count < SAMPLE_COUNT) begin
                if (dut.uart_inst.recv_buf_data ===
                    ecg_samples[rx_observed_count][7:0]) begin
                    rx_samples_passed = rx_samples_passed + 1;
                end else begin
                    rx_samples_failed = rx_samples_failed + 1;
                    $display("[%0t ns] RX DATA MISMATCH index=%0d expected=%02h got=%02h",
                             $time, rx_observed_count,
                             ecg_samples[rx_observed_count][7:0],
                             dut.uart_inst.recv_buf_data);
                end

                if ((rx_observed_count % 100) == 0) begin
                    $display("[%0t ns] UART RX progress: sample %0d / %0d",
                             $time, rx_observed_count + 1, SAMPLE_COUNT);
                end
            end else begin
                $display("[%0t ns] Unexpected extra UART RX byte: %02h",
                         $time, dut.uart_inst.recv_buf_data);
            end
            rx_observed_count = rx_observed_count + 1;
        end
    end

    // UART TX monitor. The firmware should transmit one BPM byte at the end.
    initial begin
        forever begin
            @(negedge ser_tx);
            if (resetn) begin
                // Sample in the middle of data bit 0
                #(UART_BIT_PERIOD + UART_BIT_PERIOD/2);
                uart_tx_byte = 8'h00;

                for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                    uart_tx_byte[bit_index] = ser_tx;
                    #(UART_BIT_PERIOD);
                end

                if (ser_tx !== 1'b1) begin
                    uart_tx_errors = uart_tx_errors + 1;
                    $display("[%0t ns] UART TX framing error", $time);
                end else begin
                    uart_tx_bytes_received = uart_tx_bytes_received + 1;
                    $display("[%0t ns] UART TX byte #%0d = 0x%02h (%0d)",
                             $time, uart_tx_bytes_received,
                             uart_tx_byte, uart_tx_byte);
                end
            end
        end
    end

    // Full test: deliver all 1000 samples through UART RX.
    initial begin
        wait (resetn == 1'b1);

        // Allow CPU initialization to finish.
        #200000;

        $display("[%0t ns] Sending synthetic ECG stream...", $time);
        for (i = 0; i < SAMPLE_COUNT; i = i + 1) begin
            uart_send_byte(ecg_samples[i][7:0]);
        end

        $display("[%0t ns] All ECG samples sent", $time);

        // Allow final BPM read and UART TX frame to complete.
        #(3 * UART_BIT_PERIOD * 10);

        $display("");
        $display("==================================================");
        $display(" FULL SOC SIMULATION SUMMARY");
        $display("==================================================");
        $display("UART RX samples observed = %0d", rx_observed_count);
        $display("UART RX samples passed  = %0d", rx_samples_passed);
        $display("UART RX samples failed  = %0d", rx_samples_failed);
        $display("UART TX bytes received  = %0d", uart_tx_bytes_received);
        $display("UART TX framing errors  = %0d", uart_tx_errors);
        $display("Threshold               = %0d", dut.peak_inst.threshold);
        $display("FIR result               = %0d", dut.fir_inst.result);
        $display("Peak detector RR         = %0d samples", dut.peak_inst.rr_interval);
        $display("Peak detector BPM        = %0d", dut.peak_inst.heart_rate);
        $display("Detected peak flag       = %0d", dut.peak_inst.peak_detected);
        $display("CPU trap                 = %b", dut.trap);
        $display("CPU PC                   = %h", dut.cpu.reg_pc);
        $display("==================================================");

        if (rx_observed_count == SAMPLE_COUNT &&
            rx_samples_passed == SAMPLE_COUNT &&
            rx_samples_failed == 0)
            $display("UART RX FULL STREAM: PASS");
        else
            $display("UART RX FULL STREAM: FAIL");

        if (uart_tx_errors == 0 &&
            uart_tx_bytes_received == 1 &&
            uart_tx_byte == 8'd75)
            $display("BPM UART OUTPUT: PASS (75 BPM)");
        else
            $display("BPM UART OUTPUT: FAIL (expected one byte: 75)");

        if (dut.peak_inst.rr_interval == 80 &&
            dut.peak_inst.heart_rate == 75)
            $display("ECG PEAK/RR/BPM: PASS");
        else
            $display("ECG PEAK/RR/BPM: FAIL");

        $display("Note: synthetic data validation only; not for medical use.");
        $display("==================================================");
        $finish;
    end

    // 1.5 seconds simulation-time limit for 1000 UART samples.
    initial begin
        #1500000000;
        $display("ERROR: Simulation timeout before test completion.");
        $display("RX observed=%0d, TX bytes=%0d",
                 rx_observed_count, uart_tx_bytes_received);
        $finish;
    end

endmodule
