`timescale 1ns/1ps

module tb_adaptive_calibration;

    localparam int ST_IDLE          = 0;
    localparam int ST_MEASURE       = 1;
    localparam int ST_FILTERING     = 2;
    localparam int ST_EVALUATE      = 3;
    localparam int ST_ADJUST_SLOWER = 4;
    localparam int ST_ADJUST_FASTER = 5;
    localparam int ST_DONE          = 6;

    logic       clk;
    logic       rst_n;
    logic [3:0] cal_period_in;
    logic [3:0] trc_in;

    logic [1:0] auto_trc_sel_out;
    logic [3:0] auto_adj_out;
    logic       cal_done;

    int errors = 0;
    int checks = 0;

    adaptive_calibration dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .cal_period_in    (cal_period_in),
        .trc_in           (trc_in),
        .auto_trc_sel_out (auto_trc_sel_out),
        .auto_adj_out     (auto_adj_out),
        .cal_done         (cal_done)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task automatic apply_reset();
        rst_n         = 1'b0;
        trc_in        = 4'h0;
        cal_period_in = 4'h0;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
    endtask

    logic cal_done_prev;
    always @(posedge clk) begin
        if (!rst_n) begin
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

            filt_sum = shadow_tap0 + shadow_tap1 + shadow_tap2 + shadow_tap3;
            filt_avg = filt_sum >> 2;
            baseline = period >> 1;

            if (filt_avg > baseline) begin
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

    task automatic wait_for_dut_state(input int st);
        while (dut.state !== st) @(negedge clk);
    endtask

    task automatic wait_for_cal_done();
        while (!cal_done) @(negedge clk);
    endtask

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
                end else begin
                    trc_in[sel] = 1'b0;
                end
                @(negedge clk);
            end
            trc_in[sel] = 1'b0;
        end
    endtask

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

    initial begin
        apply_reset();

        // PHASE A: flush the one spurious calibration loop that runs
        // immediately out of reset with cal_period_in/trc_in still at
        // their default (0) values. It resolves to (adj=0, sel=0), which
        // matches the shadow model's initial state, so nothing to check --
        // just get past it before starting the real sequence.
        wait_for_cal_done();
        $display("PHASE A: reset flush complete");

        // PHASE B: nominal / already-at-floor holding behavior
        $display("PHASE B: nominal, floor-hold (period=9, edges=0)");
        repeat (5) run_window(0, 4'd9);

        // PHASE C: sustained high error activity, odd period (9) so the
        // achievable max (5) exceeds the derived baseline (4) -- this
        // should ramp up auto_adj_out, saturate, switch channels, and
        // eventually hold at (adj=F, sel=3).
        $display("PHASE C: sustained thermal slowdown (period=9, edges=5)");
        repeat (60) run_window(5, 4'd9);

        // PHASE D: even-period corner case. Max achievable edges (4) for
        // period=8 exactly equals baseline (4), so this should NEVER
        // trigger ADJUST_SLOWER -- auto_adj_out/auto_trc_sel_out should
        // hold constant for the whole phase (verifying the observation
        // in the file header).
        $display("PHASE D: even-period ceiling corner case (period=8, edges=4)");
        repeat (10) run_window(4, 4'd8);

        // PHASE E: sustained zero error activity, ramps back down,
        // saturates at the floor, switches channels downward, and
        // eventually holds at (adj=0, sel=0).
        $display("PHASE E: sustained nominal / ramp-down (period=9, edges=0)");
        repeat (60) run_window(0, 4'd9);

        // PHASE F: minimum window boundary (cal_period_in=1 -> baseline=0).
        // With baseline=0 there is no HOLD band: every window is either
        // avg=0 (ADJUST_FASTER) or avg>0 (ADJUST_SLOWER).
        $display("PHASE F: minimum window boundary (period=1)");
        repeat (4) run_window(1, 4'd1);
        repeat (4) run_window(0, 4'd1);

        $display("--------------------------------------------------");
        if (errors == 0)
            $display("TESTBENCH PASSED: %0d checks, 0 errors", checks);
        else
            $display("TESTBENCH FAILED: %0d checks, %0d errors", checks, errors);
        $display("--------------------------------------------------");

        $finish;
    end

    initial begin
        #500000;
        $display("TIMEOUT: simulation did not finish in time");
        $finish;
    end

endmodule
