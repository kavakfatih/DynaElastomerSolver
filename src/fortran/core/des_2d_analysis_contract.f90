module des_2d_analysis_contract
  implicit none
  private

  ! 2D analiz kipleri. Bu sabitler solver capability iddiası değildir;
  ! mesh/element/DOF katmanlarının aynı kanonik dili kullanmasını sağlar.
  integer, parameter, public :: DES_2D_ANALYSIS_UNKNOWN = 0
  integer, parameter, public :: DES_2D_PLANE_STRESS = 1
  integer, parameter, public :: DES_2D_PLANE_STRESS_THICKNESS = 2
  integer, parameter, public :: DES_2D_PLANE_STRAIN = 3
  integer, parameter, public :: DES_2D_GENERALIZED_PLANE_STRAIN = 4
  integer, parameter, public :: DES_2D_AXISYMMETRIC = 5
  integer, parameter, public :: DES_2D_AXISYMMETRIC_TORSION = 6
  integer, parameter, public :: DES_2D_GENERAL_AXISYMMETRIC_FOURIER = 7

  ! Bilimsel çekirdek tarafından tanınan 2D continuum topolojileri.
  integer, parameter, public :: DES_TOPOLOGY_UNKNOWN = 0
  integer, parameter, public :: DES_TOPOLOGY_Q4 = 4
  integer, parameter, public :: DES_TOPOLOGY_T6 = 6
  integer, parameter, public :: DES_TOPOLOGY_Q8 = 8
  integer, parameter, public :: DES_TOPOLOGY_Q9_LEGACY = 9

  ! Kinematik/constraint formulation metadata'sı.
  integer, parameter, public :: DES_FORMULATION_UNKNOWN = 0
  integer, parameter, public :: DES_FORMULATION_PURE_U = 1
  integer, parameter, public :: DES_FORMULATION_MIXED_UP = 2

  ! Pressure approximation space. P1 burada complete-linear [1, xi, eta]
  ! element pressure alanını ve üç bağımsız pressure coefficient'ını ifade eder.
  integer, parameter, public :: DES_PRESSURE_SPACE_NONE = 0
  integer, parameter, public :: DES_PRESSURE_SPACE_P0 = 1
  integer, parameter, public :: DES_PRESSURE_SPACE_P1 = 2

  ! Element technology, topology'den ayrı tutulur. Böylece aynı Q4 topology
  ! selective/B-bar, uniform-reduced veya enhanced-strain davranışı taşıyabilir.
  ! Q8 production yönü ANSYS PLANE183 ve Marc 58/59/66 ile uyumlu reduced
  ! integration'dır. Q9 yalnız mevcut bilimsel reference hattı için tutulur.
  integer, parameter, public :: DES_ELEMENT_TECH_UNKNOWN = 0
  integer, parameter, public :: DES_ELEMENT_TECH_SELECTIVE_BBAR = 1
  integer, parameter, public :: DES_ELEMENT_TECH_UNIFORM_REDUCED = 2
  integer, parameter, public :: DES_ELEMENT_TECH_ENHANCED_STRAIN = 3
  integer, parameter, public :: DES_ELEMENT_TECH_TRIANGLE_3_POINT = 4
  integer, parameter, public :: DES_ELEMENT_TECH_LEGACY_REFERENCE_FULL = 5

  public :: des_2d_analysis_mode_is_valid
  public :: des_2d_analysis_allows_mixed_up
  public :: des_2d_analysis_requires_fourier_expansion
  public :: des_2d_nodal_kinematic_dof_count
  public :: des_2d_topology_node_count
  public :: des_2d_pressure_dof_count
  public :: des_2d_formulation_contract_is_valid
  public :: des_2d_element_technology_is_valid
  public :: des_2d_primary_mixed_pair_is_defined
  public :: des_2d_primary_mixed_configuration_is_defined

contains

  pure logical function des_2d_analysis_mode_is_valid(analysis_mode) result(is_valid)
    integer, intent(in) :: analysis_mode

    select case (analysis_mode)
    case (DES_2D_PLANE_STRESS, DES_2D_PLANE_STRESS_THICKNESS, &
          DES_2D_PLANE_STRAIN, DES_2D_GENERALIZED_PLANE_STRAIN, &
          DES_2D_AXISYMMETRIC, DES_2D_AXISYMMETRIC_TORSION, &
          DES_2D_GENERAL_AXISYMMETRIC_FOURIER)
      is_valid = .true.
    case default
      is_valid = .false.
    end select
  end function des_2d_analysis_mode_is_valid

  pure logical function des_2d_analysis_allows_mixed_up(analysis_mode) result(allows_mixed)
    integer, intent(in) :: analysis_mode

    ! ANSYS PLANE182/183 davranışına paralel ürün sözleşmesi:
    ! plane-stress kiplerinde mixed u-P kullanılmaz. Nearly-incompressible
    ! plane-stress constitutive thickness çözümü ayrı malzeme/kinematik yoludur.
    select case (analysis_mode)
    case (DES_2D_PLANE_STRAIN, DES_2D_GENERALIZED_PLANE_STRAIN, &
          DES_2D_AXISYMMETRIC, DES_2D_AXISYMMETRIC_TORSION, &
          DES_2D_GENERAL_AXISYMMETRIC_FOURIER)
      allows_mixed = .true.
    case default
      allows_mixed = .false.
    end select
  end function des_2d_analysis_allows_mixed_up

  pure logical function des_2d_analysis_requires_fourier_expansion(analysis_mode) result(requires_fourier)
    integer, intent(in) :: analysis_mode

    requires_fourier = analysis_mode == DES_2D_GENERAL_AXISYMMETRIC_FOURIER
  end function des_2d_analysis_requires_fourier_expansion

  pure integer function des_2d_nodal_kinematic_dof_count(analysis_mode) result(ndof)
    integer, intent(in) :: analysis_mode

    select case (analysis_mode)
    case (DES_2D_PLANE_STRESS, DES_2D_PLANE_STRESS_THICKNESS, &
          DES_2D_PLANE_STRAIN, DES_2D_GENERALIZED_PLANE_STRAIN, &
          DES_2D_AXISYMMETRIC)
      ndof = 2
    case (DES_2D_AXISYMMETRIC_TORSION)
      ! r-z kinematiğine çevresel/twist bileşeni eklenir.
      ndof = 3
    case (DES_2D_GENERAL_AXISYMMETRIC_FOURIER)
      ! General-axisymmetric/Fourier bir sabit üç-DOF problemi değildir.
      ! Aktif harmonik sayısına göre equation sayısı değişeceği için bu helper
      ! kasıtlı olarak 0 döndürür; dedicated Fourier DOF manager eklenmeden
      ! standard 2D layout bu analysis mode'u çözebilir gibi davranamaz.
      ndof = 0
    case default
      ndof = 0
    end select
  end function des_2d_nodal_kinematic_dof_count

  pure integer function des_2d_topology_node_count(topology) result(node_count)
    integer, intent(in) :: topology

    select case (topology)
    case (DES_TOPOLOGY_Q4)
      node_count = 4
    case (DES_TOPOLOGY_T6)
      node_count = 6
    case (DES_TOPOLOGY_Q8)
      node_count = 8
    case (DES_TOPOLOGY_Q9_LEGACY)
      node_count = 9
    case default
      node_count = 0
    end select
  end function des_2d_topology_node_count

  pure integer function des_2d_pressure_dof_count(pressure_space) result(ndof)
    integer, intent(in) :: pressure_space

    select case (pressure_space)
    case (DES_PRESSURE_SPACE_NONE)
      ndof = 0
    case (DES_PRESSURE_SPACE_P0)
      ndof = 1
    case (DES_PRESSURE_SPACE_P1)
      ndof = 3
    case default
      ndof = -1
    end select
  end function des_2d_pressure_dof_count

  pure logical function des_2d_formulation_contract_is_valid( &
      analysis_mode, formulation, pressure_space) result(is_valid)
    integer, intent(in) :: analysis_mode, formulation, pressure_space

    if (.not. des_2d_analysis_mode_is_valid(analysis_mode)) then
      is_valid = .false.
      return
    end if

    select case (formulation)
    case (DES_FORMULATION_PURE_U)
      is_valid = pressure_space == DES_PRESSURE_SPACE_NONE
    case (DES_FORMULATION_MIXED_UP)
      is_valid = des_2d_analysis_allows_mixed_up(analysis_mode) .and. &
          (pressure_space == DES_PRESSURE_SPACE_P0 .or. &
           pressure_space == DES_PRESSURE_SPACE_P1)
    case default
      is_valid = .false.
    end select
  end function des_2d_formulation_contract_is_valid

  pure logical function des_2d_element_technology_is_valid( &
      topology, analysis_mode, element_technology) result(is_valid)
    integer, intent(in) :: topology, analysis_mode, element_technology

    is_valid = .false.
    select case (topology)
    case (DES_TOPOLOGY_Q4)
      if (analysis_mode == DES_2D_AXISYMMETRIC_TORSION) then
        ! ANSYS PLANE182 torsion kipi yalnız full-integration B-bar/selective
        ! technology kullanır. Dyna Q4 torsion contract aynı kısıtı taşır.
        is_valid = element_technology == DES_ELEMENT_TECH_SELECTIVE_BBAR
      else
        is_valid = element_technology == DES_ELEMENT_TECH_SELECTIVE_BBAR .or. &
            element_technology == DES_ELEMENT_TECH_UNIFORM_REDUCED .or. &
            element_technology == DES_ELEMENT_TECH_ENHANCED_STRAIN
      end if
    case (DES_TOPOLOGY_Q8)
      ! PLANE183 quadrilateral stiffness 2x2 integration; Marc 58/59/66 da
      ! eight-node reduced-integration Herrmann ailesidir.
      is_valid = element_technology == DES_ELEMENT_TECH_UNIFORM_REDUCED
    case (DES_TOPOLOGY_T6)
      is_valid = element_technology == DES_ELEMENT_TECH_TRIANGLE_3_POINT
    case (DES_TOPOLOGY_Q9_LEGACY)
      is_valid = element_technology == DES_ELEMENT_TECH_LEGACY_REFERENCE_FULL
    case default
      is_valid = .false.
    end select
  end function des_2d_element_technology_is_valid

  pure logical function des_2d_primary_mixed_pair_is_defined( &
      topology, pressure_space) result(is_primary_pair)
    integer, intent(in) :: topology, pressure_space

    is_primary_pair = &
        (topology == DES_TOPOLOGY_Q4 .and. pressure_space == DES_PRESSURE_SPACE_P0) .or. &
        (topology == DES_TOPOLOGY_Q8 .and. pressure_space == DES_PRESSURE_SPACE_P1)
  end function des_2d_primary_mixed_pair_is_defined

  pure logical function des_2d_primary_mixed_configuration_is_defined( &
      topology, pressure_space, element_technology) result(is_primary_configuration)
    integer, intent(in) :: topology, pressure_space, element_technology

    ! İlk production aileleri:
    ! - Q4/P0 + selective/B-bar: lower-order robust nearly-incompressible path
    ! - Q8/P1 + reduced integration: ANSYS PLANE183 / Marc Herrmann high-order path
    is_primary_configuration = &
        (topology == DES_TOPOLOGY_Q4 .and. pressure_space == DES_PRESSURE_SPACE_P0 .and. &
         element_technology == DES_ELEMENT_TECH_SELECTIVE_BBAR) .or. &
        (topology == DES_TOPOLOGY_Q8 .and. pressure_space == DES_PRESSURE_SPACE_P1 .and. &
         element_technology == DES_ELEMENT_TECH_UNIFORM_REDUCED)
  end function des_2d_primary_mixed_configuration_is_defined

end module des_2d_analysis_contract
