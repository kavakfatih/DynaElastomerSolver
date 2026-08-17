program test_status_message
  use des_status, only : DES_ERROR_NONPOSITIVE_J, DES_ERROR_CUTBACK_EXHAUSTED, &
                         DES_ERROR_UNSUPPORTED_LINEAR_BACKEND, des_status_message
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

  message = des_status_message(-9999)
  if (index(message, 'Bilinmeyen') == 0) then
    error stop 'Unknown status mesajı bulunamadı.'
  end if

  write(*,'(A)') 'Status message testi BASARILI.'
end program test_status_message
