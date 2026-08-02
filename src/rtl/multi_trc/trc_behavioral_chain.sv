// =============================================================
// Module : trc_behavioral_chain  (FIXED)
// Purpose: Single Tunable Replica Circuit path: launch FF ->
//          combinational delay chain -> XOR compare -> capture FF
//
// Fixes applied vs original file:
//   1. Delay chain now driven by the LAUNCH FLIP-FLOP output
//      (trc_data_ref / launch_q), not by the raw clock. The whole
//      point of a TRC is that the *launched, toggling reference*
//      signal is what propagates through a replica of the real
//      combinational path -- comparing it against an unrelated
//      delayed clock signal (as the original code did) does not
//      model a fault-injection sensor at all.
//   2. Delay chain is now purely COMBINATIONAL (continuous
//      assign), not a chain of clocked flip-flops. A flip-flop
//      chain only ever measures whole clock periods; it can never
//      capture the sub-nanosecond, VDD-dependent propagation delay
//      that a real TRC relies on. After synthesis, each stage below
//      becomes a real inverter standard cell whose delay is exactly
//      what varies with supply voltage in silicon -- the #(DELAY_VAL)
//      annotation is for pre-synthesis simulation only and is
//      dropped by the synthesis tool (Yosys/Slang), same as it is
//      dropped in the original Intel/Black-Hat reference model.
//   3. NUM_INVERTERS must be EVEN so the chain is non-inverting
//      (trc_data_actual settles back to the same polarity as
//      trc_data_ref). The original odd counts (45/35/25/15) would
//      make the chain invert polarity, which is architecturally
//      wrong for this comparator scheme.
// =============================================================
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

    /* ------------------------------------------------------------
       COMBINATIONAL TUNABLE DELAY CHAIN (trc_data_actual)
    ------------------------------------------------------------ */
    // NOTE: the #(DELAY_VAL) here is a simulation-only annotation, used
    // only in the non-synthesis branch below.
    //
    // CRITICAL LESSON LEARNED: a behavioral `assign delay_wire[i+1] =
    // ~delay_wire[i]` with zero synthesis-time delay is, for an EVEN
    // number of stages, logically IDENTICAL to the chain's own input.
    // Yosys (and its ABC technology-mapping pass) correctly proves this
    // and collapses the *entire* delay chain -- and everything feeding
    // only into it, including the launch/capture flip-flops -- down to
    // a compile-time constant. Neither array-level nor per-stage
    // `(* keep *)` attributes stopped this: `keep` prevents outright
    // *deletion* of a named signal, but does not stop Yosys/ABC from
    // *resynthesizing* the logic driving it once boolean equivalence is
    // proven.
    //
    // The only reliable fix is to stop asking Yosys to synthesize
    // behavioral logic here at all: instead, directly instantiate the
    // real GF180MCU inverter standard cell (gf180mcu_fd_sc_mcu7t5v0__inv_1,
    // pin I -> ZN) by name for each stage. Yosys treats externally-defined
    // library cells as opaque black boxes during synthesis -- it does not
    // (and cannot) prove two named standard-cell instances are logically
    // redundant and merge them, because from Yosys's point of view they
    // are already-mapped physical primitives, not inferred logic. This
    // also happens to be exactly what the original reference RTL skeleton
    // in Adaptive_Multi_TRC_Spec.pdf recommended (inv_cell/nor2_cell
    // structural instantiation) instead of behavioral assigns.
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
