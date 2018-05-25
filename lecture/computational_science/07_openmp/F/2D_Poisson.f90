program Poisson
  use omp_lib
  implicit none
  integer::nx,ny,sIDx,sIDy,eIDx,eIDy
  double precision::stime,etime
  integer,parameter::nxmax=100,nymax=100
  double precision,parameter::Lxmax=1.0d0,Lymax=1.0d0,eps=1.0d-12,omg=1.5d0
  double precision,parameter::ep0=8.85418782d-12
  double precision::dx,dy,X,Y,bnrm,rnrm,res,C1,C2,C3,C4
  double precision::phi(-1:nxmax+1,-1:nymax+1),rho(-1:nxmax+1,-1:nymax+1)
  sIDx=0; eIDx=nxmax; sIDy=0; eIDy=nymax
  ! -- initialize array --
  do ny=-1,nymax+1
     do nx=-1,nxmax+1
        phi(nx,ny)=0.0d0; rho(nx,ny)=0.0d0
     enddo
  enddo
  ! -- set dx and dy --
  dx=Lxmax/dble(nxmax); dy=Lymax/dble(nymax)
  ! -- set charge distribution --
  bnrm=0.0d0
  !$omp parallel do default(none) &
  !$omp& private(nx,ny,X,Y,C1) &
  !$omp& shared(sIDx,eIDx,sIDy,eIDy,dx,dy,rho) &
  !$omp& reduction(+:bnrm)
  do ny=sIDy,eIDy
     do nx=sIDx,eIDx
        X=dble(nx)*dx; Y=dble(ny)*dy
        C1=(X-0.5d0*Lxmax)**2+(Y-0.5d0*Lymax)**2
        if(C1<0.05d0**2.0d0) then
           rho(nx,ny)=1.0d-8/ep0
        endif
        ! -- b norm --
        bnrm=bnrm+rho(nx,ny)**2.0d0
     enddo
  enddo
  !$omp end parallel do
  bnrm=dsqrt(bnrm)+eps; rnrm=bnrm
  C1=1.0d0/dx**2.0d0; C3=1.0d0/dy**2.0d0
  C2=1.0d0/(2.0d0/dx**2.0d0+2.0d0/dy**2.0d0)
  C4=-(2.0d0/dx**2.0d0+2.0d0/dy**2.0d0)
  ! -- main iteration --
  stime=omp_get_wtime()
  do while(rnrm/bnrm>eps)
     ! -- SOR iteration --
     !$omp parallel do default(none) &
     !$omp& private(nx,ny) &
     !$omp& shared(eIDx,sIDy,eIDy,phi,C1,C2,C3,rho)
     do ny=sIDy,eIDy
        do nx=mod(ny,2),eIDx,2
           phi(nx,ny)=(1.0d0-omg)*phi(nx,ny) &
                +omg*C2*(rho(nx,ny) &
                +C1*phi(nx+1,ny) &
                +C1*phi(nx-1,ny) &
                +C3*phi(nx,ny+1) &
                +C3*phi(nx,ny-1))
        enddo
     enddo
     !$omp end parallel do
     !
     !$omp parallel do default(none) &
     !$omp& private(nx,ny) &
     !$omp& shared(eIDx,sIDy,eIDy,phi,C1,C2,C3,rho)
     do ny=sIDy,eIDy
        do nx=1-mod(ny,2),eIDx,2
           phi(nx,ny)=(1.0d0-omg)*phi(nx,ny) &
                +omg*C2*(rho(nx,ny) &
                +C1*phi(nx+1,ny) &
                +C1*phi(nx-1,ny) &
                +C3*phi(nx,ny+1) &
                +C3*phi(nx,ny-1))
        enddo
     enddo
     !$omp end parallel do
     ! -- residual error norm --
     rnrm=0.0d0
     !$omp parallel do default(none) &
     !$omp& private(nx,ny,res) &
     !$omp& shared(sIDx,eIDx,sIDy,eIDy,phi,C1,C3,C4,rho) &
     !$omp& reduction(+:rnrm)
     do ny=sIDy,eIDy
        do nx=sIDx,eIDx
           res=C1*phi(nx+1,ny) &
              +C1*phi(nx-1,ny) &
              +C4*phi(nx,ny)   &
              +C3*phi(nx,ny+1) &
              +C3*phi(nx,ny-1) &
              +rho(nx,ny)
           rnrm=rnrm+res*res
        enddo
     enddo
     !$omp end parallel do
     rnrm=dsqrt(rnrm)
  enddo
  etime=omp_get_wtime()
  call output(dx,dy,nxmax,nymax,phi)
  print *,"The number of threads:",omp_get_max_threads()
  print *,"Elapse time[s] in main loop:",etime-stime
end program Poisson

subroutine output(dx,dy,nxmax,nymax,f)
  implicit none
  integer,intent(in)::nxmax,nymax
  double precision,intent(in)::dx,dy,f(-1:nxmax+1,-1:nymax+1)
  integer::nx,ny
  double precision::X,Y,Ex,Ey
  character(len=80)::filename
  write(filename,'("./output.dat")')
  open(unit=10,file=filename,status='replace')
  do ny=0,nymax
     do nx=0,nxmax
        X=dx*dble(nx); Y=dy*dble(ny)
        Ex=-0.5d0*(f(nx+1,ny)-f(nx-1,ny))/dx
        Ey=-0.5d0*(f(nx,ny+1)-f(nx,ny-1))/dy
        write(10,'(1pe15.7e3,1x,1pe15.7e3,1x,1pe15.7e3, &
             1x,1pe15.7e3,1x,1pe15.7e3,1x,1pe15.7e3)') &
             X,Y,f(nx,ny),Ex,Ey,dsqrt(Ex**2.0d0+Ey**2.0d0)
     enddo
     write(10,*)
  enddo
  close(10)
  return
end subroutine output
