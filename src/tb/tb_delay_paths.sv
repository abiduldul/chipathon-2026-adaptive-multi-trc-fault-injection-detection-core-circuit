`timescale 1ns / 1ps

module tb_delay_paths;

    // ------------------------------------------------------------
    // Signal Declarations
    // ------------------------------------------------------------
    logic       iCLK;
    logic       iRST;
    logic [1:0] iTRC_SEL;
    logic [3:0] oTRC_ERR;
    logic [2:0] oTRC_MUX;

    // Variable to dynamically change clock speed during simulation
    real half_period;

    // ------------------------------------------------------------
    // DUT (Device Under Test) Instantiation
    // ------------------------------------------------------------
    delay_paths dut (
        .iCLK(iCLK),
        .iRST(iRST),
        .iTRC_SEL(iTRC_SEL),
        .oTRC_ERR(oTRC_ERR),
        .oTRC_MUX(oTRC_MUX)
    );

    // ------------------------------------------------------------
    // Dynamic Clock Generator
    // ------------------------------------------------------------
    initial iCLK = 1'b0;
    always begin
        // Using half_period variable so the frequency can be altered
        #half_period iCLK = ~iCLK;
    end

    // ------------------------------------------------------------
    // Task: Reset DUT (Equivalent to reset_dut in Python)
    // ------------------------------------------------------------
    task reset_dut();
        begin
            iRST = 1'b0;
            #15; // Wait 15ns (equivalent to await Timer(15, unit="ns"))
            iRST = 1'b1;
            repeat(3) @(posedge iCLK); // Wait 3 clock cycles
        end
    endtask

    // ------------------------------------------------------------
    // Simulation Scenarios
    // ------------------------------------------------------------
    initial begin
        $dumpfile("sim_delay_paths.vcd");
        $dumpvars(0, tb_delay_paths);

        // Initial values
        iTRC_SEL = 2'b00;
        
        /* ==========================================
           Test 1: Nominal Clock (no glitch)
           ========================================== */
        $display("\n--- Test 1: Nominal Clock (100 MHz) ---");
        half_period = 5.0; // 10ns period -> 100 MHz
        
        reset_dut();
        
        repeat(20) @(posedge iCLK);
        
        $display("oTRC_ERR (nominal) = %b", oTRC_ERR);
        if (oTRC_ERR === 4'b0000) begin
            $display("[PASS] Expected no glitch at nominal clock.");
        end else begin
            $display("[FAIL] Expected no glitch, but got oTRC_ERR = %b", oTRC_ERR);
        end

        /* ==========================================
           Test 2: Glitch Injection (overclocking)
           ========================================== */
        $display("\n--- Test 2: Glitch Injection (1 GHz) ---");
        half_period = 5.0; // Return to normal before resetting
        
        reset_dut();
        
        repeat(10) @(posedge iCLK);
        
        // Drastically change clock speed (glitch injection)
        half_period = 0.5; // 1ns period -> 1 GHz
        
        repeat(30) @(posedge iCLK);
        
        $display("oTRC_ERR (during glitch) = %b", oTRC_ERR);
        if (oTRC_ERR !== 4'b0000) begin
            $display("[PASS] Expected at least one TRC channel to trip.");
        end else begin
            $display("[FAIL] Expected TRC channel to trip, but oTRC_ERR stayed 0000.");
        end
        
        $display("\n======= SIMULATION COMPLETED =======");
        $finish;
    end

endmodule
