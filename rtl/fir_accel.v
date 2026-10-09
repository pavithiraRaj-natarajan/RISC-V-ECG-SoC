module fir_accel (
    input  wire        clk,
    input  wire        resetn,

    input  wire        wr_en,
    input  wire        rd_en,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,

    output reg  [31:0] rdata
);

    reg signed [15:0] x0;
    reg signed [15:0] x1;
    reg signed [15:0] x2;
    reg signed [15:0] x3;

    reg signed [15:0] h0;
    reg signed [15:0] h1;
    reg signed [15:0] h2;
    reg signed [15:0] h3;

    reg signed [31:0] result;


    // ============================================================
    // FIR REGISTERS / CALCULATION
    // ============================================================

    always @(posedge clk) begin

        if (!resetn) begin

            x0     <= 16'sd0;
            x1     <= 16'sd0;
            x2     <= 16'sd0;
            x3     <= 16'sd0;

            h0     <= 16'sd0;
            h1     <= 16'sd0;
            h2     <= 16'sd0;
            h3     <= 16'sd0;

            result <= 32'sd0;

        end
        else begin

            if (wr_en) begin

                case (addr)

                    // Samples
                    32'h10000200:
                        x0 <= wdata[15:0];

                    32'h10000204:
                        x1 <= wdata[15:0];

                    32'h10000208:
                        x2 <= wdata[15:0];

                    32'h1000020C:
                        x3 <= wdata[15:0];


                    // Coefficients
                    32'h10000210:
                        h0 <= wdata[15:0];

                    32'h10000214:
                        h1 <= wdata[15:0];

                    32'h10000218:
                        h2 <= wdata[15:0];

                    32'h1000021C:
                        h3 <= wdata[15:0];


                    // Start FIR calculation
                    32'h10000220: begin

                        result <=
                            x0 * h0 +
                            x1 * h1 +
                            x2 * h2 +
                            x3 * h3;

                    end

                endcase

            end

        end

    end


    // ============================================================
    // COMBINATIONAL READ DATA
    // ============================================================

    always @(*) begin

        rdata = 32'h00000000;

        if (rd_en) begin

            case (addr)

                32'h10000224:
                    rdata = result;

                default:
                    rdata = 32'h00000000;

            endcase

        end

    end

endmodule
