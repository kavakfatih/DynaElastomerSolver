module des_q9_internal_mesh_herrmann_assembly
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONNECTIVITY
  use des_internal_mesh, only : internal_mesh_t, validate_internal_mesh
  use des_q9_plane_strain_herrmann_neo_hookean, only : Q9_HERRMANN_QUADRATURE_3X3
  use des_q9_plane_strain_herrmann_mesh, only : &
      q9_herrmann_mesh_reference_cache_t, &
      assemble_q9_plane_strain_herrmann_mesh_with_quadrature
  implicit none
  private

  public :: assemble_q9_internal_mesh_herrmann
  public :: assemble_q9_internal_mesh_herrmann_with_quadrature

contains

  subroutine assemble_q9_internal_mesh_herrmann( &
      mesh, u, pressure_coefficients, shear_modulus, pressure_compliance, &
      residual, tangent, status, min_j)
    ! Kanonik InternalMesh -> Q9/P1 Herrmann global assembly siniri.
    ! Varsayilan integration H1 arastirma baseline'i olan 3x3 Gauss'tur.
    type(internal_mesh_t), intent(in) :: mesh
    real(dp), intent(in) :: u(:,:), pressure_coefficients(:,:)
    real(dp), intent(in) :: shear_modulus, pressure_compliance
    real(dp), intent(out) :: residual(:), tangent(:,:)
    integer, intent(out) :: status
    real(dp), intent(out) :: min_j

    call assemble_q9_internal_mesh_herrmann_with_quadrature( &
        mesh,u,pressure_coefficients,shear_modulus,pressure_compliance, &
        Q9_HERRMANN_QUADRATURE_3X3,residual,tangent,status,min_j)
  end subroutine assemble_q9_internal_mesh_herrmann

  subroutine assemble_q9_internal_mesh_herrmann_with_quadrature( &
      mesh, u, pressure_coefficients, shear_modulus, pressure_compliance, &
      quadrature_order, residual, tangent, status, min_j, reference_cache)
    ! Public FEM/solver katmaninin ham coordinates/connectivity dizilerine bagimli
    ! kalmamasini saglar. Q9 topology dogrulanmadan mixed assembly calistirilmaz.
    ! B9.4 cache optional'dir; verilmezse eski direct assembly davranisi korunur.
    type(internal_mesh_t), intent(in) :: mesh
    real(dp), intent(in) :: u(:,:), pressure_coefficients(:,:)
    real(dp), intent(in) :: shear_modulus, pressure_compliance
    integer, intent(in) :: quadrature_order
    real(dp), intent(out) :: residual(:), tangent(:,:)
    integer, intent(out) :: status
    real(dp), intent(out) :: min_j
    type(q9_herrmann_mesh_reference_cache_t), intent(in), optional :: reference_cache

    integer :: mesh_status

    residual = 0.0_dp
    tangent = 0.0_dp
    min_j = huge(1.0_dp)

    call validate_internal_mesh(mesh,mesh_status)
    if (mesh_status /= DES_STATUS_OK) then
      status = mesh_status
      return
    end if

    if (.not. mesh%is_q9()) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if

    if (present(reference_cache)) then
      call assemble_q9_plane_strain_herrmann_mesh_with_quadrature( &
          mesh%coordinates,mesh%q9_connectivity,u,pressure_coefficients, &
          shear_modulus,pressure_compliance,quadrature_order, &
          residual,tangent,status,min_j,reference_cache)
    else
      call assemble_q9_plane_strain_herrmann_mesh_with_quadrature( &
          mesh%coordinates,mesh%q9_connectivity,u,pressure_coefficients, &
          shear_modulus,pressure_compliance,quadrature_order, &
          residual,tangent,status,min_j)
    end if
  end subroutine assemble_q9_internal_mesh_herrmann_with_quadrature

end module des_q9_internal_mesh_herrmann_assembly
