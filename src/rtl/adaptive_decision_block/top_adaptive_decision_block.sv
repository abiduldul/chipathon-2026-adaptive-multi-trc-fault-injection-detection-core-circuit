module adaptive_decision (
    input  logic       iCLK,
    input  logic       iRST,              /* active-low async reset      */
    input  logic       iSOFT_RST,

    input  logic [3:0] iTRC_ERRORS,       /* parallel TRC error bus      */
    input  logic [3:0] iTHRES_VAL,        /* REG_THRESHOLD[3:0]          */
    input  logic [3:0] iAUTO_ADJ,         /* from adaptive_calibration   */

    input  logic       iINT_EN,
    input  logic       iINT_ACK,

    output logic       oINTERRUPT,        /* interrupt_out               */
    output logic [3:0] oFAILURE_EST,      /* failure_test_out -> STATUS  */
    output logic       oGLITCH_FLAG       /* glitch_flag_out -> STATUS[0]*/
);

    /* registered severity metric from the priority encoder */
    logic [3:0] deviation_delta;

    failure_estimation u_failure_estimation (
        .iCLK         (iCLK),
        .iRST         (iRST),
        .iSOFT_RST    (iSOFT_RST),
        .iTRC_ERRORS  (iTRC_ERRORS),
        .oFAILURE_EST (deviation_delta)
    );

    decision_logic u_decision_logic (
        .iCLK             (iCLK),
        .iRST             (iRST),
        .iSOFT_RST        (iSOFT_RST),
        .iDEVIATION_DELTA (deviation_delta),
        .iTHRES_VAL       (iTHRES_VAL),
        .iAUTO_ADJ        (iAUTO_ADJ),
        .iINT_EN          (iINT_EN),
        .iINT_ACK         (iINT_ACK),
        .oINTERRUPT       (oINTERRUPT),
        .oGLITCH_FLAG     (oGLITCH_FLAG)
    );

    assign oFAILURE_EST = deviation_delta;   /* to REG_STATUS[7:4] */

endmodule