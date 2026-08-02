module tb_adaptive_calibration;
    localparam int ST_IDLE          = 0;
    localparam int ST_MEASURE       = 1;
    localparam int ST_FILTERING     = 2;
    localparam int ST_EVALUATE      = 3;
    localparam int ST_ADJUST_SLOWER = 4;
    localparam int ST_ADJUST_FASTER = 5;
    localparam int ST_DONE          = 6;

    logic       iCLK, iRST;
    logic [3:0] cal_period_in;
    logic [3:0] trc_in;

    logic       cal_done, cal_done_prev;
    logic [1:0] auto_trc_sel_out;
    logic [3:0] auto_adj_out;

    int errors = 0;
    int checks = 0;

    initial iCLK = 1'b0;
    always #5 iCLK = ~iCLK;

    adaptive_calibration adaptive_calibration (
        .iCLK (iCLK), .iRST (iRST),
        .iCAL_PERIOD (cal_period_in), .iTRC (trc_in),
        .oDONE (cal_done),
        .oAUTO_TRC_SEL (auto_trc_sel_out), .oAUTO_ADJ (auto_adj_out)
    );


    always @(posedge iCLK) begin
        if (!iRST) begin
            cal_done_prev <= 1'b0;
        end else begin
            if (cal_done_prev && cal_done) begin
                $error("[%0t] cal_done stayed high for >1 cycle", $time);
                errors++;
            end
            cal_done_prev <= cal_done;
        end
    end

    logic [3:0] shadow_adj = 4'h0;
    logic [1:0] shadow_sel = 2'h0;
    logic [3:0] shadow_tap0 = 0, shadow_tap1 = 0, shadow_tap2 = 0, shadow_tap3 = 0;


    /* ------------------------------------------------------------
       TASKS
    ------------------------------------------------------------ */
    /* apply reset task */
    task automatic apply_reset();
        iRST         = 1'b0;
        trc_in        = 4'h0;
        cal_period_in = 4'h0;
        repeat (4) @(posedge iCLK);
        iRST = 1'b1;
        @(posedge iCLK);
    endtask

    /* shadow model of the DUT's prediction logic, used to verify the DUT's outputs */
    task automatic shadow_predict(
        input  int unsigned num_edges,
        input  logic [3:0]  period,
        output logic [3:0]  pred_adj,
        output logic [1:0]  pred_sel
    );
        logic [3:0] err_cnt;
        logic [5:0] filt_sum, filt_avg;
        logic [3:0] baseline;
        begin
            err_cnt = (num_edges > 15) ? 4'hF : num_edges[3:0];

            shadow_tap3 = shadow_tap2;
            shadow_tap2 = shadow_tap1;
            shadow_tap1 = shadow_tap0;
            shadow_tap0 = err_cnt;

            filt_sum = 6'(shadow_tap0) + 6'(shadow_tap1) + 6'(shadow_tap2) + 6'(shadow_tap3);
            filt_avg = filt_sum >> 2;
            baseline = period >> 1;

            if (filt_avg > 6'(baseline)) begin
                if (shadow_adj == 4'hF) begin
                    if (shadow_sel != 2'd3) begin
                        shadow_sel = shadow_sel + 2'd1;
                        shadow_adj = 4'h8;
                    end
                end else begin
                    shadow_adj = shadow_adj + 4'h1;
                end
            end else if (filt_avg == 6'd0) begin
                if (shadow_adj == 4'h0) begin
                    if (shadow_sel != 2'd0) begin
                        shadow_sel = shadow_sel - 2'd1;
                        shadow_adj = 4'h8;
                    end
                end else begin
                    shadow_adj = shadow_adj - 4'h1;
                end
            end

            pred_adj = shadow_adj;
            pred_sel = shadow_sel;
        end
    endtask

    /* wait for DUT to reach a specific state */
    task automatic wait_for_dut_state(input int st);
        while (adaptive_calibration.state !== st[2:0]) @(negedge iCLK);
    endtask

    /* wait for DUT to assert cal_done */
    task automatic wait_for_cal_done();
        while (!cal_done) @(negedge iCLK);
    endtask

    /* drives error pulses on trc_in for one measurement window */
    task automatic drive_one_window(
        input int unsigned num_edges,
        input logic [3:0]  period,
        input logic [1:0]  sel
    );
        int edges_left;
        int max_edges;
        begin
            max_edges = (int'(period) + 1) / 2;
            if (num_edges > max_edges) begin
                $error("TB ERROR: requested %0d edges > max achievable %0d for period %0d",
                        num_edges, max_edges, period);
                errors++;
            end

            wait_for_dut_state(ST_IDLE);
            trc_in[sel] = 1'b0;

            wait_for_dut_state(ST_MEASURE);
            edges_left = num_edges;

            for (int i = 0; i < period; i++) begin
                if (edges_left > 0 && (i % 2 == 0)) begin
                    trc_in[sel] = 1'b1;
                    edges_left--;
                end else  trc_in[sel] = 1'b0;
                @(negedge iCLK);
            end
            trc_in[sel] = 1'b0;
        end
    endtask

    /* executes a complete calibration cycle and verifies outputs against the shadow model */
    task automatic run_window(input int unsigned num_edges, input logic [3:0] period);
        logic [3:0] pred_adj;
        logic [1:0] pred_sel;
        logic [1:0] sel_before;
        begin
            cal_period_in = period;
            sel_before    = shadow_sel;

            drive_one_window(num_edges, period, sel_before);
            shadow_predict(num_edges, period, pred_adj, pred_sel);

            wait_for_cal_done();
            checks++;

            if (!cal_done) begin
                $error("[%0t] Expected cal_done asserted in S_DONE", $time);
                errors++;
            end
            if (auto_adj_out !== pred_adj) begin
                $error("[%0t] auto_adj_out mismatch: got %0h expected %0h (edges=%0d period=%0d)",
                        $time, auto_adj_out, pred_adj, num_edges, period);
                errors++;
            end
            if (auto_trc_sel_out !== pred_sel) begin
                $error("[%0t] auto_trc_sel_out mismatch: got %0d expected %0d (edges=%0d period=%0d)",
                        $time, auto_trc_sel_out, pred_sel, num_edges, period);
                errors++;
            end
        end
    endtask


    /* ------------------------------------------------------------
       SIMULATION SCENARIOS
    ------------------------------------------------------------ */
    initial begin
        $dumpfile("sim/tb_adaptive_calibration.vcd");
        $dumpvars(0, tb_adaptive_calibration);
        apply_reset();

        /* ------------------------------------------------------------
           SIMULATION TEST PHASES
        ------------------------------------------------------------ */
        $display("======= ADAPTIVE CALIBRATION SIMULATION =======");

        /* phase A: reset flush complete */
        wait_for_cal_done();
        $display("PHASE A: reset flush complete");

        /* phase B: nominal, floor-hold (period=9, edges=0) */
        $display("PHASE B: nominal, floor-hold (period=9, edges=0)");
        repeat (5) run_window(0, 4'd9);

        /* phase C: sustained thermal slowdown (period=9, edges=5) */
        $display("PHASE C: sustained thermal slowdown (period=9, edges=5)");
        repeat (60) run_window(5, 4'd9);

        /* phase D: even-period ceiling corner case (period=8, edges=4) */
        $display("PHASE D: even-period ceiling corner case (period=8, edges=4)");
        repeat (10) run_window(4, 4'd8);

        /* phase E: sustained nominal / ramp-down (period=9, edges=0) */
        $display("PHASE E: sustained nominal / ramp-down (period=9, edges=0)");
        repeat (60) run_window(0, 4'd9);

        /* phase F: minimum window boundary (period=1) */
        $display("PHASE F: minimum window boundary (period=1)");
        repeat (4) run_window(1, 4'd1);
        repeat (4) run_window(0, 4'd1);

        $display("--------------------------------------------------");
        if (errors == 0) $display("TESTBENCH PASSED: %0d checks, 0 errors", checks);
        else             $display("TESTBENCH FAILED: %0d checks, %0d errors", checks, errors);
        $display("--------------------------------------------------");

        $finish;
    end

    initial begin
        #500000;
        $display("TIMEOUT: simulation did not finish in time");
        $finish;
    end

endmodule
