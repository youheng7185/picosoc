# Makefile for MDIO Verilator testbench

VERILATOR_FLAGS = -Wall --trace \
    -Wno-fatal \
    -Wno-UNUSED \
    -Wno-UNDRIVEN \
    -Wno-PINMISSING

# ==================================================
# Original MDIO master
# ==================================================

MDIO_TOP = mdio_master
MDIO_TB  = tb/tb_mdio_master.cpp
MDIO_OBJ = obj_dir_mdio

$(MDIO_OBJ)/V$(MDIO_TOP).mk: $(MDIO_TOP).v $(MDIO_TB)
	verilator $(VERILATOR_FLAGS) \
		--Mdir $(MDIO_OBJ) \
		--cc $(MDIO_TOP).v \
		--exe $(MDIO_TB)

build_mdio: $(MDIO_OBJ)/V$(MDIO_TOP).mk
	make -j -C $(MDIO_OBJ) -f V$(MDIO_TOP).mk V$(MDIO_TOP)

run_mdio: build_mdio
	./$(MDIO_OBJ)/V$(MDIO_TOP)

# ==================================================
# AXI wrapped MDIO master
# ==================================================

AXI_TOP = axi_mdio
AXI_TB  = tb/tb_axi_mdio.cpp
AXI_OBJ = obj_dir_axi_mdio

AXI_SRC = axi_mdio.v \
          mdio_master.v

$(AXI_OBJ)/V$(AXI_TOP).mk: $(AXI_SRC) $(AXI_TB)
	verilator $(VERILATOR_FLAGS) \
		--Mdir $(AXI_OBJ) \
		--cc $(AXI_SRC) \
		--exe $(AXI_TB)

build_axi_mdio: $(AXI_OBJ)/V$(AXI_TOP).mk
	make -j -C $(AXI_OBJ) -f V$(AXI_TOP).mk V$(AXI_TOP)

run_axi_mdio: build_axi_mdio
	./$(AXI_OBJ)/V$(AXI_TOP)

# ==================================================
# Default
# ==================================================

all: run_mdio run_axi_mdio

clean:
	rm -rf obj_dir_mdio obj_dir_axi_mdio
	rm -f *.vcd *.o *.d *.exe

.PHONY: all \
	build_mdio run_mdio \
	build_axi_mdio run_axi_mdio \
	clean