module delay_paths (
    input  logic       iCLK,
    input  logic       iRST,

    input  logic [1:0] iTRC_SEL,   // channel select for oTRC_MUX (calibration/debug)

    output logic [3:0] oTRC_ERR,   // {TRC3, TRC2, TRC1, TRC0}, always active (parallel)
    output logic [2:0] oTRC_MUX    // 3-bit status code, see table above
);

    localparam real DELAY_ELEMENT = 0.05; // ns, sim-only per-inverter delay

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
