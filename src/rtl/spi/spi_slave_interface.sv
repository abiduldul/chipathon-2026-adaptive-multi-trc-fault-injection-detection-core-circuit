module spi_slave_interface (
    input  logic        iCLK, iRST,

    input  logic        iSPI_CS, iSPI_SCK, iSPI_MOSI,
    output logic        oSPI_MISO,

    output logic        oREG_WRITE,
    output logic [1:0]  oREG_ADDR,
    output logic [7:0]  oREG_WDATA,
    input  logic [7:0]  iREG_RDATA
);

    logic       transaction_done;
    logic [1:0] reg_addr_reg;
    logic [2:0] bit_cnt, done_sync;
    logic [7:0] shift_reg, read_buffer;

    /* ------------------------------------------------------------
       MOSI SHIFT REGISTER
    ------------------------------------------------------------ */
    always_ff @(posedge iSPI_SCK or posedge iSPI_CS) begin
        if (iSPI_CS) begin
            shift_reg        <= 8'h00;
            bit_cnt          <= 3'd0;
            transaction_done <= 1'b0;
        end else begin
            shift_reg        <= {shift_reg[6:0], iSPI_MOSI};
            bit_cnt          <= bit_cnt + 3'd1;

            if (bit_cnt == 3'd7) transaction_done <= 1'b1;
            else                 transaction_done <= 1'b0;
        end
    end


    /* ------------------------------------------------------------
       SYSTEM CLOCK SYNCHRONIZED & BUS DECODE
    ------------------------------------------------------------ */
    always_ff @(posedge iCLK or negedge iRST) begin
        if (!iRST) begin
            done_sync       <= 3'b000;
            oREG_WRITE      <= 1'b0;
            oREG_WDATA      <= 8'h00;
            reg_addr_reg    <= 2'b00;
        end else begin
            done_sync       <= {done_sync[1:0], transaction_done};

            if (oREG_WRITE) oREG_WRITE <= 1'b0;
            
            if (done_sync[1] && !done_sync[2]) begin
                reg_addr_reg    <= shift_reg[6:5];
                if (shift_reg[7] == 1'b1) begin
                    oREG_WRITE  <= 1'b1;
                    oREG_WDATA  <= {3'b000, shift_reg[4:0]};
                end
            end
        end
    end


    /* ------------------------------------------------------------
       MISO SHIFT REGISTER
    ------------------------------------------------------------ */
    always_ff @(negedge iSPI_SCK or posedge iSPI_CS) begin
        if (iSPI_CS)            read_buffer <= 8'h00;
        else if (bit_cnt == 3'd1) read_buffer <= {iREG_RDATA[6:0], 1'b0};
        else                    read_buffer <= {read_buffer[6:0], 1'b0};
    end


    /* ------------------------------------------------------------
       OUTPUT
    ------------------------------------------------------------ */
    /* Latched address: updated in the same iCLK edge that asserts
       oREG_WRITE, and holds the transfer-1 address during the data
       phase of a read. */
    assign oREG_ADDR = reg_addr_reg;

    assign oSPI_MISO = (bit_cnt == 3'd0) ? iREG_RDATA[7] : read_buffer[7];

endmodule