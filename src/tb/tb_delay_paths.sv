module tb_delay_paths;
    logic           iCLK, iRST;
    logic [1:0]     iTRC_SEL;
    logic [2:0]     oTRC_MUX;
    logic [3:0]     oTRC_ERR;

    logic clk_100mhz    = 1'b0;
    logic clk_1ghz      = 1'b0;
    logic inject_glitch = 1'b0;

    always #5.0 clk_100mhz  = ~clk_100mhz;
    always #0.5 clk_1ghz    = ~clk_1ghz;
    
    assign iCLK = inject_glitch ? clk_1ghz : clk_100mhz;


    delay_paths delay_paths (
        .iCLK(iCLK), .iRST(iRST),
        .iTRC_SEL(iTRC_SEL),
        .oTRC_ERR(oTRC_ERR), .oTRC_MUX(oTRC_MUX)
    );


    /* ------------------------------------------------------------
       TASKS
    ------------------------------------------------------------ */
    /* reset */
    task reset_dut();
        begin
            iRST = 1'b0;
            #15;
            iRST = 1'b1;
            repeat(3) @(posedge iCLK);
        end
    endtask


    /* ------------------------------------------------------------
       SIMULATION SCENARIOS
    ------------------------------------------------------------ */
    initial begin
        $dumpfile("sim/tb_delay_paths.vcd");
        $dumpvars(0, tb_delay_paths);

        iTRC_SEL = 2'b00;
        

        /* ------------------------------------------------------------
           SIMULATION TEST CASES
        ------------------------------------------------------------ */
        $display("======= DELAY PATHS SIMULATION =======");


        /* test case 1: nominal clock */
        $display("\n--- Test 1: Nominal Clock (100 MHz) ---");
        reset_dut();
        repeat(20) @(posedge iCLK);
        $display("oTRC_ERR (nominal) = %b", oTRC_ERR);
        if (oTRC_ERR === 4'b0000)   $display("[PASS] Expected no glitch at nominal clock.");
        else                        $display("[FAIL] Expected no glitch, but got oTRC_ERR = %b", oTRC_ERR);


        /* test case 2: glitch injection */
        $display("\n--- Test 2: Glitch Injection (1 GHz) ---");
        reset_dut();
        repeat(10) @(posedge iCLK);
        inject_glitch = 1'b1;
        repeat(30) @(posedge iCLK);
        $display("oTRC_ERR (during glitch) = %b", oTRC_ERR);
        if (oTRC_ERR !== 4'b0000)   $display("[PASS] Expected at least one TRC channel to trip.");
        else                        $display("[FAIL] Expected TRC channel to trip, but oTRC_ERR stayed 0000.");
        

        $display("\n======= SIMULATION COMPLETED =======");
        $finish;
    end

endmodule
