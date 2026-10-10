module simpleuart #(parameter integer DEFAULT_DIV = 10415) (
    input clk,
    input resetn,

    output ser_tx,
    input  ser_rx,

    input  [3:0]  reg_div_we,
    input  [31:0] reg_div_di,
    output [31:0] reg_div_do,

    input          reg_dat_we,
    input          reg_dat_re,
    input  [31:0]  reg_dat_di,
    output [31:0]  reg_dat_do,
    output         reg_dat_wait,
    output         reg_dat_valid
);

    reg [31:0] cfg_divider;

    reg [3:0]  recv_state;
    reg [31:0] recv_divcnt;
    reg [7:0]  recv_pattern;
    reg [7:0]  recv_buf_data;
    reg        recv_buf_valid;

    reg [9:0]  send_pattern;
    reg [3:0]  send_bitcnt;
    reg [31:0] send_divcnt;

    assign reg_div_do = cfg_divider;

    assign reg_dat_wait =
        reg_dat_we && (send_bitcnt != 0);

    assign reg_dat_do =
        recv_buf_valid ? {24'b0, recv_buf_data} : 32'hFFFFFFFF;

    assign reg_dat_valid = recv_buf_valid;

    // Divider register
    always @(posedge clk) begin
        if (!resetn) begin
            cfg_divider <= DEFAULT_DIV;
        end else begin
            if (reg_div_we[0])
                cfg_divider[7:0] <= reg_div_di[7:0];

            if (reg_div_we[1])
                cfg_divider[15:8] <= reg_div_di[15:8];

            if (reg_div_we[2])
                cfg_divider[23:16] <= reg_div_di[23:16];

            if (reg_div_we[3])
                cfg_divider[31:24] <= reg_div_di[31:24];
        end
    end

    // UART receiver: 8 data bits, no parity, one stop bit.
    // State 0: idle/start detection
    // State 1: validate start bit at its midpoint
    // States 2-9: sample data bits
    // State 10: validate stop bit
    always @(posedge clk) begin
        if (!resetn) begin
            recv_state     <= 0;
            recv_divcnt    <= 0;
            recv_pattern   <= 0;
            recv_buf_data  <= 0;
            recv_buf_valid <= 0;
        end else begin
            // Reading data acknowledges the current byte.
            if (reg_dat_re)
                recv_buf_valid <= 0;

            case (recv_state)
                0: begin
                    recv_divcnt <= 0;

                    if (!ser_rx)
                        recv_state <= 1;
                end

                1: begin
                    if (recv_divcnt >= (cfg_divider >> 1)) begin
                        recv_divcnt <= 0;

                        if (!ser_rx)
                            recv_state <= 2;
                        else
                            recv_state <= 0;
                    end else begin
                        recv_divcnt <= recv_divcnt + 1'b1;
                    end
                end

                2, 3, 4, 5, 6, 7, 8, 9: begin
                    if (recv_divcnt >= cfg_divider) begin
                        recv_divcnt <= 0;

                        recv_pattern <= {
                            ser_rx,
                            recv_pattern[7:1]
                        };

                        recv_state <= recv_state + 1'b1;
                    end else begin
                        recv_divcnt <= recv_divcnt + 1'b1;
                    end
                end

                10: begin
                    if (recv_divcnt >= cfg_divider) begin
                        recv_divcnt <= 0;
                        recv_state  <= 0;

                        if (ser_rx) begin
                            recv_buf_data  <= recv_pattern;
                            recv_buf_valid <= 1'b1;
                        end
                    end else begin
                        recv_divcnt <= recv_divcnt + 1'b1;
                    end
                end

                default: begin
                    recv_state  <= 0;
                    recv_divcnt <= 0;
                end
            endcase
        end
    end

    // UART transmitter
    // send_pattern[0] is the output bit.
    // Frame order: start, 8 data bits, stop.
    assign ser_tx = send_pattern[0];

    always @(posedge clk) begin
        if (!resetn) begin
            send_pattern <= 10'b1111111111;
            send_bitcnt  <= 0;
            send_divcnt  <= 0;
        end else begin
            if (send_bitcnt == 0) begin
                send_divcnt <= 0;
            end else if (send_divcnt >= cfg_divider) begin
                send_divcnt <= 0;
            end else begin
                send_divcnt <= send_divcnt + 1'b1;
            end

            if (reg_dat_we && send_bitcnt == 0) begin
                send_pattern <= {
                    1'b1,
                    reg_dat_di[7:0],
                    1'b0
                };

                send_bitcnt <= 10;
                send_divcnt <= 0;
            end else if (
                send_bitcnt != 0 &&
                send_divcnt >= cfg_divider
            ) begin
                send_pattern <= {
                    1'b1,
                    send_pattern[9:1]
                };

                send_bitcnt <= send_bitcnt - 1'b1;
            end
        end
    end

endmodule
