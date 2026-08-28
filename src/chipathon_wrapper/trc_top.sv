// SPDX-License-Identifier: Apache-2.0
//
// Top-level wrapper untuk Chipathon 2026 - Tim A48
// Blok D (550 x 550 um), slot padframe W18-W22 + N01-N04
//
// Port list di bawah HARUS sama persis dengan 37 pin di A48_D.def.
// Referensi: A48_D_interface.yaml (pemetaan pin -> sel pad -> terminal)
//
//   iCLK       -> gf180mcu_fd_io__in_s (W20)  terminal Y, PU, PD
//   iRST       -> gf180mcu_fd_io__in_c (W21)  terminal Y, PU, PD
//   iSPI_CS    -> gf180mcu_fd_io__in_c (W22)  terminal Y, PU, PD
//   iSPI_SCK   -> gf180mcu_fd_io__in_s (N01)  terminal Y, PU, PD
//   iSPI_MOSI  -> gf180mcu_fd_io__in_c (N02)  terminal Y, PU, PD
//   oSPI_MISO  -> gf180mcu_fd_io__bi_t (N03)  terminal A, Y, OE, IE,
//                                             PU, PD, CS, SL, PDRV0, PDRV1
//   oINTERRUPT -> gf180mcu_fd_io__bi_t (N04)  idem

`default_nettype none

module trc_top (
`ifdef USE_POWER_PINS
    inout  wire VSS,                // gf180mcu_fd_io__dvss, slot W18
    inout  wire VDD,                // gf180mcu_fd_io__dvdd, slot W19
`endif

    // ===================== input pads =====================
    // Tiap pad input butuh 3 sinyal: Y (data masuk) + PU/PD (kontrol pull).
    input  wire iCLK,
    output wire iCLK_PU,
    output wire iCLK_PD,

    input  wire iRST,
    output wire iRST_PU,
    output wire iRST_PD,

    input  wire iSPI_CS,
    output wire iSPI_CS_PU,
    output wire iSPI_CS_PD,

    input  wire iSPI_SCK,
    output wire iSPI_SCK_PU,
    output wire iSPI_SCK_PD,

    input  wire iSPI_MOSI,
    output wire iSPI_MOSI_PU,
    output wire iSPI_MOSI_PD,

    // ============= bidirectional pad: oSPI_MISO =============
    input  wire oSPI_MISO_IN,       // terminal Y (pad -> blok)
    output wire oSPI_MISO_OUT,      // terminal A (blok -> pad)
    output wire oSPI_MISO_OE,
    output wire oSPI_MISO_IE,
    output wire oSPI_MISO_PU,
    output wire oSPI_MISO_PD,
    output wire oSPI_MISO_CS,
    output wire oSPI_MISO_SL,
    output wire oSPI_MISO_PDRV0,
    output wire oSPI_MISO_PDRV1,

    // ============= bidirectional pad: oINTERRUPT =============
    input  wire oINTERRUPT_IN,
    output wire oINTERRUPT_OUT,
    output wire oINTERRUPT_OE,
    output wire oINTERRUPT_IE,
    output wire oINTERRUPT_PU,
    output wire oINTERRUPT_PD,
    output wire oINTERRUPT_CS,
    output wire oINTERRUPT_SL,
    output wire oINTERRUPT_PDRV0,
    output wire oINTERRUPT_PDRV1
);

    // ------------------------------------------------------------------
    // Kontrol pull pada pad input.
    //
    // iRST aktif LOW   (RTL: if (!iRST) ...)      -> pull-up
    // iSPI_CS aktif LOW (RTL: if (iSPI_CS) idle)  -> pull-up
    //   Dua-duanya di-pull-up supaya kalau pin mengambang saat bring-up,
    //   chip tidak tersangkut di reset dan SPI tidak terpilih sendiri.
    //
    // Sisanya pull-down supaya level-nya terdefinisi, bukan mengambang.
    // JANGAN set PU dan PD sama-sama 1 pada pad yang sama.
    // ------------------------------------------------------------------
    assign iCLK_PU        = 1'b0;
    assign iCLK_PD        = 1'b1;

    assign iRST_PU        = 1'b1;   // aktif low -> jangan sampai ke-reset
    assign iRST_PD        = 1'b0;

    assign iSPI_CS_PU     = 1'b1;   // aktif low -> default deselected
    assign iSPI_CS_PD     = 1'b0;

    assign iSPI_SCK_PU    = 1'b0;
    assign iSPI_SCK_PD    = 1'b1;

    assign iSPI_MOSI_PU   = 1'b0;
    assign iSPI_MOSI_PD   = 1'b1;

    // ------------------------------------------------------------------
    // Konfigurasi pad bidirectional.
    // Kedua pin dipakai sebagai output murni:
    //   OE = 1  driver aktif
    //   IE = 0  input buffer mati (jalur _IN tidak dipakai)
    //   PU/PD = 0  tanpa pull, karena pad di-drive aktif
    //   CS = 0  pemilih buffer input, tidak relevan saat IE = 0
    //   SL = 0  slew cepat
    //
    // PDRV0/PDRV1 memilih kekuatan driver. Nilai 1/1 di sini cuma titik
    // awal. CEK pemetaan bit -> mA di dokumentasi gf180mcu IO sebelum
    // final; ini sekadar tie-off, gampang diganti.
    // ------------------------------------------------------------------
    assign oSPI_MISO_OE     = 1'b1;
    assign oSPI_MISO_IE     = 1'b0;
    assign oSPI_MISO_PU     = 1'b0;
    assign oSPI_MISO_PD     = 1'b0;
    assign oSPI_MISO_CS     = 1'b0;
    assign oSPI_MISO_SL     = 1'b0;
    assign oSPI_MISO_PDRV0  = 1'b1;
    assign oSPI_MISO_PDRV1  = 1'b1;

    assign oINTERRUPT_OE    = 1'b1;
    assign oINTERRUPT_IE    = 1'b0;
    assign oINTERRUPT_PU    = 1'b0;
    assign oINTERRUPT_PD    = 1'b0;
    assign oINTERRUPT_CS    = 1'b0;
    assign oINTERRUPT_SL    = 1'b0;
    assign oINTERRUPT_PDRV0 = 1'b1;
    assign oINTERRUPT_PDRV1 = 1'b1;

    // Jalur _IN tidak dipakai karena IE = 0
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
