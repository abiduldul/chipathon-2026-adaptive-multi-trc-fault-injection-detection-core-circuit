###############################################################################
# SDC minimal untuk hardening blok trc_top (LibreLane Classic flow) - Tim A48
#
# Simpan sebagai: librelane/trc_top.sdc
#
# Ini versi awal yang cukup untuk run pertama. Setelah run berhasil,
# ambil hasil write_sdc dari direktori run dan pakai versi lengkapnya
# (berisi set_load / set_driving_cell per port) seperti yang dilakukan
# repo A34 di librelane/chip_core.sdc.
###############################################################################

current_design trc_top
set_units -time ns

###############################################################################
# Clock
###############################################################################
create_clock -name iCLK -period $::env(CLOCK_PERIOD) [get_ports {iCLK}]
set_clock_transition 0.15 [get_clocks {iCLK}]
set_clock_uncertainty 0.25 [get_clocks {iCLK}]
set_propagated_clock [get_clocks {iCLK}]

###############################################################################
# I/O delay
# 20% dari periode clock di kedua arah.
###############################################################################
set io_delay [expr $::env(CLOCK_PERIOD) * 0.20]

set clk_indx [lsearch [all_inputs] [get_port iCLK]]
set input_ports [lreplace [all_inputs] $clk_indx $clk_indx]
set_input_delay  $io_delay -clock [get_clocks {iCLK}] -add_delay $input_ports
set_output_delay $io_delay -clock [get_clocks {iCLK}] -add_delay [all_outputs]

###############################################################################
# iSPI_SCK adalah clock SPI asinkron terhadap iCLK.
# spi_slave_interface men-sample dengan posedge iSPI_SCK, dan hasilnya
# disinkronkan ke domain iCLK lewat done_sync. Tanpa deklarasi ini,
# STA akan melaporkan path lintas domain yang tidak relevan.
#
# Cek ulang setelah run pertama - kalau iSPI_SCK memang mau
# diperlakukan sebagai clock sungguhan, ganti jadi create_clock.
###############################################################################
set_false_path -from [get_ports {iSPI_SCK}]
set_false_path -from [get_ports {iSPI_CS}]
set_false_path -from [get_ports {iRST}]

###############################################################################
# Driving cell & load
###############################################################################
set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_4 -pin {ZN} \
    [get_ports {iCLK}]
set_driving_cell -lib_cell gf180mcu_fd_sc_mcu7t5v0__inv_1 -pin {ZN} \
    $input_ports

set_load -pin_load 0.0729 [all_outputs]

###############################################################################
# Design rules
###############################################################################
set_max_transition 3.0 [current_design]
set_max_fanout 128 [current_design]