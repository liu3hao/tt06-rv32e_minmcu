# Makefile
# See https://docs.cocotb.org/en/stable/quickstart.html for more info

INSTALL_COCOTBEXT_SPI := $(shell \
	if ! pip show cocotbext-spi >/dev/null 2>&1; then \
        echo "Package 'cocotbext-spi' is not installed. Installing..."; \
        pip install cocotbext-spi==0.4.0; \
    fi \
)

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
SRC_DIR = $(PWD)/../src
PROJECT_SOURCES = project.sv
PROJECT_SOURCES += spi_controller.sv
PROJECT_SOURCES += mem_bus.sv
PROJECT_SOURCES += registers.sv
PROJECT_SOURCES += alu.sv
PROJECT_SOURCES += uart.sv

PDK_ROOT = $(OPENLANE_PDK_ROOT)

ifneq ($(GATES),yes)

# RTL simulation:
SIM_BUILD				= sim_build/rtl
VERILOG_SOURCES += $(addprefix $(SRC_DIR)/,$(PROJECT_SOURCES))
COMPILE_ARGS 		+= -I$(SRC_DIR)

else

# Gate level simulation:
SIM_BUILD				= sim_build/gl
COMPILE_ARGS    += -DGL_TEST
COMPILE_ARGS    += -DFUNCTIONAL
COMPILE_ARGS    += -DUSE_POWER_PINS
COMPILE_ARGS    += -DSIM
COMPILE_ARGS    += -DUNIT_DELAY=\#1
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v
VERILOG_SOURCES += $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v

# this gets copied in by the GDS action workflow
VERILOG_SOURCES += $(PWD)/gate_level_netlist.v

endif

# Include the testbench sources:
VERILOG_SOURCES += $(PWD)/tb.v 
TOPLEVEL = tb

# MODULE is the basename of the Python test file
MODULE = test

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

gtk:
	open tb.vcd -a gtkwave

prep:
	cp $(PWD)/../runs/wokwi/results/final/verilog/gl/tt_um_rv32e_cpu.v gate_level_netlist.v