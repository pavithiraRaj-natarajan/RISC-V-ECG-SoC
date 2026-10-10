module rom (
    input  wire        clk,
    input  wire [31:0] addr,
    output reg  [31:0] rdata
);

    reg [31:0] memory [0:255];
    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1)
            memory[i] = 32'h00000013; // NOP

        // Peripheral base addresses
        memory[0]  = 32'h100003B7; // lui   x7,0x10000       UART base
        memory[1]  = 32'h00838413; // addi  x8,x7,8          UART RX status
        memory[2]  = 32'h100004B7; // lui   x9,0x10000
        memory[3]  = 32'h20048493; // addi  x9,x9,0x200      FIR base
        memory[4]  = 32'h10000537; // lui   x10,0x10000
        memory[5]  = 32'h30050513; // addi  x10,x10,0x300    Peak detector base

        // Constants
        memory[6]  = 32'h00100293; // addi x5,x0,1
        memory[7]  = 32'h00000313; // addi x6,x0,0 (unused, retained)

        // FIR coefficients = 1
        memory[8]  = 32'h0054A823; // sw x5,16(x9)
        memory[9]  = 32'h0054AA23; // sw x5,20(x9)
        memory[10] = 32'h0054AC23; // sw x5,24(x9)
        memory[11] = 32'h0054AE23; // sw x5,28(x9)

        // Initialize rolling FIR sample window
        memory[12] = 32'h00000593; // addi x11,x0,0
        memory[13] = 32'h00000613; // addi x12,x0,0
        memory[14] = 32'h00000693; // addi x13,x0,0
        memory[15] = 32'h00000713; // addi x14,x0,0

        // Peak threshold = 320
        memory[16] = 32'h14000893; // addi x17,x0,320
        memory[17] = 32'h01152223; // sw x17,4(x10)

        // Sample counter and target count (1000 samples)
        memory[18] = 32'h00000913; // addi x18,x0,0
        memory[19] = 32'h3E800993; // addi x19,x0,1000

        // UART polling loop (PC = 0x50)
        memory[20] = 32'h00042783; // lw x15,0(x8)
        memory[21] = 32'hFE078EE3; // beq x15,x0,memory[20]

        // Read one UART ECG sample
        memory[22] = 32'h0003A803; // lw x16,0(x7)

        // Shift rolling sample window
        memory[23] = 32'h00068713; // addi x14,x13,0
        memory[24] = 32'h00060693; // addi x13,x12,0
        memory[25] = 32'h00058613; // addi x12,x11,0
        memory[26] = 32'h00080593; // addi x11,x16,0

        // Write FIR input samples
        memory[27] = 32'h00B4A023; // sw x11,0(x9)
        memory[28] = 32'h00C4A223; // sw x12,4(x9)
        memory[29] = 32'h00D4A423; // sw x13,8(x9)
        memory[30] = 32'h00E4A623; // sw x14,12(x9)

        // Start FIR and read its result
        memory[31] = 32'h0254A023; // sw x5,32(x9)
        memory[32] = 32'h0244A883; // lw x17,36(x9)

        // Send FIR result to peak detector
        memory[33] = 32'h01152023; // sw x17,0(x10)
        memory[34] = 32'h00552423; // sw x5,8(x10)

        // Count processed samples; continue until 1000 samples
        memory[35] = 32'h00190913; // addi x18,x18,1
        memory[36] = 32'hFD3940E3; // blt x18,x19,PC 0x50 (UART poll)

        // After sample 1000, read BPM and transmit its low byte
        memory[37] = 32'h01452883; // lw x17,20(x10) = BPM register
        memory[38] = 32'h0113A023; // sw x17,0(x7) = UART TX
        memory[39] = 32'h0000006F; // jal x0,0 (halt in a self-loop)
    end

    always @(*) begin
        rdata = memory[addr[9:2]];
    end

endmodule
