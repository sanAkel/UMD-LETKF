module letkf_state_generic
  ! TODO, make an actual generic one... this is for the MOM4 grid
  use letkf_state_I

  use netcdf

  implicit none
  private

  public :: stateio_generic

  type, extends(stateio) :: stateio_generic
   contains
     procedure :: init   => stateio_generic_init
     procedure :: read   => stateio_generic_read
     procedure :: write  => stateio_generic_write
     procedure :: latlon => stateio_generic_latlon
     procedure :: mask   => stateio_generic_mask
  end type stateio_generic


  integer :: grid_nx, grid_ny, grid_nz

  real, allocatable :: nom_lon(:), nom_lat(:), depths(:)


contains


  subroutine stateio_generic_latlon(self, lat, lon)
    class(stateio_generic) :: self
    real, intent(inout) :: lat(:,:)
    real, intent(inout) :: lon(:,:)
    integer :: ncid, varid

    ! pointless statement to prevent "self" not used warnings
    self%description = self%description

    call check(nf90_open('INPUT/grid_spec.nc', nf90_nowrite, ncid))
    call check(nf90_inq_varid(ncid, 'x_T', varid))
    call check(nf90_get_var(ncid, varid, lon))
    call check(nf90_inq_varid(ncid, 'y_T', varid))
    call check(nf90_get_var(ncid, varid, lat))
    call check(nf90_close(ncid))
  end subroutine stateio_generic_latlon



  subroutine stateio_generic_mask(self, mask)
    class(stateio_generic) :: self
    real, intent(inout) :: mask(:,:)
    integer :: ncid, varid

    ! pointless statement to prevent "self" not used warnings
    self%description = self%description

    call check(nf90_open('INPUT/grid_spec.nc', nf90_nowrite, ncid))
    call check(nf90_inq_varid(ncid, 'wet', varid))
    call check(nf90_get_var(ncid, varid, mask))
    call check(nf90_close(ncid))
  end subroutine stateio_generic_mask



  subroutine stateio_generic_init(self, x,y,z)
    class(stateio_generic) :: self
    integer, intent(in) :: x, y, z
    integer :: ncid, varid

    grid_nx = x
    grid_ny = y
    grid_nz = z
    self%description = "MOM ocean I/O"
    self%extension   = ".nc"

    call check(nf90_open('INPUT/grid_spec.nc', nf90_write, ncid))
    allocate(nom_lon(grid_nx))
    allocate(nom_lat(grid_ny))
    allocate(depths(grid_nz))
    call check(nf90_inq_varid(ncid, "grid_x_T", varid))
    call check(nf90_get_var(ncid, varid, nom_lon))
    call check(nf90_inq_varid(ncid, "grid_y_T", varid))
    call check(nf90_get_var(ncid, varid, nom_lat))
    call check(nf90_inq_varid(ncid, "zt", varid))
    call check(nf90_get_var(ncid, varid, depths))
    call check(nf90_close(ncid))
  end subroutine stateio_generic_init



  subroutine stateio_generic_read(self, filename, state)
    class(stateio_generic) :: self
    character(len=*), intent(in)  :: filename
    real, intent(out) :: state(:,:,:)

    integer :: ncid, varid

    call check(nf90_open(trim(filename)//trim(self%extension), nf90_nowrite, ncid))
    call check(nf90_inq_varid(ncid, "temp", varid))
    call check(nf90_get_var(ncid, varid, state(:,:,1:40)))
    call check(nf90_inq_varid(ncid, "salt", varid))
    call check(nf90_get_var(ncid, varid, state(:,:,41:80)))
    call check(nf90_close(ncid))

  end subroutine stateio_generic_read



  subroutine stateio_generic_write(self, filename, state)
    class(stateio_generic) :: self
    character(len=*), intent(in)  :: filename
    real, intent(in) :: state(:,:,:)

    integer :: ncid
    integer :: d_x, d_y, d_z, v_t, v_s, v_x, v_y, v_z

    call check(nf90_create(trim(filename)//trim(self%extension), nf90_write, ncid))
    call check(nf90_def_dim(ncid, "grid_x", grid_nx, d_x))
    call check(nf90_def_var(ncid, "grid_x", nf90_real, (/d_x/), v_x))
    call check(nf90_put_att(ncid, v_x, "units", "degrees_east"))

    call check(nf90_def_dim(ncid, "grid_y", grid_ny, d_y))
    call check(nf90_def_var(ncid, "grid_y", nf90_real, (/d_y/), v_y))
    call check(nf90_put_att(ncid, v_y, "units", "degrees_north"))

    call check(nf90_def_dim(ncid, "grid_z", grid_nz, d_z))
    call check(nf90_def_var(ncid, "grid_z", nf90_real, (/d_z/), v_z))
    call check(nf90_put_att(ncid, v_z, "units", "meters"))

    call check(nf90_def_var(ncid, "temp",  nf90_real, (/d_x,d_y,d_z/), v_t))
    call check(nf90_def_var(ncid, "salt",  nf90_real, (/d_x,d_y,d_z/), v_s))
    call check(nf90_enddef(ncid))

    call check(nf90_put_var(ncid, v_t, state(:,:,1:40)))
    call check(nf90_put_var(ncid, v_s, state(:,:,41:80)))
    call check(nf90_put_var(ncid, v_x, nom_lon))
    call check(nf90_put_var(ncid, v_y, nom_lat))
    call check(nf90_put_var(ncid, v_z, depths))
    call check(nf90_close(ncid))

  end subroutine stateio_generic_write



  subroutine check(status)
    integer, intent(in) :: status
    if(status /= nf90_noerr) then
       write (*,*) trim(nf90_strerror(status))
       stop 1
    end if
  end subroutine check
end module letkf_state_generic
