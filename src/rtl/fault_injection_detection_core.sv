module fault_injection_detection_core (
    input  logic        iCLK,
    input  logic        iRST,

    /* spi external interface */
    input  logic        iSPI_CS,
    input  logic        iSPI_SCK,
    input  logic        iSPI_MOSI,
    output logic        oSPI_MISO,

    /* core interrupt output */
    output logic        oINTERRUPT
);

    /* ------------------------------------------------------------
       INTERNAL WIRES & INTERCONNECTS
    ------------------------------------------------------------ */
    /* spi slave interface signals */
    logic        reg_write;
    logic [1:0]  reg_addr;
    logic [7:0]  reg_wdata, reg_rdata;

    /* register file signals */
    logic        vgd_en, auto_cal_en, int_en, soft_reset, int_ack;
    logic [1:0]  manual_trc_sel;
    logic [3:0]  thres_val;
    logic [3:0]  cal_period;

    /* delay paths signals */
    logic [1:0]  active_trc_sel;
    logic [2:0]  trc_mux_out;
    logic [3:0]  trc_errors;

    /* adaptive calibration signals */
    logic        cal_done;
    logic [1:0]  auto_trc_sel;
    logic [3:0]  auto_adj;

    /* adaptive decision signals */
    logic        glitch_flag;
    logic [3:0]  failure_est;

    /* system reset signal */
    logic sys_rst_n;
    assign sys_rst_n = iRST && (~soft_reset);


    /* ------------------------------------------------------------
       SPI SLAVE INTERFACE INSTANCE
    ------------------------------------------------------------ */
    spi_slave_interface spi_interface (
        .iCLK (iCLK), .iRST (iRST),
        .iSPI_CS (iSPI_CS), .iSPI_SCK (iSPI_SCK),
        .iSPI_MOSI (iSPI_MOSI), .oSPI_MISO (oSPI_MISO),
        .oREG_WRITE (reg_write), .oREG_ADDR (reg_addr),
        .oREG_WDATA (reg_wdata), .iREG_RDATA (reg_rdata)
    );


    /* ------------------------------------------------------------
       REGISTER FILE INSTANCE
    ------------------------------------------------------------ */
    register register_file (
        .iCLK (iCLK), .iRST (iRST),
        .reg_write (reg_write), .reg_addr (reg_addr),
        .reg_wdata (reg_wdata), .reg_rdata (reg_rdata),
        .iGLITCH_STATUS (glitch_flag), .iACTIVE_TRC (active_trc_sel), .iFAILURE_EST (failure_est),
        .oVGD_EN (vgd_en), .oAUTO_CAL_EN (auto_cal_en), .oINT_EN (int_en), .oINT_ACK (int_ack),
        .oSOFT_RESET_OUT (soft_reset), .oTRC_SEL (manual_trc_sel),
        .oTHRES_VAL (thres_val), .oCAL_PERIOD (cal_period)
    );


    /* ------------------------------------------------------------
       DELAY PATHS (TRC CHAINS) INSTANCE
    ------------------------------------------------------------ */
    delay_paths delay_paths (
        .iCLK (iCLK), .iRST (sys_rst_n),
        .iTRC_SEL (active_trc_sel),
        .oTRC_MUX (trc_mux_out), .oTRC_ERR (trc_errors)
    );


    /* ------------------------------------------------------------
       ADAPTIVE CALIBRATION INSTANCE
    ------------------------------------------------------------ */
    adaptive_calibration adaptive_calibration (
        .iCLK (iCLK), .iRST (sys_rst_n),
        .iCAL_PERIOD (cal_period), .iTRC (trc_errors),
        .oDONE (cal_done),
        .oAUTO_TRC_SEL (auto_trc_sel), .oAUTO_ADJ (auto_adj)
    );


    /* ------------------------------------------------------------
       ADAPTIVE DECISION BLOCK INSTANCE
    ------------------------------------------------------------ */
    adaptive_decision adaptive_decision (
        .iCLK (iCLK), .iRST (iRST), .iSOFT_RST (soft_reset),
        .iINT_EN (int_en), .iINT_ACK (int_ack),
        .iTRC_ERRORS (trc_errors), .iTHRES_VAL (thres_val), .iAUTO_ADJ (auto_adj),
        .oINTERRUPT (oINTERRUPT), .oGLITCH_FLAG (glitch_flag), .oFAILURE_EST (failure_est)
    );


    /* ------------------------------------------------------------
       TRC SELECT MUX LOGIC
    ------------------------------------------------------------ */
    assign active_trc_sel = auto_cal_en ? auto_trc_sel : manual_trc_sel;

endmodule