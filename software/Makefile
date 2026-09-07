CROSS = riscv32-unknown-elf-
CFLAGS = -O2 -Wall

TARGET = firmware
OUTPUT_DIR = output

ELF = $(OUTPUT_DIR)/$(TARGET).elf
BIN = $(OUTPUT_DIR)/$(TARGET).bin
HEX = $(OUTPUT_DIR)/$(TARGET).hex

MEM0 = $(OUTPUT_DIR)/$(TARGET)_b0.mem
MEM1 = $(OUTPUT_DIR)/$(TARGET)_b1.mem
MEM2 = $(OUTPUT_DIR)/$(TARGET)_b2.mem
MEM3 = $(OUTPUT_DIR)/$(TARGET)_b3.mem

# Automatically include all C and assembly source files
SRCS = start.s main.c firmware.c

all: $(ELF) $(BIN) $(HEX) $(MEM0) $(MEM1) $(MEM2) $(MEM3)

# Create output directory
$(OUTPUT_DIR):
	mkdir -p $(OUTPUT_DIR)

# Build ELF
$(ELF): sections.lds $(SRCS) | $(OUTPUT_DIR)
	$(CROSS)gcc $(CFLAGS) \
		-mabi=ilp32 -march=rv32im \
		-Wl,--build-id=none,-Bstatic,-T,sections.lds,--strip-debug \
		-ffreestanding -nostdlib \
		-o $@ $(SRCS)

# Convert ELF to binary
$(BIN): $(ELF)
	$(CROSS)objcopy -O binary $< $@

# Convert ELF to Intel HEX
$(HEX): $(ELF)
	$(CROSS)objcopy -O ihex $< $@

# Split binary into 4 byte-lane files
$(MEM0): $(BIN)
	od -v -A n -t x1 $(BIN) | tr -s ' ' '\n' | grep -v '^$$' | \
		awk 'NR%4==1' | tr '[:lower:]' '[:upper:]' > $@

$(MEM1): $(BIN)
	od -v -A n -t x1 $(BIN) | tr -s ' ' '\n' | grep -v '^$$' | \
		awk 'NR%4==2' | tr '[:lower:]' '[:upper:]' > $@

$(MEM2): $(BIN)
	od -v -A n -t x1 $(BIN) | tr -s ' ' '\n' | grep -v '^$$' | \
		awk 'NR%4==3' | tr '[:lower:]' '[:upper:]' > $@

$(MEM3): $(BIN)
	od -v -A n -t x1 $(BIN) | tr -s ' ' '\n' | grep -v '^$$' | \
		awk 'NR%4==0' | tr '[:lower:]' '[:upper:]' > $@

clean:
	rm -rf $(OUTPUT_DIR)

.PHONY: all clean