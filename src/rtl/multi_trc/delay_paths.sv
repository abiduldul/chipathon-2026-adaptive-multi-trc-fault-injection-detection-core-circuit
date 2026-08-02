module delay_paths (
    input  logic        iCLK, iRST,
    input  logic [1:0]  iTRC_SEL,

    output logic [2:0]  oTRC_MUX,
    output logic [3:0]  oTRC_ERR
);

    localparam real DELAY_ELEMENT = 0.05;

    /* ------------------------------------------------------------
       TRC CHAINS
    ------------------------------------------------------------ */
    /* extreme sensitivity 192 inverters */
    trc_behavioral_chain #(
        .NUM_INVERTERS(192), .DELAY_VAL(DELAY_ELEMENT)
    ) u_trc0 (
        .iCLK (iCLK), .iRST (iRST), .oTRC (oTRC_ERR[0])
    );

    /* high sensitivity 144 inverters */
    trc_behavioral_chain #(
        .NUM_INVERTERS(144), .DELAY_VAL(DELAY_ELEMENT)
    ) u_trc1 (
        .iCLK (iCLK), .iRST (iRST), .oTRC (oTRC_ERR[1])
    );

    /* medium sensitivity 96 inverters */
    trc_behavioral_chain #(
        .NUM_INVERTERS(96), .DELAY_VAL(DELAY_ELEMENT)
    ) u_trc2 (
        .iCLK (iCLK), .iRST (iRST), .oTRC (oTRC_ERR[2])
    );

    /* low sensitivity 48 inverters */
    trc_behavioral_chain #(
        .NUM_INVERTERS(48), .DELAY_VAL(DELAY_ELEMENT)
    ) u_trc3 (
        .iCLK (iCLK), .iRST (iRST), .oTRC (oTRC_ERR[3])
    );


    /* ------------------------------------------------------------
       MUX TRC
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
