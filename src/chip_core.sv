// SPDX-License-Identifier: Apache-2.0

`default_nettype none

module chip_core #(
    parameter NUM_INPUT_PADS,
    parameter NUM_BIDIR_PADS,
    parameter NUM_ANALOG_PADS
)(
`ifdef USE_POWER_PINS
    inout wire VDD,
    inout wire VSS,
`endif

    input  wire clk,
    input  wire rst_n,

    input  wire [NUM_INPUT_PADS-1:0] input_in,
    output wire [NUM_INPUT_PADS-1:0] input_pu,
    output wire [NUM_INPUT_PADS-1:0] input_pd,

    input  wire [NUM_BIDIR_PADS-1:0] bidir_in,
    output wire [NUM_BIDIR_PADS-1:0] bidir_out,
    output wire [NUM_BIDIR_PADS-1:0] bidir_oe,
    output wire [NUM_BIDIR_PADS-1:0] bidir_cs,
    output wire [NUM_BIDIR_PADS-1:0] bidir_sl,
    output wire [NUM_BIDIR_PADS-1:0] bidir_ie,
    output wire [NUM_BIDIR_PADS-1:0] bidir_pu,
    output wire [NUM_BIDIR_PADS-1:0] bidir_pd,

    inout wire [NUM_ANALOG_PADS-1:0] analog
);

    //------------------------------------------------------------------
    // Disable pull-up / pull-down on dedicated input pads
    //------------------------------------------------------------------
    assign input_pu = '0;
    assign input_pd = '0;

    //------------------------------------------------------------------
    // Default configuration for bidirectional pads
    //------------------------------------------------------------------
    logic [NUM_BIDIR_PADS-1:0] bidir_out_r;
    logic [NUM_BIDIR_PADS-1:0] bidir_oe_r;

    assign bidir_out = bidir_out_r;
    assign bidir_oe  = bidir_oe_r;

    // CMOS
    assign bidir_cs = '0;

    // Fast slew
    assign bidir_sl = '0;

    // Enable input buffers whenever pad is not output
    assign bidir_ie = ~bidir_oe_r;

    // Disable pullups/pulldowns
    assign bidir_pu = '0;
    assign bidir_pd = '0;

    //------------------------------------------------------------------
    // Pad mapping
    //
    // bidir[0] : SPI_CS
    // bidir[1] : SPI_SCK
    // bidir[2] : SPI_MOSI
    // bidir[3] : SPI_MISO
    // bidir[4] : INTERRUPT
    //------------------------------------------------------------------

    wire spi_cs   = bidir_in[0];
    wire spi_sck  = bidir_in[1];
    wire spi_mosi = bidir_in[2];

    wire spi_miso;
    wire interrupt;

    //------------------------------------------------------------------
    // DUT
    //------------------------------------------------------------------

    fault_injection_detection_core dut (
        .iCLK      (clk),
        .iRST      (rst_n),

        .iSPI_CS   (spi_cs),
        .iSPI_SCK  (spi_sck),
        .iSPI_MOSI (spi_mosi),

        .oSPI_MISO (spi_miso),
        .oINTERRUPT(interrupt)
    );

    //------------------------------------------------------------------
    // Output mapping
    //------------------------------------------------------------------

    always_comb begin
        bidir_out_r = '0;
        bidir_oe_r  = '0;

        // SPI MISO
        bidir_out_r[3] = spi_miso;
        bidir_oe_r[3]  = 1'b1;

        // Interrupt
        bidir_out_r[4] = interrupt;
        bidir_oe_r[4]  = 1'b1;
    end

    //------------------------------------------------------------------
    // Prevent optimisation
    //------------------------------------------------------------------

    logic unused;

    assign unused = &{
        1'b0,
        analog,
        input_in,
        bidir_in[NUM_BIDIR_PADS-1:5]
    };

endmodule

`default_nettype wire
