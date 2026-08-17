module des_status
  implicit none
  private

  integer, parameter, public :: DES_STATUS_OK = 0
  integer, parameter, public :: DES_STATUS_NOT_EVALUATED = 1
  integer, parameter, public :: DES_ERROR_INVALID_PARAMETERS = -100
  integer, parameter, public :: DES_ERROR_SINGULAR_F = -101
  integer, parameter, public :: DES_ERROR_NONPOSITIVE_J = -102
end module des_status
