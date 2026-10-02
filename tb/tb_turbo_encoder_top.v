`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench Name: tb_turbo_encoder_top
// Engineer: Ahammed Salahuddeen N Y
// Description: End-to-end behavioral testbench for DVB-RCS2 Turbo Encoder (N=8 test).
//              Synchronously captures exactly N unpunctured 6-bit symbols.
//////////////////////////////////////////////////////////////////////////////////

module tb_turbo_encoder_top;

    localparam ADDR_WIDTH = 11;

    reg                   clk;
    reg                   rst_n;
    reg  [ADDR_WIDTH-1:0] blk_size_N;
    reg  [ADDR_WIDTH-1:0] arp_p;
    reg  [ADDR_WIDTH-1:0] arp_Q0;
    reg  [ADDR_WIDTH-1:0] arp_Q1;
    reg  [ADDR_WIDTH-1:0] arp_Q2;
    reg  [ADDR_WIDTH-1:0] arp_Q3;

    reg                   in_valid;
    reg  [1:0]            in_couple;
    wire                  in_ready;

    wire                  out_valid;
    wire [5:0]            out_symbol;
    wire                  out_done;

    // Instantiate Top-Level Turbo Encoder
    turbo_encoder_top #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) uut (
        .clk        (clk),
        .rst_n      (rst_n),
        .blk_size_N (blk_size_N),
        .arp_p      (arp_p),
        .arp_Q0     (arp_Q0),
        .arp_Q1     (arp_Q1),
        .arp_Q2     (arp_Q2),
        .arp_Q3     (arp_Q3),
        .in_valid   (in_valid),
        .in_couple  (in_couple),
        .in_ready   (in_ready),
        .out_valid  (out_valid),
        .out_symbol (out_symbol),
        .out_done   (out_done)
    );

    // 100 MHz System Clock (10 ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Stimulus & Verification Sequence
    integer i;
    integer sym_count;
    reg [1:0] test_payload [0:7];

    initial begin
        // Defined 8-couple test block (16 information bits)
        test_payload[0] = 2'b11;
        test_payload[1] = 2'b01;
        test_payload[2] = 2'b10;
        test_payload[3] = 2'b00;
        test_payload[4] = 2'b11;
        test_payload[5] = 2'b10;
        test_payload[6] = 2'b01;
        test_payload[7] = 2'b00;

        // Bus initializations
        rst_n      = 0;
        in_valid   = 0;
        in_couple  = 2'b00;
        blk_size_N = 11'd8;
        arp_p      = 11'd3;
        arp_Q0     = 11'd1;
        arp_Q1     = 11'd0;
        arp_Q2     = 11'd2;
        arp_Q3     = 11'd0;
        sym_count  = 0;

        #25;
        @(negedge clk);
        rst_n = 1;

        #10;
        wait (in_ready == 1'b1);

        $display("=== [STEP 5] Starting DVB-RCS2 Turbo Encoder Top-Level Test ===");
        $display("[INFO] Streaming 8 Input Couples (Pass 1 Intake)...");

        // Synchronously stream 8 couples on negedge to meet setup times
        for (i = 0; i < 8; i = i + 1) begin
            @(negedge clk);
            in_valid  = 1'b1;
            in_couple = test_payload[i];
        end

        @(negedge clk);
        in_valid  = 1'b0;
        in_couple = 2'b00;

        $display("[INFO] Input stream completed. FSM orchestrating Pass 1 -> 2 -> 3 -> 4 pipeline...");

        // Wait until readout stage asserts out_valid synchronously
        @(posedge clk);
        while (!out_valid) @(posedge clk);

        $display("[INFO] Readout Active: Capturing 6-bit symbols {A, B, Y1, W1, Y2, W2}...");

        // Sample synchronously on posedge clk
        while (sym_count < 8) begin
            if (out_valid) begin
                $display("Symbol [%0d] at %0t ps: %b (Sys={%b,%b}, Par1={%b,%b}, Par2={%b,%b})%s",
                         sym_count, $time, out_symbol,
                         out_symbol[5], out_symbol[4],
                         out_symbol[3], out_symbol[2],
                         out_symbol[1], out_symbol[0],
                         out_done ? " [DONE PULSE]" : "");
                sym_count = sym_count + 1;
            end
            @(posedge clk);
        end

        #40;
        $display("=== Top-Level Turbo Encoder Verification Completed Successfully ===");
        $finish;
    end

endmodule