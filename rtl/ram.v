module ram (
    input  wire        clk,
    input  wire        we,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire [3:0]  wstrb,
    output reg  [31:0] rdata
);

    reg [31:0] memory [0:255];

    always @(posedge clk) begin

        if (we) begin
            if (wstrb[0])
                memory[addr[9:2]][7:0]   <= wdata[7:0];

            if (wstrb[1])
                memory[addr[9:2]][15:8]  <= wdata[15:8];

            if (wstrb[2])
                memory[addr[9:2]][23:16] <= wdata[23:16];

            if (wstrb[3])
                memory[addr[9:2]][31:24] <= wdata[31:24];
        end

        rdata <= memory[addr[9:2]];

    end

endmodule
