# Makefile for verilator testbench

VERILATOR_FLAGS = -Wall --trace \
    -Wno-fatal \
    -Wno-UNUSED \
    -Wno-UNDRIVEN \
    -Wno-PINMISSING

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# ==================================================
# qspi nor master
# ==================================================

nor_TOP = qspi_nor_master
nor_TB  = tb/tb_qspi_nor_master.cpp
nor_OBJ = obj_dir_qspi_nor

nor_SRC = qspi_nor_master.v \
		  ../fifo/fifo.v

$(nor_OBJ)/V$(nor_TOP).mk: $(nor_SRC) $(nor_TB)
	verilator $(VERILATOR_FLAGS) \
		--Mdir $(nor_OBJ) \
		--cc $(nor_SRC) \
		--exe $(nor_TB)

build_nor: $(nor_OBJ)/V$(nor_TOP).mk
	make -j -C $(nor_OBJ) -f V$(nor_TOP).mk V$(nor_TOP)

run_nor: build_nor
	./$(nor_OBJ)/V$(nor_TOP)

# ==================================================
# axi qspi nor master
# ==================================================

axi_qspi_nor_TOP = axi_qspi_nor
axi_qspi_nor_TB  = tb/tb_axi_qspi_nor.cpp
axi_qspi_nor_OBJ = obj_dir_axi_qspi_nor

axi_qspi_nor_SRC = axi_qspi_nor.v \
				   qspi_nor_master.v \
		  		   ../axi_fifo/fifo.v

$(axi_qspi_nor_OBJ)/V$(axi_qspi_nor_TOP).mk: $(axi_qspi_nor_SRC) $(axi_qspi_nor_TB)
	verilator $(VERILATOR_FLAGS) \
		--Mdir $(axi_qspi_nor_OBJ) \
		--cc $(axi_qspi_nor_SRC) \
		--exe $(axi_qspi_nor_TB)

build_axi_nor: $(axi_qspi_nor_OBJ)/V$(axi_qspi_nor_TOP).mk
	make -j -C $(axi_qspi_nor_OBJ) -f V$(axi_qspi_nor_TOP).mk V$(axi_qspi_nor_TOP)

run_axi_nor: build_axi_nor
	./$(axi_qspi_nor_OBJ)/V$(axi_qspi_nor_TOP)	

# ==================================================
# Default
# ==================================================

all: run_nand

clean:
	rm -rf obj_dir_qspi_nor obj_dir_axi_qspi_nor
	rm -f *.vcd *.o *.d *.exe

.PHONY: all \
	build_nor run_nor \
	build_axi_nor run_axi_nor \
	clean