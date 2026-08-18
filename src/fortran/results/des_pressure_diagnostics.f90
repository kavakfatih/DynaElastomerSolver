module des_pressure_diagnostics
  use des_kinds, only : dp
  use des_status, only : DES_STATUS_OK, DES_ERROR_INVALID_CONNECTIVITY, &
                         DES_ERROR_INVALID_CONSTRAINT
  implicit none
  private

  type, public :: pressure_diagnostics_t
    integer :: element_count = 0
    integer :: neighbor_pair_count = 0
    real(dp) :: minimum = 0.0_dp
    real(dp) :: maximum = 0.0_dp
    real(dp) :: mean = 0.0_dp
    real(dp) :: standard_deviation = 0.0_dp
    real(dp) :: rms = 0.0_dp
    real(dp) :: neighbor_jump_rms = 0.0_dp
    real(dp) :: maximum_neighbor_jump = 0.0_dp
    real(dp) :: normalized_neighbor_jump_rms = 0.0_dp
    logical :: valid = .false.
  end type pressure_diagnostics_t

  public :: evaluate_q4_pressure_diagnostics

contains

  subroutine evaluate_q4_pressure_diagnostics( &
      connectivity, pressure, diagnostics, status)
    ! P0 pressure alanı için formulation-bağımsız temel teşhisler.
    !
    ! Komşuluk iki Q4 elemanın tam bir kenarı, yani iki ortak düğümü paylaşmasıyla
    ! tanımlanır. Neighbor jump tek başına "checkerboard" kararı değildir; fiziksel
    ! pressure gradient de jump üretebilir. V0.3'te mesh-refinement ve bağımsız
    ! referans ile birlikte yorumlanması için ham ölçü olarak saklanır.
    integer, intent(in) :: connectivity(:,:)
    real(dp), intent(in) :: pressure(:)
    type(pressure_diagnostics_t), intent(out) :: diagnostics
    integer, intent(out) :: status

    integer :: nelem, e1, e2, shared_nodes, a, b, pair_count
    real(dp) :: centered_sum, square_sum, jump, jump_square_sum
    real(dp), parameter :: scale_floor = 100.0_dp*epsilon(1.0_dp)

    diagnostics = pressure_diagnostics_t()
    status = DES_STATUS_OK

    nelem = size(connectivity,1)
    if (nelem < 1 .or. size(connectivity,2) /= 4) then
      status = DES_ERROR_INVALID_CONNECTIVITY
      return
    end if
    if (size(pressure) /= nelem) then
      status = DES_ERROR_INVALID_CONSTRAINT
      return
    end if

    diagnostics%element_count = nelem
    diagnostics%minimum = minval(pressure)
    diagnostics%maximum = maxval(pressure)
    diagnostics%mean = sum(pressure)/real(nelem,dp)

    centered_sum = sum((pressure-diagnostics%mean)**2)
    square_sum = sum(pressure**2)
    diagnostics%standard_deviation = sqrt(centered_sum/real(nelem,dp))
    diagnostics%rms = sqrt(square_sum/real(nelem,dp))

    pair_count = 0
    jump_square_sum = 0.0_dp
    diagnostics%maximum_neighbor_jump = 0.0_dp

    do e1 = 1,nelem-1
      do e2 = e1+1,nelem
        shared_nodes = 0
        do a = 1,4
          do b = 1,4
            if (connectivity(e1,a) == connectivity(e2,b)) then
              shared_nodes = shared_nodes + 1
            end if
          end do
        end do

        if (shared_nodes == 2) then
          pair_count = pair_count + 1
          jump = abs(pressure(e1)-pressure(e2))
          jump_square_sum = jump_square_sum + jump*jump
          diagnostics%maximum_neighbor_jump = max( &
              diagnostics%maximum_neighbor_jump, jump)
        end if
      end do
    end do

    diagnostics%neighbor_pair_count = pair_count
    if (pair_count > 0) then
      diagnostics%neighbor_jump_rms = &
        sqrt(jump_square_sum/real(pair_count,dp))
    end if

    diagnostics%normalized_neighbor_jump_rms = &
      diagnostics%neighbor_jump_rms/max(diagnostics%rms,scale_floor)
    diagnostics%valid = .true.
  end subroutine evaluate_q4_pressure_diagnostics

end module des_pressure_diagnostics
