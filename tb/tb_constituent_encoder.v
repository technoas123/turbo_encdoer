`timescale 1ns / 1ps

module tb_constituent_encoder;

    // ==========================================
    // 2. Declare Testbench Signals
    // ==========================================
    reg clk;
    reg rst_n;
    reg load_init;
    reg enable;
    reg a;
    reg b;
    reg [3:0] init_state;

    wire y;
    wire w;
    wire [3:0] state_out;

    // ==========================================
    // 3. Instantiate the Module Under Test (DUT)
    // ==========================================
    constituent_encoder uut (
        .clk(clk),
        .rst_n(rst_n),
        .load_init(load_init),
        .enable(enable),
        .a(a),
        .b(b),
        .init_state(init_state),
        .y(y),
        .w(w),
        .state_out(state_out)
    );

    // ==========================================
    // 4. Clock Generation (100 MHz / 10 ns Period)
    // ==========================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ==========================================
    // 5. Stimulus Sequence
    // ==========================================
    initial begin
        // --- Scenario 1: Reset Check ---
        $display("[TB] --- Starting Scenario 1: Reset Check ---");
        rst_n      = 0;
        load_init  = 0;
        enable     = 0;
        a          = 0;
        b          = 0;
        init_state = 4'd0;
        
        #20; // Hold reset for 2 clock cycles
        rst_n = 1;
        #5;  // Align stimulus changes slightly off the active edge for safety
        
        // --- Scenario 2: Circular State Load Check ---
        $display("[TB] --- Starting Scenario 2: Circular State Load ---");
        load_init  = 1;
        init_state = 4'd5;
        #10; // Wait 1 full clock cycle
        
        load_init  = 0;
        #1;  // Small delta to let state settle in simulation
        $display("Time=%0t | Load Check | Expected State=5 | Actual State=%d", $time, state_out);
        
        // --- Scenario 3: Trellis Step Check ---
        $display("[TB] --- Starting Scenario 3: Trellis Step Check ---");
        // Reset back to State 0 as requested
        rst_n = 0; 
        #10; 
        rst_n = 1;
        enable = 1;
        
        // Step 3a: Feed Couple A=1, B=0
        a = 1; b = 0;
        #10; // Run for 1 clock cycle
        $display("Time=%0t | Step 1 (A=1, B=0) | Expected State=8 | State=%d | Y=%b W=%b", 
                 $time, state_out, y, w);
        
        // Step 3b: Feed Couple A=0, B=1
        a = 0; b = 1;
        #10; // Run for 1 clock cycle
        $display("Time=%0t | Step 2 (A=0, B=1) | State=%d | Y=%b W=%b", 
                 $time, state_out, y, w);
        
        // End simulation
        $display("[TB] --- Simulation Finished ---");
        $finish;
    end

endmodule
