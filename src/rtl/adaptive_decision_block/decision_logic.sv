module decision_logic (
    input  logic        iCLK, iRST, iSOFT_RST,
    input  logic        iINT_EN, iINT_ACK,

    input  logic [3:0]  iDEVIATION_DELTA, iTHRES_VAL, iAUTO_ADJ,
    output logic        oINTERRUPT, oGLITCH_FLAG
);

    logic attack_detected, attack_latched;
    logic [3:0] masking_limit;


    always_comb begin
        if (iAUTO_ADJ > iTHRES_VAL) masking_limit = 4'd0;
        else                        masking_limit = iTHRES_VAL - iAUTO_ADJ;
    end


    always_comb begin
        attack_detected = (iDEVIATION_DELTA > masking_limit);
    end


    always_ff @(posedge iCLK or negedge iRST) begin
        if (!iRST) begin
            attack_latched <= 1'b0;
        end else begin
            if (iSOFT_RST)             attack_latched <= 1'b0;
            else if (iINT_ACK)         attack_latched <= 1'b0;  /* re-arm  */
            else if (attack_detected)  attack_latched <= 1'b1;  /* latch   */
        end
    end


    /* ------------------------------------------------------------
       OUTPUT LOGIC
    ------------------------------------------------------------ */
    assign oINTERRUPT   = iINT_EN & (attack_detected | attack_latched);
    assign oGLITCH_FLAG = attack_detected | attack_latched;

endmodule
