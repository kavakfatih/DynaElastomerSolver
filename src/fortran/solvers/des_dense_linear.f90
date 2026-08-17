module des_dense_linear
  use des_kinds, only : dp
  use des_linear_solver, only : linear_solver_report_t, solve_linear_system
  implicit none
  private
  public :: solve_dense_system
contains

  subroutine solve_dense_system(A, b, x, ok)
    real(dp), intent(in) :: A(:,:), b(:)
    real(dp), intent(out) :: x(:)
    logical, intent(out) :: ok

    type(linear_solver_report_t) :: report

    ! Bu prosedür yalnız geriye dönük uyumluluk wrapper'ıdır.
    ! Yeni solver kodu Dyna'nın backend-bağımsız solve_linear_system API'sini kullanmalıdır.
    call solve_linear_system(A, b, x, report=report)
    ok = report%converged
  end subroutine solve_dense_system
end module des_dense_linear
