module adaptive_calibration (
    input  logic       clk,
    input  logic       rst_n,
    
    input  logic [3:0] cal_period_in,
    input  logic [3:0] trc_in,

    output logic [1:0] auto_trc_sel_out,
    output logic [3:0] auto_adj_out,
    output logic       cal_done
);

    localparam int THRESH_SHIFT = 1;

    localparam logic [3:0] ADJ_MAX = 4'hF;
    localparam logic [3:0] ADJ_MIN = 4'h0;
    localparam logic [3:0] ADJ_MID = 4'h8;

    localparam logic [1:0] SEL_MAX = 2'd3;
    localparam logic [1:0] SEL_MIN = 2'd0;

    typedef enum logic [2:0] {
        S_IDLE,
        S_MEASURE,
        S_FILTERING,
        S_EVALUATE,
        S_ADJUST_SLOWER,
        S_ADJUST_FASTER,
        S_DONE
    } state_t;

    state_t state, state_n;

    logic [3:0] adj_work;
    logic [1:0] sel_work;

    logic [3:0] window_cnt;
    logic [3:0] window_target;
    logic       active_trc, active_trc_prev;
    logic [3:0] err_cnt;

    logic [3:0] tap0, tap1, tap2, tap3;
    logic [5:0] filt_sum;
    logic [5:0] filt_avg;
    logic [3:0] baseline;

    assign active_trc    = trc_in[sel_work];
    assign baseline      = cal_period_in >> THRESH_SHIFT;
    assign window_target = (cal_period_in == 4'h0) ? 4'h0 : (cal_period_in - 4'h1);

    assign filt_sum = tap0 + tap1 + tap2 + tap3;
    assign filt_avg = filt_sum >> 2;

    always_comb begin
        state_n = state;

        unique case (state)
            S_IDLE:
                state_n = S_MEASURE;

            S_MEASURE:
                if (window_cnt == window_target)
                    state_n = S_FILTERING;

            S_FILTERING:
                state_n = S_EVALUATE;

            S_EVALUATE:
                if (filt_avg > baseline)
                    state_n = S_ADJUST_SLOWER;
                else if (filt_avg == 6'd0)
                    state_n = S_ADJUST_FASTER;
                else
                    state_n = S_DONE;

            S_ADJUST_SLOWER:
                state_n = S_DONE;

            S_ADJUST_FASTER:
                state_n = S_DONE;

            S_DONE:
                state_n = S_IDLE;

            default:
                state_n = S_IDLE;
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= S_IDLE;

            adj_work         <= ADJ_MIN;
            sel_work         <= SEL_MIN;

            window_cnt       <= 4'h0;
            err_cnt          <= 4'h0;
            active_trc_prev  <= 1'b0;

            tap0             <= 4'h0;
            tap1             <= 4'h0;
            tap2             <= 4'h0;
            tap3             <= 4'h0;

            auto_adj_out     <= 4'h0;
            auto_trc_sel_out <= 2'h0;
            cal_done         <= 1'b0;

        end else begin
            state    <= state_n;
            cal_done <= 1'b0;

            unique case (state)

                S_IDLE: begin
                    window_cnt      <= 4'h0;
                    err_cnt         <= 4'h0;
                    active_trc_prev <= active_trc;
                end

                S_MEASURE: begin
                    active_trc_prev <= active_trc;
                    window_cnt      <= window_cnt + 4'h1;

                    if (active_trc && !active_trc_prev && (err_cnt != 4'hF))
                        err_cnt <= err_cnt + 4'h1;
                end

                S_FILTERING: begin
                    tap0 <= err_cnt;
                    tap1 <= tap0;
                    tap2 <= tap1;
                    tap3 <= tap2;
                end

                S_EVALUATE: begin
                end

                S_ADJUST_SLOWER: begin
                    if (adj_work == ADJ_MAX) begin
                        if (sel_work != SEL_MAX) begin
                            sel_work <= sel_work + 2'd1;
                            adj_work <= ADJ_MID;
                        end
                    end else begin
                        adj_work <= adj_work + 4'h1;
                    end
                end

                S_ADJUST_FASTER: begin
                    if (adj_work == ADJ_MIN) begin
                        if (sel_work != SEL_MIN) begin
                            sel_work <= sel_work - 2'd1;
                            adj_work <= ADJ_MID;
                        end
                    end else begin
                        adj_work <= adj_work - 4'h1;
                    end
                end

                S_DONE: begin
                    auto_adj_out     <= adj_work;
                    auto_trc_sel_out <= sel_work;
                    cal_done         <= 1'b1;
                    window_cnt       <= 4'h0;
                    err_cnt          <= 4'h0;
                end

                default: ;

            endcase
        end
    end

endmodule
