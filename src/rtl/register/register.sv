module register (
    input  logic        iCLK, iRST,
    
    /* spi interface */
    input  logic        reg_write,
    input  logic [1:0]  reg_addr,
    input  logic [7:0]  reg_wdata,
    output logic [7:0]  reg_rdata,

    input  logic        iGLITCH_STATUS,
    input  logic [1:0]  iACTIVE_TRC,
    input  logic [3:0]  iFAILURE_EST,

    output logic        oVGD_EN, oAUTO_CAL_EN, oINT_EN, oSOFT_RESET_OUT,
    output logic [1:0]  oTRC_SEL,
    output logic [3:0]  oTHRES_VAL, oCAL_PERIOD
);

    localparam logic [1:0] ADDR_CONFIG    = 2'b00;
    localparam logic [1:0] ADDR_THRESHOLD = 2'b01;
    localparam logic [1:0] ADDR_STATUS    = 2'b10;

    logic we_config, we_threshold, int_ack;
    logic [7:0] rdata_config, rdata_threshold, rdata_status;


    /* ------------------------------------------------------------
       REGISTER INSTANCES
    ------------------------------------------------------------ */
    /* control and configuration register */
    register_control_config reg_config (
        .iCLK, .iRST, .iWR(we_config), 
        .iWDATA(reg_wdata), .oRDATA(rdata_config),
        .VGD_EN(oVGD_EN), .AUTO_CAL_EN(oAUTO_CAL_EN), 
        .INT_EN(oINT_EN), .TRC_SEL(oTRC_SEL), 
        .INT_ACK_OUT(int_ack), .SOFT_RESET_OUT(oSOFT_RESET_OUT)
    );

    /* threshold register */
    register_threshold reg_threshold (
        .iCLK, .iRST, .iWR(we_threshold), 
        .iWDATA(reg_wdata), .oRDATA(rdata_threshold),
        .THRES_VAL(oTHRES_VAL), .CAL_PERIOD(oCAL_PERIOD)
    );

    /* status register */
    register_status reg_status (
        .iCLK, .iRST, 
        .oRDATA(rdata_status),
        .iSOFT_RST(oSOFT_RESET_OUT), .iINT_ACK(int_ack),
        .GLITCH_STATUS(iGLITCH_STATUS), .ACTIVE_TRC(iACTIVE_TRC), .FAILURE_EST(iFAILURE_EST)
    );


    /* ------------------------------------------------------------
       MUX REGISTER
    ------------------------------------------------------------ */
    always_comb begin
        case (reg_addr)
            ADDR_CONFIG:    reg_rdata = rdata_config;
            ADDR_THRESHOLD: reg_rdata = rdata_threshold;
            ADDR_STATUS:    reg_rdata = rdata_status;
            default:        reg_rdata = 8'h00;
        endcase
    end


    /* ------------------------------------------------------------
       OUTPUT
    ------------------------------------------------------------ */
    assign we_config    = (reg_write && (reg_addr == ADDR_CONFIG));
    assign we_threshold = (reg_write && (reg_addr == ADDR_THRESHOLD));

endmodule
