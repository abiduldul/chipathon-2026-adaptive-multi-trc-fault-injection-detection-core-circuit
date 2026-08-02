module tb_register;
    logic           iCLK, iRST;

    logic           reg_write;
    logic [1:0]     reg_addr;
    logic [7:0]     reg_wdata, reg_rdata;

    logic           glitch_detected_in;
    logic [1:0]     virtual_active_trc_in;
    logic [3:0]     failure_est_in;

    logic           vgd_en, auto_cal_en, int_en, soft_reset_out;
    logic [1:0]     trc_mask_sel;
    logic [3:0]     thres_val, cal_period;

    localparam CLK_PERIOD = 10;

    register regfile (
        .iCLK(iCLK), .iRST(iRST),
        .reg_write(reg_write), .reg_addr(reg_addr), .reg_wdata(reg_wdata), .reg_rdata(reg_rdata),
        .iGLITCH_STATUS(glitch_detected_in), .iACTIVE_TRC(virtual_active_trc_in), .iFAILURE_EST(failure_est_in),
        .oVGD_EN(vgd_en), .oAUTO_CAL_EN(auto_cal_en), .oINT_EN(int_en), .oTRC_SEL(trc_mask_sel),
        .oTHRES_VAL(thres_val), .oCAL_PERIOD(cal_period), .oSOFT_RESET_OUT(soft_reset_out)
    );

    always begin
        iCLK = 1'b0; #(CLK_PERIOD/2);
        iCLK = 1'b1; #(CLK_PERIOD/2);
    end


    /* ------------------------------------------------------------
       TASKS
    ------------------------------------------------------------ */
    /* Write task */
    task write_reg(input logic [1:0] addr, input logic [7:0] data);
        begin
            @(posedge iCLK);
            reg_addr  = addr;
            reg_write = 1'b1;
            reg_wdata = data;

            #(CLK_PERIOD);
                reg_write = 1'b0;
        end
    endtask

    /* Read task */
    task read_reg(input logic [1:0] addr);
        begin
            @(posedge iCLK);
            reg_addr  = addr;
            reg_write = 1'b0;

            #(CLK_PERIOD);
                $display("[READ ADDR: 0x%0h] Read data = 8'h%0h", addr, reg_rdata);
        end
    endtask


    /* ------------------------------------------------------------
       SIMULATION SCENARIOS
    ------------------------------------------------------------ */
    initial begin
        $dumpfile("sim/tb_register.vcd");
        $dumpvars(0, tb_register);
        iRST                  = 1'b0;
        reg_write             = 1'b0;
        reg_addr              = 2'b00;
        reg_wdata             = 8'h00;
        glitch_detected_in    = 1'b0;
        virtual_active_trc_in = 2'b00;
        failure_est_in        = 4'h0;

        #25;
        iRST = 1'b1;


        /* ------------------------------------------------------------
           SIMULATION TEST CASES
        ------------------------------------------------------------ */
        $display("======= REGISTER SIMULATION =======");
        
        
        /* Test 1: Read default register values */
        $display("\n--- Read default configuration values ---");
        read_reg(2'b00); // must output 0x07
        read_reg(2'b01); // must output 0x70


        /* Test 2: Write new configuration values */
        $display("\n--- Change configuration value ---");
        write_reg(2'b00, 8'h15); // VGD_EN=1, AUTO_CAL_EN=0, INT_EN=1, TRC_MASK_SEL=2'b10 (0x15)
        #10;
            if (auto_cal_en === 1'b0 && trc_mask_sel === 2'b10) $display("[SUCCESS] Configuration control register update is valid.");
            else $display("[ERROR] Failed to change operation mode!");


        /* Test 3: Write new threshold values */
        $display("\n--- Setting New Security Threshold Values ---");
        write_reg(2'b01, 8'hA5); // CAL_PERIOD=4'hA, THRES_VAL=4'h5 (0xA5)
        #10; read_reg(2'b01);


        /* Test 4: Simulate attack detection from hardware side */
        $display("\n--- Injecting Threat Status from Hardware Block ---");
        glitch_detected_in    = 1'b1;
        virtual_active_trc_in = 2'b11;
        failure_est_in        = 4'hB;
        #20; read_reg(2'b10);


        /* Test 5: Trigger interrupt acknowledge to clear locked alarm */
        $display("\n--- Sending Interrupt Clear Signal (INT_ACK) ---");
        glitch_detected_in = 1'b0;
        write_reg(2'b00, 8'h35);
        #20; read_reg(2'b10);


        $display("\n======= REGISTER SIMULATION DONE =======");
        $finish;
    end

endmodule
