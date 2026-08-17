module des_status
  implicit none
  private

  integer, parameter, public :: DES_STATUS_OK = 0
  integer, parameter, public :: DES_STATUS_NOT_EVALUATED = 1
  integer, parameter, public :: DES_ERROR_INVALID_PARAMETERS = -100
  integer, parameter, public :: DES_ERROR_SINGULAR_F = -101
  integer, parameter, public :: DES_ERROR_NONPOSITIVE_J = -102
  integer, parameter, public :: DES_ERROR_INVALID_ELEMENT_JACOBIAN = -200
  integer, parameter, public :: DES_ERROR_MATERIAL_POINT = -201
  integer, parameter, public :: DES_ERROR_INVALID_CONNECTIVITY = -202
  integer, parameter, public :: DES_ERROR_INVALID_CONSTRAINT = -300
  integer, parameter, public :: DES_ERROR_LINEAR_SOLVE = -301
  integer, parameter, public :: DES_ERROR_NEWTON_DID_NOT_CONVERGE = -302
end module des_status
