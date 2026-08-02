module register_control_config (
    input  logic        iCLK, iRST, iWR,
    
    input  logic [7:0]  iWDATA,
    output logic [7:0]  oRDATA,
    
    output logic        VGD_EN, AUTO_CAL_EN, INT_EN,
    output logic        INT_ACK_OUT, SOFT_RESET_OUT,
    output logic [1:0]  TRC_SEL
);

    logic [7:0] reg_data;

    assign VGD_EN           = reg_data[0];
    assign AUTO_CAL_EN      = reg_data[1];
    assign INT_EN           = reg_data[2];
    assign TRC_SEL          = reg_data[4:3];
    assign INT_ACK_OUT      = reg_data[5];
    assign SOFT_RESET_OUT   = reg_data[6];

    always_ff @(posedge iCLK or negedge iRST) begin
        if (!iRST) begin
            reg_data <= 8'h07;
        end else begin
            if (iWR) begin
                reg_data <= {1'b0, iWDATA[6:0]};
            end else begin
                /* Auto-clear strobe behavior */
                reg_data[5] <= 1'b0;    /* auto clear INT_ACK_OUT */
                reg_data[6] <= 1'b0;    /* auto clear SOFT_RESET_OUT */
            end
        end
    end

    assign oRDATA = reg_data;

endmodule
