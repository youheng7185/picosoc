# Makefile for verilator testbench

VERILATOR_FLAGS = -Wall --trace \
    -Wno-fatal \
    -Wno-UNUSED \
    -Wno-UNDRIVEN \
    -Wno-PINMISSING

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# ==================================================
# axi stream slave
# ==================================================

axi_stream_slave_TOP = axi_stream_slave
axi_stream_slave_TB  = tb/tb_axi_stream_slave.cpp
axi_stream_slave_OBJ = obj_dir_axi_stream_slave

axi_stream_slave_SRC = axi_stream_slave.v

$(axi_stream_slave_OBJ)/V$(axi_stream_slave_TOP).mk: $(axi_stream_slave_SRC) $(axi_stream_slave_TB)
	verilator $(VERILATOR_FLAGS) \
		--Mdir $(axi_stream_slave_OBJ) \
		--cc $(axi_stream_slave_SRC) \
		--exe $(axi_stream_slave_TB)

build_stream_s: $(axi_stream_slave_OBJ)/V$(axi_stream_slave_TOP).mk
	make -j -C $(axi_stream_slave_OBJ) -f V$(axi_stream_slave_TOP).mk V$(axi_stream_slave_TOP)

run_stream_s: build_stream_s
	./$(axi_stream_slave_OBJ)/V$(axi_stream_slave_TOP)

# ==================================================
# axi stream master
# ==================================================

axi_stream_master_TOP = axi_stream_master
axi_stream_master_TB  = tb/tb_axi_stream_master.cpp
axi_stream_master_OBJ = obj_dir_axi_stream_master

axi_stream_master_SRC = axi_stream_master.v

$(axi_stream_master_OBJ)/V$(axi_stream_master_TOP).mk: $(axi_stream_master_SRC) $(axi_stream_master_TB)
	verilator $(VERILATOR_FLAGS) \
		--Mdir $(axi_stream_master_OBJ) \
		--cc $(axi_stream_master_SRC) \
		--exe $(axi_stream_master_TB)

build_stream_m: $(axi_stream_master_OBJ)/V$(axi_stream_master_TOP).mk
	make -j -C $(axi_stream_master_OBJ) -f V$(axi_stream_master_TOP).mk V$(axi_stream_master_TOP)

run_stream_m: build_stream_m
	./$(axi_stream_master_OBJ)/V$(axi_stream_master_TOP)

# ==================================================
# axi stream data processing template
# ==================================================

axi_stream_data_processing_TOP = axi_stream_data_processing
axi_stream_data_processing_TB  = tb/tb_axi_stream_data_processing.cpp
axi_stream_data_processing_OBJ = obj_dir_axi_stream_data_processing

axi_stream_data_processing_SRC = axi_stream_data_processing.v

$(axi_stream_data_processing_OBJ)/V$(axi_stream_data_processing_TOP).mk: $(axi_stream_data_processing_SRC) $(axi_stream_data_processing_TB)
	verilator $(VERILATOR_FLAGS) \
		--Mdir $(axi_stream_data_processing_OBJ) \
		--cc $(axi_stream_data_processing_SRC) \
		--exe $(axi_stream_data_processing_TB)

build_data_process: $(axi_stream_data_processing_OBJ)/V$(axi_stream_data_processing_TOP).mk
	make -j -C $(axi_stream_data_processing_OBJ) -f V$(axi_stream_data_processing_TOP).mk V$(axi_stream_data_processing_TOP)

run_data_process: build_data_process
	./$(axi_stream_data_processing_OBJ)/V$(axi_stream_data_processing_TOP)

# ==================================================
# Default
# ==================================================

all: run_stream_s

clean:
	rm -rf obj_dir_axi_stream_slave obj_dir_axi_stream_master obj_dir_axi_stream_data_processing
	rm -f *.vcd *.o *.d *.exe

.PHONY: all \
	build_stream_s run_stream_s\
	build_stream_m run_stream_m\
	build_data_process run_data_process\
	clean