#include <stddef.h>
#include <stdlib.h>
#include <string.h>

#include "mpi.h"
#include "dmumps_c.h"

#define DES_MUMPS_JOB_INIT (-1)
#define DES_MUMPS_JOB_END  (-2)
#define DES_MUMPS_JOB_ANALYZE 1
#define DES_MUMPS_JOB_FACTORIZE 2
#define DES_MUMPS_JOB_SOLVE 3
#define DES_MUMPS_USE_COMM_WORLD (-987654)

typedef struct {
  DMUMPS_STRUC_C id;
  MUMPS_INT *irn;
  MUMPS_INT *jcn;
  double *a;
  size_t *csr_value_index;
  int full_nnz;
  int n;
  MUMPS_INT8 supplied_nnz;
  int symmetry_mode;
  int pattern_ready;
  int analyzed;
  int factorized;
} des_mumps_handle_t;

static int des_mumps_mpi_started = 0;

static void des_mumps_copy_info(
    const des_mumps_handle_t *handle, int *info_primary, int *info_secondary)
{
  if (info_primary != NULL) {
    *info_primary = (handle != NULL) ? (int)handle->id.infog[0] : 0;
  }
  if (info_secondary != NULL) {
    *info_secondary = (handle != NULL) ? (int)handle->id.infog[1] : 0;
  }
}

static int des_mumps_ensure_sequential_mpi(void)
{
  int ierr;
  int argc = 0;
  char **argv = NULL;

  if (des_mumps_mpi_started) {
    return 0;
  }

  ierr = MPI_Init(&argc, &argv);
  if (ierr != 0) {
    return -1;
  }

  des_mumps_mpi_started = 1;
  return 0;
}

static void des_mumps_release_pattern(des_mumps_handle_t *handle)
{
  if (handle == NULL) {
    return;
  }

  free(handle->irn);
  free(handle->jcn);
  free(handle->a);
  free(handle->csr_value_index);
  handle->irn = NULL;
  handle->jcn = NULL;
  handle->a = NULL;
  handle->csr_value_index = NULL;
  handle->full_nnz = 0;
  handle->supplied_nnz = 0;
  handle->n = 0;
  handle->pattern_ready = 0;
  handle->analyzed = 0;
  handle->factorized = 0;

  handle->id.irn = NULL;
  handle->id.jcn = NULL;
  handle->id.a = NULL;
  handle->id.nnz = 0;
}

static int des_mumps_refresh_values(
    des_mumps_handle_t *handle, int full_nnz, const double *values)
{
  size_t k;

  if (handle == NULL || values == NULL || !handle->pattern_ready ||
      full_nnz != handle->full_nnz) {
    return -1;
  }

  for (k = 0; k < (size_t)handle->supplied_nnz; ++k) {
    handle->a[k] = values[handle->csr_value_index[k]];
  }

  return 0;
}

void *des_mumps_c_create(
    int symmetry_mode, int *info_primary, int *info_secondary)
{
  des_mumps_handle_t *handle;

  if (info_primary != NULL) {
    *info_primary = 0;
  }
  if (info_secondary != NULL) {
    *info_secondary = 0;
  }

  if (symmetry_mode < 0 || symmetry_mode > 2) {
    return NULL;
  }
  if (des_mumps_ensure_sequential_mpi() != 0) {
    return NULL;
  }

  handle = (des_mumps_handle_t *)calloc(1, sizeof(*handle));
  if (handle == NULL) {
    return NULL;
  }

  memset(&handle->id, 0, sizeof(handle->id));
  handle->symmetry_mode = symmetry_mode;
  handle->id.comm_fortran = DES_MUMPS_USE_COMM_WORLD;
  handle->id.par = 1;
  handle->id.sym = symmetry_mode;
  handle->id.job = DES_MUMPS_JOB_INIT;
  dmumps_c(&handle->id);
  des_mumps_copy_info(handle, info_primary, info_secondary);

  if (handle->id.infog[0] < 0) {
    free(handle);
    return NULL;
  }

  handle->id.icntl[0] = -1;
  handle->id.icntl[1] = -1;
  handle->id.icntl[2] = -1;
  handle->id.icntl[3] = 0;
  return (void *)handle;
}

int des_mumps_c_configure(
    void *opaque_handle, int ordering, double pivot_threshold,
    int refinement_steps, double refinement_tolerance, int error_analysis,
    int out_of_core, int null_pivot_detection, double null_pivot_tolerance,
    int *info_primary, int *info_secondary)
{
  des_mumps_handle_t *handle = (des_mumps_handle_t *)opaque_handle;

  if (handle == NULL || refinement_steps < 0 ||
      error_analysis < 0 || error_analysis > 2 ||
      (out_of_core != 0 && out_of_core != 1) ||
      (null_pivot_detection != 0 && null_pivot_detection != 1)) {
    return -1;
  }

  /*
   * MUMPS production controls:
   * ICNTL(7)  ordering
   * CNTL(1)   numerical pivoting threshold
   * ICNTL(10) internal iterative refinement
   * CNTL(2)   refinement stopping tolerance
   * ICNTL(11) backward-error analysis
   * ICNTL(22) in-core/out-of-core numerical factorization
   * ICNTL(24) null-pivot row detection
   * CNTL(3)   null-pivot threshold
   */
  handle->id.icntl[6] = (MUMPS_INT)ordering;
  handle->id.cntl[0] = pivot_threshold;
  handle->id.icntl[9] = (MUMPS_INT)refinement_steps;
  handle->id.cntl[1] = refinement_tolerance;
  handle->id.icntl[10] = (MUMPS_INT)error_analysis;
  handle->id.icntl[21] = (MUMPS_INT)out_of_core;
  handle->id.icntl[23] = (MUMPS_INT)null_pivot_detection;
  handle->id.cntl[2] = null_pivot_tolerance;

  des_mumps_copy_info(handle, info_primary, info_secondary);
  return 0;
}

int des_mumps_c_get_diagnostics(
    void *opaque_handle, int *ordering_used, int *negative_pivots,
    int *delayed_pivots, int *null_pivots, int *refinement_steps,
    int *out_of_core, double *scaled_residual, double *backward_error_1,
    double *backward_error_2)
{
  des_mumps_handle_t *handle = (des_mumps_handle_t *)opaque_handle;

  if (handle == NULL || ordering_used == NULL || negative_pivots == NULL ||
      delayed_pivots == NULL || null_pivots == NULL ||
      refinement_steps == NULL || out_of_core == NULL ||
      scaled_residual == NULL || backward_error_1 == NULL ||
      backward_error_2 == NULL) {
    return -1;
  }

  *ordering_used = (int)handle->id.infog[6];       /* INFOG(7)  */
  *negative_pivots = (int)handle->id.infog[11];   /* INFOG(12) */
  *delayed_pivots = (int)handle->id.infog[12];    /* INFOG(13) */
  *refinement_steps = (int)handle->id.infog[14];  /* INFOG(15) */
  *null_pivots = (int)handle->id.infog[27];       /* INFOG(28) */
  *out_of_core = (handle->id.icntl[21] == 1) ? 1 : 0;
  *scaled_residual = handle->id.rinfog[5];         /* RINFOG(6) */
  *backward_error_1 = handle->id.rinfog[6];        /* RINFOG(7) */
  *backward_error_2 = handle->id.rinfog[7];        /* RINFOG(8) */
  return 0;
}

int des_mumps_c_set_pattern(
    void *opaque_handle, int n, int nnz, const int *row_ptr,
    const int *col_ind, int *info_primary, int *info_secondary)
{
  des_mumps_handle_t *handle = (des_mumps_handle_t *)opaque_handle;
  size_t supplied = 0;
  size_t cursor = 0;
  int row;
  int position;

  if (handle == NULL || n < 1 || nnz < 1 ||
      row_ptr == NULL || col_ind == NULL) {
    return -1;
  }
  if (row_ptr[0] != 1 || row_ptr[n] != nnz + 1) {
    return -1;
  }

  for (row = 0; row < n; ++row) {
    if (row_ptr[row] > row_ptr[row + 1]) {
      return -1;
    }
    for (position = row_ptr[row] - 1;
         position < row_ptr[row + 1] - 1; ++position) {
      int col = col_ind[position];
      if (col < 1 || col > n) {
        return -1;
      }
      if (handle->symmetry_mode == 0 || col <= row + 1) {
        ++supplied;
      }
    }
  }

  if (supplied == 0) {
    return -1;
  }

  des_mumps_release_pattern(handle);
  handle->irn = (MUMPS_INT *)malloc(supplied * sizeof(MUMPS_INT));
  handle->jcn = (MUMPS_INT *)malloc(supplied * sizeof(MUMPS_INT));
  handle->a = (double *)malloc(supplied * sizeof(double));
  handle->csr_value_index = (size_t *)malloc(supplied * sizeof(size_t));
  if (handle->irn == NULL || handle->jcn == NULL ||
      handle->a == NULL || handle->csr_value_index == NULL) {
    des_mumps_release_pattern(handle);
    return -2;
  }

  for (row = 0; row < n; ++row) {
    for (position = row_ptr[row] - 1;
         position < row_ptr[row + 1] - 1; ++position) {
      int col = col_ind[position];
      if (handle->symmetry_mode == 0 || col <= row + 1) {
        handle->irn[cursor] = (MUMPS_INT)(row + 1);
        handle->jcn[cursor] = (MUMPS_INT)col;
        handle->csr_value_index[cursor] = (size_t)position;
        handle->a[cursor] = 0.0;
        ++cursor;
      }
    }
  }

  handle->n = n;
  handle->full_nnz = nnz;
  handle->supplied_nnz = (MUMPS_INT8)supplied;
  handle->pattern_ready = 1;
  handle->analyzed = 0;
  handle->factorized = 0;

  handle->id.n = (MUMPS_INT)n;
  handle->id.nnz = handle->supplied_nnz;
  handle->id.irn = handle->irn;
  handle->id.jcn = handle->jcn;
  handle->id.a = handle->a;

  des_mumps_copy_info(handle, info_primary, info_secondary);
  return 0;
}

int des_mumps_c_analyze(
    void *opaque_handle, int nnz, const double *values,
    int *info_primary, int *info_secondary)
{
  des_mumps_handle_t *handle = (des_mumps_handle_t *)opaque_handle;

  if (des_mumps_refresh_values(handle, nnz, values) != 0) {
    return -1;
  }

  handle->id.job = DES_MUMPS_JOB_ANALYZE;
  dmumps_c(&handle->id);
  des_mumps_copy_info(handle, info_primary, info_secondary);
  if (handle->id.infog[0] < 0) {
    handle->analyzed = 0;
    return -3;
  }

  handle->analyzed = 1;
  handle->factorized = 0;
  return 0;
}

int des_mumps_c_factorize(
    void *opaque_handle, int nnz, const double *values,
    int *info_primary, int *info_secondary)
{
  des_mumps_handle_t *handle = (des_mumps_handle_t *)opaque_handle;

  if (handle == NULL || !handle->analyzed) {
    return -1;
  }
  if (des_mumps_refresh_values(handle, nnz, values) != 0) {
    return -1;
  }

  handle->id.job = DES_MUMPS_JOB_FACTORIZE;
  dmumps_c(&handle->id);
  des_mumps_copy_info(handle, info_primary, info_secondary);
  if (handle->id.infog[0] < 0) {
    handle->factorized = 0;
    return -3;
  }

  handle->factorized = 1;
  return 0;
}

int des_mumps_c_solve(
    void *opaque_handle, int n, const double *rhs, double *x,
    int *info_primary, int *info_secondary)
{
  des_mumps_handle_t *handle = (des_mumps_handle_t *)opaque_handle;

  if (handle == NULL || !handle->factorized || n != handle->n ||
      rhs == NULL || x == NULL) {
    return -1;
  }

  memcpy(x, rhs, (size_t)n * sizeof(double));
  handle->id.rhs = x;
  handle->id.nrhs = 1;
  handle->id.lrhs = (MUMPS_INT)n;
  handle->id.job = DES_MUMPS_JOB_SOLVE;
  dmumps_c(&handle->id);
  des_mumps_copy_info(handle, info_primary, info_secondary);
  handle->id.rhs = NULL;

  if (handle->id.infog[0] < 0) {
    return -3;
  }

  return 0;
}

void des_mumps_c_destroy(void *opaque_handle)
{
  des_mumps_handle_t *handle = (des_mumps_handle_t *)opaque_handle;

  if (handle == NULL) {
    return;
  }

  handle->id.job = DES_MUMPS_JOB_END;
  dmumps_c(&handle->id);
  des_mumps_release_pattern(handle);
  free(handle);

  /*
   * B6 workstation profili libseq kullanır. MPI_Finalize burada bilinçli
   * çağrılmaz: bir süreçte art arda oluşturulan solver context'leri MPI'yi
   * yeniden initialize etmek zorunda kalmamalıdır. Gerçek MPI yaşam döngüsü
   * gelecekteki distributed backend profilinde uygulama seviyesinde yönetilir.
   */
}
