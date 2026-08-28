#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

int main(void) {
    // Parameters (same as your Python code)
    const double ppr = 3.6;    // petals per 1 revolution
    const int nr = 30;         // radius resolution
    const int pr = 30;         // petal resolution
    const int pn = 40;         // total number of petals
    const double pf = 2.0;     // petal tilt factor
    const double ps = 5.0 / 4.0; // petal separation
    double ol[2] = {0.2, 1.02};  // openness [inner, outer]

    // Derived parameters
    int ntheta = pn * pr + 1;  // number of theta samples (e.g. 1201)
    double pt = (1.0 / ppr) * M_PI * 2.0; // petal angle increment per revolution
    double theta_max = pn * pt;

    // Allocate and compute 1D arrays for theta and phi
    double *theta = (double *)malloc(ntheta * sizeof(double));
    double *phi   = (double *)malloc(ntheta * sizeof(double));
    if (!theta || !phi) {
        fprintf(stderr, "Memory allocation error\n");
        exit(EXIT_FAILURE);
    }
    for (int j = 0; j < ntheta; j++) {
        theta[j] = theta_max * j / (ntheta - 1);
        double val = ol[0] + (ol[1] - ol[0]) * j / (double)(ntheta - 1);
        phi[j] = (M_PI / 2.0) * (val * val);
    }

    // Allocate arrays for the 2D grid outputs.
    // These arrays are stored in row-major order:
    // index = i * ntheta + j, with i = 0 ... nr-1 and j = 0 ... ntheta-1.
    double *X = (double *)malloc(nr * ntheta * sizeof(double));
    double *Y = (double *)malloc(nr * ntheta * sizeof(double));
    double *Z = (double *)malloc(nr * ntheta * sizeof(double));
    double *C = (double *)malloc(nr * ntheta * sizeof(double));
    if (!X || !Y || !Z || !C) {
        fprintf(stderr, "Memory allocation error\n");
        exit(EXIT_FAILURE);
    }

    // Loop over radius (R) and theta values to compute the surfaces.
    // Here, r corresponds to a linear spacing in [0,1] (R = r),
    // and theta[j] and phi[j] are the corresponding angular values.
    for (int i = 0; i < nr; i++) {
        double r = (nr == 1 ? 0.0 : (double)i / (nr - 1));
        for (int j = 0; j < ntheta; j++) {
            double th = theta[j];
            // Compute x as in Python:
            double mod_val = fmod(ppr * th, 2.0 * M_PI);
            double term = 1.0 - (mod_val / M_PI);
            term = term * term; // squared
            double x_val = 1.0 - ( pow((ps * term - 0.25), 2) / 2.0 );

            // Compute y based on r and phi[j]
            double y_val = pf * (r * r) * pow((1.28 * r - 1.0), 2) * sin(phi[j]);

            // Compute R2 as the weighted combination
            double r2 = x_val * (r * sin(phi[j])) + y_val * cos(phi[j]);

            // Compute (X, Y, Z) coordinates
            double X_val = r2 * sin(th);
            double Y_val = r2 * cos(th);
            double Z_val = x_val * (r * cos(phi[j]) - y_val * sin(phi[j]));

            // Compute the color metric C as the Euclidean norm
            double C_val = sqrt(X_val * X_val + Y_val * Y_val + Z_val * Z_val);

            int idx = i * ntheta + j;
            X[idx] = X_val;
            Y[idx] = Y_val;
            Z[idx] = Z_val;
            C[idx] = C_val;
        }
    }

    // Write the computed data to a binary file.
    // File format:
    // [int nr][int ntheta][double array X][double array Y][double array Z][double array C]
    FILE *fp = fopen("output.bin", "wb");
    if (!fp) {
        fprintf(stderr, "Failed to open output file for writing\n");
        exit(EXIT_FAILURE);
    }
    fwrite(&nr, sizeof(int), 1, fp);
    fwrite(&ntheta, sizeof(int), 1, fp);
    fwrite(X, sizeof(double), nr * ntheta, fp);
    fwrite(Y, sizeof(double), nr * ntheta, fp);
    fwrite(Z, sizeof(double), nr * ntheta, fp);
    fwrite(C, sizeof(double), nr * ntheta, fp);
    fclose(fp);

    // Free allocated memory.
    free(theta);
    free(phi);
    free(X);
    free(Y);
    free(Z);
    free(C);

    return 0;
}
