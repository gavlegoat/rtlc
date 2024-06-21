module scenes

    use, intrinsic :: iso_fortran_env, dp=>real64
    use shapes
    use vectors

    implicit none

    public :: scene, object

    type object
        class(shape), allocatable :: item
    end type

    type :: scene
        real(dp) :: camera(3)
        real(dp) :: light(3)
        real(dp) :: ambient
        real(dp) :: specular
        integer :: specular_power
        integer :: max_reflections
        real(dp) :: background(3)
        type(object), dimension(:), allocatable :: shapes
        integer :: shapes_len
        contains
        procedure :: get_intersection
        procedure :: color_ray
        procedure :: color_point
    end type scene

    contains

    subroutine get_intersection(self, pt, vec, sh, min_time)
        class(scene), intent(in) :: self
        real(dp), intent(in) :: pt(3), vec(3)
        type(object), intent(out) :: sh
        real(dp), intent(out) :: min_time
        real(dp) :: time
        integer :: i

        min_time = -1._dp

        do i = 1, self%shapes_len
            time = self%shapes(i)%item%get_intersection(pt, vec)
            if (time > 0 .and. (min_time < 0 .or. time < min_time)) then
                min_time = time
                sh = self%shapes(i)
            end if
        end do
    end subroutine get_intersection

    recursive function color_ray(self, pt, vec, refls) result(col)
        class(scene), intent(in) :: self
        real(dp), intent(in) :: pt(3), vec(3)
        integer, intent(in) :: refls
        real(dp), dimension(3) :: col, int, c, l_amb, l_diff, l_spec, l_refl, &
        light_dir, norm, v, half, diff, refl
        type(object) :: obj, unused
        real(dp) :: t, amb, shadow_check

        call self%get_intersection(pt, vec, obj, t)

        if (t < 0) then
            col = self%background
            return
        end if

        int = pt + t * vec
        c = obj%item%get_color(int)
        amb = self%ambient * (1 - obj%item%reflectivity)
        l_amb = amb * c

        light_dir = self%light - int
        v = -vec / norm2(vec)
        norm = obj%item%get_normal_vector(int)
        norm = norm / norm2(norm)
        call self%get_intersection(int + 1.0e-5_dp * light_dir, light_dir, unused, shadow_check)
        if (shadow_check < 0) then
            light_dir = light_dir / norm2(light_dir)
            l_diff = (1 - amb) * (1 - obj%item%reflectivity) * max(0._dp, dot_product(norm, light_dir)) * c

            half = v + light_dir
            half = half / norm2(half)
            l_spec = self%specular * max(0._dp, dot_product(half, norm)) ** self%specular_power * &
            [255._dp, 255._dp, 255._dp]
        else
            l_diff = [0._dp, 0._dp, 0._dp]
            l_spec = [0._dp, 0._dp, 0._dp]
        end if

        if (refls < self%max_reflections .and. obj%item%reflectivity > 0.003) then
            diff = project(v, norm) - v
            refl = v + 2 * diff
            l_refl = (1 - amb) * obj%item%reflectivity * &
            self%color_ray(int + 1.0e-5_dp * refl, refl, refls + 1)
        else
            l_refl = [0._dp, 0._dp ,0._dp]
        end if

        col = l_amb + l_diff + l_spec + l_refl
    end function color_ray

    function color_point(self, pt) result(col)
        class(scene), intent(in) :: self
        real(dp), intent(in) :: pt(3)
        real(dp) :: col(3)

        col = self%color_ray(pt, pt - self%camera, 0)
    end function color_point

end module scenes
