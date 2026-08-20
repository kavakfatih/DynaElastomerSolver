program test_status_message
  use des_status, only : DES_ERROR_NONPOSITIVE_J, DES_ERROR_CUTBACK_EXHAUSTED, &
                         DES_ERROR_UNSUPPORTED_LINEAR_BACKEND, DES_ERROR_INVALID_ELEMENT_EDGE, &
                         DES_ERROR_LINE_SEARCH_FAILED, DES_ERROR_NONLINEAR_DIVERGENCE, &
                         DES_ERROR_NONFINITE_NONLINEAR, des_status_message
  implicit none
  character(len=80) :: message

  message = des_status_message(DES_ERROR_NONPOSITIVE_J)
  if (index(message, 'J') == 0) then
    error stop 'Non-positive J mesajı beklenen içeriği taşımıyor.'
  end if

  message = des_status_message(DES_ERROR_CUTBACK_EXHAUSTED)
  if (index(message, 'Cutback') == 0) then
    error stop 'Cutback exhaustion mesajı bulunamadı.'
  end if

  message = des_status_message(DES_ERROR_UNSUPPORTED_LINEAR_BACKEND)
  if (index(message, 'lineer solver backend') == 0) then
    error stop 'Lineer backend hata mesajı bulunamadı.'
  end if

  message = des_status_message(DES_ERROR_LINE_SEARCH_FAILED)
  if (index(message, 'line-search') == 0) then
    error stop 'Line-search hata mesajı bulunamadı.'
  end if

  message = des_status_message(DES_ERROR_NONLINEAR_DIVERGENCE)
  if (index(message, 'diverge') == 0) then
    error stop 'Nonlinear divergence hata mesajı bulunamadı.'
  end if

  message = des_status_message(DES_ERROR_NONFINITE_NONLINEAR)
  if (index(message, 'NaN/Inf') == 0) then
    error stop 'Non-finite nonlinear hata mesajı bulunamadı.'
  end if

  message = des_status_message(DES_ERROR_INVALID_ELEMENT_EDGE)
  if (index(message, 'kenar') == 0) then
    error stop 'Q4 yerel kenar hata mesajı bulunamadı.'
  end if

  message = des_status_message(-9999)
  if (index(message, 'Bilinmeyen') == 0) then
    error stop 'Unknown status mesajı bulunamadı.'
  end if

  write(*,'(A)') 'Status message testi BASARILI.'
end program test_status_message
