// =============================================================
// Module : delay_paths  (UPDATED -- 3-bit status code for oTRC_MUX)
//
// History:
//   1. Instance names (u_trc0..u_trc3) no longer collide with net
//      names (trc0_err..trc3_err) -- the original file used the
//      SAME identifiers for both, which is illegal Verilog.
//   2. Output changed from a single MUX'd bit to a 4-bit PARALLEL
//      error bus oTRC_ERR[3:0], since failure_estimation.sv needs
//      the full thermometer-coded vector, not one bit at a time.
//   3. Inverter counts corrected to 192/144/96/48 per the spec table.
//   4. Added oTRC_MUX + iTRC_SEL[1:0] alongside oTRC_ERR for
//      per-channel calibration/observation -- does NOT replace
//      oTRC_ERR (failure_estimation still needs the full parallel
//      bus).
//   5. UPDATE: oTRC_MUX is now a 3-bit STATUS CODE rather than a
//      raw bit/mask:
//        000 = normal     (selected channel is NOT tripped)
//        001 = TRC0 trip  (iTRC_SEL=00 and oTRC_ERR[0]=1)
//        010 = TRC1 trip  (iTRC_SEL=01 and oTRC_ERR[1]=1)
//        011 = TRC2 trip  (iTRC_SEL=10 and oTRC_ERR[2]=1)
//        100 = TRC3 trip  (iTRC_SEL=11 and oTRC_ERR[3]=1)
//        101-111 = reserved (unused, only 4 channels exist)
//      iTRC_SEL still selects which channel is being observed;
//      oTRC_MUX now reports "normal" or "which channel + tripped"
//      as a single readable code instead of a bit position.
// =============================================================
module delay_paths (
    input  logic       iCLK,
    input  logic       iRST,

    input  logic [1:0] iTRC_SEL,   // channel select for oTRC_MUX (calibration/debug)

    output logic [3:0] oTRC_ERR,   // {TRC3, TRC2, TRC1, TRC0}, always active (parallel)
    output logic [2:0] oTRC_MUX    // 3-bit status code, see table above
);

    localparam real DELAY_ELEMENT = 0.05; // ns, sim-only per-inverter delay

    /* ------------------------------------------------------------
       TRC CHANNELS -- run in parallel at all times, per spec
    ------------------------------------------------------------ */
    trc_behavioral_chain #(
        .NUM_INVERTERS(192),   // Extreme sensitivity
        .DELAY_VAL(DELAY_ELEMENT)
    ) u_trc0 (
        .iCLK (iCLK), .iRST (iRST), .oTRC (oTRC_ERR[0])
    );

    trc_behavioral_chain #(
        .NUM_INVERTERS(144),   // High sensitivity
        .DELAY_VAL(DELAY_ELEMENT)
    ) u_trc1 (
        .iCLK (iCLK), .iRST (iRST), .oTRC (oTRC_ERR[1])
    );

    trc_behavioral_chain #(
        .NUM_INVERTERS(96),    // Medium sensitivity
        .DELAY_VAL(DELAY_ELEMENT)
    ) u_trc2 (
        .iCLK (iCLK), .iRST (iRST), .oTRC (oTRC_ERR[2])
    );

    trc_behavioral_chain #(
        .NUM_INVERTERS(48),    // Low sensitivity
        .DELAY_VAL(DELAY_ELEMENT)
    ) u_trc3 (
        .iCLK (iCLK), .iRST (iRST), .oTRC (oTRC_ERR[3])
    );

    /* ------------------------------------------------------------
       CALIBRATION MUX -- 3-bit status code
       000 normal | 001 TRC0 | 010 TRC1 | 011 TRC2 | 100 TRC3
       101/110/111 reserved
    ------------------------------------------------------------ */
    always_comb begin
        case (iTRC_SEL)
            2'b00:   oTRC_MUX = oTRC_ERR[0] ? 3'b001 : 3'b000;
            2'b01:   oTRC_MUX = oTRC_ERR[1] ? 3'b010 : 3'b000;
            2'b10:   oTRC_MUX = oTRC_ERR[2] ? 3'b011 : 3'b000;
            2'b11:   oTRC_MUX = oTRC_ERR[3] ? 3'b100 : 3'b000;
            default: oTRC_MUX = 3'b000;
        endcase
    end

endmodule
