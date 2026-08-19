module des_q4_edge_traction
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_ELEMENT_JACOBIAN, &
                         DES_ERROR_INVALID_ELEMENT_EDGE
  use des_q4_shape, only : q4_shape_functions
  implicit none
  private

  integer, parameter, public :: Q4_EDGE_BOTTOM = 1
  integer, parameter, public :: Q4_EDGE_RIGHT  = 2
  integer, parameter, public :: Q4_EDGE_TOP    = 3
  integer, parameter, public :: Q4_EDGE_LEFT   = 4

  public :: q4_reference_edge_traction
contains

  subroutine q4_reference_edge_traction(X, edge_id, traction, force, status, reference_length)
    ! Total-Lagrangian Q4 elemanının referans konfigürasyonundaki bir kenarına
    ! sabit nominal traction uygular. 2B formulation için birim kalınlık kabul edilir.
    !
    ! force = integral_A0 N^T * traction dA0
    !
    ! Q4 yerel kenar numaraları:
    !   1: alt   (eta = -1)
    !   2: sağ   (xi  = +1)
    !   3: üst   (eta = +1)
    !   4: sol   (xi  = -1)
    real(dp), intent(in) :: X(4,2)
    integer, intent(in) :: edge_id
    real(dp), intent(in) :: traction(2)
    real(dp), intent(out) :: force(8)
    integer, intent(out) :: status
    real(dp), intent(out), optional :: reference_length

    real(dp), parameter :: gauss_point = 0.57735026918962576451_dp
    real(dp) :: s, xi, eta
    real(dp) :: N(4), dN_parent(4,2)
    real(dp) :: tangent(2), edge_jacobian
    real(dp) :: length_accumulator
    integer :: integration_direction
    integer :: ig, a

    force = 0.0_dp
    status = DES_STATUS_OK
    length_accumulator = 0.0_dp

    if (edge_id < Q4_EDGE_BOTTOM .or. edge_id > Q4_EDGE_LEFT) then
      status = DES_ERROR_INVALID_ELEMENT_EDGE
      if (present(reference_length)) reference_length = 0.0_dp
      return
    end if

    do ig = 1, 2
      if (ig == 1) then
        s = -gauss_point
      else
        s = gauss_point
      end if

      select case (edge_id)
      case (Q4_EDGE_BOTTOM)
        xi = s
        eta = -1.0_dp
        integration_direction = 1
      case (Q4_EDGE_RIGHT)
        xi = 1.0_dp
        eta = s
        integration_direction = 2
      case (Q4_EDGE_TOP)
        xi = s
        eta = 1.0_dp
        integration_direction = 1
      case (Q4_EDGE_LEFT)
        xi = -1.0_dp
        eta = s
        integration_direction = 2
      end select

      call q4_shape_functions(xi, eta, N, dN_parent)

      tangent(1) = sum(dN_parent(:,integration_direction) * X(:,1))
      tangent(2) = sum(dN_parent(:,integration_direction) * X(:,2))
      edge_jacobian = sqrt(sum(tangent*tangent))

      if (edge_jacobian <= epsilon(1.0_dp)) then
        force = 0.0_dp
        status = DES_ERROR_INVALID_ELEMENT_JACOBIAN
        if (present(reference_length)) reference_length = 0.0_dp
        return
      end if

      length_accumulator = length_accumulator + edge_jacobian

      do a = 1, 4
        force(2*a-1) = force(2*a-1) + N(a) * traction(1) * edge_jacobian
        force(2*a)   = force(2*a)   + N(a) * traction(2) * edge_jacobian
      end do
    end do

    if (present(reference_length)) reference_length = length_accumulator
  end subroutine q4_reference_edge_traction

end module des_q4_edge_traction
