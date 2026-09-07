typedef struct{
    unsigned int CPB;
    unsigned int STP;
    unsigned int RDR;
    unsigned int TDR;
    unsigned int CFG;
}uart_regspace;

#define UART_BASE_ADDR 0x80000100

int main() {
    volatile unsigned int *gpio = (volatile unsigned int *)0x80000000;
    gpio[1] = 0x0000ABCD;

    volatile uart_regspace *uart = ((volatile uart_regspace *) UART_BASE_ADDR);

    // Init UART
    uart->CPB = 290;
    uart->STP = 0;
    uart->CFG = 0;
    const char *msg = "Hello World!\r\n";

    while (1) {

        for (int i = 0; msg[i] != '\0'; i++) {

            // Put character into TX register
            uart->TDR = msg[i];

            // Start transmission
            uart->CFG |= (1UL << 0);

            // Wait for transmission to complete
            while (!(uart->CFG & (1UL << 2))) {}

            // Clear TX complete flag
            uart->CFG &= ~(1UL << 2);
        }
    }


    while(1);

    return 0;
}