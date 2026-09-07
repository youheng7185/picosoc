/*
 * axi_gen.c — AXI4-Lite Interconnect Generator
 *
 * Usage:
 *   Populate the peripheral list at the top of main(), then compile and run.
 *   The generated Verilog is written to the path set by OUTPUT_FILE.
 *
 *   gcc -o axi_gen axi_gen.c && ./axi_gen
 *
 * Peripheral types:
 *   PERIPH_MEM      — exact byte-range decode  (e.g. SRAM, DDR)
 *   PERIPH_IO_256B  — 256-byte peripheral window (mask 0xFFFF_FF00)
 *   PERIPH_IO_4KB   — 4 KiB peripheral window   (mask 0xFFFF_F000)
 *
 * API:
 *   add_peripheral(name, base, size_bytes, type)
 *   add_peripheral_mem(name, base, size_bytes)   // shorthand for PERIPH_MEM
 *   add_peripheral_io(name, base)                // shorthand for 256-byte I/O
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <ctype.h>

/* ------------------------------------------------------------------ */
/* Configuration                                                        */
/* ------------------------------------------------------------------ */

#define MAX_PERIPHERALS 32
#define OUTPUT_FILE     "axi_interconnect.v"
#define MODULE_NAME     "axi_interconnect"

typedef enum {
    PERIPH_MEM,      /* exact range: addr >= BASE && addr < BASE+SIZE */
    PERIPH_IO_256B,  /* 256-byte window: (addr & 0xFFFFFF00) == BASE  */
    PERIPH_IO_4KB    /* 4-KiB  window: (addr & 0xFFFFF000) == BASE   */
} periph_type_t;

typedef struct {
    char          name[64];   /* e.g. "DATA_MEM", "UART0", "GPIO" */
    uint32_t      base;
    uint32_t      size;       /* used for PERIPH_MEM; ignored for IO types */
    periph_type_t type;
} peripheral_t;

static peripheral_t peripherals[MAX_PERIPHERALS];
static int          n_periph = 0;

/* ------------------------------------------------------------------ */
/* Helper: add a peripheral to the list                                 */
/* ------------------------------------------------------------------ */

static void add_peripheral(const char *name, uint32_t base,
                            uint32_t size, periph_type_t type)
{
    if (n_periph >= MAX_PERIPHERALS) {
        fprintf(stderr, "Too many peripherals (max %d)\n", MAX_PERIPHERALS);
        exit(1);
    }
    strncpy(peripherals[n_periph].name, name,
            sizeof(peripherals[n_periph].name) - 1);
    peripherals[n_periph].base = base;
    peripherals[n_periph].size = size;
    peripherals[n_periph].type = type;
    n_periph++;
}

/* Shorthands */
static void add_peripheral_mem(const char *name,
                                uint32_t base, uint32_t size)
{
    add_peripheral(name, base, size, PERIPH_MEM);
}

static void add_peripheral_io(const char *name, uint32_t base)
{
    add_peripheral(name, base, 256, PERIPH_IO_256B);
}

static void add_peripheral_io_4k(const char *name, uint32_t base)
{
    add_peripheral(name, base, 4096, PERIPH_IO_4KB);
}

/* ------------------------------------------------------------------ */
/* String utilities                                                     */
/* ------------------------------------------------------------------ */

/* Lowercase copy of s into buf */
static void to_lower(const char *s, char *buf, size_t n)
{
    size_t i;
    for (i = 0; i < n - 1 && s[i]; i++)
        buf[i] = (char)tolower((unsigned char)s[i]);
    buf[i] = '\0';
}

/* ------------------------------------------------------------------ */
/* Code generation helpers                                              */
/* ------------------------------------------------------------------ */

/* Emit one slave port block */
static void emit_slave_port(FILE *f, int idx, const char *name)
{
    char lname[64];
    to_lower(name, lname, sizeof(lname));

    fprintf(f,
        "    // =====================================================\n"
        "    // Slave %d: %s (0x%08X)\n"
        "    // =====================================================\n"
        "    output wire [31:0] s%d_axi_awaddr,\n"
        "    output wire        s%d_axi_awvalid,\n"
        "    input  wire        s%d_axi_awready,\n"
        "\n"
        "    output wire [31:0] s%d_axi_wdata,\n"
        "    output wire [3:0]  s%d_axi_wstrb,\n"
        "    output wire        s%d_axi_wvalid,\n"
        "    input  wire        s%d_axi_wready,\n"
        "\n"
        "    input  wire [1:0]  s%d_axi_bresp,\n"
        "    input  wire        s%d_axi_bvalid,\n"
        "    output wire        s%d_axi_bready,\n"
        "\n"
        "    output wire [31:0] s%d_axi_araddr,\n"
        "    output wire        s%d_axi_arvalid,\n"
        "    input  wire        s%d_axi_arready,\n"
        "\n"
        "    input  wire [31:0] s%d_axi_rdata,\n"
        "    input  wire [1:0]  s%d_axi_rresp,\n"
        "    input  wire        s%d_axi_rvalid,\n"
        "    output wire        s%d_axi_rready",
        idx, name, peripherals[idx].base,
        idx, idx, idx,
        idx, idx, idx, idx,
        idx, idx, idx,
        idx, idx, idx,
        idx, idx, idx, idx
    );
}

/* ------------------------------------------------------------------ */
/* Main generation function                                             */
/* ------------------------------------------------------------------ */

static void generate(FILE *f)
{
    int i;
    int sel_bits = n_periph;   /* one sel bit per peripheral */

    /* ---- Module header & parameters ---- */
    fprintf(f,
        "// Auto-generated by axi_gen.c\n"
        "// DO NOT EDIT BY HAND\n"
        "\n"
        "module %s (\n"
        "    input  wire        clk_i,\n"
        "    input  wire        rst_ni,\n"
        "\n"
        "    // =====================================================\n"
        "    // Master interface (from core / bridge)\n"
        "    // =====================================================\n"
        "    // Write address channel\n"
        "    input  wire [31:0] m_axi_awaddr,\n"
        "    input  wire        m_axi_awvalid,\n"
        "    output wire        m_axi_awready,\n"
        "\n"
        "    // Write data channel\n"
        "    input  wire [31:0] m_axi_wdata,\n"
        "    input  wire [3:0]  m_axi_wstrb,\n"
        "    input  wire        m_axi_wvalid,\n"
        "    output wire        m_axi_wready,\n"
        "\n"
        "    // Write response channel\n"
        "    output wire [1:0]  m_axi_bresp,\n"
        "    output wire        m_axi_bvalid,\n"
        "    input  wire        m_axi_bready,\n"
        "\n"
        "    // Read address channel\n"
        "    input  wire [31:0] m_axi_araddr,\n"
        "    input  wire        m_axi_arvalid,\n"
        "    output wire        m_axi_arready,\n"
        "\n"
        "    // Read data channel\n"
        "    output wire [31:0] m_axi_rdata,\n"
        "    output wire [1:0]  m_axi_rresp,\n"
        "    output wire        m_axi_rvalid,\n"
        "    input  wire        m_axi_rready,\n"
        "\n",
        MODULE_NAME
    );

    /* ---- Slave ports ---- */
    for (i = 0; i < n_periph; i++) {
        emit_slave_port(f, i, peripherals[i].name);
        if (i < n_periph - 1)
            fprintf(f, ",\n\n");
        else
            fprintf(f, "\n");
    }
    fprintf(f, ");\n\n");

    /* ---- Address decode parameters / localparam ---- */
    fprintf(f,
        "    // =====================================================\n"
        "    // Address decode constants\n"
        "    // =====================================================\n"
    );
    for (i = 0; i < n_periph; i++) {
        fprintf(f, "    localparam [31:0] %-20s = 32'h%08X;\n",
                peripherals[i].name, peripherals[i].base);
        if (peripherals[i].type == PERIPH_MEM) {
            char szname[80];
            snprintf(szname, sizeof(szname), "%s_BYTES", peripherals[i].name);
            fprintf(f, "    localparam [31:0] %-20s = 32'h%08X;\n",
                    szname, peripherals[i].size);
        }
    }
    /* mask localparams */
    fprintf(f,
        "    localparam [31:0] PERIPH_MASK_256  = 32'hFFFF_FF00;\n"
        "    localparam [31:0] PERIPH_MASK_4K   = 32'hFFFF_F000;\n"
        "\n"
    );

    /* ---- Sel signals ---- */
    fprintf(f,
        "    // =====================================================\n"
        "    // Slave selection signals (%d slaves)\n"
        "    // =====================================================\n"
        "    reg [%d:0] aw_slave_sel;\n"
        "    reg [%d:0] ar_slave_sel;\n"
        "    reg default_bvalid_q;\n"
        "    reg default_rvalid_q;\n"
        "    wire default_write_select =\n"
        "           m_axi_awvalid\n"
        "        && (aw_slave_sel == %d'b0);\n"
        "    wire default_read_select =\n"
        "           m_axi_arvalid\n"
        "        && (ar_slave_sel == %d'b0);\n"
        "\n",
        n_periph,
        sel_bits - 1, sel_bits - 1,
        sel_bits, sel_bits
    );

    /* ---- decode_addr function ---- */
    fprintf(f,
        "    // =====================================================\n"
        "    // Address decode function\n"
        "    // =====================================================\n"
        "    function [%d:0] decode_addr;\n"
        "        input [31:0] addr;\n"
        "        reg [%d:0] sel;\n"
        "        begin\n"
        "            sel = %d'b0;\n",
        sel_bits - 1, sel_bits - 1, sel_bits
    );

    const char *kw = "if";
    for (i = 0; i < n_periph; i++) {
        peripheral_t *p = &peripherals[i];
        switch (p->type) {
        case PERIPH_MEM:
            fprintf(f,
                "            %s ((addr >= %s)\n"
                "                    && (addr < %s + %s_BYTES))\n"
                "                sel[%d] = 1'b1;\n",
                kw, p->name, p->name, p->name, i);
            break;
        case PERIPH_IO_256B:
            fprintf(f,
                "            %s ((addr & PERIPH_MASK_256) == %s)\n"
                "                sel[%d] = 1'b1;\n",
                kw, p->name, i);
            break;
        case PERIPH_IO_4KB:
            fprintf(f,
                "            %s ((addr & PERIPH_MASK_4K) == %s)\n"
                "                sel[%d] = 1'b1;\n",
                kw, p->name, i);
            break;
        }
        kw = "else if";
    }

    fprintf(f,
        "            decode_addr = sel;\n"
        "        end\n"
        "    endfunction\n"
        "\n"
    );
    /* ---- AW channel decode + write-route capture ---- */
    fprintf(f,
        "    // =====================================================\n"
        "    // Write address channel decode\n"
        "    // =====================================================\n"
        "    always @(*) begin\n"
        "        aw_slave_sel = %d'b0;\n"
        "        if (m_axi_awvalid)\n"
        "            aw_slave_sel = decode_addr(m_axi_awaddr);\n"
        "    end\n"
        "\n"
        "    reg [%d:0] write_slave_sel_q;\n"
        "    reg        write_aw_seen_q;\n"
        "    reg        write_w_seen_q;\n"
        "    wire       write_route_captured = write_aw_seen_q || write_w_seen_q;\n"
        "    wire [%d:0] write_slave_sel = write_route_captured\n"
        "                                ? write_slave_sel_q : aw_slave_sel;\n"
        "    wire write_default_select = write_route_captured\n"
        "                              ? (write_slave_sel == %d'b0)\n"
        "                              : (m_axi_awvalid && (aw_slave_sel == %d'b0));\n"
        "    wire write_aw_fire = m_axi_awvalid && m_axi_awready;\n"
        "    wire write_w_fire  = m_axi_wvalid  && m_axi_wready;\n"
        "\n"
        "    always @(posedge clk_i or negedge rst_ni) begin\n"
        "        if (!rst_ni) begin\n"
        "            write_slave_sel_q <= %d'b0;\n"
        "            write_aw_seen_q   <= 1'b0;\n"
        "            write_w_seen_q    <= 1'b0;\n"
        "        end else if (m_axi_bvalid && m_axi_bready) begin\n"
        "            write_slave_sel_q <= %d'b0;\n"
        "            write_aw_seen_q   <= 1'b0;\n"
        "            write_w_seen_q    <= 1'b0;\n"
        "        end else begin\n"
        "            if (write_aw_fire) begin\n"
        "                write_slave_sel_q <= aw_slave_sel;\n"
        "                write_aw_seen_q   <= 1'b1;\n"
        "            end\n"
        "            if (write_w_fire) begin\n"
        "                if (!write_route_captured)\n"
        "                    write_slave_sel_q <= aw_slave_sel;\n"
        "                write_w_seen_q <= 1'b1;\n"
        "            end\n"
        "        end\n"
        "    end\n"
        "\n",
        sel_bits,
        sel_bits - 1,
        sel_bits - 1,
        sel_bits, sel_bits,
        sel_bits, sel_bits
    );

    /* ---- AR channel decode ---- */
    fprintf(f,
        "    // =====================================================\n"
        "    // Read address channel decode\n"
        "    // =====================================================\n"
        "    always @(*) begin\n"
        "        ar_slave_sel = %d'b0;\n"
        "        if (m_axi_arvalid)\n"
        "            ar_slave_sel = decode_addr(m_axi_araddr);\n"
        "    end\n"
        "\n",
        sel_bits
    );

    /* ---- AW routing ---- */
    fprintf(f,
        "    // =====================================================\n"
        "    // Write address channel routing\n"
        "    // =====================================================\n"
    );
    for (i = 0; i < n_periph; i++) {
        fprintf(f,
            "    assign s%d_axi_awaddr  = m_axi_awaddr;\n"
            "    assign s%d_axi_awvalid = m_axi_awvalid & aw_slave_sel[%d];\n"
            "\n",
            i, i, i);
    }

    /* m_axi_awready */
    fprintf(f, "    assign m_axi_awready = !write_aw_seen_q &&\n");
    fprintf(f, "                           (");
    for (i = 0; i < n_periph; i++) {
        fprintf(f, "(s%d_axi_awready & aw_slave_sel[%d])", i, i);
        fprintf(f, " |\n                            ");
    }
    fprintf(f, "(default_write_select & !default_bvalid_q));\n\n");

    /* ---- W routing ---- */
    fprintf(f,
        "    // =====================================================\n"
        "    // Write data channel routing\n"
        "    // =====================================================\n"
    );
    for (i = 0; i < n_periph; i++) {
        fprintf(f,
            "    assign s%d_axi_wdata  = m_axi_wdata;\n"
            "    assign s%d_axi_wstrb  = m_axi_wstrb;\n"
            "    assign s%d_axi_wvalid = m_axi_wvalid & write_slave_sel[%d];\n"
            "\n",
            i, i, i, i);
    }

    fprintf(f, "    assign m_axi_wready = !write_w_seen_q &&\n");
    fprintf(f, "                          (");
    for (i = 0; i < n_periph; i++) {
        fprintf(f, "(s%d_axi_wready & write_slave_sel[%d])", i, i);
        fprintf(f, " |\n                           ");
    }
    fprintf(f, "(write_default_select & !default_bvalid_q));\n\n");

    /* ---- Default DECERR for writes ---- */
    fprintf(f,
        "    always @(posedge clk_i or negedge rst_ni) begin\n"
        "        if (!rst_ni)\n"
        "            default_bvalid_q <= 1'b0;\n"
        "        else if (write_route_captured\n"
        "                && (write_slave_sel == %d'b0)\n"
        "                && write_aw_seen_q && write_w_seen_q)\n"
        "            default_bvalid_q <= 1'b1;\n"
        "        else if (default_bvalid_q && m_axi_bready)\n"
        "            default_bvalid_q <= 1'b0;\n"
        "    end\n"
        "\n",
        sel_bits
    );

    /* ---- B routing ---- */
    fprintf(f,
        "    // =====================================================\n"
        "    // Write response channel routing\n"
        "    // =====================================================\n"
    );
    for (i = 0; i < n_periph; i++)
        fprintf(f, "    assign s%d_axi_bready = m_axi_bready;\n", i);
    fprintf(f, "\n");

    fprintf(f, "    assign m_axi_bresp =");
    for (i = 0; i < n_periph; i++)
        fprintf(f, " s%d_axi_bvalid ? s%d_axi_bresp :\n                        ", i, i);
    fprintf(f, " default_bvalid_q ? 2'b11 :\n                         2'b00;\n\n");

    fprintf(f, "    assign m_axi_bvalid =");
    for (i = 0; i < n_periph; i++) {
        fprintf(f, " s%d_axi_bvalid |", i);
        if ((i & 3) == 3) fprintf(f, "\n                         ");
    }
    fprintf(f, "\n                          default_bvalid_q;\n\n");

    /* ---- AR routing ---- */
    fprintf(f,
        "    // =====================================================\n"
        "    // Read address channel routing\n"
        "    // =====================================================\n"
    );
    for (i = 0; i < n_periph; i++) {
        fprintf(f,
            "    assign s%d_axi_araddr  = m_axi_araddr;\n"
            "    assign s%d_axi_arvalid = m_axi_arvalid & ar_slave_sel[%d];\n"
            "\n",
            i, i, i);
    }

    fprintf(f, "    assign m_axi_arready = ");
    for (i = 0; i < n_periph; i++) {
        fprintf(f, "(s%d_axi_arready & ar_slave_sel[%d]) |\n"
                   "                           ", i, i);
    }
    fprintf(f, "(default_read_select & !default_rvalid_q);\n\n");

    /* ---- Default DECERR for reads ---- */
    fprintf(f,
        "    always @(posedge clk_i or negedge rst_ni) begin\n"
        "        if (!rst_ni)\n"
        "            default_rvalid_q <= 1'b0;\n"
        "        else if (default_read_select && m_axi_arready)\n"
        "            default_rvalid_q <= 1'b1;\n"
        "        else if (default_rvalid_q && m_axi_rready)\n"
        "            default_rvalid_q <= 1'b0;\n"
        "    end\n"
        "\n"
    );

    /* ---- R routing ---- */
    fprintf(f,
        "    // =====================================================\n"
        "    // Read data channel routing\n"
        "    // =====================================================\n"
    );
    for (i = 0; i < n_periph; i++)
        fprintf(f, "    assign s%d_axi_rready = m_axi_rready;\n", i);
    fprintf(f, "\n");

    fprintf(f, "    assign m_axi_rdata  =");
    for (i = 0; i < n_periph; i++)
        fprintf(f, " s%d_axi_rvalid ? s%d_axi_rdata :\n                        ", i, i);
    fprintf(f, " default_rvalid_q ? 32'b0 :\n                         32'h0;\n\n");

    fprintf(f, "    assign m_axi_rresp  =");
    for (i = 0; i < n_periph; i++)
        fprintf(f, " s%d_axi_rvalid ? s%d_axi_rresp :\n                        ", i, i);
    fprintf(f, " default_rvalid_q ? 2'b11 :\n                         2'b00;\n\n");

    fprintf(f, "    assign m_axi_rvalid =");
    for (i = 0; i < n_periph; i++) {
        fprintf(f, " s%d_axi_rvalid |", i);
        if ((i & 3) == 3) fprintf(f, "\n                         ");
    }
    fprintf(f, "\n                          default_rvalid_q;\n\n");

    fprintf(f, "endmodule\n");
}

/* ------------------------------------------------------------------ */
/* Entry point — define your system here                               */
/* ------------------------------------------------------------------ */

int main(void)
{
    /* ----------------------------------------------------------------
     * Populate your system's address map below.
     * Order matters inside PERIPH_MEM entries (checked first to last).
     * IO entries are matched with a mask and have no explicit ordering
     * requirement, but earlier entries take priority in the if/else chain.
     * ---------------------------------------------------------------- */

    /* Memory slaves */
    add_peripheral_mem("INSTR_MEM",  0x10000000, 0x00008000);   /* 256 KiB  */
    add_peripheral_mem("DATA_MEM", 0x20000000, 0x00008000);   /*  32 KiB  */
    // add_peripheral_mem("DDR_MEM",   0x40000000, 0x40000000);   /*   1 GiB  */

    // /* CLINT / PLIC — large aligned memory-mapped ranges */
    // add_peripheral_mem("CLINT",     0x02000000, 0x00010000);   /*  64 KiB  */
    // add_peripheral_mem("PLIC",      0x0C000000, 0x00400000);   /*   4 MiB  */

    // /* JTAG UART — exact 256-byte range (use MEM decode to avoid conflicts) */
    // add_peripheral_mem("JTAG_UART", 0x70000000, 0x00000100);   /* 256 B    */

    /* 256-byte peripheral windows at 0x8000_0x00 */
    add_peripheral_io("GPIO",      0x80000000);
    add_peripheral_io("UART0",     0x80000100);
    // add_peripheral_io("TIMER",     0x80000200);
    // add_peripheral_io("HDMI_CTRL", 0x80000300);
    // add_peripheral_io("I2C",       0x80000400);
    // add_peripheral_io("QSPI",      0x80000500);

    /* 4-KiB window example (CNN accelerator register bank) */
    // add_peripheral_io_4k("CNN_ACCEL", 0x80001000);

    /* ----------------------------------------------------------------
     * Generate
     * ---------------------------------------------------------------- */
    FILE *f = fopen(OUTPUT_FILE, "w");
    if (!f) {
        perror("fopen");
        return 1;
    }

    generate(f);
    fclose(f);

    printf("Generated %s with %d slaves.\n", OUTPUT_FILE, n_periph);
    return 0;
}