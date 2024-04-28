# 4x4_2d_dct_accelerator
Zynq-7000과 AMBA AXI4를 사용하는 4x4 discrete cosine transform 연산 가속기.<br/> 
AXI 인터페이스를 익히고 RTL 설계를 경험하기 위한 프로젝트입니다.

# Things used in this project
- HW
    - Zybo Z7-10 FPGA
- SW 
    - Xilinx Vivado 2020.2 (linux, window)
    - Xilinx Vitis 2020.2 (window)

# Block diagram
![block_diagram](https://github.com/syjang14/4x4_2d_dct_accelerator/assets/59993682/6fcaea91-bc70-42c7-b53c-6c98c5e86d1b)


# How to run
## Run testbench
1. (linux) "./testbench/run 파일 실행

## Run on FPGA (Zybo Z7-10)
1. (window) Xilinx Vitis 실행
2. Create Application Project
3. Create a new platform from hardware (XSA) -> Browse... -> "./xsa/dct_4x4_opt.xsa" 추가
![2](https://github.com/syjang14/4x4_2d_dct_accelerator/assets/59993682/1b4372ba-6c45-4424-a612-a76d83d78964)
4. Application 프로젝트 이름 지정 -> Next (Domain 없음) -> Empty Application 템플릿 사용
5. src 폴더에 "./sw/dct.h"와 "./sw/main.c" 추가
![3](https://github.com/syjang14/4x4_2d_dct_accelerator/assets/59993682/cf9329cf-d275-4502-aaa9-587b921f59d4)
6. Build Project -> Launch on Hardware
7. 시리얼 터미널에서 transfer bytes 입력 및 결과 확인

# Result