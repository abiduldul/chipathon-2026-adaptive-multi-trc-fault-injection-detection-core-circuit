/* ============================================================
   TESTBENCH - ADAPTIVE DECISION BLOCK
   (failure_estimation + decision_logic)

   Self-checking, directed tests:
     T1  Async reset state
     T2  Nominal condition (no TRC errors) -> no interrupt
     T3  Light attack (TRC0) below masking limit -> masked
     T4  Strong attack (TRC2) above limit -> interrupt + sticky flag
     T5  INT_ACK clears interrupt and re-arms
     T6  auto_adj shrinks the guardband -> same glitch now trips
     T7  INT_EN=0 masks interrupt, glitch flag still logs
     T8  SOFT_RESET clears everything
     T9  Underflow guard: auto_adj > thres_val saturates limit to 0
     T10 Priority encoding sweep (severity values 0/3/7/B/F)

   Run:
     iverilog -g2012 -o sim failure_estimation.sv decision_logic.sv \
              adaptive_decision.sv tb_adaptive_decision.sv
     vvp sim
   ============================================================ */

`timescale 1ns/1ps

module tb_adaptive_decision;

    /* ---------------- DUT signals ---------------- */
    logic       iCLK;
    logic       iRST;
    logic       iSOFT_RST;
    logic [3:0] iTRC_ERRORS;
    logic [3:0] iTHRES_VAL;
    logic [3:0] iAUTO_ADJ;
    logic       iINT_EN;
    logic       iINT_ACK;
    logic       oINTERRUPT;
    logic [3:0] oFAILURE_EST;
    logic       oGLITCH_FLAG;

    integer pass_count = 0;
    integer fail_count = 0;

    /* ---------------- DUT ---------------- */
    adaptive_decision dut (
        .iCLK         (iCLK),
        .iRST         (iRST),
        .iSOFT_RST    (iSOFT_RST),
        .iTRC_ERRORS  (iTRC_ERRORS),
        .iTHRES_VAL   (iTHRES_VAL),
        .iAUTO_ADJ    (iAUTO_ADJ),
        .iINT_EN      (iINT_EN),
        .iINT_ACK     (iINT_ACK),
        .oINTERRUPT   (oINTERRUPT),
        .oFAILURE_EST (oFAILURE_EST),
        .oGLITCH_FLAG (oGLITCH_FLAG)
    );

    /* ---------------- 100 MHz clock ---------------- */
    initial iCLK = 1'b0;
    always #5 iCLK = ~iCLK;

    /* ---------------- helpers ---------------- */
    task automatic check (input string name,
                          input logic  actual,
                          input logic  expected);
        if (actual === expected) begin
            pass_count++;
            $display("  PASS  %-45s = %b", name, actual);
        end else begin
            fail_count++;
            $display("  FAIL  %-45s = %b (expected %b)", name, actual, expected);
        end
    endtask

    task automatic check4 (input string      name,
                           input logic [3:0] actual,
                           input logic [3:0] expected);
        if (actual === expected) begin
            pass_count++;
            $display("  PASS  %-45s = 4'h%h", name, actual);
        end else begin
            fail_count++;
            $display("  FAIL  %-45s = 4'h%h (expected 4'h%h)", name, actual, expected);
        end
    endtask

    /* drive TRC pattern, wait for it to register through
       failure_estimation (1 cycle) + settle                */
    task automatic apply_trc (input logic [3:0] pattern);
        @(negedge iCLK);
        iTRC_ERRORS = pattern;
        @(negedge iCLK);   /* severity now registered in oFAILURE_EST */
        #1;
    endtask

    task automatic pulse_ack ();
        @(negedge iCLK);
        iINT_ACK = 1'b1;
        @(negedge iCLK);
        iINT_ACK = 1'b0;
        #1;
    endtask

    task automatic pulse_soft_rst ();
        @(negedge iCLK);
        iSOFT_RST = 1'b1;
        @(negedge iCLK);
        iSOFT_RST = 1'b0;
        #1;
    endtask

    /* ---------------- stimulus ---------------- */
    initial begin
        $dumpfile("tb_adaptive_decision.vcd");
        $dumpvars(0, tb_adaptive_decision);

        /* defaults */
        iRST        = 1'b0;
        iSOFT_RST   = 1'b0;
        iTRC_ERRORS = 4'b0000;
        iTHRES_VAL  = 4'h8;      /* generous guardband to start */
        iAUTO_ADJ   = 4'h0;
        iINT_EN     = 1'b1;
        iINT_ACK    = 1'b0;

        /* ================= T1: async reset ================= */
        $display("\n[T1] Asynchronous reset state");
        #12;
        check ("oINTERRUPT during reset",   oINTERRUPT,   1'b0);
        check ("oGLITCH_FLAG during reset", oGLITCH_FLAG, 1'b0);
        check4("oFAILURE_EST during reset", oFAILURE_EST, 4'h0);
        @(negedge iCLK);
        iRST = 1'b1;

        /* ================= T2: nominal, no errors ================= */
        $display("\n[T2] Nominal condition, TRC = 4'b0000");
        apply_trc(4'b0000);
        check4("oFAILURE_EST (no attack)",  oFAILURE_EST, 4'h0);
        check ("oINTERRUPT (no attack)",    oINTERRUPT,   1'b0);
        check ("oGLITCH_FLAG (no attack)",  oGLITCH_FLAG, 1'b0);

        /* ================= T3: light attack below limit ================= */
        /* TRC0 -> severity 4'h3, limit = 8 - 0 = 8, 3 <= 8 -> masked */
        $display("\n[T3] Light attack (TRC0, sev=3) vs limit=8 -> masked");
        apply_trc(4'b0001);
        check4("oFAILURE_EST (light attack)", oFAILURE_EST, 4'h3);
        check ("oINTERRUPT (below limit)",    oINTERRUPT,   1'b0);
        check ("oGLITCH_FLAG (below limit)",  oGLITCH_FLAG, 1'b0);
        apply_trc(4'b0000);

        /* ================= T4: strong attack above limit ================= */
        /* TRC2 -> severity 4'hB, limit = 8, B > 8 -> attack */
        $display("\n[T4] Strong attack (TRC2, sev=B) vs limit=8 -> interrupt");
        apply_trc(4'b0100);
        check4("oFAILURE_EST (strong attack)", oFAILURE_EST, 4'hB);
        check ("oINTERRUPT fires",             oINTERRUPT,   1'b1);
        check ("oGLITCH_FLAG latched",         oGLITCH_FLAG, 1'b1);

        /* glitch removed -> outputs must stay latched (sticky) */
        apply_trc(4'b0000);
        @(negedge iCLK); #1;   /* one more cycle after severity clears */
        check ("oINTERRUPT sticky after glitch ends",   oINTERRUPT,   1'b1);
        check ("oGLITCH_FLAG sticky after glitch ends", oGLITCH_FLAG, 1'b1);

        /* ================= T5: INT_ACK clears ================= */
        $display("\n[T5] INT_ACK clears and re-arms");
        pulse_ack();
        check ("oINTERRUPT cleared by ACK",   oINTERRUPT,   1'b0);
        check ("oGLITCH_FLAG cleared by ACK", oGLITCH_FLAG, 1'b0);

        /* ================= T6: adaptive guardband shrink ================= */
        /* severity 7 (TRC1): limit = 8 -> masked; then auto_adj=4 ->
           limit = 4 -> 7 > 4 -> attack detected                       */
        $display("\n[T6] auto_adj shrinks guardband (sev=7, thres=8)");
        apply_trc(4'b0010);
        check4("oFAILURE_EST (medium attack)",     oFAILURE_EST, 4'h7);
        check ("masked while auto_adj=0 (limit=8)", oINTERRUPT,  1'b0);
        @(negedge iCLK);
        iAUTO_ADJ = 4'h4;        /* calibration compensation kicks in */
        #1;
        check ("fires when auto_adj=4 (limit=4)",  oINTERRUPT,   1'b1);
        check ("glitch flag set",                  oGLITCH_FLAG, 1'b1);
        apply_trc(4'b0000);
        iAUTO_ADJ = 4'h0;
        pulse_ack();

        /* ================= T7: INT_EN masking ================= */
        $display("\n[T7] INT_EN=0 masks interrupt, status still logs");
        @(negedge iCLK);
        iINT_EN = 1'b0;
        apply_trc(4'b1000);      /* TRC3 -> severity F, extreme attack */
        check4("oFAILURE_EST (extreme attack)",  oFAILURE_EST, 4'hF);
        check ("oINTERRUPT masked by INT_EN=0",  oINTERRUPT,   1'b0);
        check ("oGLITCH_FLAG still logs attack", oGLITCH_FLAG, 1'b1);
        @(negedge iCLK);
        iINT_EN = 1'b1;
        #1;
        check ("oINTERRUPT appears once re-enabled", oINTERRUPT, 1'b1);

        /* ================= T8: SOFT_RESET ================= */
        $display("\n[T8] SOFT_RESET clears FSM and status");
        apply_trc(4'b0000);      /* remove stimulus first */
        pulse_soft_rst();
        check ("oINTERRUPT after soft reset",   oINTERRUPT,   1'b0);
        check ("oGLITCH_FLAG after soft reset", oGLITCH_FLAG, 1'b0);
        check4("oFAILURE_EST after soft reset", oFAILURE_EST, 4'h0);

        /* ================= T9: underflow saturation ================= */
        /* thres=2, adj=5 -> limit saturates to 0, any severity trips */
        $display("\n[T9] Underflow guard: thres=2, auto_adj=5 -> limit=0");
        @(negedge iCLK);
        iTHRES_VAL = 4'h2;
        iAUTO_ADJ  = 4'h5;
        apply_trc(4'b0001);      /* lightest attack, severity 3 */
        check ("light attack trips at limit=0", oINTERRUPT,   1'b1);
        check ("glitch flag set",               oGLITCH_FLAG, 1'b1);
        apply_trc(4'b0000);
        pulse_ack();
        iTHRES_VAL = 4'hF;       /* max threshold for sweep below */
        iAUTO_ADJ  = 4'h0;

        /* ================= T10: priority encoding sweep ================= */
        $display("\n[T10] Thermometer-code priority encoder sweep");
        apply_trc(4'b0001); check4("TRC0 only        -> 4'h3", oFAILURE_EST, 4'h3);
        apply_trc(4'b0011); check4("TRC1 (+TRC0)     -> 4'h7", oFAILURE_EST, 4'h7);
        apply_trc(4'b0111); check4("TRC2 (+lower)    -> 4'hB", oFAILURE_EST, 4'hB);
        apply_trc(4'b1111); check4("TRC3 (+lower)    -> 4'hF", oFAILURE_EST, 4'hF);
        apply_trc(4'b1000); check4("TRC3 alone       -> 4'hF", oFAILURE_EST, 4'hF);
        /* thres=F, adj=0 -> limit=F: even severity F must not trip (F !> F) */
        check ("severity F vs limit F -> no false interrupt", oINTERRUPT, 1'b0);
        apply_trc(4'b0000);

        /* ================= summary ================= */
        $display("\n============================================");
        $display("  RESULT: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("  ALL TESTS PASSED");
        else                 $display("  *** TEST FAILURES DETECTED ***");
        $display("============================================\n");
        $finish;
    end

    /* watchdog */
    initial begin
        #10000;
        $display("*** TIMEOUT ***");
        $finish;
    end

endmodule