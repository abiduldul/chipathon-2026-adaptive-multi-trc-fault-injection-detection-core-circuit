// SPDX-License-Identifier: Apache-2.0
//
// Top-level wrapper untuk submission Chipathon 2026 - Tim A48
//
// PENTING: nama port di sini HARUS persis sama dengan nama pin di file DEF
// yang di-generate panitia dari info.yaml. Cek dulu file DEF + verilog
// referensi yang Mitch upload ke GitHub issue repo kalian, lalu sesuaikan:
//   - suffix kontrol pad (_OE vs _OE_N, _IE, _PU, _PD, _CS, _SL)
//   - nama net power (vdd/vss/vcc/gnd)
//
// Sampai DEF diterima, file ini bersifat sementara.

`default_nettype none

module trc_top (
`ifdef USE_POWER_PINS
    inout  wire vss,            // quiet ground (pin pertama kuadran)
    inout  wire vcc,            // 5.0 V
    inout  wire gnd,            // ground pasangan vcc
    inout  wire vdd,            // 3.3 V (kalau memang dipakai)
    inout  wire vss3v3,         // ground pasangan vdd
`endif

    // ---------- dedicated input pads ----------
    input  wire iCLK,           // input_schmitt
    input  wire iRST,           // input_cmos
    input  wire iSPI_CS,        // input_cmos
    input  wire iSPI_SCK,       // input_schmitt
    input  wire iSPI_MOSI,      // input_cmos

    // ---------- bidirectional pad: oSPI_MISO ----------
    input  wire oSPI_MISO_IN,
    output wire oSPI_MISO_OUT,
    output wire oSPI_MISO_OE,
    output wire oSPI_MISO_IE,
    output wire oSPI_MISO_PU,
    output wire oSPI_MISO_PD,
    output wire oSPI_MISO_CS,
    output wire oSPI_MISO_SL,

    // ---------- bidirectional pad: oINTERRUPT ----------
    input  wire oINTERRUPT_IN,
    output wire oINTERRUPT_OUT,
    output wire oINTERRUPT_OE,
    output wire oINTERRUPT_IE,
    output wire oINTERRUPT_PU,
    output wire oINTERRUPT_PD,
    output wire oINTERRUPT_CS,
    output wire oINTERRUPT_SL
);

    // ------------------------------------------------------------------
    // Konfigurasi pad bidirectional
    // Kedua pin ini dipakai sebagai output murni, jadi:
    //   OE = 1 (driver aktif), IE = 0 (input buffer mati)
    //   PU/PD = 0 (tanpa pull), CS = 0 (CMOS), SL = 0 (fast slew)
    // ------------------------------------------------------------------
    assign oSPI_MISO_OE   = 1'b1;
    assign oSPI_MISO_IE   = 1'b0;
    assign oSPI_MISO_PU   = 1'b0;
    assign oSPI_MISO_PD   = 1'b0;
    assign oSPI_MISO_CS   = 1'b0;
    assign oSPI_MISO_SL   = 1'b0;

    assign oINTERRUPT_OE  = 1'b1;
    assign oINTERRUPT_IE  = 1'b0;
    assign oINTERRUPT_PU  = 1'b0;
    assign oINTERRUPT_PD  = 1'b0;
    assign oINTERRUPT_CS  = 1'b0;
    assign oINTERRUPT_SL  = 1'b0;

    // _IN tidak dipakai (pad dipakai output-only)
    wire _unused = &{oSPI_MISO_IN, oINTERRUPT_IN, 1'b0};

    // ------------------------------------------------------------------
    // Core
    // ------------------------------------------------------------------
    fault_injection_detection_core u_core (
        .iCLK       (iCLK),
        .iRST       (iRST),
        .iSPI_CS    (iSPI_CS),
        .iSPI_SCK   (iSPI_SCK),
        .iSPI_MOSI  (iSPI_MOSI),
        .oSPI_MISO  (oSPI_MISO_OUT),
        .oINTERRUPT (oINTERRUPT_OUT)
    );

endmodule

`default_nettype wire
