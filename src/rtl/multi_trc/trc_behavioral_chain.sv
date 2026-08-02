module trc_behavioral_chain #(
    parameter int  NUM_INVERTERS = 192,  // MUST be even. See table in
                                          // Adaptive_Multi_TRC_Spec.pdf
                                          // (192/144/96/48 recommended)
    parameter real DELAY_VAL     = 0.05  // ns, per-stage SIM-ONLY delay
)(
    input  logic iCLK,
    input  logic iRST,   // active-low async reset
    output logic oTRC    // registered error flag
);

    (* keep *) logic launch_q;
    (* keep *) logic capture_q;
    (* keep *) logic [NUM_INVERTERS:0] delay_wire;

    /* ------------------------------------------------------------
       LAUNCH FLIP-FLOP  (trc_data_ref)
    ------------------------------------------------------------ */
    always_ff @(posedge iCLK or negedge iRST) begin
        if (!iRST) launch_q <= 1'b0;
        else       launch_q <= ~launch_q;
    end

    assign delay_wire[0] = launch_q;

    genvar i;
    generate
        for (i = 0; i < NUM_INVERTERS; i = i + 1) begin : gen_inv_stage
`ifdef SYNTHESIS
            gf180mcu_fd_sc_mcu7t5v0__inv_1 u_inv (
                .I  (delay_wire[i]),
                .ZN (delay_wire[i+1])
            );
`else
            assign #(DELAY_VAL) delay_wire[i+1] = ~delay_wire[i];
`endif
        end
    endgenerate

    (* keep *) wire trc_data_actual = delay_wire[NUM_INVERTERS];

    /* ------------------------------------------------------------
       XOR COMPARATOR + CAPTURE FLIP-FLOP
    ------------------------------------------------------------ */
    (* keep *) wire check_error = launch_q ^ trc_data_actual;

    always_ff @(posedge iCLK or negedge iRST) begin
        if (!iRST) capture_q <= 1'b0;
        else       capture_q <= check_error;
    end

    assign oTRC = capture_q;

    // synthesis translate_off
    initial begin
        if (NUM_INVERTERS % 2 != 0)
            $warning("trc_behavioral_chain: NUM_INVERTERS=%0d is odd -> chain inverts polarity, TRC comparison will be wrong. Use an even count.", NUM_INVERTERS);
    end
    // synthesis translate_on

endmodule
