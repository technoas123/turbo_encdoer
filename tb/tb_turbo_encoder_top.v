`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench Name: tb_turbo_encoder_top
// Engineer: Ahammed Salahuddeen N Y
// Description: Automated cross-verification testbench for the DVB-RCS2 Turbo Encoder.
//              Compares FPGA outputs against Octave reference vectors, with:
//                (1) internal FSM probes for C1 / C2 (bugs #1 and #2 detection)
//                (2) watchdog timeout (bug #3: PASS4 deadlock detection)
//                (3) per-field match summary (sys / Y1W1 / Y2W2 split)
//////////////////////////////////////////////////////////////////////////////////

module tb_turbo_encoder_top;

    localparam ADDR_WIDTH  = 11;
    localparam N_COUPLES   = 48;
    localparam N_BITS      = 96;
    localparam TIMEOUT_CYC = 5000;

    // FSM state codes (kept in sync with turbo_encoder_top)
    localparam S_PASS1_TAIL  = 4'd2;
    localparam S_PASS3_TAIL  = 4'd6;
    localparam S_PASS3_TAIL2 = 4'd11;    // exists ONLY in corrected RTL

    // Reference values taken from Octave (info.lastState1 / info.lastState2)
    localparam EXPECTED_LAST_STATE1 = 4'd15;   // -> C1 = table[r=3][15] = 7
    localparam EXPECTED_C1          = 4'd7;
    localparam EXPECTED_LAST_STATE2 = 4'd11;   // -> C2 = table[r=3][11] = 5
    localparam EXPECTED_C2          = 4'd5;

    // ---------------- DUT ports ----------------
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

    // 100 MHz system clock (10 ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // =================================================================
    //  INTERNAL FSM PROBES
    // =================================================================
    reg [3:0] probed_c1;
    reg [3:0] probed_c2;
    reg       bug1_flag;
    reg       bug2_flag;
    reg       tail2_seen;

    initial begin
        probed_c1  = 4'hx;
        probed_c2  = 4'hx;
        bug1_flag  = 1'b0;
        bug2_flag  = 1'b0;
        tail2_seen = 1'b0;
    end

    always @(posedge clk) begin
        if (uut.state_reg == S_PASS1_TAIL) begin
            probed_c1 <= uut.rom_circ_state;
            if (uut.rom_circ_state !== EXPECTED_C1) begin
                $display("[DBG] %0t  PASS1_TAIL : lastState1=%0d (expect %0d) -> C1=%0d (expect %0d)   <-- BUG #1",
                         $time, uut.ce_state_out, EXPECTED_LAST_STATE1,
                         uut.rom_circ_state, EXPECTED_C1);
                bug1_flag <= 1'b1;
            end else begin
                $display("[DBG] %0t  PASS1_TAIL : lastState1=%0d -> C1=%0d   OK",
                         $time, uut.ce_state_out, uut.rom_circ_state);
            end
        end

        if (uut.state_reg == S_PASS3_TAIL2) begin
            tail2_seen <= 1'b1;
            probed_c2  <= uut.rom_circ_state;
            if (uut.rom_circ_state !== EXPECTED_C2) begin
                $display("[DBG] %0t  PASS3_TAIL2: lastState2=%0d (expect %0d) -> C2=%0d (expect %0d)   <-- BUG #2",
                         $time, uut.ce_state_out, EXPECTED_LAST_STATE2,
                         uut.rom_circ_state, EXPECTED_C2);
                bug2_flag <= 1'b1;
            end else begin
                $display("[DBG] %0t  PASS3_TAIL2: lastState2=%0d -> C2=%0d   OK",
                         $time, uut.ce_state_out, uut.rom_circ_state);
            end
        end

        // If you ever see this firing, it means PASS3_TAIL is still sampling
        // rom_circ_state before the CE finishes the 48th interleaved couple.
        if (uut.state_reg == S_PASS3_TAIL) begin
            $display("[DBG] %0t  PASS3_TAIL  : ce_state_out=%0d (still S47; PASS3_TAIL2 missing in RTL)",
                     $time, uut.ce_state_out);
        end
    end

    // =================================================================
    //  WATCHDOG
    // =================================================================
    integer wd_cycles;
    initial wd_cycles = 0;

    always @(posedge clk) begin
        if (rst_n)
            wd_cycles <= wd_cycles + 1;

        if (wd_cycles > TIMEOUT_CYC) begin
            $display("\n[FATAL] WATCHDOG TIMEOUT after %0d cycles.", TIMEOUT_CYC);
            $display("[FATAL] FSM state = %0d, count = %0d, pipe_valid = %b",
                     uut.state_reg, uut.count, uut.pipe_valid);

            if (uut.state_reg == 4'd7)
                $display("[FATAL] Detected: stuck in PASS4. Check PASS4 exit condition: it must be (`count == blk_size_N - 1`), not (`count == blk_size_N`)  <-- BUG #3.");

            if (!tail2_seen)
                $display("[FATAL] Detected: PASS3_TAIL2 was never reached. C2 is sampled one CE state too early. Add PASS3_TAIL2  <-- BUG #2.");

            if (bug1_flag)
                $display("[FATAL] Detected: C1 is wrong. IDLE is not encoding couple 0 during the dry run  <-- BUG #1.");

            $display("");
            $finish;
        end
    end

    // =================================================================
    //  REFERENCE / CAPTURE STORAGE
    // =================================================================
    reg [0:0] raw_input_bits       [0:191];   // 96 bits for N=48
    reg [7:0] expected_hex_symbols [0:95];    // 48 hex symbols
    reg [5:0] captured_symbols     [0:95];

    integer i;
    integer sym_count;
    integer match_count;
    integer error_count;
    integer sys_match;
    integer par1_match;
    integer par2_match;

    // =================================================================
    //  MAIN FLOW
    // =================================================================
    initial begin
        // --- 1. Configuration (must match Octave reference) ---
        blk_size_N = N_COUPLES;
        arp_p      = 13;
        arp_Q0     = 0;
        arp_Q1     = 2;
        arp_Q2     = 4;
        arp_Q3     = 6;

        rst_n     = 0;
        in_valid  = 0;
        in_couple = 2'b00;
        sym_count = 0;

        // --- 2. Load Octave reference files ---
        $readmemb("tb_input_bits.txt",       raw_input_bits);
        $readmemh("tb_expected_symbols.txt", expected_hex_symbols);

        #25;
        @(negedge clk);
        rst_n = 1;

        #10;
        wait (in_ready == 1'b1);

        $display("");
        $display("=== [STEP 5] DVB-RCS2 Turbo Encoder (Octave vs FPGA Cross-Verification) ===");
        $display("[INFO] Config  : N=%0d, P=%0d, Q0=%0d, Q1=%0d, Q2=%0d, Q3=%0d",
                 N_COUPLES, 13, 0, 2, 4, 6);
        $display("[INFO] Expected: C1=%0d (lastState1=%0d), C2=%0d (lastState2=%0d)",
                 EXPECTED_C1, EXPECTED_LAST_STATE1, EXPECTED_C2, EXPECTED_LAST_STATE2);
        $display("[INFO] Streaming %0d input couples (%0d bits) into Pass 1...",
                 N_COUPLES, N_BITS);
        $display("");

        // --- 3. Stream 48 couples on negedge ---
        for (i = 0; i < N_COUPLES; i = i + 1) begin
            @(negedge clk);
            in_valid  = 1'b1;
            in_couple = {raw_input_bits[2*i], raw_input_bits[2*i+1]};
        end

        @(negedge clk);
        in_valid  = 1'b0;
        in_couple = 2'b00;

        $display("[INFO] Input stream done. FSM running Pass1->2->3->4->Readout...");
        $display("");

        // --- 4. Wait for readout ---
        @(posedge clk);
        while (!out_valid) @(posedge clk);

        $display("[INFO] Readout active: capturing 6-bit symbols {A,B,Y1,W1,Y2,W2}...");
        $display("");

        while (sym_count < N_COUPLES) begin
            if (out_valid) begin
                captured_symbols[sym_count] = out_symbol;
                sym_count = sym_count + 1;
            end
            @(posedge clk);
        end

        // --- 5. Compare and report ---
        match_count = 0;
        error_count = 0;
        sys_match   = 0;
        par1_match  = 0;
        par2_match  = 0;

        $display("=================== VERIFICATION RESULTS (Octave vs Vivado) ===================");
        $display("Idx |  FPGA  = {A,B,Y1,W1,Y2,W2} |  Octave = {A,B,Y1,W1,Y2,W2} | Status");
        $display("----+----------------------------+-----------------------------+-------");

        for (i = 0; i < N_COUPLES; i = i + 1) begin
            if (captured_symbols[i][5:4] === expected_hex_symbols[i][5:4])
                sys_match  = sys_match  + 1;
            if (captured_symbols[i][3:2] === expected_hex_symbols[i][3:2])
                par1_match = par1_match + 1;
            if (captured_symbols[i][1:0] === expected_hex_symbols[i][1:0])
                par2_match = par2_match + 1;

            if (captured_symbols[i] === expected_hex_symbols[i][5:0]) begin
                $display("%3d | 6'b%b  (%02X)            | 6'b%b  (%02X)             | PASS",
                         i, captured_symbols[i], captured_symbols[i],
                            expected_hex_symbols[i][5:0], expected_hex_symbols[i][5:0]);
                match_count = match_count + 1;
            end else begin
                $display("%3d | 6'b%b  (%02X)            | 6'b%b  (%02X)             | FAIL",
                         i, captured_symbols[i], captured_symbols[i],
                            expected_hex_symbols[i][5:0], expected_hex_symbols[i][5:0]);
                error_count = error_count + 1;
            end
        end

        $display("-------------------------------------------------------------------------------");
        $display("SUMMARY");
        $display("  Full-symbol matches : %0d / %0d", match_count, N_COUPLES);
        $display("  Mismatches          : %0d",        error_count);
        $display("  Field-level matches :");
        $display("    sys  (A , B)      : %0d / %0d", sys_match,  N_COUPLES);
        $display("    par1 (Y1, W1)     : %0d / %0d    [Pass 2, RSC1]", par1_match, N_COUPLES);
        $display("    par2 (Y2, W2)     : %0d / %0d    [Pass 4, RSC2 + ARP]", par2_match, N_COUPLES);
        $display("  Probed C1 = %0d (expect %0d),  C2 = %0d (expect %0d)",
                 probed_c1, EXPECTED_C1, probed_c2, EXPECTED_C2);
        $display("-------------------------------------------------------------------------------");

        if (error_count == 0) begin
            $display("");
            $display("  SUCCESS: VERILOG RTL MATCHES OCTAVE REFERENCE 100%%!");
            $display("");
        end else begin
            $display("");
            $display("  FAILURE: %0d symbol mismatches.", error_count);
            $display("  Diagnosis:");

            if (sys_match < N_COUPLES && par1_match < N_COUPLES && par2_match < N_COUPLES)
                $display("   -> ALL fields wrong: input path / RAM / reset problem.");
            else if (par1_match < N_COUPLES && par2_match < N_COUPLES)
                $display("   -> BOTH parity streams wrong: check C1 and C2 (see [DBG] lines above).");
            else if (par1_match < N_COUPLES)
                $display("   -> Y1/W1 wrong: check Pass 1 dry-run and C1 load (BUG #1).");
            else if (par2_match < N_COUPLES)
                $display("   -> Y2/W2 wrong: check Pass 3 tail / C2 load / ARP swap timing (BUG #2).");

            if (bug1_flag)
                $display("   -> CONFIRMED BUG #1: IDLE did not encode couple 0 -> C1 wrong.");
            if (!tail2_seen)
                $display("   -> CONFIRMED BUG #2: PASS3_TAIL2 absent -> C2 sampled one state early.");
            $display("");
        end

        #40;
        $finish;
    end

endmodule