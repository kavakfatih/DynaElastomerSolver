program test_mumps_int64_index_capability
  use, intrinsic :: iso_c_binding, only : c_int
  use des_kinds, only : i64
  use des_mumps_backend, only : mumps_backend_index_bits, &
                                mumps_backend_c_index_range_supported
  implicit none

  integer :: index_bits
  integer(i64) :: c_int_max, beyond_c_int

  ! Bu test yalnız DES_MUMPS_INT64_INDEX=ON profilinde CMake tarafindan eklenir.
  ! Amaç full Dyna equation-numbering zincirini 64-bit ilan etmek degil; pinned
  ! MUMPS build'inin gercek MUMPS_INT genişliğini ve B9.5e bridge capability
  ! sinirini allocation yapmadan dogrulamaktir.
  index_bits = mumps_backend_index_bits()
  if (index_bits < 64) then
    error stop 'MUMPS int64 profilinde MUMPS_INT en az 64-bit olmali.'
  end if

  c_int_max = int(huge(0_c_int),i64)
  beyond_c_int = c_int_max + 1_i64

  if (.not. mumps_backend_c_index_range_supported(beyond_c_int,5_i64)) then
    error stop 'MUMPS int64 profilinde equation index c_int ustune cikamadi.'
  end if
  if (.not. mumps_backend_c_index_range_supported(3_i64,beyond_c_int)) then
    error stop 'MUMPS int64 profilinde nnz cardinality c_int ustune cikamadi.'
  end if

  write(*,'(A,I0)') 'MUMPS backend index bits = ',index_bits
  write(*,'(A,I0)') 'c_int ustu capability probe = ',beyond_c_int
  write(*,'(A)') 'MUMPS int64 index capability gate BASARILI.'
end program test_mumps_int64_index_capability
