module letkf
  !! main entry point for the LETKF library
  use timing
  use letkf_obs
  use letkf_mpi
  use letkf_core
  use letkf_state
  use letkf_loc

  implicit none
  private

  public :: letkf_driver_init
  public :: letkf_driver_run


  character(len=1024) :: nml_filename = "namelist.letkf"


  real :: infl_mul = 1.0
  real :: infl_rtps = 0.0
  real :: infl_rtpp = 0.0

  real :: loc_hz(2) = (/-1.0,-1.0/)

  real, allocatable :: diag_count_ij(:,:)
contains



  subroutine letkf_driver_init()
    !! Initialize the LETKF module. This must be called before anything else.
    call letkf_mpi_preinit()
    call timing_init(mpi_comm_letkf, pe_root)
    if (pe_isroot) then
       print "(A)", "============================================================"
       print "(A)", " Universal Multi-Domain Local Ensemble Transform Kalman Filter"
       print "(A)", " (UMD-LETKF)"
       print "(A)", " version 0.0.0"
       print "(A)", " Travis Sluka (tsluka@umd.edu, travis.sluka@noaa.gov)"
       print "(A)", "============================================================"
       print "(A)", ""
    end if
  end subroutine letkf_driver_init



  subroutine letkf_driver_run()
    real, allocatable :: wrk1(:)
    real, allocatable :: wrk3(:,:,:)
    real, allocatable :: wrk4(:,:,:,:)

    character(len=1024) :: filename
    integer :: t_total, t_init, t_letkf, t_output, timer, t_ens, t_ms
    integer :: unit
    integer :: m, i

    namelist /letkf_settings/ mem, grid_nx, grid_ny, grid_ns
    namelist /letkf_inflation/ infl_mul, infl_rtps, infl_rtpp
    namelist /letkf_localization/ loc_hz

    ! Initialize timers
    t_total = timer_init("Total")

    call timer_start(t_total)


    ! read in main section of the  namelist
    open(newunit=unit, file=nml_filename)
    read(unit, nml=letkf_settings)
    rewind(unit)
    read(unit, nml=letkf_inflation)
    rewind(unit)
    read(unit, nml=letkf_localization)
    close(unit)
    if (loc_hz(2) <= 0) loc_hz(2) = loc_hz(1)
    if (pe_isroot) then
       print letkf_settings
       print *, ""
       print letkf_inflation
       print *, ""
       print letkf_localization
    end if

    !make sure inflation parameters are correct
    if(pe_isroot) then
       if(loc_hz(1) <=0 .or. loc_hz(2) <= 0) then
          print *, "ERROR: illegal values for loc_hz. ", loc_hz
          stop 1
       end if
       if(infl_rtps > 1.0 .or. infl_rtps < 0.0) then
          print *, "ERROR: illegal value for infl_rtps (should be < 1.0 and >0.0). Value given: ", infl_rtps
          stop 1
       end if
       if(infl_rtpp > 1.0 .or. infl_rtpp < 0.0) then
          print *, "ERROR: illegal value for infl_rtpp (should be < 1.0 and >0.0). Value given: ", infl_rtpp
          stop 1
       end if
       if(infl_rtpp /= 0.0 .and. infl_rtps /= 0.0) then
          print *, "ERROR: cannot have both RTPS and RTPP enabled at the same time, check infl_rtpp and infl_rtps"
          stop 1
       end if
       if (infl_mul < 1.0) then
          print *, "WARNING, infl_mul is < 1.0. Are you sure this is what is intended ??? Value given: ",infl_mul
       end if
       if (infl_mul <= 0.0) then
          print *, "ERROR: illegal value for infl_mul: ",infl_mul
       end if
    end if


    ! initialize individual modules
    t_init  = timer_init("(init) ", TIMER_SYNC)
    call timer_start(t_init)

    ! mpi
    call letkf_mpi_init(nml_filename, mem, grid_nx, grid_ny, grid_ns)

    ! observations
    timer = timer_init("  obs", TIMER_SYNC)
    call timer_start(timer)
    call letkf_obs_init(nml_filename, "obsdef.cfg", "platdef.cfg")
    call timer_stop(timer)

    ! background state
    timer = timer_init("  state", TIMER_SYNC)
    call timer_start(timer)
    call letkf_state_init(nml_filename)
    call timer_stop(timer)

    ! LETKFcore
    call letkf_core_init(mem)
    call timer_stop(t_init)


    ! ensure output directory is setup right
    call system('mkdir -p OUTPUT')


    !------------------------------------------------------------

    ! run LETKF core
    if(pe_isroot) then
       print *, new_line('a'),&
            new_line('a'), '============================================================',&
            new_line('a'), ' Running LETKF core',&
            new_line('a'), '============================================================'
       print *, "Beginning core solver.."
    end if
    t_letkf = timer_init("(solve)", TIMER_SYNC)

    allocate(diag_count_ij(grid_ns,ij_count))
    diag_count_ij = 0.0
    call timer_start(t_letkf)
    call letkf_do_letkf()
    call timer_stop(t_letkf)


    ! begin output
    t_output = timer_init("(output)", TIMER_SYNC)
    call timer_start(t_output)
    allocate(wrk3(grid_nx, grid_ny, grid_ns))
    allocate(wrk1(ij_count))


    ! gather the analysis mean/sprd and write out
    if(pe_isroot) then
       print *, ""
       print *, "Writing analysis mean / spread..."
    end if
    t_ms = timer_init("  ana_meansprd", TIMER_SYNC)
    call timer_start(t_ms)

    ! ana mean
    do i=1,grid_ns
       wrk1 = ana_mean_ij(i,:)
       call letkf_mpi_ij2grd(wrk1, wrk3(:,:,i))
    end do
    if (pe_isroot) then
       print '(A,I5,3A)', " PROC ",pe_rank, " is WRITING file: ",&
            'OUTPUT/ana_mean', trim(stateio_class%extension)
       call stateio_class%write('OUTPUT/ana_mean', wrk3)
    end if

    ! ana spread
    do i=1,grid_ns
       wrk1 = ana_sprd_ij(i,:)
       call letkf_mpi_ij2grd(wrk1, wrk3(:,:,i))
    end do
    if (pe_isroot)  then
       print '(A,I5,3A)', " PROC ",pe_rank, " is WRITING file: ",&
            'OUTPUT/ana_sprd', trim(stateio_class%extension)
       call stateio_class%write('OUTPUT/ana_sprd', wrk3)
    end if
    call timer_stop(t_ms)


    ! write out other diagnostics
    if(pe_isroot) then
       print *, ""
       print *, "Writing diagnostics files..."
    end if

    ! obs count
    do i=1,grid_ns
       wrk1=diag_count_ij(i,:)
       call letkf_mpi_ij2grd(wrk1, wrk3(:,:,i))
    end do
    if(pe_isroot) then
       print '(A,I5,3A)', " PROC ",pe_rank, " is WRITING file: ",&
            'OUTPUT/diag_count', trim(stateio_class%extension)
       call stateio_class%write('OUTPUT/diag_count', wrk3)
    end if

    deallocate(wrk3)
    deallocate(wrk1)



    ! write the analysis ensemble members
    if(pe_isroot) then
       print *, ""
       print *, "Collecting analysis ensemble members..."
    end if
    t_ens = timer_init("  ana_ensemble", TIMER_SYNC)
    call timer_start(t_ens)

    allocate(wrk4(grid_nx, grid_ny, grid_ns, size(ens_list)))

    call letkf_mpi_ij2ens(ana_ij, wrk4)
    do m=1,size(ens_list)
       write (filename, '(A,I0.4,A)') 'OUTPUT/',ens_list(m)
       print '(A,I5,3A)', " PROC ",pe_rank, " is WRITING file: ", trim(filename), trim(stateio_class%extension)
       call stateio_class%write(filename, wrk4(:,:,:,m))
    end do

    deallocate(wrk4)
    call timer_stop(t_ens)
    call timer_stop(t_output)

    ! all done, cleanup
    call timer_stop(t_total)
    call timer_print()
    call letkf_mpi_final()

  end subroutine letkf_driver_run





  !============================================================
  subroutine letkf_do_letkf()
    !TODO move this to another module
    integer :: ij
    integer, parameter :: maxpt = 100000
    integer :: rpoints(maxpt)
    real :: rdistance(maxpt)
    integer :: rnum, ob_cnt

    real :: hdxb(mem,maxpt), rdiag(maxpt), rloc(maxpt), dep(maxpt)
    real :: trans(mem,mem)
    integer :: timer1, timer2, n, timer3
    integer :: i

    real :: loc_h
    real :: loc_hz_max
    real :: loc_hz_ij
    real, parameter :: pi = 4.0*atan(1.0)

    timer1 = timer_init("  obs_search")
    timer2 = timer_init("  core_solve")
    timer3 = timer_init("  core_trans")

    ana_ij = 0

    ! perform analysis at each grid point
    ! ------------------------------
    do ij=1,ij_count
       !TODO, don't include these gridpoints at all in the mpi ij allocation if the point is masked out
       if(mask_ij(ij) == 0) cycle

       !TODO, use a precomputed cos(lat) grid
       loc_hz_ij = loc_hz(2) + (loc_hz(1)-loc_hz(2))*cos(lat_ij(ij) * pi/180.0)
       loc_hz_max = loc_hz_ij * sqrt(40.0/3.0)

       ! search for all observations in a given radius of this gridpoint
       !TODO, do the KD tree call once to get all possible obs to be used by a grid BLOCK
       !
       call timer_start(timer1)
       call letkf_obs_get(lat_ij(ij), lon_ij(ij), loc_hz_max, rpoints, rdistance, rnum)
       call timer_stop(timer1)

       ! if there are observations found, process them
       ob_cnt = 0
       do i=1,rnum
          n = rpoints(i)

          !TODO, do this earlier in program
          ! get rid of obs with bad QC values
          if (obs_qc(n) /= 0) cycle

          ! calculate observation localization, and
          ! get rid of obs outside of localization radius
          loc_h = loc_gc(rdistance(i), loc_hz_ij)
          if (loc_h <= 0 ) cycle

          ! use this observation
          ob_cnt = ob_cnt + 1
          hdxb(:,ob_cnt) = obs_ohx(:,n)
          rdiag(ob_cnt)  = obs_list(n)%err
          rloc(ob_cnt) = loc_h
          dep(ob_cnt) = obs_list(n)%val - obs_ohx_mean(n)
          diag_count_ij(:,ij) = diag_count_ij(:,ij)+loc_h
       end do



       ! if there are still good quality observations to assimilate, do so
       if (ob_cnt > 0) then
          ! main LETKF equations
          call timer_start(timer2)
          call letkf_core_solve(ob_cnt,&
               hdxb(:,:ob_cnt), rdiag(:ob_cnt), rloc(:ob_cnt),&
               dep(:ob_cnt), 1.0e0, trans)
          call timer_stop(timer2)

          ! calculate the ensemble increments by applying the trans matrix
          !TODO, if not doing vertical localization, do all grid_ns layers at once
          call timer_start(timer3)
          do i=1,grid_ns
             call sgemm('n','n', 1, mem, mem, 1.0e0, bkg_ij(:,i,ij),&
                  1, trans, mem, 0.0e0, ana_ij(:,i,ij), 1)
          end do
          call timer_stop(timer3)
       else
          ana_ij(:,:, ij) = bkg_ij(:,:,ij)
       end if

       ! recenter analysis perturbations on new analysis mean
       do i=1,grid_ns
          ana_ij(:,i,ij) = ana_ij(:,i,ij) + bkg_mean_ij(i,ij)
          ana_mean_ij(i,ij) = sum(ana_ij(:,i,ij),1)/mem
          ana_ij(:,i,ij) = ana_ij(:,i,ij) - ana_mean_ij(i,ij)
       end do
       do i = 1, grid_ns
          ana_sprd_ij(i,ij) = sqrt(dot_product(ana_ij(:,i,ij),ana_ij(:,i,ij)) /mem)
       end do


       ! inflation
       ! ------------------------------
       ! RTPS (relaxation to prior spread)
       if(infl_rtps > 0) then
          do i =1,grid_ns
             if (ana_sprd_ij(i,ij) > 0) then
                ana_ij(:,i,ij) = ana_ij(:,i,ij) * &
                     (infl_rtps * (bkg_sprd_ij(i,ij)-ana_sprd_ij(i,ij))/ana_sprd_ij(i,ij) + 1)
             end if
          end do
       end if

       ! RTPP (relaxation to prior perturbations
       if(infl_rtpp > 0) then
          do i=1,grid_ns
             ana_ij(:,i,ij) = bkg_ij(:,i,ij) * infl_rtpp + (1.0-infl_rtpp)*ana_ij(:,i,ij)
          end do
       end if

       ! constant multiplicative
       if(infl_mul /= 1.0) then
          ana_ij(:,:,ij) = ana_ij(:,:,ij) * infl_mul
       end if

       ! ------------------------------

       !add mean to perturbations
       do i=1,grid_ns
          ana_ij(:,i,ij) = ana_ij(:,i,ij) + ana_mean_ij(i,ij)
       end do


       ! recalculate analysis spread
       do i = 1, grid_ns
          ana_sprd_ij(i,ij) = sqrt(&
               dot_product(ana_ij(:,i,ij)-ana_mean_ij(i,ij),ana_ij(:,i,ij)-ana_mean_ij(i,ij)) /mem)
       end do

    end do


  end subroutine letkf_do_letkf



end module letkf