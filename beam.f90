! Copyright (C) 2002, 2010 Carnegie Mellon University and others.
! All Rights Reserved.
! This code is published under the Eclipse Public License.
!
!    $Id: hs071_f.f.in 1861 2010-12-21 21:34:47Z andreasw $
!
! =============================================================================
!
!
!  This file contains routines to define a small Rosenbrock test problem.
!
!  f=0 at the optimal solution for x_i=1 for all i!
!
! =============================================================================
!
!
! =============================================================================
!
!                            Main driver program
!
! =============================================================================
!
program example
  !
  implicit none
  !
  !     include the Ipopt return codes
  !
  include 'IpReturnCodes.inc'
  !
  !     Size of the problem (number of variables and equality constraints)
  !
  integer     N,     M,     NELE_JAC,     NELE_HESS,      IDX_STY
  parameter  (N = 4, M = 3, NELE_JAC = 12, NELE_HESS = 10)
  parameter  (IDX_STY = 1 )
  !
  !     Space for multipliers and constraints
  !
  double precision LAM(M)
  double precision G(M)
  !
  !     Vector of variables
  !
  double precision X(N)
  !
  !     Vector of lower and upper bounds
  !
  double precision X_L(N), X_U(N), Z_L(N), Z_U(N)
  double precision G_L(M), G_U(M)
  !
  !     Private data for evaluation routines
  !     This could be used to pass double precision and integer arrays untouched
  !     to the evaluation subroutines EVAL_*
  !
  double precision DAT(1000)
  integer IDAT(1)
  !
  !     Place for storing the Ipopt Problem Handle
  !
  integer*8 IPROBLEM
  integer*8 IPCREATE
  !
  integer IERR
  integer IPSOLVE, IPADDSTROPTION
  integer IPADDNUMOPTION, IPADDINTOPTION
  integer IPOPENOUTPUTFILE
  !
  double precision F
  integer i

  double precision  infbound
  parameter        (infbound = 1.d+20)

  !
  !     The following are the Fortran routines for computing the model
  !     functions and their derivatives - their code can be found further
  !     down in this file.
  !
  external EV_F, EV_G, EV_GRAD_F, EV_JAC_G, EV_HESS
  !!
  !!     The next is an optional callback method.  It is called once per
  !!     iteration.
  !!
  external ITER_CB
  !
  !     Set initial point and bounds:
  !

  do i=1,N-2
     X(i)   = 1.00  
     X_L(i) = 0.25  
     X_U(i) = infbound 
  end do

  X(3)  = 40.e6
  X_L(3)= 30.e6
  X_U(3)= 50.e6

  X(4)  = 150.0e3
  X_L(4)= 130.0e3
  X_U(4)= 170.0e3


  dat(1) = 10.d6         !     sigma_allow= 10.0 !N/mm2
  dat(2) = 2.0d6         !     tau_allow
  dat(3) = 1.0           !     Fs

  !
  !     Set bounds for the constraints
  !

  do i=1,M-1
     G_L(i)=-infbound
     G_U(i)=0.d0
  end do

  !Equality constraint
  G_L(M)=0.0d0
  G_U(M)=0.d0

  !
  !     First create a handle for the Ipopt problem (and read the options
  !     file)
  !

  IPROBLEM = IPCREATE(N, X_L, X_U, M, G_L, G_U, NELE_JAC, NELE_HESS,IDX_STY, EV_F, EV_G, EV_GRAD_F, EV_JAC_G, EV_HESS)
  if (IPROBLEM.eq.0) then
     write(*,*) 'Error creating an Ipopt Problem handle.'
     stop
  endif
  !
  !     Open an output file
  !
  IERR = IPOPENOUTPUTFILE(IPROBLEM, 'IPOPT.OUT', 50)
  if (IERR.ne.0 ) then
     write(*,*) 'Error opening the Ipopt output file.'
     goto 9000
  endif

  !
  !!
  !!     Set a callback function to give you control once per iteration.
  !!     You can use it if you want to generate some output, or to stop
  !!     the optimization early.
  !!
  call IPSETCALLBACK(IPROBLEM, ITER_CB)

  !
  !     As a simple example, we pass the constants in the constraints to
  !     the EVAL_C routine via the "private" DAT array.
  !

  !      DAT(2) = 0.d0
  !
  !     Call optimization routine
  !
  IERR = IPSOLVE(IPROBLEM, X, G, F, LAM, Z_L, Z_U, IDAT, DAT)
  !
  !     Output:
  !
  if( IERR.eq.IP_SOLVE_SUCCEEDED ) then
     write(*,*)
     write(*,*) 'The solution was found.'
     write(*,*)
     write(*,*) 'The final value of the objective function is ',F
     write(*,*)
     write(*,*) 'The optimal values of X are:'
     write(*,*)
     do i = 1, N
        write(*,*) 'X  (',i,') = ',X(i)
     enddo
!!$         write(*,*)
!!$         write(*,*) 'The multipliers for the lower bounds are:'
!!$         write(*,*)
!!$         do i = 1, N
!!$            write(*,*) 'Z_L(',i,') = ',Z_L(i)
!!$         enddo
!!$         write(*,*)
!!$         write(*,*) 'The multipliers for the upper bounds are:'
!!$         write(*,*)
!!$         do i = 1, N
!!$            write(*,*) 'Z_U(',i,') = ',Z_U(i)
!!$         enddo
     write(*,*)
     write(*,*) 'The multipliers for the equality constraints are:'
     write(*,*)
     do i = 1, M
        write(*,*) 'LAM(',i,') = ',LAM(i)
     enddo
  else
     write(*,*)
     write(*,*) 'An error occoured.'
     write(*,*) 'The error code is ',IERR
     write(*,*)
  endif
  !
9000 continue
  !
  !     Clean up
  !
  call IPFREE(IPROBLEM)
  stop
  !
9990 continue
  write(*,*) 'Error setting an option'
  goto 9000
end program example
!
! =============================================================================
!
!                    Computation of objective function
!
! =============================================================================
!
      subroutine EV_F(N, X, NEW_X, F, IDAT, DAT, IERR)
      implicit none
      integer N, NEW_X,I
      double precision F, X(N)
      double precision DAT(*)
      integer IDAT(*)
      integer IERR
      real*8 :: rho, L, sigmay, pi, Fs, p, E, R, T,sigma_allow
      real*8:: tau_allow,BM,V

      f=x(1)*x(2)

      IERR = 0

      return
    end subroutine EV_F
!
! =============================================================================
!
!                Computation of gradient of objective function
!
! =============================================================================
!
      subroutine EV_GRAD_F(N, X, NEW_X, GRAD, IDAT, DAT, IERR)
      implicit none
      integer N, NEW_X,i
      double precision GRAD(N), X(N)
      double precision DAT(*)
      integer IDAT(*)
      integer IERR
      real*8 :: rho, L, sigmay, pi, Fs, p, E, R, T,sigma_allow
      real*8:: tau_allow,BM,V

      sigma_allow=dat(1)
      tau_allow=dat(2)
      Fs=dat(3)

      grad(1) = x(2)*Fs
      grad(2) = x(1)*Fs
      grad(3)= 0.0
      grad(4)= 0.0

      IERR = 0

      return
    end subroutine EV_GRAD_F
!
! =============================================================================
!
!                     Computation of equality constraints
!
! =============================================================================
!
      subroutine EV_G(N, X, NEW_X, M, G, IDAT, DAT, IERR)
      implicit none
      integer N, NEW_X, M
      double precision G(M), X(N)
      double precision DAT(*)
      integer IDAT(*)
      integer IERR
      real*8 :: rho, L, sigmay, pi, Fs, p, E, R, T,sigma_allow
      real*8:: tau_allow,BM,V,B,D

      sigma_allow=dat(1)
      tau_allow=dat(2)
      Fs=dat(3)


      B=x(1)
      D=x(2)
      BM=x(3)
      V=x(4)
      
      G(1)=6.0*BM*Fs/(B*D**2*sigma_allow) -1.0
      G(2)=3.0*V*Fs/(2.0*B*D*tau_allow) -1.0
      G(3)=D*Fs/(2.0*B) -1.0


      IERR = 0

      return
    end subroutine EV_G
!
! =============================================================================
!
!                Computation of Jacobian of equality constraints
!
! =============================================================================
!
      subroutine EV_JAC_G(TASK, N, X, NEW_X, M, NZ, ACON, AVAR, A,IDAT, DAT, IERR)
      integer TASK, N, NEW_X, M, NZ
      double precision X(N), A(NZ)
      integer ACON(NZ), AVAR(NZ), I
      double precision DAT(*),dc(M,N)
      integer IDAT(*)
      integer IERR
      real*8 :: rho, L, sigmay, pi, Fs, p, E, R, T,sigma_allow
      real*8:: tau_allow,BM,V


      if( TASK.eq.0 ) then 
         !
         !     structure of Jacobian:
         !     

         ! con 1

         ACON(1) = 1
         AVAR(1) = 1

         ACON(2) = 1
         AVAR(2) = 2

         ACON(3) = 1
         AVAR(3) = 3
      
         ACON(4) = 1
         AVAR(4) = 4


         ! con 2
         
         ACON(5) = 2
         AVAR(5) = 1
         
         ACON(6) = 2
         AVAR(6) = 2
         
         ACON(7) = 2
         AVAR(7) = 3
         
         ACON(8) = 2
         AVAR(8) = 4

         !con 3

         
         ACON(9)  = 3
         AVAR(9)  = 1
         
         ACON(10) = 3
         AVAR(10) = 2
         
         ACON(11) = 3
         AVAR(11) = 3
         
         ACON(12) = 3
         AVAR(12) = 4
        

      else


      sigma_allow=dat(1)
      tau_allow=dat(2)
      Fs=dat(3)

      B=x(1)
      D=x(2)
      BM=x(3)
      V=x(4)

         !---- GRADIENT OF CONSTRAINTS

         dc(:,:) =  0.0


         dc(1,1)= -(6.0*Fs*BM)/(B**2*D**2*sigma_allow)
         dc(1,2)= -(12.0*Fs*BM)/(B*D**3*sigma_allow)
         dc(1,3)=  (6.0*Fs)/(B*D**2*sigma_allow)
         dc(1,4)=  0.0


         dc(2,1)= -(3.0*Fs*V)/(2.0*B**2*D*tau_allow)
         dc(2,2)= -(3.0*Fs*V)/(2.0*B*D**2*tau_allow)
         dc(2,3)=   0.0
         dc(2,4)=  (3.0*Fs)/(2.0*B*D*tau_allow)

         dc(3,1)= -(D*Fs)/(2.0*B**2)
         dc(3,2)= Fs/(2.0*B)
         dc(3,3)= 0.0
         dc(3,4)= 0.0


         A(1)=dc(1,1)
         A(2)=dc(1,2)
         A(3)=dc(1,3)
         A(4)=dc(1,4)


         A(5)=dc(2,1)
         A(6)=dc(2,2)
         A(7)=dc(2,3)
         A(8)=dc(2,4)

         A(9)=dc(3,1)
         A(10)=dc(3,2)
         A(11)=dc(3,3)
         A(12)=dc(3,4)

      end if

      IERR = 0
      return
    end subroutine EV_JAC_G

!
! =============================================================================
!
!                Computation of Hessian of Lagrangian
!
! =============================================================================
!
      subroutine EV_HESS(TASK, N, X, NEW_X, OBJFACT, M, LAM, NEW_LAM,NNZH, IRNH, ICNH, HESS, IDAT, DAT, IERR)
      implicit none
      integer TASK, N, NEW_X, M, NEW_LAM, NNZH, i, ir,j
      double precision X(N), OBJFACT, LAM(M), HESS(NNZH),OBJHESS(NNZH),CONHESS(M,NNZH)

      integer IRNH(NNZH), ICNH(NNZH)
      double precision DAT(*)
      integer IDAT(*)
      integer IERR
      double precision :: hesstmp

      if( TASK.eq.0 ) then
         
         !
         !     structure of sparse Hessian (lower triangle):
         !
         
         IRNH(1) = 1
         ICNH(1) = 1

         IRNH(2) = 2
         ICNH(2) = 2

         IRNH(3)=  3
         ICNH(3)=  3

         IRNH(4)=4
         ICNH(4)=4

         IRNH(5)= 2
         ICNH(5)=1


         IRNH(6)=3
         ICNH(6)=2

         IRNH(7)=4
         ICNH(7)=3

         IRNH(8)=3
         ICNH(8)=1

         IRNH(9)=4
         ICNH(9)=2

         IRNH(10) = 4
         ICNH(10) = 1

      else
!
!     calculate Hessian:
!
!!$         !Objective function
!!$         objhess(1)=0.0
!!$         objhess(2)=0.0
!!$         objhess(3)=1.0
!!$
!!$
!!$         ! first constraint
!!$
!!$         conhess(1,1)= (12.0*BM*fs)/((x(1)**3)*(x(2)**2)*sigma_allow)
!!$         conhess(1,2)= (36.0*BM*fs)/(x(1)*(x(2)**4)*sigma_allow)
!!$         conhess(1,3)= (12.0*BM*Fs)/((x(1)**2)*(x(2)**3)*sigma_allow)
!!$
!!$         ! Second constraint
!!$
!!$         conhess(2,1)=(3.0*V*fs)/((x(1)**3)*x(2)*tau_allow)
!!$         conhess(2,2)=(3.0*V*fs)/(x(1)*(x(2)**3)*tau_allow)
!!$         conhess(2,3)=(3.0*V*fs)/(2.0*(x(1)**2)*(x(2)**2)*tau_allow)
!!$
!!$         ! Third Constaint
!!$
!!$         conhess(3,1)=  x(2)/(x(1)**3)
!!$         conhess(3,2)=  0.0
!!$         conhess(3,3)= -1.0/(2.0*x(1)**2)
!!$
!!$
!!$         ! Assemble
!!$
!!$         HESS(:)=0.0
!!$         do i=1,NNZH
!!$            hesstmp=0.0
!!$            do j=1,m
!!$               hesstmp=hesstmp+lam(j)*conhess(j,i)
!!$            end do
!!$            hess(i)=hesstmp+objhess(i)
!!$         end do

      IERR = 0
      
   endif
   return
 end subroutine EV_HESS
 !
! =============================================================================
 !
 !                   Callback method called once per iteration
 !
 ! =============================================================================
!
      subroutine ITER_CB(ALG_MODE, ITER_COUNT,OBJVAL, INF_PR, INF_DU,MU, DNORM, REGU_SIZE, ALPHA_DU, ALPHA_PR, LS_TRIAL, IDAT,DAT, ISTOP)
      implicit none
      integer ALG_MODE, ITER_COUNT, LS_TRIAL
      double precision OBJVAL, INF_PR, INF_DU, MU, DNORM, REGU_SIZE
      double precision ALPHA_DU, ALPHA_PR
      double precision DAT(*)
      integer IDAT(*)
      integer ISTOP

      if (ITER_COUNT .eq.0) then
         write(*,*) 
         write(*,*) 'iter    objective      ||grad||        inf_pr          inf_du         lg(mu)'
      end if

      write(*,'(i5,5e15.7)') ITER_COUNT,OBJVAL,DNORM,INF_PR,INF_DU,MU
      if (ITER_COUNT .gt. 1 .and. DNORM.le.1D-10) ISTOP = 1

      return
    end subroutine ITER_CB
