module letkf_obs_nc
  use letkf_obs
  use netcdf

  implicit none
  private


  ! public types
  public :: obsio_nc



  !============================================================  
  type, extends(obsio) :: obsio_nc
     !! class to read and write observations in NetCDF format
   contains
     procedure :: get_name => obsio_get_name
     procedure :: get_desc => obsio_get_desc     
     procedure :: write    => obs_write_nc
     procedure :: read     => obs_read_nc

  end type obsio_nc
  !============================================================



  
contains


  
  
  !============================================================
  function obsio_get_name(self)
    class(obsio_nc) :: self
    character(:), allocatable :: obsio_get_name
    obsio_get_name = "LETKF_NC"

    !pointless statement to get rid of unused argument warning
    self%i = self%i
  end function obsio_get_name
  !============================================================


  

  !============================================================
  function obsio_get_desc(self)
    class(obsio_nc) :: self
    character(:), allocatable :: obsio_get_desc
    obsio_get_desc = "netCDF observation I/O"

    !pointless statement to get rid of unused argument warning
    self%i = self%i    
  end function obsio_get_desc
  !============================================================
   
  

  
  !============================================================
  subroutine obs_write_nc(self, file, obs, iostat)
    class(obsio_nc) :: self
    character(len=*), intent(in) :: file
    type(observation), intent(in) :: obs(:)
    integer, optional, intent(out) :: iostat

    integer :: nobs, n
    integer :: ncid, dimid, varid
    integer,  allocatable :: tmp_i(:)
    real(4), allocatable :: tmp_r(:)

    !pointless statement to get rid of unused argument warning
    self%i = self%i

    !!@todo have iostat do something useful, or remove it
    if (present(iostat)) iostat = 1

    nobs = size(obs)
    allocate(tmp_i(nobs))
    allocate(tmp_r(nobs))

    ! create file definition
    call check( nf90_create(file, nf90_clobber, ncid))

    call check( nf90_put_att(ncid, nf90_global, "description",&
         "UMD-LETKF compatible observation file"))

    call check( nf90_def_dim(ncid, "obs",  nobs, dimid))
    call check( nf90_def_var(ncid, "obid",    nf90_int,  dimid, varid))
    call check( nf90_put_att(ncid, varid, "long_name", "observation ID number"))

    call check( nf90_def_var(ncid, "plat",  nf90_int,  dimid, varid))
    call check( nf90_put_att(ncid, varid, "long_name", "platform ID number"))
    call check( nf90_put_att(ncid, varid, "missing_value", 0))

    call check( nf90_def_var(ncid, "lat",   nf90_real, dimid, varid))
    call check( nf90_put_att(ncid, varid, "long_name", "latitude"))
    call check( nf90_put_att(ncid, varid, "units", "degrees"))

    call check( nf90_def_var(ncid, "lon",   nf90_real, dimid, varid))
    call check( nf90_put_att(ncid, varid, "long_name", "longitude"))
    call check( nf90_put_att(ncid, varid, "units", "degrees"))

    call check( nf90_def_var(ncid, "depth", nf90_real, dimid, varid))
    call check( nf90_put_att(ncid, varid, "long_name", "depth/height"))

    call check( nf90_def_var(ncid, "hr",  nf90_real, dimid, varid))
    call check( nf90_put_att(ncid, varid, "units", "hours"))

    call check( nf90_def_var(ncid, "val",   nf90_real, dimid, varid))
    call check( nf90_put_att(ncid, varid, "long_name", "observation value"))

    call check( nf90_def_var(ncid, "err",   nf90_real, dimid, varid))
    call check( nf90_put_att(ncid, varid, "long_name", "observation error"))

!    call check( nf90_def_var(ncid, "qc",    nf90_int,  dimid, varid))
!    call check( nf90_put_att(ncid, varid, "long_name", "quality control"))

    call check( nf90_enddef(ncid))

    ! write observations
    do n=1, nobs
       tmp_i(n) = obs(n)%id
    end do
    call check( nf90_inq_varid(ncid, "id", varid))
    call check( nf90_put_var(ncid, varid, tmp_i))

    do n=1, nobs
       tmp_i(n) = obs(n)%plat
    end do
    call check( nf90_inq_varid(ncid, "plat", varid))
    call check( nf90_put_var(ncid, varid, tmp_i))

    do n=1, nobs
       tmp_r(n) = obs(n)%lat
    end do
    call check( nf90_inq_varid(ncid, "lat", varid))
    call check( nf90_put_var(ncid, varid, tmp_r))

    do n=1, nobs
       tmp_r(n) = obs(n)%lon
    end do
    call check( nf90_inq_varid(ncid, "lon", varid))
    call check( nf90_put_var(ncid, varid, tmp_r))

    do n=1, nobs
       tmp_r(n) = obs(n)%depth
    end do
    call check( nf90_inq_varid(ncid, "depth", varid))
    call check( nf90_put_var(ncid, varid, tmp_r))

    do n=1, nobs
       tmp_r(n) = obs(n)%time
    end do
    call check( nf90_inq_varid(ncid, "time", varid))
    call check( nf90_put_var(ncid, varid, tmp_r))

    do n=1, nobs
       tmp_r(n) = obs(n)%val
    end do
    call check( nf90_inq_varid(ncid, "val", varid))
    call check( nf90_put_var(ncid, varid, tmp_r))

    do n=1, nobs
       tmp_r(n) = obs(n)%err
    end do
    call check( nf90_inq_varid(ncid, "err", varid))
    call check( nf90_put_var(ncid, varid, tmp_r))

    ! do n=1, nobs
    !    tmp_i(n) = obs(n)%qc
    ! end do
    ! call check( nf90_inq_varid(ncid, "qc", varid))
    ! call check( nf90_put_var(ncid, varid, tmp_i))

    ! all done, cleanup

    call check( nf90_close(ncid))

    deallocate(tmp_i)
    deallocate(tmp_r)

  end subroutine obs_write_nc
  !============================================================



  !============================================================
  subroutine obs_read_nc(self, file, obs, obs_ohx, obs_qc, iostat)
    class(obsio_nc) :: self
    character(len=*), intent(in) :: file
    type(observation), allocatable, intent(out) :: obs(:)
    real,    allocatable, intent(out) :: obs_ohx(:)
    integer, allocatable, intent(out) :: obs_qc(:)
    integer, intent(out), optional :: iostat

    integer :: nobs, n
    integer :: ncid, dimid, varid
    integer, allocatable :: tmp_i(:)
    real(4), allocatable :: tmp_r(:)

    !pointless statement to get rid of unused argument warning
    self%i = self%i

    !!@todo have iostat do something useful, or remove it
    if (present(iostat)) iostat = 1

    ! open the file
    call check( nf90_open(file, nf90_nowrite, ncid) )
    call check( nf90_inq_dimid(ncid, "obs", dimid))
    call check( nf90_inquire_dimension(ncid, dimid, len=nobs))

    ! allocate space depending on number of observations
    allocate(tmp_i(nobs))
    allocate(tmp_r(nobs))
    allocate(obs(nobs))

    ! read in the variables
    call check( nf90_inq_varid(ncid, "obid", varid))
    call check( nf90_get_var(ncid, varid, tmp_i))
    do n=1,nobs
       obs(n)%id = tmp_i(n)
    end do

    call check( nf90_inq_varid(ncid, "plat", varid))
    call check( nf90_get_var(ncid, varid, tmp_i))
    do n=1,nobs
       obs(n)%plat = tmp_i(n)
    end do

    call check( nf90_inq_varid(ncid, "lat", varid))
    call check( nf90_get_var(ncid, varid, tmp_r))
    do n=1,nobs
       obs(n)%lat = tmp_r(n)
    end do

    call check( nf90_inq_varid(ncid, "lon", varid))
    call check( nf90_get_var(ncid, varid, tmp_r))
    do n=1,nobs
       obs(n)%lon = tmp_r(n)
    end do

    call check( nf90_inq_varid(ncid, "depth", varid))
    call check( nf90_get_var(ncid, varid, tmp_r))
    do n=1,nobs
       obs(n)%depth = tmp_r(n)
    end do

    call check( nf90_inq_varid(ncid, "hr", varid))
    call check( nf90_get_var(ncid, varid, tmp_r))
    do n=1,nobs
       obs(n)%time = tmp_r(n)
    end do

    call check( nf90_inq_varid(ncid, "val", varid))
    call check( nf90_get_var(ncid, varid, tmp_r))
    do n=1,nobs
       obs(n)%val = tmp_r(n)
    end do

    call check( nf90_inq_varid(ncid, "err", varid))
    call check( nf90_get_var(ncid, varid, tmp_r))
    do n=1,nobs
       obs(n)%err = tmp_r(n)
    end do

    allocate(obs_qc(nobs))
    call check( nf90_inq_varid(ncid, "qc", varid))
    call check( nf90_get_var(ncid, varid, tmp_r))
    do n=1,nobs
       obs_qc(n)=tmp_r(n)
    end do

    allocate(obs_ohx(nobs))
    call check( nf90_inq_varid(ncid, "inc", varid))
    call check( nf90_get_var(ncid, varid, tmp_r))
    do n=1,nobs
       obs_ohx(n)=tmp_r(n)+obs(n)%val
    enddo

    ! close / cleanup
    call check( nf90_close(ncid))
    deallocate(tmp_i)
    deallocate(tmp_r)

  end subroutine obs_read_nc
  !============================================================




  !============================================================
  subroutine check(status)
    integer, intent(in) :: status

    if(status /= nf90_noerr) then
       write (*,*) trim(nf90_strerror(status))
       stop 1
    end if
  end subroutine check
  !============================================================



end module letkf_obs_nc
