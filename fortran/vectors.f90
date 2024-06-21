module vectors

    use, intrinsic :: iso_fortran_env, dp=>real64

    implicit none

    public :: project

    contains

    pure function project(u, v) result (p)
        real(dp), intent(in) :: u(:), v(:)
        real(dp), dimension(size(u)) :: p

        p = dot_product(u, v) / dot_product(v, v) * v
    end function project

end module vectors
