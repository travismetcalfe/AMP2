! Module   : gyre_atmos
! Purpose  : atmosphere utility routines
!
! Copyright 2013-2020 Rich Townsend & The GYRE Team
!
! This file is part of GYRE. GYRE is free software: you can
! redistribute it and/or modify it under the terms of the GNU General
! Public License as published by the Free Software Foundation, version 3.
!
! GYRE is distributed in the hope that it will be useful, but WITHOUT
! ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
! or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
! License for more details.
!
! You should have received a copy of the GNU General Public License
! along with this program.  If not, see <http://www.gnu.org/licenses/>.

$include 'core.inc'

module gyre_atmos

  ! Uses

  use core_kinds

  use gyre_point
  use gyre_math
  use gyre_model

  use ISO_FORTRAN_ENV

  ! No implicit typing

  implicit none

  ! Interfaces

  interface atmos_chi
     module procedure atmos_chi_r_
     module procedure atmos_chi_c_
  end interface atmos_chi

  ! Access specifiers

  private

  public :: atmos_chi
  public :: eval_atmos_cutoff_freqs
  public :: eval_atmos_coeffs_unno
  public :: eval_atmos_coeffs_isothrm

  ! Procedures

contains

  function atmos_chi_r_ (V, As, c_1, Gamma_1, omega, lambda) result (chi)

    real(WP), intent(in) :: V
    real(WP), intent(in) :: As
    real(WP), intent(in) :: c_1
    real(WP), intent(in) :: Gamma_1
    real(WP), intent(in) :: omega
    real(WP), intent(in) :: lambda
    real(WP)             :: chi

    real(WP)      :: a_11
    real(WP)      :: a_12
    real(WP)      :: a_21
    real(WP)      :: a_22
    real(WP)      :: b
    real(WP)      :: c
    real(WP)      :: psi2
    logical, save :: warned = .FALSE.

    ! Calculate the atmospheric radial wavenumber (real frequencies)

    a_11 = V/Gamma_1 - 3._WP
    a_12 = lambda/(c_1*omega**2) - V/Gamma_1
    a_21 = c_1*omega**2 - As
    a_22 = As + 1._WP

    b = -(a_11 + a_22)
    c = a_11*a_22 - a_12*a_21

    psi2 = b**2 - 4._WP*c

    if (psi2 < 0._WP) then

       if (.NOT. warned) then
!          $WARN(WARNING: Discarding imaginary part of atmospheric radial wavenumber)
          warned = .TRUE.
       endif

       chi = -b/2._WP

    else

       if (b >= 0._WP) then
          chi = (- b - sqrt(psi2))/2._WP
       else
          chi = 2._WP*c/(- b + sqrt(psi2))
       endif
       
    endif

    ! Finish

    return

  end function atmos_chi_r_

  !****

  function atmos_chi_c_ (V, As, c_1, Gamma_1, omega, lambda, branch) result (chi)

    real(WP), intent(in)               :: V
    real(WP), intent(in)               :: As
    real(WP), intent(in)               :: c_1
    real(WP), intent(in)               :: Gamma_1
    complex(WP), intent(in)            :: omega
    complex(WP), intent(in)            :: lambda
    character(*), intent(in), optional :: branch
    complex(WP)                        :: chi

    character(:), allocatable :: branch_
    complex(WP)               :: a_11
    complex(WP)               :: a_12
    complex(WP)               :: a_21
    complex(WP)               :: a_22
    complex(WP)               :: b
    complex(WP)               :: c
    complex(WP)               :: psi2
    complex(WP)               :: psi

    if (PRESENT(branch)) then
       branch_ = branch
    else
       branch_ = 'E_NEG'
    endif

    ! Calculate the atmospheric radial wavenumber (complex frequencies)

    a_11 = V/Gamma_1 - 3._WP
    a_12 = lambda/(c_1*omega**2) - V/Gamma_1
    a_21 = c_1*omega**2 - As
    a_22 = As + 1._WP

    b = -(a_11 + a_22)
    c = a_11*a_22 - a_12*a_21

    psi2 = b**2 - 4._WP*c
    psi = sqrt(psi2)

    ! Adjust the sign of psi to choose the correct solution branch

    select case (branch_)

    case ('E_POS')

       ! Outwardly-growing energy density

       if (REAL(psi) < 0._WP) psi = -psi

    case ('E_NEG')

       ! Outwardly-decaying energy density

       if (REAL(psi) > 0._WP) psi = -psi

    case ('F_POS')

       ! Outward energy flux

       if (AIMAG((psi - a_11)*CONJG(omega)) < 0._WP) psi = -psi

    case ('F_NEG')

       ! Inward energy flux

       if (AIMAG((psi - a_11)*CONJG(omega)) > 0._WP) psi = -psi

    case ('V_POS')

       ! Outward phase velocity

       if (AIMAG(psi)/REAL(omega) < 0._WP) psi = -psi

    case ('V_NEG')

       ! Inward phase velocity

       if (AIMAG(psi)/REAL(omega) > 0._WP) psi = -psi

    case default

       $ABORT(Invalid branch)

    end select

    ! Set up chi

    if (SIGN(1._WP, REAL(psi)) == SIGN(1._WP, REAL(b))) then

       chi = -2._WP*c/(b + psi)

    else

       chi = (- b + psi)/2._WP

    endif

    ! Finish

    return

  end function atmos_chi_c_

  !****

  subroutine eval_atmos_cutoff_freqs (V, As, c_1, Gamma_1, lambda, omega_cutoff_lo, omega_cutoff_hi)

    real(WP), intent(in)  :: V
    real(WP), intent(in)  :: As
    real(WP), intent(in)  :: c_1
    real(WP), intent(in)  :: Gamma_1
    real(WP), intent(in)  :: lambda
    real(WP), intent(out) :: omega_cutoff_lo
    real(WP), intent(out) :: omega_cutoff_hi

    real(WP) :: a
    real(WP) :: b
    real(WP) :: c

    ! Evaluate the atmospheric cutoff frequencies from the supplied coefficients

    a = -4._WP*V/Gamma_1*c_1**2
    b = ((As - V/Gamma_1 - 4._WP)**2 + 4._WP*V/Gamma_1*As + 4._WP*lambda)*c_1
    c = -4._WP*lambda*As

    omega_cutoff_lo = sqrt((-b + sqrt(b**2 - 4._WP*a*c))/(2._WP*a))
    omega_cutoff_hi = sqrt((-b - sqrt(b**2 - 4._WP*a*c))/(2._WP*a))
    
    $ASSERT(omega_cutoff_hi >= omega_cutoff_lo,Incorrect cutoff frequency ordering)

    ! Finish

    return

  end subroutine eval_atmos_cutoff_freqs

  !****
  
  subroutine eval_atmos_coeffs_unno (ml, pt, V, As, c_1, Gamma_1)

    class(model_t), intent(in) :: ml
    type(point_t), intent(in)  :: pt
    real(WP), intent(out)      :: V
    real(WP), intent(out)      :: As
    real(WP), intent(out)      :: c_1
    real(WP), intent(out)      :: Gamma_1

    ! Evaluate atmosphere coefficients ([Unn1989] formulation)

    V = ml%coeff(I_V_2, pt)*pt%x**2
    As = ml%coeff(I_AS, pt)
    c_1 = ml%coeff(I_C_1, pt)
    Gamma_1 = ml%coeff(I_GAMMA_1, pt)

    ! Finish

    return

  end subroutine eval_atmos_coeffs_unno

  !****
  
  subroutine eval_atmos_coeffs_isothrm (ml, pt, V, As, c_1, Gamma_1)

    class(model_t), intent(in) :: ml
    type(point_t), intent(in)  :: pt
    real(WP), intent(out)      :: V
    real(WP), intent(out)      :: As
    real(WP), intent(out)      :: c_1
    real(WP), intent(out)      :: Gamma_1

    ! Evaluate atmosphere coefficients for an isothermal, massless
    ! atmosphere

    V = ml%coeff(I_V_2, pt)*pt%x**2
    As = ml%coeff(I_V_2, pt)*pt%x**2*(1._WP-1._WP/ml%coeff(I_GAMMA_1, pt))
    c_1 = ml%coeff(I_C_1, pt)
    Gamma_1 = ml%coeff(I_GAMMA_1, pt)

    ! Finish

    return

  end subroutine eval_atmos_coeffs_isothrm

 end module gyre_atmos
