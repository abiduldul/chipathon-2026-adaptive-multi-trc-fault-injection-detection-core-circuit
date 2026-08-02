# Makefile (cocotb) -- Multi-TRC block
# Mirrors the tb/Makefile convention used in
# examples/librelane_rtl2gds_gf180/04_counter_alu_multimacro
#
# Usage:
#   make                 # pre-synthesis RTL simulation (behavioral)
#   make GATES=1         # post-synthesis gate-level simulation
#                        # (point this at LibreLane's synthesized netlist)
#   make wave            # open the resulting VCD in gtkwave

TOPLEVEL_LANG = verilog
SIM           ?= icarus
TOPLEVEL      = delay_paths
MODULE        = test_delay_paths

ifeq ($(GATES),1)
  # Post-synthesis: point at LibreLane's synthesized netlist + the
  # GF180MCU standard-cell Verilog models it was mapped to.
  VERILOG_SOURCES = $(PDK_ROOT)/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu9t5v0/verilog/gf180mcu_fd_sc_mcu9t5v0.v \
                     $(LIBRELANE_RUN_DIR)/final/verilog/gl/delay_paths.v
  COMPILE_ARGS    += -DGL_TEST -DFUNCTIONAL -DUNIT_DELAY=\#1
else
  # Pre-synthesis: plain RTL
  VERILOG_SOURCES = $(PWD)/../rtl/trc_behavioral_chain.sv \
                     $(PWD)/../rtl/delay_paths.sv
endif

include $(shell cocotb-config --makefiles)/Makefile.sim

wave:
	gtkwave dump.vcd
