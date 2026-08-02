module decision_logic (
    input  logic       iCLK,
    input  logic       iRST,              /* active-low async reset          */
    input  logic       iSOFT_RST,         /* REG_CONTROL_CONFIG[6]           */

    input  logic [3:0] iDEVIATION_DELTA,  /* from failure_estimation         */
    input  logic [3:0] iTHRES_VAL,        /* REG_THRESHOLD[3:0] static margin*/
    input  logic [3:0] iAUTO_ADJ,         /* from adaptive_calibration       */

    input  logic       iINT_EN,           /* REG_CONTROL_CONFIG[2]           */
    input  logic       iINT_ACK,          /* REG_CONTROL_CONFIG[5] W1C pulse */

    output logic       oINTERRUPT,        /* hardware interrupt to core      */
    output logic       oGLITCH_FLAG       /* attack flag -> REG_STATUS[0]    */
);

    logic [3:0] masking_limit;

    always_comb begin
        if (iAUTO_ADJ > iTHRES_VAL)
            masking_limit = 4'd0;                    /* saturate low        */
        else
            masking_limit = iTHRES_VAL - iAUTO_ADJ;
    end

     logic attack_detected;

    always_comb begin
        attack_detected = (iDEVIATION_DELTA > masking_limit);
    end

    logic attack_latched;

    always_ff @(posedge iCLK or negedge iRST) begin
        if (!iRST) begin
            attack_latched <= 1'b0;
        end else begin
            if (iSOFT_RST)             attack_latched <= 1'b0;
            else if (iINT_ACK)         attack_latched <= 1'b0;  /* re-arm  */
            else if (attack_detected)  attack_latched <= 1'b1;  /* latch   */
        end
    end
    
    assign oINTERRUPT   = iINT_EN & (attack_detected | attack_latched);
    assign oGLITCH_FLAG = attack_detected | attack_latched;

endmodule