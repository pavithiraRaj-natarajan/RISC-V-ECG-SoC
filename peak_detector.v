module peak_detector (
    input wire clk,
    input wire resetn,

    input wire        wr_en,
    input wire        rd_en,
    input wire [31:0] addr,
    input wire [31:0] wdata,
    output reg [31:0] rdata
);

reg [31:0] sample;
reg [31:0] threshold;

reg        peak_detected;
reg        first_peak_seen;

reg [31:0] sample_counter;
reg [31:0] rr_interval;
reg [31:0] heart_rate;


// ECG sample rate = 250 Hz
// HR = (60 * 250) / RR
// HR = 15000 / RR

always @(posedge clk) begin

    if (!resetn) begin

        sample          <= 32'd0;
        threshold       <= 32'd100;
        peak_detected   <= 1'b0;

        first_peak_seen <= 1'b0;
        sample_counter  <= 32'd0;
        rr_interval     <= 32'd0;
        heart_rate      <= 32'd0;

    end

    else begin

        // Count elapsed sample periods
        if (first_peak_seen)
            sample_counter <= sample_counter + 1'b1;


        if (wr_en) begin

            case (addr)

                // ECG sample
                32'h10000300:
                    sample <= wdata;

                // Threshold
                32'h10000304:
                    threshold <= wdata;

                // Start peak detection
                32'h10000308: begin

                    if (wdata != 0) begin

                        peak_detected <= (sample > threshold);

                        if (sample > threshold) begin

                            // First peak
                            if (!first_peak_seen) begin

                                first_peak_seen <= 1'b1;
                                sample_counter  <= 32'd0;

                            end

                            // Second/subsequent peak
                            else begin

                                rr_interval    <= sample_counter;

                                // Heart rate = 15000 / RR
                                if (sample_counter != 0)
                                    heart_rate <= 32'd15000 / sample_counter;
                                else
                                    heart_rate <= 32'd0;

                                sample_counter <= 32'd0;

                            end

                        end

                    end

                end

            endcase

        end

    end

end


// Read registers
always @(*) begin

    rdata = 32'd0;

    if (rd_en) begin

        case (addr)

            // Peak result
            32'h1000030C:
                rdata = {31'd0, peak_detected};

            // R-R interval
            32'h10000310:
                rdata = rr_interval;

            // Heart rate
            32'h10000314:
                rdata = heart_rate;

            default:
                rdata = 32'd0;

        endcase

    end

end

endmodule