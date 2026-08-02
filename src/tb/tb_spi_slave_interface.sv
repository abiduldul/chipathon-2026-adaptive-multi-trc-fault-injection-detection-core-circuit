module top_spi_register (
    input  logic       iCLK,
    input  logic       iRST,

    input  logic       iSPI_CS, iSPI_SCK, iSPI_MOSI,
    output logic       oSPI_MISO,

    input  logic       iGLITCH_STATUS,
    input  logic [1:0] iACTIVE_TRC,
    input  logic [3:0] iFAILURE_EST,

    output logic       oVGD_EN, oAUTO_CAL_EN, oINT_EN, oSOFT_RESET_OUT,
    output logic [1:0] oTRC_SEL,
    output logic [3:0] oTHRES_VAL, oCAL_PERIOD
);
    logic       reg_write;
    logic [1:0] reg_addr, trc_sel;
    logic [3:0] thres_val, cal_period;
    logic [7:0] reg_wdata, reg_rdata;

    spi_slave_interface spi (
        .iCLK(iCLK), .iRST(iRST),
        .iSPI_CS(iSPI_CS), .iSPI_SCK(iSPI_SCK), .iSPI_MOSI(iSPI_MOSI), .oSPI_MISO(oSPI_MISO),
        .oREG_WRITE(reg_write), .oREG_ADDR(reg_addr), .oREG_WDATA(reg_wdata),
        .iREG_RDATA(reg_rdata)
    );

    register regfile (
        .iCLK(iCLK), .iRST(iRST),
        .reg_write(reg_write), .reg_addr(reg_addr), .reg_wdata(reg_wdata), .reg_rdata(reg_rdata),
        .iGLITCH_STATUS(iGLITCH_STATUS), .iACTIVE_TRC(iACTIVE_TRC), .iFAILURE_EST(iFAILURE_EST),
        .oVGD_EN(oVGD_EN), .oAUTO_CAL_EN(oAUTO_CAL_EN), .oINT_EN(oINT_EN), .oSOFT_RESET_OUT(oSOFT_RESET_OUT),
        .oTRC_SEL(trc_sel), .oTHRES_VAL(thres_val), .oCAL_PERIOD(cal_period)
    );

    assign oTRC_SEL     = trc_sel;
    assign oTHRES_VAL   = thres_val;
    assign oCAL_PERIOD  = cal_period;

endmodule


module tb_spi_slave_interface;
    logic       iCLK, iRST;

    logic       iSPI_CS, iSPI_SCK;
    logic       iSPI_MOSI, oSPI_MISO;

    logic       vgd_en, auto_cal_en, int_en, soft_reset_out, glitch_status;
    logic [1:0] active_trc, trc_sel;
    logic [3:0] failure_est, thres_val, cal_period;
    logic [7:0] spi_rx;

    localparam SYS_CLK_PERIOD = 10;
    localparam SPI_CLK_PERIOD = 40;

    top_spi_register uut (
        .iCLK(iCLK), .iRST(iRST),
        .iSPI_CS(iSPI_CS), .iSPI_SCK(iSPI_SCK), .iSPI_MOSI(iSPI_MOSI), .oSPI_MISO(oSPI_MISO),
        .iGLITCH_STATUS(glitch_status), .iACTIVE_TRC(active_trc), .iFAILURE_EST(failure_est),
        .oVGD_EN(vgd_en), .oAUTO_CAL_EN(auto_cal_en), .oINT_EN(int_en), .oSOFT_RESET_OUT(soft_reset_out),
        .oTRC_SEL(trc_sel), .oTHRES_VAL(thres_val), .oCAL_PERIOD(cal_period)
    );

    always begin
        iCLK = 1'b0; #(SYS_CLK_PERIOD/2);
        iCLK = 1'b1; #(SYS_CLK_PERIOD/2);
    end


    /* ------------------------------------------------------------
       TASKS
    ------------------------------------------------------------ */
    /* spi transfer task */
    task spi_transfer_8bit(input logic [7:0] data_to_send, output logic [7:0] data_received);
        int bit_idx;
        begin
            data_received = 8'h00;
            iSPI_SCK  = 1'b0;
            iSPI_CS   = 1'b0;

            #(SPI_CLK_PERIOD/4);

            for (bit_idx = 7; bit_idx >= 0; bit_idx--) begin
                    iSPI_MOSI = data_to_send[bit_idx];
                #(SPI_CLK_PERIOD/2);
                    iSPI_SCK  = 1'b1;
                    data_received[bit_idx] = oSPI_MISO;
                #(SPI_CLK_PERIOD/2);
                    iSPI_SCK  = 1'b0;
            end

            #(SPI_CLK_PERIOD/4);
                iSPI_CS   = 1'b1;
                iSPI_MOSI = 1'b0;
            #(SPI_CLK_PERIOD);
        end
    endtask


    /* ------------------------------------------------------------
       SIMULATION SCENARIOS
    ------------------------------------------------------------ */
    initial begin
        $dumpfile("sim/tb_spi_slave_interface.vcd");
        $dumpvars(0, tb_spi_slave_interface);

        iRST          = 1'b0;
        iSPI_CS       = 1'b1;
        iSPI_SCK      = 1'b0;
        iSPI_MOSI     = 1'b0;
        glitch_status = 1'b0;
        active_trc    = 2'b00;
        failure_est   = 4'h0;

        #30; iRST = 1'b1; #50;


        /* ------------------------------------------------------------
           TEST CASE SIMULATION
        ------------------------------------------------------------ */
        $display("======= SPI + REGISTER INTEGRATION SIMULATION =======");


        /* test case 1: Write to REG_CONTROL_CONFIG */
        $display("\n[SPI WRITE] Writing data to REG_CONTROL_CONFIG...");
                spi_transfer_8bit(8'h95, spi_rx);
        #150;
        $display("[HARDWARE CHECK] vgd_en=%b, auto_cal_en=%b, trc_sel=%b", vgd_en, auto_cal_en, trc_sel);


        /* test case 2: Write to REG_THRESHOLD */
        $display("\n[SPI WRITE] Writing data to REG_THRESHOLD...");
        spi_transfer_8bit(8'hB5, spi_rx);
        #150;
        $display("[HARDWARE CHECK] thres_val=4'h%0h, cal_period=4'h%0h", thres_val, cal_period);


        /* test case 3: Hardware signal injection */
        $display("\n[HARDWARE INJECTION] Changing internal error status...");
        glitch_status = 1'b1;
        active_trc    = 2'b10;
        failure_est   = 4'hD;
        #150;


        /* test case 4: Read from REG_STATUS */
        $display("\n[SPI READ] Reading data from REG_STATUS...");
        spi_transfer_8bit(8'h40, spi_rx);
        #150;


        /* test case 5: Read from REG_STATUS again to verify MISO shifting */
        $display("\n[SPI READ] Shifting out status data via MISO...");
        spi_transfer_8bit(8'h00, spi_rx);
        $display("[SPI READ RESULT] Data read from status register via MISO = 8'h%0h", spi_rx);
        if (spi_rx[6:3] == 4'hD) $display(">>> SUCCESS: SPI Mode 0 Protocol and Register CDC Integration Working Properly!");
        else                     $display(">>> ERROR: Data Mismatch or Bit Shift detected! Read: 4'h%0h (Expected: 4'hD)", spi_rx[6:3]);


        $display("\n======= SIMULATION COMPLETED =======");
        $finish;
    end

endmodule
