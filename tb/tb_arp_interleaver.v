`timescale 1ns / 1ps

module tb_arp_interleaver;

    localparam ADDR_WIDTH = 11;

    reg                   clk;
    reg                   rst_n;
    reg                   start;
    reg                   enable;
    reg  [ADDR_WIDTH-1:0] N;
    reg  [ADDR_WIDTH-1:0] p;
    reg  [ADDR_WIDTH-1:0] Q0;
    reg  [ADDR_WIDTH-1:0] Q1;
    reg  [ADDR_WIDTH-1:0] Q2;
    reg  [ADDR_WIDTH-1:0] Q3;

    wire [ADDR_WIDTH-1:0] int_addr;
    wire                  swap_bits;
    wire                  valid;
    wire                  done;

    // Instantiate Unit Under Test (UUT)
    arp_interleaver #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) uut (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (start),
        .enable    (enable),
        .N         (N),
        .p         (p),
        .Q0        (Q0),
        .Q1        (Q1),
        .Q2        (Q2),
        .Q3        (Q3),
        .int_addr  (int_addr),
        .swap_bits (swap_bits),
        .valid     (valid),
        .done      (done)
    );

    // 100 MHz Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Stimulus Evaluation
    initial begin
        // Reset and initialization
        rst_n  = 0;
        start  = 0;
        enable = 0;
        N      = 11'd8;
        p      = 11'd3;
        Q0     = 11'd1;
        Q1     = 11'd0;
        Q2     = 11'd2;
        Q3     = 11'd0;

        #20;
        @(negedge clk);
        rst_n = 1; // Release reset

        #10;
        $display("=== Starting ARP Interleaver Test (N=8, P=3, Q0=1, Q1=0, Q2=2, Q3=0) ===");

        // Trigger start pulse for 1 clock cycle
        @(negedge clk);
        start  = 1;
        enable = 1;
        @(negedge clk);
        start  = 0;

        // --------------------------------------------------------------
        // Trace outputs across all cycles (j = 0 .. N-1)
        //   * Sample FIRST, then advance clock -> j=0 is not skipped.
        //   * Loop on 'valid' (not '!done') because 'done' is a
        //     registered pulse that fires one cycle AFTER the last
        //     valid address has been presented.
        // --------------------------------------------------------------
        while (valid) begin
            $display("Time: %0t ps | addr: %0d | swap: %b | done: %b",
                     $time, int_addr, swap_bits, done);
            @(negedge clk);
        end

        // Capture the final cycle (done pulse)
        $display("Time: %0t ps | Final step complete. Interleaver deactivated. Valid: %b | done: %b",
                 $time, valid, done);

        #20;
        $display("=== ARP Interleaver Verification Complete ===");
        $finish;
    end

endmodule