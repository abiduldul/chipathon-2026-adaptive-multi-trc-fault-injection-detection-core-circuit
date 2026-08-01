module failure_estimation (
    input  logic       iCLK,
    input  logic       iRST,
    input  logic       iSOFT_RST,
    
    input  logic [3:0] iTRC_ERRORS,   
    output logic [3:0] oFAILURE_EST 
);

    logic [3:0] attack_strength_raw;

    always_comb begin
        casez (iTRC_ERRORS)
            4'b1???: attack_strength_raw = 4'hF;    /* extreme attack (trc3) */
            4'b01??: attack_strength_raw = 4'hB;    /* strong attack (trc2) */
            4'b001?: attack_strength_raw = 4'h7;    /* moderate attack (trc1) */
            4'b0001: attack_strength_raw = 4'h3;    /* light attack (trc0) */
            default: attack_strength_raw = 4'h0;    /* no attack */
        endcase
    end


    /* ------------------------------------------------------------
       OUTPUT LOGIC
    ------------------------------------------------------------ */
    always_ff @(posedge iCLK or negedge iRST) begin
        if (!iRST) begin
            oFAILURE_EST <= 4'd0;
        end else begin
            if (iSOFT_RST) oFAILURE_EST <= 4'd0;
            else           oFAILURE_EST <= attack_strength_raw;
        end
    end

endmodule
