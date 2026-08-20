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
  integer, parameter, public :: DES_ERROR_INVALID_ELEMENT_EDGE = -203
  integer, parameter, public :: DES_ERROR_INVALID_CONSTRAINT = -300
  integer, parameter, public :: DES_ERROR_LINEAR_SOLVE = -301
  integer, parameter, public :: DES_ERROR_NEWTON_DID_NOT_CONVERGE = -302
  integer, parameter, public :: DES_ERROR_CUTBACK_EXHAUSTED = -303
  integer, parameter, public :: DES_ERROR_UNSUPPORTED_LINEAR_BACKEND = -304
  integer, parameter, public :: DES_ERROR_LINE_SEARCH_FAILED = -305
  integer, parameter, public :: DES_ERROR_NONLINEAR_DIVERGENCE = -306

  public :: des_status_message
contains

  pure function des_status_message(status) result(message)
    integer, intent(in) :: status
    character(len=80) :: message

    select case (status)
    case (DES_STATUS_OK)
      message = 'Başarılı'
    case (DES_STATUS_NOT_EVALUATED)
      message = 'Henüz değerlendirilmedi'
    case (DES_ERROR_INVALID_PARAMETERS)
      message = 'Geçersiz malzeme parametreleri'
    case (DES_ERROR_SINGULAR_F)
      message = 'Tekil deformasyon gradyanı F'
    case (DES_ERROR_NONPOSITIVE_J)
      message = 'Geçersiz deformasyon: J sıfır veya negatif'
    case (DES_ERROR_INVALID_ELEMENT_JACOBIAN)
      message = 'Geçersiz eleman geometrik Jacobianı'
    case (DES_ERROR_MATERIAL_POINT)
      message = 'Material-point değerlendirmesi başarısız'
    case (DES_ERROR_INVALID_CONNECTIVITY)
      message = 'Geçersiz mesh bağlantısı'
    case (DES_ERROR_INVALID_ELEMENT_EDGE)
      message = 'Geçersiz Q4 yerel kenar kimliği'
    case (DES_ERROR_INVALID_CONSTRAINT)
      message = 'Geçersiz sınır şartı veya solver girdisi'
    case (DES_ERROR_LINEAR_SOLVE)
      message = 'Doğrusal denklem sistemi çözülemedi'
    case (DES_ERROR_NEWTON_DID_NOT_CONVERGE)
      message = 'Newton iterasyonları yakınsamadı'
    case (DES_ERROR_CUTBACK_EXHAUSTED)
      message = 'Cutback/retry sınırı tükendi'
    case (DES_ERROR_UNSUPPORTED_LINEAR_BACKEND)
      message = 'Desteklenmeyen lineer solver backend seçildi'
    case (DES_ERROR_LINE_SEARCH_FAILED)
      message = 'Newton line-search yeterli residual azalması bulamadı'
    case (DES_ERROR_NONLINEAR_DIVERGENCE)
      message = 'Nonlinear residual ardışık olarak büyüyerek diverge etti'
    case default
      message = 'Bilinmeyen DES durum kodu'
    end select
  end function des_status_message

end module des_status
