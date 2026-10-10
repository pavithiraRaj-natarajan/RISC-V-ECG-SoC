`timescale 1ns/1ps

module peak_detector #(
    parameter integer SAMPLE_RATE = 100
) (
    input  wire        clk,
    input  wire        resetn,
    input  wire        wr_en,
    input  wire        rd_en,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata
);

    localparam [31:0] SAMPLE_ADDR    = 32'h10000300;
    localparam [31:0] THRESHOLD_ADDR = 32'h10000304;
    localparam [31:0] START_ADDR     = 32'h10000308;
    localparam [31:0] PEAK_ADDR      = 32'h1000030C;
    localparam [31:0] RR_ADDR        = 32'h10000310;
    localparam [31:0] BPM_ADDR       = 32'h10000314;

    reg [31:0] sample;
    reg [31:0] threshold;
    reg peak_detected;
    reg first_peak_seen;
    reg above_threshold;
    reg [31:0] sample_counter;
    reg [31:0] rr_interval;
    reg [31:0] heart_rate;

    always @(posedge clk) begin
        if (!resetn) begin
            sample          <= 0;
            threshold       <= 32'd320;
            peak_detected   <= 0;
            first_peak_seen <= 0;
            above_threshold <= 0;
            sample_counter  <= 0;
            rr_interval     <= 0;
            heart_rate      <= 0;
        end else if (wr_en) begin
            case (addr)
                SAMPLE_ADDR: begin
                    sample <= wdata;
                end

                THRESHOLD_ADDR: begin
                    threshold <= wdata;
                end

                START_ADDR: begin
                    if (wdata != 0) begin
                        peak_detected <= 0;

                        // Count processed ECG samples, not FPGA clock cycles.
                        if (first_peak_seen)
                            sample_counter <= sample_counter + 1;

                        // Rising threshold crossing: one event per excursion.
                        if ((sample > threshold) && !above_threshold) begin
                            peak_detected <= 1;

                            if (!first_peak_seen) begin
                                first_peak_seen <= 1;
                                sample_counter <= 0;
                            end else begin
                                rr_interval <= sample_counter + 1;
                                if ((sample_counter + 1) != 0)
                                    heart_rate <= (60 * SAMPLE_RATE) /
                                                  (sample_counter + 1);
                                else
                                    heart_rate <= 0;
                                sample_counter <= 0;
                            end
                        end

                        above_threshold <= (sample > threshold);
                    end
                end

                default: begin
                end
            endcase
        end
    end

    always @(*) begin
        rdata = 32'd0;
        if (rd_en) begin
            case (addr)
                PEAK_ADDR: rdata = {31'd0, peak_detected};
                RR_ADDR:   rdata = rr_interval;
                BPM_ADDR:  rdata = heart_rate;
                default:   rdata = 32'd0;
            endcase
        end
    end

endmodule
