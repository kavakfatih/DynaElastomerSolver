module des_q9_plane_strain_herrmann_mesh
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONNECTIVITY, &
                         DES_ERROR_INVALID_CONSTRAINT
  use des_mixed_dof_layout, only : mixed_global_equation_counts, &
                                   build_discontinuous_pressure_element_dof_map
  use des_q9_plane_strain_herrmann_neo_hookean, only : &
      Q9_HERRMANN_P_DOF, Q9_HERRMANN_TOTAL_DOF, &
      Q9_HERRMANN_QUADRATURE_3X3, &
      q9_herrmann_reference_cache_t, &
      initialize_q9_herrmann_reference_cache, &
      evaluate_q9_plane_strain_herrmann_element_with_quadrature, &
      evaluate_q9_plane_strain_herrmann_element_with_cache
  implicit none
  private

  type, public :: q9_herrmann_mesh_reference_cache_t
    ! B9.4: solver omru boyunca degismeyen undeformed Q9 reference geometri
    ! verilerini element bazinda tutar. Nonlinear state bu tipe girmez.
    integer :: quadrature_order = 0
    integer :: element_count = 0
    type(q9_herrmann_reference_cache_t), allocatable :: element(:)
    logical :: initialized = .false.
  end type q9_herrmann_mesh_reference_cache_t

  public :: initialize_q9_plane_strain_herrmann_mesh_reference_cache
  public :: assemble_q9_plane_strain_herrmann_mesh
  public :: assemble_q9_plane_strain_herrmann_mesh_with_quadrature

contains

  subroutine initialize_q9_plane_strain_herrmann_mesh_reference_cache( &
      X, connectivity, quadrature_order, cache, status)
    ! Undeformed mesh ve quadrature sabitken her elementin reference gradient,
    ! P1 pressure basis ve integration weight verisini bir kez hazirlar.
    real(dp), intent(in) :: X(:,:)
    integer, intent(in) :: connectivity(:,:)
    integer, intent(in) :: quadrature_order
    type(q9_herrmann_mesh_reference_cache_t), intent(out) :: cache
    integer, intent(out) :: status

    real(dp) :: Xe(9,2)
    integer :: nnode, nelem, e, a, node, element_status

    cache%quadrature_order = 0
    cache%element_count = 0
    cache%initialized = .false.
    status = DES_STATUS_OK

    nnode = size(X,1)
    nelem = size(connectivity,1)

    if (size(X,2) /= 2 .or. nnode < 9) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if
    if (size(connectivity,2) /= 9 .or. nelem < 1) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if
    if (any(connectivity < 1) .or. any(connectivity > nnode)) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if

    allocate(cache%element(nelem))
    do e = 1,nelem
      do a = 1,9
        node = connectivity(e,a)
        Xe(a,:) = X(node,:)
      end do

      call initialize_q9_herrmann_reference_cache( &
          Xe,quadrature_order,cache%element(e),element_status)
      if (element_status /= DES_STATUS_OK) then
        status = element_status
        return
      end if
    end do

    cache%quadrature_order = quadrature_order
    cache%element_count = nelem
    cache%initialized = .true.
  end subroutine initialize_q9_plane_strain_herrmann_mesh_reference_cache

  subroutine assemble_q9_plane_strain_herrmann_mesh( &
      X, connectivity, u, pressure_coefficients, shear_modulus, pressure_compliance, &
      residual, tangent, status, min_j)
    ! Varsayilan global Q9/P1 Herrmann assembly yolu 3x3 Gauss baseline'ini korur.
    real(dp), intent(in) :: X(:,:), u(:,:), pressure_coefficients(:,:)
    integer, intent(in) :: connectivity(:,:)
    real(dp), intent(in) :: shear_modulus, pressure_compliance
    real(dp), intent(out) :: residual(:), tangent(:,:)
    integer, intent(out) :: status
    real(dp), intent(out) :: min_j

    call assemble_q9_plane_strain_herrmann_mesh_with_quadrature( &
        X,connectivity,u,pressure_coefficients,shear_modulus,pressure_compliance, &
        Q9_HERRMANN_QUADRATURE_3X3,residual,tangent,status,min_j)
  end subroutine assemble_q9_plane_strain_herrmann_mesh

  subroutine assemble_q9_plane_strain_herrmann_mesh_with_quadrature( &
      X, connectivity, u, pressure_coefficients, shear_modulus, pressure_compliance, &
      quadrature_order, residual, tangent, status, min_j, reference_cache)
    ! Global mixed unknown sirasi:
    ! [u1x,u1y,...,unx,uny,
    !  p_element_1_mode_1,p_element_1_mode_2,p_element_1_mode_3,...]
    !
    ! Pressure coefficients mesh dugumlerine yapistirilmaz. Her elementin 3 pressure
    ! unknown'u global saddle-point sisteminde bagimsiz denklem olarak tutulur.
    !
    ! B9.4 reference_cache verilmezse eski direct geometri yolu aynen korunur.
    real(dp), intent(in) :: X(:,:), u(:,:), pressure_coefficients(:,:)
    integer, intent(in) :: connectivity(:,:)
    real(dp), intent(in) :: shear_modulus, pressure_compliance
    integer, intent(in) :: quadrature_order
    real(dp), intent(out) :: residual(:), tangent(:,:)
    integer, intent(out) :: status
    real(dp), intent(out) :: min_j
    type(q9_herrmann_mesh_reference_cache_t), intent(in), optional :: reference_cache

    real(dp) :: Xe(9,2), ue(9,2), pe(Q9_HERRMANN_P_DOF)
    real(dp) :: re(Q9_HERRMANN_TOTAL_DOF)
    real(dp) :: Ke(Q9_HERRMANN_TOTAL_DOF,Q9_HERRMANN_TOTAL_DOF)
    real(dp) :: element_min_j
    integer :: dof_map(Q9_HERRMANN_TOTAL_DOF)
    integer :: element_status, map_status, count_status
    integer :: nnode, nelem, ndisp, npres, ntotal
    integer :: e, a, lr, lc, gr, gc, node
    logical :: use_reference_cache

    residual = 0.0_dp
    tangent = 0.0_dp
    status = DES_STATUS_OK
    min_j = huge(1.0_dp)

    nnode = size(X,1)
    nelem = size(connectivity,1)

    if (size(X,2) /= 2 .or. size(u,1) /= nnode .or. size(u,2) /= 2) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if
    if (size(connectivity,2) /= 9 .or. nelem < 1) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if
    if (size(pressure_coefficients,1) /= nelem .or. &
        size(pressure_coefficients,2) /= Q9_HERRMANN_P_DOF) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    use_reference_cache = present(reference_cache)
    if (use_reference_cache) then
      if (.not. reference_cache%initialized .or. &
          reference_cache%quadrature_order /= quadrature_order .or. &
          reference_cache%element_count /= nelem .or. &
          .not. allocated(reference_cache%element)) then
        status = DES_ERROR_INVALID_CONSTRAINT
        return
      end if
      if (size(reference_cache%element) /= nelem) then
        status = DES_ERROR_INVALID_CONSTRAINT
        return
      end if
    end if

    call mixed_global_equation_counts( &
        nnode,nelem,2,Q9_HERRMANN_P_DOF,ndisp,npres,ntotal,count_status)
    if (count_status /= DES_STATUS_OK) then
      status = count_status
      return
    end if
    if (ntotal /= ndisp+npres) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    if (size(residual) /= ntotal) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if
    if (size(tangent,1) /= ntotal .or. size(tangent,2) /= ntotal) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    do e = 1,nelem
      do a = 1,9
        node = connectivity(e,a)
        if (node < 1 .or. node > nnode) then
          status = DES_ERROR_INVALID_CONNECTIVITY
          return
        end if
        ue(a,:) = u(node,:)
        if (.not. use_reference_cache) Xe(a,:) = X(node,:)
      end do
      pe = pressure_coefficients(e,:)

      call build_discontinuous_pressure_element_dof_map( &
          connectivity(e,:),e,nnode,2,Q9_HERRMANN_P_DOF,dof_map,map_status)
      if (map_status /= DES_STATUS_OK) then
        status = map_status
        return
      end if

      if (use_reference_cache) then
        call evaluate_q9_plane_strain_herrmann_element_with_cache( &
            ue,pe,shear_modulus,pressure_compliance, &
            reference_cache%element(e),re,Ke,element_status,element_min_j)
      else
        call evaluate_q9_plane_strain_herrmann_element_with_quadrature( &
            Xe,ue,pe,shear_modulus,pressure_compliance,quadrature_order, &
            re,Ke,element_status,element_min_j)
      end if
      if (element_status /= DES_STATUS_OK) then
        status = element_status
        return
      end if
      min_j = min(min_j,element_min_j)

      do lr = 1,Q9_HERRMANN_TOTAL_DOF
        gr = dof_map(lr)
        residual(gr) = residual(gr)+re(lr)
        do lc = 1,Q9_HERRMANN_TOTAL_DOF
          gc = dof_map(lc)
          tangent(gr,gc) = tangent(gr,gc)+Ke(lr,lc)
        end do
      end do
    end do
  end subroutine assemble_q9_plane_strain_herrmann_mesh_with_quadrature

end module des_q9_plane_strain_herrmann_mesh
