#include <math.h>

void matrix_multiply(float A[][4], float B[][4], float C[][4]) {
    int i, j, k;
    for(i=0; i<4; i++) {
        for(j=0; j<4; j++) {
            C[i][j] = 0;
            for(k=0; k<4; k++) {
                C[i][j] += 1.0 * A[i][k] * B[k][j];
            }
        }
    }
}

void matrix_multiply_u16(float A[][4], u16 B[][4], float C[][4]) {
    int i, j, k;
    for(i=0; i<4; i++) {
        for(j=0; j<4; j++) {
            C[i][j] = 0;
            for(k=0; k<4; k++) {
                C[i][j] += 1.0 * A[i][k] * B[k][j];
            }
        }
    }
}

void matrix_multiply_hadamard(float A[][4], float B[][4], float C[][4]) {
    int i, j;
    for(i=0; i<4; i++) {
        for(j=0; j<4; j++) {
            C[i][j] = 1.0 * A[i][j] * B[i][j];
        }
    }
}

void print_matrix(float mat[][4]) {
    int i, j;
    for(i=0; i<4; i++) {
        for(j=0; j<4; j++) {
            printf("%.2f  ", mat[i][j]);
        }
        printf("\n");
    }
}

void print_matrix_u16(u16 mat[][4]) {
    int i, j;
    for(i=0; i<4; i++) {
        for(j=0; j<4; j++) {
            printf("%d  ", mat[i][j]);
        }
        printf("\n");
    }
}

void transpose(float mat[][4], float mat_t[][4]) {
    int i, j;
    for(i=0; i<4; i++) {
        for(j=0; j<4; j++) {
            mat_t[i][j] = mat[j][i];
        }
    }
}

void dct_4x4(u16 in[][4], float out[][4]) {
    float C[4][4] = { 
                     {1.0, 1.0, 1.0, 1.0},
                     {2.0, 1.0, -1.0, -2.0},
                     {1.0, -1.0, -1.0, 1.0},
                     {1.0, -2.0, 2.0, -1.0}
                    };
    float C_t[4][4];
    float S[4][4] = {
                     {0.25, 1/(2*sqrt(10)), 0.25, 1/(2*sqrt(10))},
                     {1/(2*sqrt(10)), 0.1, 1/(2*sqrt(10)), 0.1},
                     {0.25, 1/(2*sqrt(10)), 0.25, 1/(2*sqrt(10))},
                     {1/(2*sqrt(10)), 0.1, 1/(2*sqrt(10)), 0.1}
                    };
    float buf0[4][4];
    float buf1[4][4];

    transpose(C, C_t);

    matrix_multiply_u16(C, in, buf0);
    matrix_multiply(buf0, C_t, buf1);
    matrix_multiply_hadamard(buf1, S, out);
}
