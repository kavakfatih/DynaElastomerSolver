program test_mixed_dof_layout
  use des_kinds, only : i64
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONNECTIVITY, &
                         DES_ERROR_INVALID_CONSTRAINT
  use des_mixed_dof_layout, only : mixed_global_equation_counts, &
                                    mixed_global_equation_counts_i64, &
                                    build_discontinuous_pressure_element_dof_map
  implicit none

  integer :: nd_u, nd_p, nd_total, status, legacy_overflow_nodes
  integer :: map_q8_1(19), map_q8_2(19), map_torsion(27)
  integer :: overflow_nodes(1), overflow_map(3)
  integer, parameter :: nodes_1(8) = [1,2,3,4,5,6,7,8]
  integer, parameter :: nodes_2(8) = [2,9,10,3,11,12,13,6]
  integer :: bad_nodes(8)
  integer(i64) :: nd_u_i64, nd_p_i64, nd_total_i64

  call mixed_global_equation_counts(13,2,2,3,nd_u,nd_p,nd_total,status)
  if (status /= DES_STATUS_OK) error stop 'Plane-strain mixed denklem sayisi kurulamadi.'
  if (nd_u /= 26 .or. nd_p /= 6 .or. nd_total /= 32) then
    error stop 'Plane-strain mixed global denklem sayisi hatali.'
  end if

  call build_discontinuous_pressure_element_dof_map( &
      nodes_1,1,13,2,3,map_q8_1,status)
  if (status /= DES_STATUS_OK) error stop 'Birinci Q8/P1 DOF haritasi kurulamadi.'
  if (any(map_q8_1(1:16) /= [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16])) then
    error stop 'Birinci Q8 displacement DOF sirasi hatali.'
  end if
  if (any(map_q8_1(17:19) /= [27,28,29])) then
    error stop 'Birinci Q8 pressure DOF sirasi hatali.'
  end if

  call build_discontinuous_pressure_element_dof_map( &
      nodes_2,2,13,2,3,map_q8_2,status)
  if (status /= DES_STATUS_OK) error stop 'Ikinci Q8/P1 DOF haritasi kurulamadi.'
  if (map_q8_2(1) /= 3 .or. map_q8_2(2) /= 4) then
    error stop 'Paylasilan Q8 node displacement denklem numarasi korunmadi.'
  end if
  if (map_q8_2(5) /= 19 .or. map_q8_2(6) /= 20) then
    error stop 'Q8 displacement global numbering hatali.'
  end if
  if (any(map_q8_2(17:19) /= [30,31,32])) then
    error stop 'Element-internal pressure DOF gruplari birbirinden ayrilmadi.'
  end if

  ! Ayni layout sozlesmesi axisymmetric-with-torsion icin uc displacement component tasir.
  call mixed_global_equation_counts(13,2,3,3,nd_u,nd_p,nd_total,status)
  if (status /= DES_STATUS_OK) error stop 'Torsion mixed denklem sayisi kurulamadi.'
  if (nd_u /= 39 .or. nd_p /= 6 .or. nd_total /= 45) then
    error stop 'Torsion mixed global denklem sayisi hatali.'
  end if

  call build_discontinuous_pressure_element_dof_map( &
      nodes_1,1,13,3,3,map_torsion,status)
  if (status /= DES_STATUS_OK) error stop 'Torsion Q8/P1 DOF haritasi kurulamadi.'
  if (any(map_torsion(25:27) /= [40,41,42])) then
    error stop 'Torsion element pressure DOF offseti hatali.'
  end if

  bad_nodes = nodes_1
  bad_nodes(8) = 14
  call build_discontinuous_pressure_element_dof_map( &
      bad_nodes,1,13,2,3,map_q8_1,status)
  if (status /= DES_ERROR_INVALID_CONNECTIVITY) then
    error stop 'Gecersiz mixed element connectivity reddedilmedi.'
  end if

  ! B9.5g: Default integer sinirinin cok ustunde cardinality allocation yapmadan
  ! dogru i64 sonuc vermelidir.
  call mixed_global_equation_counts_i64( &
      3000000000_i64,1000000000_i64,2_i64,3_i64, &
      nd_u_i64,nd_p_i64,nd_total_i64,status)
  if (status /= DES_STATUS_OK) error stop 'i64 mixed cardinality hesaplanamadi.'
  if (nd_u_i64 /= 6000000000_i64 .or. nd_p_i64 /= 3000000000_i64 .or. &
      nd_total_i64 /= 9000000000_i64) then
    error stop 'i64 mixed cardinality sonucu hatali.'
  end if

  ! i64 carpim overflow'u wrap etmek yerine deterministic fail-fast olmalidir.
  call mixed_global_equation_counts_i64( &
      huge(0_i64),1_i64,2_i64,1_i64,nd_u_i64,nd_p_i64,nd_total_i64,status)
  if (status /= DES_ERROR_INVALID_CONSTRAINT) then
    error stop 'i64 mixed cardinality overflow reddedilmedi.'
  end if
  if (nd_u_i64 /= 0_i64 .or. nd_p_i64 /= 0_i64 .or. nd_total_i64 /= 0_i64) then
    error stop 'Overflow sonrasinda i64 cardinality ciktilari sifirlanmadi.'
  end if

  ! Legacy API default integer kapasitesini asan gecerli i64 sayimi narrow etmemelidir.
  legacy_overflow_nodes = shiftr(huge(0),1)+1
  call mixed_global_equation_counts( &
      legacy_overflow_nodes,1,2,1,nd_u,nd_p,nd_total,status)
  if (status /= DES_ERROR_INVALID_CONSTRAINT) then
    error stop "Legacy mixed cardinality default-integer overflow reddedilmedi."
  end if
  if (nd_u /= 0 .or. nd_p /= 0 .or. nd_total /= 0) then
    error stop 'Legacy overflow sonrasinda cardinality ciktilari sifirlanmadi.'
  end if

  ! Pressure offset de default integer'a yazilmadan once i64 uzerinde dogrulanir.
  overflow_nodes = [1]
  overflow_map = -1
  call build_discontinuous_pressure_element_dof_map( &
      overflow_nodes,1,huge(0),2,1,overflow_map,status)
  if (status /= DES_ERROR_INVALID_CONSTRAINT) then
    error stop "Mixed pressure DOF offset overflow reddedilmedi."
  end if
  if (any(overflow_map /= 0)) then
    error stop 'Pressure offset overflow sonrasinda DOF map sifir kalmadi.'
  end if

  write(*,'(A)') 'Mixed displacement/pressure DOF layout testleri BASARILI.'
end program test_mixed_dof_layout
