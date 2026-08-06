module register_status (
    input  logic        iCLK, iRST,
    output logic [7:0]  oRDATA,
    
    input  logic        iSOFT_RST, iINT_ACK,

    input  logic        GLITCH_STATUS,
    input  logic [1:0]  ACTIVE_TRC,
    input  logic [3:0]  FAILURE_EST
);

    logic [7:0] reg_data;

    always_ff @(posedge iCLK or negedge iRST) begin
        if (!iRST) begin
            reg_data        <= 8'h00;
        end else if (iSOFT_RST) begin
        /* synchronous soft reset */
        reg_data        <= 8'h00;
        end else begin
            reg_data[0]     <= (iINT_ACK) ? 1'b0 : (GLITCH_STATUS ? 1'b1 : reg_data[0]);
            reg_data[2:1]   <= ACTIVE_TRC;
            reg_data[6:3]   <= FAILURE_EST;
            reg_data[7]     <= 1'b0;
        end
    end

    assign oRDATA = reg_data;

endmodule
