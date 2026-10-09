
`timescale 1ns/1ps

module soc_tb;

    reg clk;
    reg resetn;

    // UART connections
    wire ser_tx;
    reg  ser_rx;

    // UART TX monitor variables
    reg [7:0] uart_rx_byte;
    integer uart_bit;
    integer uart_errors;
    integer uart_bytes_received;

    integer ecg_bytes_sent;

    // Device under test
    soc dut (
        .clk    (clk),
        .resetn (resetn),
        .ser_tx (ser_tx),
        .ser_rx (ser_rx)
    );

    // 100 MHz clock: 10 ns period
    always #5 clk = ~clk;


    // -----------------------------------------
    // UART: simulated PC sends one byte to SoC
    // -----------------------------------------
    // Uses the 30 ns bit period assumed by the
    // existing testbench. Confirm against the
    // actual UART divider implementation.
    task uart_send_byte;
        input [7:0] data;
        integer i;
        begin
            // Start bit
            ser_rx = 1'b0;
            #30;

            // Eight data bits, LSB first
            for (i = 0; i < 8; i = i + 1) begin
                ser_rx = data[i];
                #30;
            end

            // Stop bit
            ser_rx = 1'b1;
            #30;
        end
    endtask


    // -----------------------------------------
    // Main test sequence
    // -----------------------------------------
    initial begin
        clk                  = 1'b0;
        resetn               = 1'b0;
        ser_rx               = 1'b1;

        uart_rx_byte         = 8'h00;
        uart_errors          = 0;
        uart_bytes_received  = 0;
        ecg_bytes_sent       = 0;

        $display("");
        $display("==========================================");
        $display("       RISC-V ECG SoC TESTBENCH");
        $display("==========================================");

        // Apply reset
        #100;
        resetn = 1'b1;

        $display("Reset released at %0t ns", $time);

        // Allow the existing ROM program to run
        #500;

        // Send synthetic ECG-like sample bytes
        $display("");
        $display("----- UART RX: ECG SAMPLE INPUT -----");

        uart_send_byte(8'd100);
        ecg_bytes_sent = ecg_bytes_sent + 1;
        $display("Sample byte sent: 100");

        uart_send_byte(8'd150);
        ecg_bytes_sent = ecg_bytes_sent + 1;
        $display("Sample byte sent: 150");

        uart_send_byte(8'd220);
        ecg_bytes_sent = ecg_bytes_sent + 1;
        $display("Sample byte sent: 220");

        uart_send_byte(8'd285);
        ecg_bytes_sent = ecg_bytes_sent + 1;
        $display("Sample byte sent: 285");

        uart_send_byte(8'd300);
        ecg_bytes_sent = ecg_bytes_sent + 1;
        $display("Sample byte sent: 300");

        uart_send_byte(8'd240);
        ecg_bytes_sent = ecg_bytes_sent + 1;
        $display("Sample byte sent: 240");

        uart_send_byte(8'd180);
        ecg_bytes_sent = ecg_bytes_sent + 1;
        $display("Sample byte sent: 180");

        uart_send_byte(8'd120);
        ecg_bytes_sent = ecg_bytes_sent + 1;
        $display("Sample byte sent: 120");

        $display("Total sample bytes driven into RX = %0d",
                 ecg_bytes_sent);

        // Allow CPU and UART activity to continue
        #95000;

        // -------------------------------------
        // Final results
        // -------------------------------------
        $display("");
        $display("==========================================");
        $display("          FINAL SOC RESULTS");
        $display("==========================================");

        $display("CPU PC       = %h", dut.cpu.reg_pc);
        $display("CPU TRAP     = %b", dut.cpu.trap);
        $display("UART TX      = %b", ser_tx);

        $display("");
        $display("----- RR INTERVAL / HEART RATE -----");

        $display("RR INTERVAL STORED IN RAM = %0d",
                 dut.ram_inst.memory[2]);

        $display("HEART RATE STORED IN RAM  = %0d",
                 dut.ram_inst.memory[3]);

        $display("");
        $display("----- UART TRANSMIT VERIFICATION -----");

        $display("UART TX bytes received by monitor = %0d",
                 uart_bytes_received);

        $display("UART TX errors = %0d", uart_errors);

        if (uart_bytes_received == 1 && uart_errors == 0)
            $display("UART TX TEST: PASS");
        else
            $display("UART TX TEST: CHECK OUTPUT");

        $display("");
        $display("NOTE: RX sample bytes were driven by the");
        $display("testbench. CPU processing of those bytes");
        $display("must be verified separately.");

        $display("==========================================");

        $finish;
    end


    // -----------------------------------------
    // UART TX receiver monitor
    // Checks the existing expected character A
    // -----------------------------------------
    initial begin
        forever begin
            @(negedge ser_tx);

            // Sample first data bit at its center
            #45;

            uart_rx_byte = 8'h00;

            // Receive 8 bits, LSB first
            for (uart_bit = 0; uart_bit < 8;
                 uart_bit = uart_bit + 1) begin

                uart_rx_byte[uart_bit] = ser_tx;
                #30;
            end

            // Check stop bit
            if (ser_tx !== 1'b1) begin
                uart_errors = uart_errors + 1;
                $display("UART ERROR: Invalid stop bit");
            end
            else if (uart_rx_byte !== 8'h41) begin
                uart_errors = uart_errors + 1;
                $display("UART ERROR: Unexpected byte %02h",
                         uart_rx_byte);
            end
            else begin
                uart_bytes_received = uart_bytes_received + 1;
                $display("UART TX PASS: Received character A");
            end

            // Finish sampling the stop-bit interval
            #30;
        end
    end

endmodule
