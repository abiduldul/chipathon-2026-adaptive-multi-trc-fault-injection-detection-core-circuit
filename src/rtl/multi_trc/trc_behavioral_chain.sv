module trc_behavioral_chain #(
    parameter int  NUM_INVERTERS = 192,
    parameter real DELAY_VAL     = 0.05
)(
    input  logic        iCLK, iRST,
    output logic        oTRC
);

    genvar i;


    /* ------------------------------------------------------------
       SIGNAL DECLARATIONS
    ------------------------------------------------------------ */
    (* keep *) logic launch_q, capture_q;
    (* keep *) logic [NUM_INVERTERS:0] delay_wire;
    (* keep *) wire  trc_data_actual, check_error;


    /* ------------------------------------------------------------
       FLIP-FLOP CHAINS
    ------------------------------------------------------------ */
    /* launch flip-flop */
    always_ff @(posedge iCLK or negedge iRST) begin
        if (!iRST)  launch_q <= 1'b0;
        else        launch_q <= ~launch_q;
    end

    /* capture flip-flop */
    always_ff @(posedge iCLK or negedge iRST) begin
        if (!iRST)  capture_q <= 1'b0;
        else        capture_q <= check_error;
    end


    /* ------------------------------------------------------------
       INVERTER DELAT CHAIN
    ------------------------------------------------------------ */
    assign delay_wire[0] = launch_q;

    generate
        for (i = 0; i < NUM_INVERTERS; i = i + 1) begin : gen_inv_stage
            `ifdef SYNTHESIS
                gf180mcu_fd_sc_mcu7t5v0__inv_1 inv (
                    .I  (delay_wire[i]),
                    .ZN (delay_wire[i+1])
                );
            `else
                assign #(DELAY_VAL) delay_wire[i+1] = ~delay_wire[i];
            `endif
        end
    endgenerate

    // synthesis translate_off
    initial begin
        if (NUM_INVERTERS % 2 != 0)
            $warning("trc_behavioral_chain: NUM_INVERTERS=%0d is odd -> chain inverts polarity, TRC comparison will be wrong. Use an even count.", NUM_INVERTERS);
    end
    // synthesis translate_on


    /* ------------------------------------------------------------
       OUTPUT & COMPARATOR LOGIC
    ------------------------------------------------------------ */
    assign trc_data_actual  = delay_wire[NUM_INVERTERS];
    assign check_error      = launch_q ^ trc_data_actual;
    assign oTRC             = capture_q;

endmodule
