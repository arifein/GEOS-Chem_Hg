! $Id: gasconc.f,v 1.1 2003/06/30 20:26:05 bmy Exp $
      SUBROUTINE GASCONC( FIRSTCHEM, STT,    NTRACER,
     &                    XNUMOL,    LPAUSE, FRCLND )
!
!******************************************************************************
!  Subroutine GASCONC initializes gas concentrations for SMVGEAR II.
!  (M. Jacobson 1997; bdf, bmy, 4/18/03)
!
!  NOTES:
!  (1 ) Now reference ABSHUM, AIRDENS, CSPEC, IXSAVE, IYSAVE, IZSAVE,  
!        PRESS3, T3 from "comode_mod.f".  Also now references tracer ID flags
!        from "tracerid_mod.f".  Also removed code that is not needed for
!        GEOS-CHEM.  Now also force double precision with "D" exponents.
!        (bdf, bmy, 4/18/03)
!******************************************************************************
!
      ! References to F90 modules 
      USE COMODE_MOD, ONLY : ABSHUM, AIRDENS, CSPEC,  IXSAVE,
     &                       IYSAVE, IZSAVE,  PRESS3, T3
      USE TRACERID_MOD

      IMPLICIT NONE

#     include "CMN_SIZE"     ! Size parameters
#     include "comode.h"     ! SMVGEAR II arrays

      ! Arguments
      LOGICAL, INTENT(IN)    :: FIRSTCHEM
      INTEGER, INTENT(IN)    :: NTRACER
      INTEGER, INTENT(IN)    :: LPAUSE(IIPAR,JJPAR)
      REAL*8,  INTENT(INOUT) :: STT(IIPAR,JJPAR,LLPAR,NNPAR)
      REAL*8,  INTENT(IN)    :: XNUMOL(NNPAR)
      REAL*8,  INTENT(IN)    :: FRCLND(IIPAR,JJPAR)
C
C *********************************************************************
C ************       WRITTEN BY MARK JACOBSON (1991-4)     ************
C ***            (C) COPYRIGHT, 1991-4 BY MARK Z. JACOBSON          *** 
C ***                          (650) 723-6836                       *** 
C *********************************************************************
C
C    GGGGGG      A       SSSSSS   CCCCCC   OOOOO   N     N   CCCCCC  
C   G           A A     S        C        O     O  N N   N  C  
C   G  GGGG    A   A    SSSSSSS  C        O     O  N  N  N  C   
C   G     G   AAAAAAA         S  C        O     O  N   N N  C    
C    GGGGGG  A       A  SSSSSS    CCCCCC   OOOOO   N     N   CCCCCC    
C
C *********************************************************************
C ******       INITIALIZE GAS CONCENTRATIONS IN THE MODEL        ******
C ***********       AND SET MISCELLANEOUS PARAMETERS         ********** 
C *********************************************************************
C
C *********************************************************************
C * SET THE CONCENTRATION  (# CM-3) OF ACTIVE AND INACTIVE GASES      *
C *********************************************************************
C
C NTLOOP    = NUMBER OF GRID-CELLS IN THE ENTIRE GRID-DOMAIN
C NTSPECGAS = NUMBER OF ACTIVE PLUS INACTIVE GASES
C NVERT     = NUMBER OF VERTICAL LAYERS.  
C
C QBKGAS    = INITIAL BACKGROUND CONCENTRATION (VOL MIXING RATIO) 
C RHO3      = G-AIR CM-3-AIR
C DENCONS   = AVG / WTAIR 
C C(GAS)    = GAS CONCENTRATION IN A GIVEN GRID-CELL (# CM-3)
C
      ! Local variables
      INTEGER :: IX, IY, IZ, N, NK, JJ
      INTEGER :: JGAS,JLOOP,NGASMIX,JALTS,K,J,NM,L,JN,MLOOP,I
      INTEGER :: IPCOMPAR,JRUN,JNEW,JOLD,NGCOUNT,IAVG,KN,SUM,SUM1
      REAL*8  :: PMBCEN,PBELOW,PABOVE,ALNPRES,PS,ALNCONC,AVMIX,S1CON
      REAL*8  :: S2CON,GRCONC1,GRCONC2,GRCONC3,SUMRMS,SUMFRACS,QNEW
      REAL*8  :: QACC,FRACDIF,FRACABS,AVGERR,RMSCUR
      REAL*8  :: TK,CONSEXP,VPRESH2O

      !=================================================================
      ! GASCONC begins here!
      !=================================================================
      NCS = 1

      !=================================================================
      ! First time through here, copy initial conditions from QBKCHEM
      ! to CSPEC() for each grid box.  QBKCHEM stores the default
      ! background concentrations for species in the file "chem.dat".
      !=================================================================
      IF ( FIRSTCHEM ) THEN

         ! Loop over species
         DO 28 JGAS = 1, NTSPEC(NCS)

            !===========================================================
            ! For methanol (MOH), now use different initial background
            ! concentrations for different regions of the atmosphere:
            !
            ! (a) 2.0 ppbv MOH -- continental boundary layer
            ! (b) 0.9 ppbv MOH -- marine boundary layer
            ! (c) 0.6 ppbv MOH -- free troposphere
            !
            ! The concentrations listed above are from Heikes et al,
            ! "Atmospheric methanol budget and ocean implication",
            ! _Global Biogeochem. Cycles_, submitted, 2002.  These
            ! represent the best estimates for the methanol conc.'s
            ! in the troposphere based on various measurements.
            !
            ! MOH is an inactive chemical species in GEOS-CHEM, so
            ! these initial concentrations will never change.  However,
            ! MOH acts as a sink for OH, and therefore will affect both
            ! the OH concentration and the methylchloroform lifetime.
            !
            ! We specify the MOH concentration as ppbv, but then we
            ! need to multiply by PRESS3(JLOOP) / ( T3(JLOOP) * BK )
            ! in order to convert to [molec/cm3].  (bdf, bmy, 2/22/02)
            !===========================================================
            IF ( NAMEGAS(JGAS) == 'MOH' ) THEN

               ! Loop over all grid boxes sent to SMVGEAR
               DO JLOOP = 1, NTLOOP

                  ! Convert 1-D grid box index to 3-D indices
                  IX = IXSAVE(JLOOP)
                  IY = IYSAVE(JLOOP)
                  IZ = IZSAVE(JLOOP)

                  !------------------------------
                  ! Test for altitude
                  ! IZ < 9 is always in the trop.
                  !------------------------------
                  IF ( IZ <= 9 ) THEN

                     !---------------------------
                     ! Test for ocean/land boxes
                     !---------------------------
                     IF ( FRCLND(IX,IY) >= 0.5 ) THEN

                        ! Continental boundary layer: 2 ppbv MOH
                        CSPEC(JLOOP,JGAS) =
     &                     2.000d-9 * PRESS3(JLOOP) / ( T3(JLOOP) * BK )

                        ! Make sure MOH conc. is not negative (SMAL2 = 1d-99)
                        CSPEC(JLOOP,JGAS) = MAX(CSPEC(JLOOP,JGAS),SMAL2)

                     ELSE

                        ! Marine boundary layer: 0.9 ppbv MOH
                        CSPEC(JLOOP,JGAS) =
     &                     0.900d-9 * PRESS3(JLOOP) / ( T3(JLOOP) * BK )

                        ! Make sure MOH conc. is not negative (SMAL2 = 1d-99)
                        CSPEC(JLOOP,JGAS) = MAX(CSPEC(JLOOP,JGAS),SMAL2)

                     ENDIF

                  ELSE

                     !---------------------------
                     ! Test for troposphere
                     !---------------------------
                     IF ( IZ < LPAUSE(IX,IY) ) THEN

                        ! Free troposphere: 0.6 ppbv MOH
                        CSPEC(JLOOP,JGAS) =
     &                     0.600d-9 * PRESS3(JLOOP) / ( T3(JLOOP) * BK )

                        ! Make sure MOH conc. is not negative (SMAL2 = 1d-99)
                        CSPEC(JLOOP,JGAS) = MAX(CSPEC(JLOOP,JGAS),SMAL2)

                     ELSE

                        ! Stratosphere: set MOH conc. to SMAL2 = 1d-99
                        CSPEC(JLOOP,JGAS) = SMAL2

                     ENDIF
                  ENDIF
               ENDDO
            ELSE

               !========================================================
               ! Set default initial conc. for species other than
               ! Methanol (MOH) in mixing ratios units
               !========================================================
               DO 26 JLOOP = 1, NTLOOP

                  ! Copy default background conc. from "globchem.dat" to CSPEC
                  CSPEC(JLOOP,JGAS) = QBKCHEM(JGAS,NCS)*
     &                 PRESS3(JLOOP)/(T3(JLOOP)* BK)

                  ! Make sure concentration is not negative (SMAL2 = 1d-99)
                  CSPEC(JLOOP,JGAS) = MAX(CSPEC(JLOOP,JGAS),SMAL2)

                  ! For emission species, don't do unit conversion
                  IF (NAMEGAS(JGAS).EQ.'EMISSION')
     &                 CSPEC(JLOOP,JGAS) = QBKCHEM(JGAS,NCS)
 26            CONTINUE
            ENDIF
 28      CONTINUE
      ENDIF                     !(FIRSTCHEM)

C  ********************************************************************
C  *            Update starting concentrations for plumes             *
C  ********************************************************************
C

! currently only partition species in full chemistry.
!   should be added as needed to other chemistries.
!      if (NCS .eq. 1) then
!  maybe??
      CALL PARTITION(STT, NTRACER, XNUMOL)
!      endif
C
C *********************************************************************
C *              zero out dry deposition counter species              *
C *********************************************************************

      ! NCS should equal 1 for drydep, only happens in first layer.
      NCS = 1
      DO 130 N = 1,NDRYDEP(NCS)
         NK = NTDEP(N)
         IF (NK.EQ.0) GOTO 130
         JJ = IRM(NPRODLO+1,NK,NCS)
         !write(6,*) 'value of drydep reactions in cspec= ',jj
         IF (JJ.LE.0) GOTO 130
         DO 135 JLOOP = 1,NTTLOOP
            CSPEC(JLOOP,JJ) = 0.0D0
 135     CONTINUE
 130  CONTINUE

C
C *********************************************************************
C *           INITIALIZE H2O (# CM-3) IF H2O IS INACTIVE              *
C *********************************************************************
C VPRESH2O = SATURATION VAPOR PRESSURE OVER H2O (# CM-3)
C ABSHUM   = ABSOLUTE HUMIDITY (molec cm^-3) [input] (ABSHUM)
C ABSHUM   = RELATIVE HUMIDITY (FRACTION)    [output]
C TK       = TEMPERATURE (K)
C
      IF (IH2O.GT.NGAS) THEN
         DO 33 JLOOP    = 1, NTTLOOP
            TK            = T3(JLOOP)
            CONSEXP       = 17.2693882D0 * (TK - 273.16D0) /
     1           (TK - 35.86D0)
            VPRESH2O      = CONSVAP * EXP(CONSEXP) / TK 
            CSPEC(JLOOP,IH2O) = ABSHUM(JLOOP)
C     then calculate R.H.
            ABSHUM(JLOOP) = CSPEC(JLOOP,IH2O) / VPRESH2O 
!            write(297,*) 'in initgas',jloop,abshum(jloop)
 33      CONTINUE
      ENDIF

C *********************************************************************
C *           INITIALIZE O2 (# CM-3) IF O2 IS INACTIVE                *
C *********************************************************************
C RHO3    = AIR DENSITY (G CM-3)
C OXYCONS = (# G-1) CONVERSION OF O2 FROM G CM-3 TO # CM-3
C

! bdf smv2, using cspec as chemistry matrix.
!      write(6,*) 'must take this out later.'
!      if (ioxygen .ne. 79) stop 400
      IF (IOXYGEN.GT.NGAS) THEN
         OXYCONS           = 0.2095d0
         DO 260 JLOOP      = 1, NTLOOP
! 260    CSPEC(JLOOP,IOXYGEN) = RHO3(JLOOP) * OXYCONS
 260        CSPEC(JLOOP,IOXYGEN) = AIRDENS(JLOOP) * OXYCONS
      ENDIF
 999  format(E10.3)

C
C *********************************************************************
C *             SUM UP INITIAL GAS MASSES OVER ENTIRE GRID            *
C *********************************************************************
C GQSUMINI(JGAS)  = INITIAL # MOLECULES, OVER THE ENTIRE GRID
C QSUMINIT        = SUM OF ALL ME OR IM # OVER GRID
C                    SUM OF ALL MEVF OR IMVF CM3 OVER GRID
C GRIDVH          = VOLUME OF A GRID-CELL (CM**3)
C

!       DO 800 JGAS      = 1, NTSPECGAS
!        GQSUMINI(JGAS)  = 0. 
!        DO 800 JLOOP    = 1, NTLOOP
!         GQSUMINI(JGAS)=GQSUMINI(JGAS)+CSPEC(JLOOP,JGAS)*GRIDVH(JLOOP) 
! 800   CONTINUE
C
C *********************************************************************
C *                    IDENTIFY GASES FOR PRINTING                    *
C *********************************************************************
C
      NUMPRG            = 0 
      DO 290 JGAS       = 1, NTSPECGAS
       JST              = NAMEGAS(JGAS)
       IF (APGASA.EQ.JST) IFPRGAS(JGAS) = 2 
       IF (APGASB.EQ.JST) IFPRGAS(JGAS) = 2  
       IF (APGASC.EQ.JST) IFPRGAS(JGAS) = 2 
       IF (APGASD.EQ.JST) IFPRGAS(JGAS) = 2 
       IF (APGASE.EQ.JST) IFPRGAS(JGAS) = 2 
       IF (APGASF.EQ.JST) IFPRGAS(JGAS) = 2  
       IF (APGASG.EQ.JST) IFPRGAS(JGAS) = 2 
       IF (APGASH.EQ.JST) IFPRGAS(JGAS) = 2 
       IF (IFPRGAS(JGAS).GE.1) THEN
        NUMPRG                          = NUMPRG + 1
        LGNUM(NUMPRG)                   = JGAS 
       ENDIF
 290  CONTINUE
C
 370  FORMAT(25X,0PF6.4/) 
 380  FORMAT(A14,1X,1PE10.4,I5,I7)
C
C *********************************************************************
C ****          PRINT OUT INITIAL CONCENTRATION INFORMATION        ****
C *********************************************************************
C
      NCS         =  1
C
      IF (ITESTGEAR.EQ.2) THEN 
       WRITE(KCPD,810) 0.,0.,IRUN,(NAMENCS(INEWOLD(I,NCS),NCS),
     1        CSPEC(LLOOP,INEWOLD(I,NCS)), I = 1, ISCHANG(NCS))
       WRITE(KCPD,820)
      ENDIF
C
 810  FORMAT('CONC (# CM-3) AT TIME=',1PE10.2,' SECONDS. ',  
     l       'STEP=',E10.2,' . RUN =',I3/3(A13,'=',E11.4,1X))
 820  FORMAT('END')
C
C *********************************************************************
C ********** READ DATA FOR TESTING RESULTS FROM CHEMISTRY *************
C *********************************************************************
C CSPEC(), GEARCONC ARE # CM-3 FOR GASES
C
      IF (ITESTGEAR.EQ.1) THEN
       IPCOMPAR    = 0  
       JRUN        = 0 
       WRITE(6,*)
       WRITE(6,*)'GEAR-CODE CONCENTRATIONS TO TEST'
       READ(KCPD,450) HEADING
 470   READ(KCPD,460) RINP(1), GRCONC1, RINP(2), GRCONC2, 
     1              RINP(3), GRCONC3  
       IF (RINP(1).NE.'END') THEN
        DO 480 JNEW = 1, ISCHANG(NCS)
         JOLD       = INEWOLD(JNEW,NCS)
         JST        = NAMENCS(JOLD,NCS)
         IF (JST.EQ.RINP(1)) GEARCONC(JNEW,JRUN,NCS) = GRCONC1
         IF (JST.EQ.RINP(2)) GEARCONC(JNEW,JRUN,NCS) = GRCONC2
         IF (JST.EQ.RINP(3)) GEARCONC(JNEW,JRUN,NCS) = GRCONC3
 480    CONTINUE
        GOTO 470 
       ELSE
        IF (IPCOMPAR.EQ.1) THEN
         WRITE(6,450) HEADING
         WRITE(6,460)(NAMENCS(INEWOLD(JNEW,NCS),NCS),
     1                GEARCONC(JNEW,JRUN,NCS), JNEW = 1, ISCHANG(NCS)) 
        ENDIF
C
C COMPARE INITIAL CONDITIONS OF GEAR DATA TO chem.dat DATA
C
        IF (JRUN.EQ.0) THEN
         IF (IPCOMPAR.EQ.1) WRITE(6,475)
C
         SUMRMS      = 0.d0
         SUMFRACS    = 0.d0
         NGCOUNT     = 0
C
         DO 485 JNEW = 1, ISCHANG(NCS)
          JOLD       = INEWOLD(JNEW,NCS)
          QNEW       = QBKCHEM(JOLD,NCS) 
          QACC       = GEARCONC(JNEW,0,NCS) 
C
          IF (QACC.EQ.0.AND.QNEW.NE.0.) THEN
           WRITE(6,465) NAMEGAS(JOLD) 
           STOP 
          ENDIF 
C
          IF (QNEW.GT.1.0d-20) THEN
           FRACDIF   = (QNEW - QACC)/QACC
           FRACABS   = ABS(FRACDIF)
           SUMFRACS  = SUMFRACS + FRACABS 
           SUMRMS    = SUMRMS   + FRACABS * FRACABS
           NGCOUNT   = NGCOUNT + 1
           IAVG      = 1
          ELSE
           FRACDIF   = 0.d0
           IAVG      = 0
          ENDIF
          IF (IPCOMPAR.EQ.1) 
     1    WRITE(6,495) NAMENCS(JOLD,NCS),QACC,QNEW,
     2                 FRACDIF*100, IAVG
 485     CONTINUE
C
         AVGERR      = 100.d0 * SUMFRACS     / NGCOUNT  
         RMSCUR      = 100.d0 * SQRT(SUMRMS  / NGCOUNT)
         WRITE(6,505) JRUN, AVGERR, NGCOUNT  
C
        ENDIF
C       ENDIF JRUN.EQ.0
C
        JRUN        = JRUN + 1
        IF (GRCONC1.EQ.0.) THEN 
         READ(KCPD,450) HEADING
         GOTO 470 
        ENDIF
        IF (JRUN.GT.MXHOLD) THEN
         WRITE(6,*)'JSPARSE: JRUN > MXHOLD'
         STOP
        ENDIF
       ENDIF
      ENDIF
C
 475  FORMAT(4X,'SPECIES',5X,'GEARCONC     chem.dat    % ERROR IFAVG')
 495  FORMAT(A14,2(1X,1PE11.4),2X,0PF8.2,'%',3X,I1)
 505  FORMAT(I3,37X,F8.2,'%   AVERAGE OF ',I5,' SPECIES')
 450  FORMAT(A76) 
 460  FORMAT(3(A13,1X,1PE11.4,1X))
 465  FORMAT('GASCONC: AN INITIAL CONCENTRATION FROM compare.dat '/
     1       'DOES NOT MATCH THAT FROM globchem.dat. CHECK WHETHER '/
     2       'THE CONDITIONS FOR THIS RUN (ITESTGEAR = 1) ARE THE '/
     3       'SAME FOR THE CONDITIONS FOR THE RUN WITH ITESTGEAR=2. '/
     4       'OTHERWISE, TURN ITESTGEAR = 0 OR 2. ',A14)   
C
C *********************************************************************
C ********************* END OF SUBROUTINE GASCONC *********************
C *********************************************************************
C
      RETURN
      END SUBROUTINE GASCONC
