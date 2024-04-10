#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "xparameters.h"
#include "xil_io.h"
#include "xtime_l.h"
#include "dct.h"

#define AXI_DATA_BYTE 32

// REG MAP
#define ADDR_AP_CTRL                    0x00
#define ADDR_RDMA_TRANSFER_BYTE_DATA_0  0x04
#define ADDR_RDMA_MEM_PTR_DATA_0        0x08
#define ADDR_WDMA_TRANSFER_BYTE_DATA_0  0x0c
#define ADDR_WDMA_MEM_PTR_DATA_0        0x10

#define CTRL_IDLE_MASK                  0x00000002
#define CTRL_DONE_MASK                  0x00000008

#define BASE_ADDR                       0x10000000

void hw_dct(void* dest, const void* source, size_t num) {
    u32 read_data;
	Xil_Out32((XPAR_DMA_IP_TOP_0_BASEADDR) + ADDR_RDMA_TRANSFER_BYTE_DATA_0, (u32)num);
	Xil_Out32((XPAR_DMA_IP_TOP_0_BASEADDR) + ADDR_RDMA_MEM_PTR_DATA_0, (u32) source );
	Xil_Out32((XPAR_DMA_IP_TOP_0_BASEADDR) + ADDR_WDMA_TRANSFER_BYTE_DATA_0, (u32)num);
	Xil_Out32((XPAR_DMA_IP_TOP_0_BASEADDR) + ADDR_WDMA_MEM_PTR_DATA_0, (u32) dest);

	while(1) {
		read_data = Xil_In32((XPAR_DMA_IP_TOP_0_BASEADDR) + ADDR_AP_CTRL);
	    if( (read_data & CTRL_IDLE_MASK) == CTRL_IDLE_MASK ) // IDLE check
	    	break;
	}
	Xil_Out32((XPAR_DMA_IP_TOP_0_BASEADDR) + ADDR_AP_CTRL, (u32)(0x00000001)); // start

 	while(1) {
		read_data = Xil_In32((XPAR_DMA_IP_TOP_0_BASEADDR) + ADDR_AP_CTRL);
	    if( (read_data & CTRL_DONE_MASK) == CTRL_DONE_MASK ) // DONE check
	    	break;
	}
}

int main() {
    u32 transfer_cnt;
    XTime tStart, tEnd;
    u16 dct_in[4][4];
    float dct_out[4][4];

    while(1) {
        do{
            printf("\n");
            printf("Input transfer bytes number : ");
            scanf("%u", &transfer_cnt);
        } while( !( (0 < transfer_cnt) && (transfer_cnt%AXI_DATA_BYTE == 0) && (transfer_cnt <= 67108864) ) );

        u16* rdma_baseaddr = (u16*) BASE_ADDR;
        u16* wdma_baseaddr = (u16*) (BASE_ADDR + transfer_cnt);

        // initialize data : 1, 2, 3, ..., 16
        for(int addr = 0; addr < (transfer_cnt/2); addr++) {
            rdma_baseaddr[addr] = (addr % 16) + 1;
        }

        // initialize data : 0 ~ 255, random
        // srand(time(NULL));
        // for(int addr = 0; addr < (transfer_cnt/2); addr++) {
        //     rdma_baseaddr[addr] = rand() % 256;
        // }

        Xil_DCacheDisable(); // flush to external mem.
        float transfer_bytes_display = transfer_cnt/1024;
        printf("\n");
    	printf("rdma_baseaddr : 0x%x\n", rdma_baseaddr);
    	printf("wdma_baseaddr : 0x%x\n", wdma_baseaddr);
    	printf("transfer_cnt size : %f Kbytes\n\n", transfer_bytes_display);

        printf("####### HW start #######\n");
        XTime_GetTime(&tStart);
    	hw_dct(wdma_baseaddr, rdma_baseaddr, transfer_cnt);
    	XTime_GetTime(&tEnd);
		printf("HW DCT time %.2f us.\n\n", 1.0 * (tEnd - tStart) / (COUNTS_PER_SECOND/1000000));

        ////// print for debug //////
        // printf("DCT in :\n");
        // for(int addr = 0; addr < (transfer_cnt/2); addr++) {
        //     if((addr)%16 == 0) {
        //         printf("(%d)\n", addr/16);
        //     }
        //     printf("%d ", rdma_baseaddr[addr]);
        //     if((addr+1)%4 == 0) {
        //         printf("\n");
        //     }
        // }
        // printf("\n");
        // printf("DCT out :\n");
        // for(int addr = (transfer_cnt/2); addr > 0; addr--) {
        //     if((addr)%16 == 0) {
        //         printf("(%d)\n", (transfer_cnt/2-addr)/16);
        //     }
        //     short data;
        //     data = wdma_baseaddr[addr-1];
        //     printf("%.2f ", (float)data / 16);
        //     if((addr-1)%4 == 0) {
        //         printf("\n");
        //     }
        // }


        printf("\n\n");
        printf("####### SW start #######\n");
        XTime_GetTime(&tStart);
        for(int i = 0; i < (transfer_cnt/32); i++) {
            for(int j = 0; j < 4; j++) {
                for(int k = 0; k < 4; k++) {
                    dct_in[j][k] = rdma_baseaddr[16*i+4*j+k];
                }
            }
            dct_4x4(dct_in, dct_out);

            ////// print for debug //////
            // (It makes SW DCT take longer.)
            // printf("DCT in (%d) :\n", i);
            // print_matrix_u16(dct_in);
            // printf("\n");
            // printf("DCT out (%d) :\n", i);
            // print_matrix(dct_out);
            // printf("\n");
        }
        XTime_GetTime(&tEnd);
        printf("SW DCT Time %.2f us.\n\n", 1.0 * (tEnd-tStart) / (COUNTS_PER_SECOND/1000000));
    }

    return 0;
}
