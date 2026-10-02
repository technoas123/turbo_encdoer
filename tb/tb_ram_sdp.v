`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Testbench Name: tb_ram_sdp
// Engineer: Ahammed Salahuddeen N Y
// Description: Testbench to verify a Simple Dual-Port RAM with 1-cycle read latency.
//////////////////////////////////////////////////////////////////////////////////

// --- Section 1: Timescale, Module Header, and Parameters ---
module tb_ram_sdp;

    localparam DATA_WIDTH = 2;
    localparam ADDR_WIDTH = 11;

// --- Section 2: Signal Declarations and DUT Instantiation ---
    reg                   clk;
    reg                   we;
    reg  [ADDR_WIDTH-1:0] waddr;
    reg  [DATA_WIDTH-1:0] din;
    reg  [ADDR_WIDTH-1:0] raddr;
    wire [DATA_WIDTH-1:0] dout;

    // Instantiate Unit Under Test (UUT)
    ram_sdp #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) uut (
        .clk   (clk),
        .we    (we),
        .waddr (waddr),
        .din   (din),
        .raddr (raddr),
        .dout  (dout)
    );

// --- Section 3: Clock Generation (100 MHz) ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

// --- Section 4: Stimulus Sequence ---
    initial begin
        // 1. Initialize all buses to zero and wait for 20 ns
        we    = 0;
        waddr = 0;
        din   = 0;
        raddr = 0;
        #20;

        // 2. Phase 1 (Write): Synchronously write four known 2-bit couple patterns
        $display("[INFO] Starting Write Phase...");
        
        @(negedge clk); we = 1; waddr = 11'd0; din = 2'b11; // Addr 0 -> 3
        @(negedge clk); we = 1; waddr = 11'd1; din = 2'b01; // Addr 1 -> 1
        @(negedge clk); we = 1; waddr = 11'd2; din = 2'b10; // Addr 2 -> 2
        @(negedge clk); we = 1; waddr = 11'd3; din = 2'b00; // Addr 3 -> 0
        
        // Disable write operation after finishing writes
        @(negedge clk); we = 0; waddr = 0; din = 0;
        #10;

        // 3. Phase 2 (Read & Latency Observation)
        $display("[INFO] Starting Read Phase (Observing 1-Cycle Latency)...");
        
        // Present Addr 0
        @(negedge clk); raddr = 11'd0;
        @(negedge clk); // Data out updates on the NEXT posedge clk (observed here at negedge)
        $display("Time: %0t ps | Read Addr: 0 | Expected: 2'b11 | Got: 2'b%b", $time, dout);
        
        // Present Addr 1
        @(negedge clk); raddr = 11'd1;
        @(negedge clk); 
        $display("Time: %0t ps | Read Addr: 1 | Expected: 2'b01 | Got: 2'b%b", $time, dout);
        
        // Present Addr 2
        @(negedge clk); raddr = 11'd2;
        @(negedge clk); 
        $display("Time: %0t ps | Read Addr: 2 | Expected: 2'b10 | Got: 2'b%b", $time, dout);
        
        // Present Addr 3
        @(negedge clk); raddr = 11'd3;
        @(negedge clk); 
        $display("Time: %0t ps | Read Addr: 3 | Expected: 2'b00 | Got: 2'b%b", $time, dout);

        // 4. Finish simulation
        #20;
        $display("[INFO] Simulation Complete successfully.");
        $finish;
    end

endmodule
