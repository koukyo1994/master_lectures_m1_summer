#include <stdio.h>
#include <math.h>
#include <omp.h>

void output(double dx,double dy,int nxmax,int nymax,
	    int sIDx,int sIDy,int eIDx,int eIDy,
	    double phi[nxmax][nymax]);

int main(int argc,char *argv[]){
  int nx,ny,sIDx,sIDy,eIDx,eIDy;
  int ithrd;
  double stime,etime;
  const int nxmax=100,nymax=100;
  const double Lxmax=1.0, Lymax=1.0, eps=1.0e-12, omg=1.5;
  const double ep0=8.85418782e-12;
  double dx,dy,X,Y,bnrm,rnrm,res,C1,C2,C3,C4;
  double phi[nxmax+3][nymax+3],rho[nxmax+3][nymax+3];
  sIDx=1; eIDx=nxmax+1; sIDy=1; eIDy=nymax+1;
  // -- initialize array --
  for(nx=0; nx<=nxmax+2; nx++){
    for(ny=0; ny<=nymax+2; ny++){
      phi[nx][ny]=0.0; rho[nx][ny]=0.0;
    }
  }
  // -- set dx and dy --
  dx=Lxmax/(double)(eIDx-sIDx); dy=Lymax/(double)(eIDy-sIDy);
  // -- set charge distribution --
  bnrm=0.0;
#pragma omp parallel for default(none) \
  private(nx,ny,X,Y,C1) \
  shared(sIDx,eIDx,sIDy,eIDy,dx,dy,rho)		\
  reduction(+:bnrm)
  for(nx=sIDx; nx<=eIDx; nx++){
    for(ny=sIDy; ny<=eIDy; ny++){
      X=(double)(nx-sIDx)*dx; Y=(double)(ny-sIDy)*dy;
      C1=(X-0.5*Lxmax)*(X-0.5*Lxmax)+(Y-0.5*Lymax)*(Y-0.5*Lymax);
      if(C1<0.05*0.05){
	rho[nx][ny]=1.0e-8/ep0;
      }
      // -- b norm --
      bnrm=bnrm+rho[nx][ny]*rho[nx][ny];
    }
  }
  bnrm=sqrt(bnrm)+eps; rnrm=bnrm;
  C1=1.0/(dx*dx); C3=1.0/(dy*dy);
  C2=1.0/(2.0/(dx*dx)+2.0/(dy*dy));
  C4=-(2.0/(dx*dx)+2.0/(dy*dy));
  // -- main iteration --
  stime=omp_get_wtime();
  while(rnrm/bnrm>eps){
    // -- SOR iteration --
#pragma omp parallel for default(none)		\
  private(nx,ny)				\
  shared(sIDx,eIDx,eIDy,phi,C1,C2,C3,rho)
    for(nx=sIDx; nx<=eIDx; nx++){
      for(ny=2-nx%2; ny<=eIDy; ny=ny+2){
	phi[nx][ny]=(1.0-omg)*phi[nx][ny]
	        +omg*C2*(rho[nx][ny]
		   +C1*phi[nx+1][ny]
		   +C1*phi[nx-1][ny]
		   +C3*phi[nx][ny+1]
		   +C3*phi[nx][ny-1]);
      }
    }
#pragma omp parallel for default(none)		\
  private(nx,ny)				\
  shared(sIDx,eIDx,eIDy,phi,C1,C2,C3,rho)    
    for(nx=sIDx; nx<=eIDx; nx++){
      for(ny=nx%2+1; ny<=eIDy; ny=ny+2){
	phi[nx][ny]=(1.0-omg)*phi[nx][ny]
	        +omg*C2*(rho[nx][ny]
		   +C1*phi[nx+1][ny]
		   +C1*phi[nx-1][ny]
		   +C3*phi[nx][ny+1]
		   +C3*phi[nx][ny-1]);
      }
    }
    // -- residual error norm --
    rnrm=0.0;
#pragma omp parallel for default(none)		\
  private(nx,ny,res)				\
  shared(sIDx,eIDx,sIDy,eIDy,phi,C1,C3,C4,rho)	\
  reduction(+:rnrm)
    for(nx=sIDx; nx<=eIDx; nx++){
      for(ny=sIDy; ny<=eIDy; ny++){
	res=C1*phi[nx+1][ny]
	   +C1*phi[nx-1][ny]
	   +C4*phi[nx][ny]
	   +C3*phi[nx][ny+1]
	   +C3*phi[nx][ny-1]
	   +rho[nx][ny];
	rnrm=rnrm+res*res;
      }
    }
    rnrm=sqrt(rnrm);
  }
  etime=omp_get_wtime();
  output(dx,dy,nxmax+3,nymax+3,sIDx,sIDy,eIDx,eIDy,phi);
  printf("The number of threads: %d\n",omp_get_max_threads());
  printf("Elapse time[s] in main loop: %lf\n",etime-stime);
}

void output(double dx,double dy,int nxmax,int nymax,
	    int sIDx,int sIDy,int eIDx,int eIDy,
	    double phi[nxmax][nymax]){
  int nx,ny;
  FILE *fp;
  char filename[80];
  double Ex,Ey;
  sprintf(filename,"./output.dat");
  fp=fopen(filename,"w");
  for(nx=sIDx;nx<=eIDx;nx++){
    for(ny=sIDy;ny<=eIDy;ny++){
      Ex=0.5*(phi[nx+1][ny]-phi[nx-1][ny])/dx;
      Ey=0.5*(phi[nx][ny+1]-phi[nx][ny-1])/dy;
      fprintf(fp,"%14.7e %14.7e %14.7e %14.7e %14.7e %14.7e\n",
      	      dx*(double)(nx-sIDx),dy*(double)(ny-sIDy),
	      phi[nx][ny],Ex,Ey,sqrt(Ex*Ex+Ey*Ey));
    }
    fprintf(fp,"\n");
  }
  fclose(fp);
  return;
}
