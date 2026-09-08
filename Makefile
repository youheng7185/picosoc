# Makefile for MDIO Verilator testbench

VERILATOR_FLAGS = -Wall --trace \
    -Wno-fatal \
    -Wno-UNUSED \
    -Wno-UNDRIVEN \
    -Wno-PINMISSING

# ==================================================
# axil ram
# ==================================================

axil_ram_TOP = axil_ram
axil_ram_TB  = tb/tb_axil_ram.cpp
axil_ram_OBJ = obj_dir_axil_ram

axil_ram_SRC = rtl/axil_block_ram/axil_ram.v

$(axil_ram_OBJ)/V$(axil_ram_TOP).mk: $(axil_ram_SRC) $(axil_ram_TB)
	verilator $(VERILATOR_FLAGS) \
		--Mdir $(axil_ram_OBJ) \
		--cc $(axil_ram_SRC) \
		--exe $(axil_ram_TB)

build_axil_ram: $(axil_ram_OBJ)/V$(axil_ram_TOP).mk
	make -j -C $(axil_ram_OBJ) -f V$(axil_ram_TOP).mk V$(axil_ram_TOP)

run_axil_ram: build_axil_ram
	./$(axil_ram_OBJ)/V$(axil_ram_TOP)

# ==================================================
# soc
# ==================================================

picosoc_TOP = picosoc
picosoc_TB  = tb/tb_picosoc.cpp
picosoc_OBJ = obj_dir_picosoc

picosoc_SRC = rtl/picosoc.v \
				rtl/picorv32/picorv32.v \
				rtl/axi_gpio/axi_gpio.v \
				rtl/axi_interconnect/axi_interconnect.v \
				rtl/axil_block_ram/axil_ram.v \
				rtl/axil_block_ram/axil_rom_verilator.v \
				rtl/axi_uart/axi_uart.v \
				rtl/axi_uart/uart_rx.v \
				rtl/axi_uart/uart_tx.v \
				rtl/axi_uart/uart.v \
				rtl/axi_qspi_nor/axi_qspi_nor_xilinx.v \
				rtl/axi_qspi_nor/axi_qspi_nor.v \
				rtl/axi_qspi_nor/ODDR.v \
				rtl/axi_qspi_nor/qspi_nor_master.v \
				rtl/fifo/fifo.v \
				rtl/axi_fifo/axi_fifo.v

$(picosoc_OBJ)/V$(picosoc_TOP).mk: $(picosoc_SRC) $(picosoc_TB)
	verilator $(VERILATOR_FLAGS) \
		--Mdir $(picosoc_OBJ) \
		--cc $(picosoc_SRC) \
		--exe $(picosoc_TB)

build_picosoc: $(picosoc_OBJ)/V$(picosoc_TOP).mk
	make -j -C $(picosoc_OBJ) -f V$(picosoc_TOP).mk V$(picosoc_TOP)

run_picosoc: build_picosoc
	./$(picosoc_OBJ)/V$(picosoc_TOP)

# ==================================================
# Default
# ==================================================

all: run_axil_ram run_picosoc

clean:
	rm -rf obj_dir_axil_ram obj_dir_picosoc
	rm -f *.vcd *.o *.d *.exe

.PHONY: all \
	build_axil_ram run_axil_ram \
	build_picosoc run_picosoc \
	clean