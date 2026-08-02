module adaptive_decision (
    input  logic        iCLK, iRST, iSOFT_RST,

    input  logic        iINT_EN, iINT_ACK,
    input  logic [3:0]  iTRC_ERRORS, iTHRES_VAL, iAUTO_ADJ,

    output logic        oINTERRUPT, oGLITCH_FLAG,
    output logic [3:0]  oFAILURE_EST
);

    logic [3:0] deviation_delta;

    failure_estimation failure_estimation (
        .iCLK (iCLK), .iRST (iRST), .iSOFT_RST (iSOFT_RST),
        .iTRC_ERRORS  (iTRC_ERRORS),
        .oFAILURE_EST (deviation_delta)
    );

    decision_logic decision_logic (
        .iCLK (iCLK), .iRST (iRST), .iSOFT_RST (iSOFT_RST),
        .iDEVIATION_DELTA (deviation_delta), .iTHRES_VAL (iTHRES_VAL), .iAUTO_ADJ (iAUTO_ADJ),
        .iINT_EN (iINT_EN), .iINT_ACK (iINT_ACK),
        .oINTERRUPT (oINTERRUPT), .oGLITCH_FLAG (oGLITCH_FLAG)
    );


    /* ------------------------------------------------------------
       OUTPUT LOGIC
    ------------------------------------------------------------ */
    assign oFAILURE_EST = deviation_delta;

endmodule
