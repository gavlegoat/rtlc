module shapes

    use, intrinsic :: iso_fortran_env, dp=>real64
    use vectors

    implicit none

    public :: shape, sphere, plane

    type, abstract :: shape
        real(dp) :: color(3)
        real(dp) :: reflectivity
        contains
        procedure :: get_color => get_color_shape
        procedure(get_normal_itf), deferred :: get_normal_vector
        procedure(get_intersection_itf), deferred :: get_intersection
    end type shape

    abstract interface
    function get_normal_itf(self, pt) result(norm)
        import :: shape, dp
        class(shape), intent(in) :: self
        real(dp), intent(in) :: pt(3)
        real(dp) :: norm(3)
    end function get_normal_itf

    function get_intersection_itf(self, pt, vec) result(t)
        import :: shape, dp
        class(shape), intent(in) :: self
        real(dp), intent(in) :: pt(3), vec(3)
        real(dp) :: t
    end function get_intersection_itf
    end interface

    type, extends(shape) :: sphere
        real(dp) :: center(3)
        real(dp) :: radius
        contains
        procedure :: get_normal_vector => get_normal_sphere
        procedure :: get_intersection => get_int_sphere
    end type sphere

    type, extends(shape) :: plane
        real(dp) :: point(3), normal(3), orientation(3), check_color(3)
        logical :: checkerboard
        contains
        procedure :: get_color => get_color_plane
        procedure :: get_normal_vector => get_normal_plane
        procedure :: get_intersection => get_int_plane
    end type plane

    contains

    !! Shape implementation

    pure function get_color_shape(self, pt) result(col)
        class(shape), intent(in) :: self
        real(dp), intent(in) :: pt(3)
        real(dp) :: col(3)

        col = self%color
    end function get_color_shape

    !! Sphere implementation

    pure function get_normal_sphere(self, pt) result(norm)
        class(sphere), intent(in) :: self
        real(dp), intent(in) :: pt(3)
        real(dp) :: norm(3)

        norm = pt - self%center
    end function get_normal_sphere

    pure function get_int_sphere(self, pt, vec) result(t)
        class(sphere), intent(in) :: self
        real(dp), intent(in) :: pt(3), vec(3)
        real(dp) :: t, a, b, c, discr, t1, t2

        a = dot_product(vec, vec)
        b = 2 * dot_product(pt - self%center, vec)
        c = dot_product(self%center - pt, self%center - pt) - self%radius ** 2
        discr = b**2 - 4 * a * c

        if (discr < 0) then
            t = -1._dp
        else
            t1 = (-b - sqrt(discr)) / (2 * a)
            t2 = (-b + sqrt(discr)) / (2 * a)
            if (t1 < 0) then
                t = t2
            else if (t2 < 0) then
                t = t1
            else
                t = min(t1, t2)
            end if
        end if
    end function get_int_sphere

    !! Plane implementation

    pure function get_normal_plane(self, pt) result(norm)
        class(plane), intent(in) :: self
        real(dp), intent(in) :: pt(3)
        real(dp) :: norm(3)

        norm = self%normal
    end function get_normal_plane

    pure function get_color_plane(self, pt) result(col)
        class(plane), intent(in) :: self
        real(dp), intent(in) :: pt(3)
        real(dp) :: col(3)
        real(dp) :: v(3), x(3), y(3)
        integer :: ix, iy

        if (.not. self%checkerboard) then
            col = self%color
            return
        end if

        v = pt - self%point
        x = project(v, self%orientation)
        y = v - x
        ix = floor(norm2(x) + 0.5_dp)
        iy = floor(norm2(y) + 0.5_dp)

        if (mod(ix + iy, 2) == 0) then
            col = self%color
        else
            col = self%check_color
        end if
    end function get_color_plane

    pure function get_int_plane(self, pt, vec) result(t)
        class(plane), intent(in) :: self
        real(dp), intent(in) :: pt(3), vec(3)
        real(dp) :: t

        if (abs(dot_product(vec, self%normal)) < 1.0e-6_dp) then
            t = -1._dp
        else
            t = dot_product(self%point - pt, self%normal) / dot_product(vec, self%normal)
        end if
    end function get_int_plane

end module shapes
