program main
  use, intrinsic :: iso_fortran_env, dp=>real64
    use scenes
    use json_module, wp=>json_RK
    implicit none

    type(json_file) :: infile
    character(len=100) :: arg
    type(scene) :: sc
    real(dp), allocatable :: image(:, :, :)
    integer :: i, j, k, antialias, io, num_objs
    real(dp) :: rx, ry, light(3), cam(3), color(3), radius, center(3), &
    point(3), normal(3), ori(3), check_color(3), refl
    real(wp), dimension(:), allocatable :: tmp
    character(len=:, kind=json_CK), allocatable :: type
    logical :: found, checkerboard
    type(sphere) :: sph
    type(plane) :: pl
    integer :: pixel, width = 512, height = 512

    if (command_argument_count() /= 2) then
        call perror("Usage: ./trace <config-file> <output-file>")
        return
    end if

    ! Parse scene

    call infile%initialize()
    call get_command_argument(1, arg)
    call infile%load(filename = arg)

    sc%ambient = 0.2_dp
    sc%specular = 0.5_dp
    sc%specular_power = 8
    sc%max_reflections = 6
    sc%background = [135._dp, 206._dp, 235._dp]
    call infile%get('antialias', antialias, found)
    if (.not. found) stop 1
    call infile%get('light', tmp, found)
    light = tmp
    if (.not. found) stop 1
    call infile%get('camera', tmp, found)
    cam = tmp
    if (.not. found) stop 1
    sc%light = light
    sc%camera = cam
    num_objs = 0
    do
        num_objs = num_objs + 1
        write (arg, '(A, I0, A)') 'objects(', num_objs, ').reflectivity'
        call infile%get(arg, refl, found)
        if (.not. found) exit
    end do
    num_objs = num_objs - 1
    allocate(sc%shapes(num_objs))
    sc%shapes_len = num_objs
    do i = 1, num_objs
        write (arg, '(A, I0, A)') 'objects(', i, ').reflectivity'
        call infile%get(arg, refl, found)
        if (.not. found) stop 1
        write (arg, '(A, I0, A)') 'objects(', i, ').color'
        call infile%get(arg, tmp, found)
        color = tmp
        if (.not. found) stop 1
        write (arg, '(A, I0, A)') 'objects(', i, ').type'
        call infile%get(arg, type, found)
        if (.not. found) stop 1
        if (type == "sphere") then
            sph%reflectivity = refl
            sph%color = color
            write (arg, '(A, I0, A)') 'objects(', i, ').center'
            call infile%get(arg, tmp, found)
            if (.not. found) stop 1
            sph%center = tmp
            write (arg, '(A, I0, A)') 'objects(', i, ').radius'
            call infile%get(arg, sph%radius, found)
            if (.not. found) stop 1
            allocate(sphere::sc%shapes(i)%item)
            sc%shapes(i)%item = sph
        else
            pl%reflectivity = refl
            pl%color = color
            write (arg, '(A, I0, A)') 'objects(', i, ').point'
            call infile%get(arg, tmp, found)
            if (.not. found) stop 1
            pl%point = tmp
            write (arg, '(A, I0, A)') 'objects(', i, ').normal'
            call infile%get(arg, tmp, found)
            if (.not. found) stop 1
            pl%normal = tmp
            write (arg, '(A, I0, A)') 'objects(', i, ').checkerboard'
            call infile%get(arg, pl%checkerboard, found)
            if (.not. found) stop 1
            if (pl%checkerboard) then
                write (arg, '(A, I0, A)') 'objects(', i, ').orientation'
                call infile%get(arg, tmp, found)
                if (.not. found) stop 1
                pl%orientation = tmp
                write (arg, '(A, I0, A)') 'objects(', i, ').color2'
                call infile%get(arg, tmp, found)
                if (.not. found) stop 1
                pl%check_color = tmp
            end if
            allocate(plane::sc%shapes(i)%item)
            sc%shapes(i)%item = pl
        end if
    end do

    call infile%destroy()

    ! Generate image

    allocate(image(width, height, 3))

    do j = 1, height
        do i = 1, width
            image(j, i, :) = 0._dp
            do k = 1, antialias
                rx = rand(0)
                ry = rand(0)
                color = sc%color_point( &
                [(real(i) + rx) / width, &
                0._dp, &
                1._dp - (real(j) + ry) / width])
                image(j, i, :) = image(j, i, :) + color
            end do
            image(j, i, :) = image(j, i, :) / antialias
        end do
    end do

    deallocate(sc%shapes)

    ! Write Image (PPM)

    call get_command_argument(2, arg)
    open(newunit=io, file=arg, access="stream")

    write(io) 'P6' // achar(10)
    write(arg, '(I0,A,I0,A)') size(image, 1), ' ', size(image, 2), achar(10)
    write(io) arg
    write(io) '255' // achar(10)

    do i = 1, size(image, 1)
        do j = 1, size(image, 2)
            pixel = min(255, max(0, floor(image(i, j, 1) + 0.5_dp)))
            write(io) achar(pixel)
            pixel = min(255, max(0, floor(image(i, j, 2) + 0.5_dp)))
            write(io) achar(pixel)
            pixel = min(255, max(0, floor(image(i, j, 3) + 0.5_dp)))
            write(io) achar(pixel)
        end do
    end do

    close(io)
    deallocate(image)

end program main
