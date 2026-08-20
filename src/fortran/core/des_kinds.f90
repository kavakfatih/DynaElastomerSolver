module des_kinds
  use, intrinsic :: iso_fortran_env, only : real64, int32, int64
  implicit none
  private
  public :: dp, i32, i64

  ! Bilimsel çekirdekte gerçek sayılar için tek ve açık precision politikası kullanılır.
  integer, parameter :: dp = real64
  integer, parameter :: i32 = int32
  integer, parameter :: i64 = int64
end module des_kinds
