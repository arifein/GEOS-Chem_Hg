! $Id: restart_mod.f,v 1.2 2003/07/08 15:31:13 bmy Exp $
      MODULE RESTART_MOD
!
!******************************************************************************
!  Module RESTART_MOD contains variables and routines which are used to read
!  and write GEOS-CHEM restart files, which contain tracer concentrations
!  in [v/v] mixing ratio. (bmy, 6/25/02, 4/29/03)
!
!  Module Variables:
!  ============================================================================
!  (1 ) INPUT_RESTART_FILE   : Full path name of the restart file to be read
!  (2 ) OUTPUT_RESTART_FILE  : Full path name (w/ tokens!) of output file
!
!  Module Routines:
!  ============================================================================
!  (1 ) MAKE_RESTART_FILE    : Writes restart file to disk 
!  (2 ) READ_RESTART_FILE    : Reads restart file from disk 
!  (3 ) CONVERT_TRACER_TO_VV : Converts from [ppbv], [ppmv], etc to [v/v]
!  (4 ) CHECK_DIMENSIONS     : Ensures that restart file contains global data
!  (5 ) TRUE_TRACER_INDEX    : Removes GAMAP tracer offset from tracer number
!  (6 ) COPY_STT             : Converts [v/v] to [kg] and stores in STT
!  (7 ) COPY_STT_FOR_CO_OH   : Converts [v/v] to [kg] for CO w/ param. OH run
!  (8 ) COPY_STT_FOR_OX      : Converts [v/v] to [kg] for Tagged Ox run
!  (9 ) CHECK_DATA_BLOCKS    : Makes sure we have read in data for each tracer
!
!  GEOS-CHEM modules referenced by restart_mod.f
!  ============================================================================
!  (1 ) bpch2_mod.f : Module containing routines for binary punch file I/O
!  (2 ) error_mod.f : Module containing NaN and other error check routines
!  (3 ) file_mod.f  : Module containing file unit numbers and error checks
!  (4 ) grid_mod.f  : Module containing horizontal grid information
!  (5 ) time_mod.f  : Module containing routines for computing time & date
!
!  NOTES:
!  (1 ) Moved routines "make_restart_file.f"" and "read_restart_file.f" into
!        this module.  Also now internal routines to "read_restart_file.f"
!        are now a part of this module.  Now reference "file_mod.f" to get
!        file unit numbers and error checking routines. (bmy, 6/25/02)
!  (2 ) Now reference AD from "dao_mod.f".  Now reference "error_mod.f".
!        Also added minor bug fix for ALPHA platform. (bmy, 10/15/02)
!  (3 ) Now references "grid_mod.f" and the new "time_mod.f" (bmy, 2/11/03)
!  (4 ) Added error-check and cosmetic changes (bmy, 4/29/03)
!******************************************************************************
!
      IMPLICIT NONE

      !=================================================================
      ! MODULE PRIVATE DECLARATIONS -- keep certain internal variables 
      ! and routines from being seen outside "restart_mod.f"
      !=================================================================

      ! Private module routines
      PRIVATE :: CONVERT_TRACER_TO_VV
      PRIVATE :: CHECK_DIMENSIONS
      PRIVATE :: TRUE_TRACER_INDEX
      PRIVATE :: COPY_STT
      PRIVATE :: COPY_STT_FOR_CO_OH
      PRIVATE :: COPY_STT_FOR_OX
      PRIVATE :: CHECK_DATA_BLOCKS

      !=================================================================
      ! MODULE VARIABLES
      !=================================================================    
      CHARACTER(LEN=255) :: INPUT_RESTART_FILE  
      CHARACTER(LEN=255) :: OUTPUT_RESTART_FILE 

      !=================================================================
      ! MODULE ROUTINES -- follow below the "CONTAINS" statement 
      !=================================================================
      CONTAINS

!------------------------------------------------------------------------------

      SUBROUTINE MAKE_RESTART_FILE( YYYYMMDD, HHMMSS )
!
!******************************************************************************
!  Subroutine MAKE_RESTART_FILE creates GEOS-CHEM restart files of tracer 
!  mixing ratios (v/v), in binary punch file format. (bmy, 5/27/99, 4/29/03)
!
!  Arguments as Input:
!  ============================================================================
!  (1 ) YYYYMMDD : Year-Month-Date 
!  (2 ) HHMMSS   :  and Hour-Min-Sec for which to create a restart file       
!
!  Passed via F90 module dao_mod.f:
!  ============================================================================
!  (1 ) AD     : Air mass array (kg)       dim=(IIPAR,JJPAR,NNPAR) 
!
!  Passed via CMN:
!  ============================================================================
!  (1 ) TAU    : TAU value (elapsed hours) at start of diagnostic interval
!  (2 ) STT    : Tracer array (kg)         dim=(IIPAR,JJPAR,LLPAR,NNPAR)
!  (3 ) TCVV   : Air MW / Tracer MW array, dim=(NNPAR)
!
!  Passed via CMN_DIAG:
!  ============================================================================
!  (1 ) TRCOFFSET : Offset for special tracers (like Rn, HCN, etc)
!
!  NOTES:
!  (1 ) Now use function NYMD_STRING from "time_mod.f" to generate a
!        Y2K compliant string for all data sets. (bmy, 6/22/00)
!  (2 ) Reference F90 module "bpch2_mod.f" which contains routines BPCH2_HDR, 
!        BPCH2, and GET_MODELNAME for writing data to binary punch files. 
!        (bmy, 6/22/00)
!  (3 ) Now do not write more than NTRACE data blocks to disk.  
!        Also updated comments. (bmy, 7/17/00)
!  (4 ) Now use IOS /= 0 to trap both I/O errors and EOF. (bmy, 9/13/00)
!  (5 ) Added to "restart_mod.f".  Also now save the entire grid to the
!        restart file. (bmy, 6/24/02)
!  (6 ) Bug fix: Remove duplicate definition of MM.  This causes compile-time
!        problems on the ALPHA platform. (gcc, bmy, 11/6/02)
!  (7 ) Now references functions GET_OFFSET, GET_YOFFSET from "grid_mod.f".
!        Now references function GET_TAU from "time_mod.f".  Now added a call 
!        to DEBUG_MSG from "error_mod.f" (bmy, 2/11/03)
!  (8 ) Cosmetic changes (bmy, 4/29/03)
!******************************************************************************
!     
      ! References to F90 modules
      USE BPCH2_MOD
      USE DAO_MOD,   ONLY : AD
      USE ERROR_MOD, ONLY : DEBUG_MSG
      USE FILE_MOD,  ONLY : IU_RST,      IOERROR
      USE GRID_MOD,  ONLY : GET_XOFFSET, GET_YOFFSET
      USE TIME_MOD,  ONLY : EXPAND_DATE, GET_TAU

#     include "CMN_SIZE"   ! Size parameters
#     include "CMN"        ! STT, TCVV, LPRT
#     include "CMN_DIAG"   ! TRCOFFSET

      ! Arguments
      INTEGER, INTENT(IN)  :: YYYYMMDD, HHMMSS

      ! Local Variables      
      INTEGER              :: I,    I0, IOS, J,  J0, L, N
      INTEGER              :: YYYY, MM, DD,  HH, SS
      REAL*4               :: TRACER(IIPAR,JJPAR,LLPAR)
      CHARACTER(LEN=255)   :: FILENAME

      ! For binary punch file, version 2.0
      REAL*4               :: LONRES, LATRES
      INTEGER, PARAMETER   :: HALFPOLAR = 1
      INTEGER, PARAMETER   :: CENTER180 = 1
      
      CHARACTER(LEN=20)    :: MODELNAME
      CHARACTER(LEN=40)    :: CATEGORY
      CHARACTER(LEN=40)    :: UNIT     
      CHARACTER(LEN=40)    :: RESERVED = ''
      CHARACTER(LEN=80)    :: TITLE 

      !=================================================================
      ! MAKE_RESTART_FILE begins here!
      !=================================================================

      ! Hardwire output file for now
#if   defined( GEOS_1 ) || defined( GEOS_STRAT )
      OUTPUT_RESTART_FILE = 'gctm.trc.YYMMDD'
#else
      OUTPUT_RESTART_FILE = 'gctm.trc.YYYYMMDD'
#endif

      ! Define variables for BINARY PUNCH FILE OUTPUT
      TITLE    = 'GEOS-CHEM Restart File: ' // 
     &           'Instantaneous Tracer Concentrations (v/v)'
      UNIT     = 'v/v'
      CATEGORY = 'IJ-AVG-$'
      LONRES   = DISIZE
      LATRES   = DJSIZE

      ! Call GET_MODELNAME to return the proper model name for
      ! the given met data being used (bmy, 6/22/00)
      MODELNAME = GET_MODELNAME()

      ! Get the nested-grid offsets
      I0 = GET_XOFFSET( GLOBAL=.TRUE. )
      J0 = GET_YOFFSET( GLOBAL=.TRUE. )

      !=================================================================
      ! Open the restart file for output -- binary punch format
      !=================================================================

      ! Copy the output restart file name into a local variable
      FILENAME = TRIM( OUTPUT_RESTART_FILE )

      ! Replace YYYY, MM, DD, HH tokens in FILENAME w/ actual values
      CALL EXPAND_DATE( FILENAME, YYYYMMDD, HHMMSS )

      WRITE( 6, 100 ) TRIM( FILENAME )
 100  FORMAT( '     - MAKE_RESTART_FILE: Writing ', a )

      ! Open restart file for output
      CALL OPEN_BPCH2_FOR_WRITE( IU_RST, FILENAME, TITLE )

      !=================================================================
      ! Write each tracer to the restart file
      !=================================================================
      DO N = 1, NTRACE
         
         ! Convert from [kg] to [v/v] and store in the TRACER array
!$OMP PARALLEL DO
!$OMP+DEFAULT( SHARED )
!$OMP+PRIVATE( I, J, L )
         DO L = 1, LLPAR
         DO J = 1, JJPAR
         DO I = 1, IIPAR
            TRACER(I,J,L) = STT(I,J,L,N) * TCVV(N) / AD(I,J,L)
         ENDDO
         ENDDO
         ENDDO
!$OMP END PARALLEL DO

         ! Convert STT from [kg] to [v/v] mixing ratio 
         ! and store in temporary variable TRACER
         CALL BPCH2( IU_RST,    MODELNAME, LONRES,    LATRES,    
     &               HALFPOLAR, CENTER180, CATEGORY,  N+TRCOFFSET,
     &               UNIT,      GET_TAU(), GET_TAU(), RESERVED,   
     &               IIPAR,     JJPAR,     LLPAR,     I0+1,            
     &               J0+1,      1,         TRACER )
      ENDDO  

      ! Close file
      CLOSE( IU_RST )

      !### Debug
      IF ( LPRT ) CALL DEBUG_MSG( '### MAKE_RESTART_FILE: wrote file' )

      ! Return to calling program
      END SUBROUTINE MAKE_RESTART_FILE

!------------------------------------------------------------------------------

      SUBROUTINE READ_RESTART_FILE( YYYYMMDD, HHMMSS ) 
!
!******************************************************************************
!  Subroutine READ_RESTART_FILE initializes GEOS-CHEM tracer concentrations 
!  from a restart file (binary punch file format) (bmy, 5/27/99, 9/18/02)
!
!  Arguments as input:
!  ============================================================================
!  (1 ) YYYYMMDD : Year-Month-Day 
!  (2 ) HHMMSS   :  and Hour-Min-Sec for which to read restart file
!
!  Passed via F90 module dao_mod.f:
!  ============================================================================
!  (1 ) AD     : Air mass array (kg)       dim=(IIPAR,JJPAR,NNPAR) 
!
!  Passed via CMN:
!  ============================================================================
!  (1 ) TAU    : TAU value (elapsed hours) at start of diagnostic interval
!  (2 ) STT    : Tracer array (kg)         dim=(IIPAR,JJPAR,LLPAR,NNPAR)
!  (3 ) TCVV   : Air MW / Tracer MW array, dim=(NNPAR)
!
!  Passed via CMN_DIAG:
!  ============================================================================
!  (1 ) TRCOFFSET : Offset for special tracers (like Rn, HCN, etc)
! 
!  NOTES:
!  (1 ) Now check that N = NTRACER - TRCOFFSET is valid.  
!        Also reorganize some print statements  (bmy, 10/25/99)
!  (2 ) Now pass LFORCE, LSPLIT via CMN_SETUP. (bmy, 11/4/99)
!  (3 ) Cosmetic changes, added comments (bmy, 3/17/00)
!  (4 ) Now use function NYMD_STRING from "time_mod.f" to generate a
!        Y2K compliant string for all data sets. (bmy, 6/22/00)
!  (5 ) Broke up sections of code into internal subroutines.  Also updated
!        comments & cleaned up a few things. (bmy, 7/17/00)
!  (6 ) Now use IOS /= 0 to trap both I/O errors and EOF. (bmy, 9/13/00)
!  (7 ) Print max & min of tracer regardless of the units (bmy, 10/5/00)
!  (8 ) Removed obsolete code from 10/00 (bmy, 12/21/00)
!  (9 ) Removed obsolete commented out code (bmy, 4/23/01)
!  (10) Added updates from amf for tagged Ox run.  Also updated comments
!        and made some cosmetic changes (bmy, 7/3/01)
!  (11) Bug fix: if starting from multiox restart file, then NTRACER 
!        will be greater than 40  but less than 60.  Adjust COPY_STT_FOR_OX
!        accordingly. (amf, bmy, 9/6/01)
!  (12) Now reference TRANUC from "charpak_mod.f" (bmy, 11/15/01)
!  (13) Updated comments (bmy, 1/25/02)
!  (14) Now reference AD from "dao_mod.f" (bmy, 9/18/02)
!  (15) Now added a call to DEBUG_MSG from "error_mod.f" (bmy, 2/11/03)
!******************************************************************************
!
      ! References to F90 modules
      USE BPCH2_MOD, ONLY : OPEN_BPCH2_FOR_READ
      USE DAO_MOD,   ONLY : AD
      USE ERROR_MOD, ONLY : DEBUG_MSG
      USE FILE_MOD,  ONLY : IU_RST, IOERROR
      USE TIME_MOD,  ONLY : EXPAND_DATE

#     include "CMN_SIZE"   ! Size parameters
#     include "CMN"        ! STT, NSRCX, TCVV, NTRACE, TCMASS, etc..
#     include "CMN_DIAG"   ! TRCOFFSET
#     include "CMN_SETUP"  ! LSPLIT

      ! Arguments
      INTEGER, INTENT(IN) :: YYYYMMDD, HHMMSS

      ! Local Variables
      INTEGER             :: I, IOS, J, L, N
      INTEGER             :: NCOUNT(NNPAR) 
      REAL*4              :: TRACER(IIPAR,JJPAR,LLPAR)
      REAL*8              :: SUMTC
      CHARACTER(LEN=255)  :: FILENAME

      ! For binary punch file, version 2.0
      INTEGER             :: NI,     NJ,     NL
      INTEGER             :: IFIRST, JFIRST, LFIRST
      INTEGER             :: NTRACER,   NSKIP
      INTEGER             :: HALFPOLAR, CENTER180
      REAL*4              :: LONRES,    LATRES
      REAL*8              :: ZTAU0,     ZTAU1
      CHARACTER(LEN=20)   :: MODELNAME
      CHARACTER(LEN=40)   :: CATEGORY
      CHARACTER(LEN=40)   :: UNIT     
      CHARACTER(LEN=40)   :: RESERVED

      !=================================================================
      ! READ_RESTART_FILE begins here!
      !=================================================================

      ! Hardwire output file for now
#if   defined( GEOS_1 ) || defined( GEOS_STRAT )
      INPUT_RESTART_FILE = 'gctm.trc.YYMMDD'
#else
      INPUT_RESTART_FILE = 'gctm.trc.YYYYMMDD'
#endif

      ! Initialize some variables
      NCOUNT(:)     = 0
      TRACER(:,:,:) = 0e0

      !=================================================================
      ! Open restart file and read top-of-file header
      !=================================================================
      
      ! Copy input file name to a local variable
      FILENAME = TRIM( INPUT_RESTART_FILE )

      ! Replace YYYY, MM, DD, HH tokens in FILENAME w/ actual values
      CALL EXPAND_DATE( FILENAME, YYYYMMDD, HHMMSS )

      ! Echo some input to the screen
      WRITE( 6, '(a)' ) REPEAT( '=', 79 )
      WRITE( 6, 100 ) TRIM( FILENAME )
 100  FORMAT( 'READ_RESTART_FILE: Reading restart file ', a )

      ! Open the binary punch file for input
      CALL OPEN_BPCH2_FOR_READ( IU_RST, FILENAME )
      
      ! Echo more output
      WRITE( 6, 110 )
 110  FORMAT( /, 'Min and Max of each tracer, as read from the file:',
     &        /, '(in volume mixing ratio units: v/v)' )
      
      !=================================================================
      ! Read concentrations -- store in the TRACER array
      !=================================================================
      DO 
         READ( IU_RST, IOSTAT=IOS ) 
     &     MODELNAME, LONRES, LATRES, HALFPOLAR, CENTER180

         ! IOS < 0 is end-of-file, so exit
         IF ( IOS < 0 ) EXIT

         ! IOS > 0 is a real I/O error -- print error message
         IF ( IOS > 0 ) CALL IOERROR( IOS,IU_RST,'read_restart_file:4' )

         READ( IU_RST, IOSTAT=IOS ) 
     &        CATEGORY, NTRACER,  UNIT, ZTAU0,  ZTAU1,  RESERVED,
     &        NI,       NJ,       NL,   IFIRST, JFIRST, LFIRST,
     &        NSKIP

         IF ( IOS /= 0 ) CALL IOERROR( IOS,IU_RST,'read_restart_file:5')

         READ( IU_RST, IOSTAT=IOS ) 
     &        ( ( ( TRACER(I,J,L), I=1,NI ), J=1,NJ ), L=1,NL )

         IF ( IOS /= 0 ) CALL IOERROR( IOS,IU_RST,'read_restart_file:6')

         !==============================================================
         ! Assign data from the TRACER array to the STT array.
         !==============================================================
  
         ! Only process concentration data (i.e. mixing ratio)
         IF ( CATEGORY(1:8) == 'IJ-AVG-$' ) THEN 

            ! Make sure array dimensions are of global size
            ! (NI=IIPAR; NJ=JJPAR, NL=LLPAR), or stop the run
            CALL CHECK_DIMENSIONS( NI, NJ, NL )

            ! Convert TRACER from its native units to [v/v] mixing ratio
            CALL CONVERT_TRACER_TO_VV( NTRACER, TRACER, UNIT )

            ! Convert TRACER from [v/v] to [kg] and copy into STT array
            SELECT CASE ( NSRCX )

               ! For CO-OH 
               CASE ( 5 )
                  CALL COPY_STT_FOR_CO_OH( NTRACER, TRACER, NCOUNT )

               ! For Tagged OX
               CASE ( 6 )
                  CALL COPY_STT_FOR_OX( NTRACER, TRACER, NCOUNT )

               ! All other simulations
               CASE DEFAULT    
                  CALL COPY_STT( NTRACER, TRACER, NCOUNT )

            END SELECT
         ENDIF
      ENDDO

      !=================================================================
      ! Examine data blocks, print totals, and return
      !=================================================================

      ! Check for missing or duplicate data blocks
      CALL CHECK_DATA_BLOCKS( NTRACE, NCOUNT )

      ! Close file
      CLOSE( IU_RST )      

      ! Print totals atmospheric mass for each tracer
      WRITE( 6, 120 )
 120  FORMAT( /, 'Total atmospheric masses for each tracer: ' ) 

      DO N = 1, NTRACE

         ! For tracers in kg C, be sure to use correct unit string
         IF ( INT( TCMASS(N) + 0.5 ) == 12 ) THEN
            UNIT = 'kg C'
         ELSE
            UNIT = 'kg  '
         ENDIF

         ! Print totals
         WRITE( 6, 130 ) N, TCNAME(N), SUM(STT(:,:,:,N)), ADJUSTL(UNIT)
 130     FORMAT( 'Tracer ', i3, ' (', a4, ') ', es12.5, 1x, a4)
      ENDDO

      ! Fancy output
      WRITE( 6, '(a)' ) REPEAT( '=', 79 )

      !### Debug
      IF ( LPRT ) CALL DEBUG_MSG( '### READ_RESTART_FILE: read file' )

      ! Return to calling program
      END SUBROUTINE READ_RESTART_FILE

!------------------------------------------------------------------------------

      SUBROUTINE CONVERT_TRACER_TO_VV( NTRACER, TRACER, UNIT )
!
!******************************************************************************
!  Subroutine CONVERT_TRACER_TO_VV converts the TRACER array from its
!  natural units (e.g. ppbv, ppmv) as read from the restart file to v/v
!  mixing ratio. (bmy, 6/25/02, 10/15/02)
!
!  Arguments as Input:
!  ============================================================================
!  (1 ) NTRACER (INTEGER)   : Tracer number
!  (2 ) TRACER  (REAL*4 )   : Array containing tracer concentrations
!  (3 ) UNIT    (CHARACTER) : Unit of tracer as read in from restart file
!
!  NOTES:
!  (1 ) Added to "restart_mod.f".  Can now also convert from ppm or ppmv
!        to v/v mixing ratio. (bmy, 6/25/02)
!  (2 ) Now reference GEOS_CHEM_STOP from "error_mod.f", which frees all
!        allocated memory before stopping the run. (bmy, 10/15/02)
!******************************************************************************
!
      ! References to F90 modules
      USE CHARPAK_MOD, ONLY : TRANUC
      USE ERROR_MOD,   ONLY : GEOS_CHEM_STOP

#     include "CMN_SIZE"              ! Size parameters
#     include "CMN"                   ! TCNAME

      ! Arguments
      INTEGER,          INTENT(IN)    :: NTRACER
      REAL*4,           INTENT(INOUT) :: TRACER(IIPAR,JJPAR,LLPAR) 
      CHARACTER(LEN=*), INTENT(IN)    :: UNIT

      !=================================================================
      ! CONVERT_TRACER_TO_VV begins here!
      !=================================================================

      ! Convert UNIT to uppercase
      CALL TRANUC( UNIT )
      
      ! Convert from the current unit to v/v
      SELECT CASE ( TRIM( UNIT ) )

         CASE ( '', 'V/V' )
            ! Do nothing, TRACER is already in v/v
            
         CASE ( 'PPM', 'PPMV', 'PPMC' ) 
            TRACER = TRACER * 1d-6

         CASE ( 'PPB', 'PPBV', 'PPBC' ) 
            TRACER = TRACER * 1d-9

         CASE ( 'PPT', 'PPTV', 'PPTC' )
            TRACER = TRACER * 1d-12

         CASE DEFAULT
            WRITE( 6, '(a)' ) 'Incompatible units in punch file!'
            WRITE( 6, '(a)' ) 'STOP in CONVERT_TRACER_TO_VV'
            WRITE( 6, '(a)' ) REPEAT( '=', 79 )
            CALL GEOS_CHEM_STOP

      END SELECT

      ! Print the min & max of each tracer as it is read from the file
      WRITE( 6, 110 ) NTRACER,  MINVAL( TRACER ), MAXVAL( TRACER )
 110  FORMAT( 'Tracer ', i3, ': Min = ', es12.5, '  Max = ',  es12.5 )

      ! Return to READ_RESTART_FILE
      END SUBROUTINE CONVERT_TRACER_TO_VV

!------------------------------------------------------------------------------

      SUBROUTINE CHECK_DIMENSIONS( NI, NJ, NL ) 
!
!******************************************************************************
!  Subroutine CHECK_DIMENSIONS makes sure that the dimensions of the
!  restart file extend to cover the entire grid. (bmy, 6/25/02, 10/15/02)
!
!  Arguments as Input:
!  ============================================================================
!  (1 ) NI (INTEGER) : Number of longitudes read from restart file
!  (2 ) NJ (INTEGER) : Number of latitudes  read from restart file
!  (3 ) NL (INTEGER) : Numbef of levels     read from restart file
!
!  NOTES:
!  (1 ) Added to "restart_mod.f".  Now no longer allow initialization with 
!        less than a globally-sized data block. (bmy, 6/25/02)
!  (2 ) Now reference GEOS_CHEM_STOP from "error_mod.f", which frees all
!        allocated memory before stopping the run. (bmy, 10/15/02)
!******************************************************************************
!
      ! References to F90 modules
      USE ERROR_MOD, ONLY : GEOS_CHEM_STOP

      ! Arguments
      INTEGER, INTENT(IN) :: NI, NJ, NL

#     include "CMN_SIZE"

      !=================================================================
      ! CHECK_DIMENSIONS begins here!
      !=================================================================

      ! Error check longitude dimension: NI must equal IIPAR
      IF ( NI /= IIPAR ) THEN
         WRITE( 6, '(a)' ) 'ERROR reading in restart file!'
         WRITE( 6, '(a)' ) 'Wrong number of longitudes encountered!'
         WRITE( 6, '(a)' ) 'STOP in CHECK_DIMENSIONS (restart_mod.f)'
         WRITE( 6, '(a)' ) REPEAT( '=', 79 )
         CALL GEOS_CHEM_STOP
      ENDIF

      ! Error check latitude dimension: NJ must equal JJPAR
      IF ( NJ /= JJPAR ) THEN
         WRITE( 6, '(a)' ) 'ERROR reading in restart file!'
         WRITE( 6, '(a)' ) 'Wrong number of latitudes encountered!'
         WRITE( 6, '(a)' ) 'STOP in CHECK_DIMENSIONS (restart_mod.f)'
         WRITE( 6, '(a)' ) REPEAT( '=', 79 )
         CALL GEOS_CHEM_STOP
      ENDIF
      
      ! Error check vertical dimension: NL must equal LLPAR
      IF ( NL /= LLPAR ) THEN
         WRITE( 6, '(a)' ) 'ERROR reading in restart file!'
         WRITE( 6, '(a)' ) 'Wrong number of levels encountered!'
         WRITE( 6, '(a)' ) 'STOP in CHECK_DIMENSIONS (restart_mod.f)'
         WRITE( 6, '(a)' ) REPEAT( '=', 79 )
         CALL GEOS_CHEM_STOP
      ENDIF

      ! Return to calling program
      END SUBROUTINE CHECK_DIMENSIONS

!------------------------------------------------------------------------------

      FUNCTION TRUE_TRACER_INDEX( NTRACER ) RESULT( N )
!
!******************************************************************************
!  Function TRUE_TRACER_INDEX returns the "true" index for CTM tracers; that
!  is, the tracer number minus the GAMAP "special chemistry" offset.
!  (bmy, 6/25/02, 10/15/02)
!
!  NOTES:
!  (1 ) Added to "restart_mod.f".  Also now use F90 intrinsic REPEAT to
!        write a long line of "="'s to the screen. (bmy, 6/25/02)
!  (2 ) Now reference GEOS_CHEM_STOP from "error_mod.f", which frees all
!        allocated memory before stopping the run. (bmy, 10/15/02)
!******************************************************************************
!
      ! References to F90 modules
      USE ERROR_MOD, ONLY : GEOS_CHEM_STOP

#     include "CMN_SIZE"  ! Size parameters
#     include "CMN_DIAG"  ! TRCOFFSET

      ! Arguments
      INTEGER, INTENT(IN) :: NTRACER
      
      ! Return value
      INTEGER             :: N

      !=================================================================
      ! TRUE_TRACER_INDEX begins here!
      !=================================================================

      ! Subtract TRCOFFSET from NTRACER -- TRCOFFSET is used
      ! by GAMAP to distinguish special chemistry routines
      N = NTRACER - TRCOFFSET

      ! Stop with error message if N is out of range
      IF ( N < 1 ) THEN 
         WRITE( 6, '(a)' ) 'NTRACER - TRCOFFSET is less than 1!'
         WRITE( 6, '(a)' ) 'Please double-check the value of NSRCX!'
         WRITE( 6, '(a)' ) 'STOP in TRUE_TRACER_INDEX (restart_mod.f)'
         WRITE( 6, '(a)' ) REPEAT( '=', 79 )
         CALL GEOS_CHEM_STOP
      ENDIF

      ! Return to calling program
      END FUNCTION TRUE_TRACER_INDEX

!------------------------------------------------------------------------------
     
      SUBROUTINE COPY_STT( NTRACER, TRACER, NCOUNT )
!
!******************************************************************************
!  Subroutine COPY_STT converts tracer concetrations from [v/v] to [kg] and 
!  then copies the results into the STT tracer array. (bmy, 6/25/02, 4/29/03)
!
!  Arguments as Input:
!  ============================================================================
!  (1 ) NTRACER (INTEGER) : Tracer number
!  (2 ) NCOUNT  (INTEGER) : Ctr array - # of data blocks read for each tracer
!  (3 ) TRACER  (REAL*4 ) : Tracer concentrations from restart file [v/v]
!
!  NOTES:
!  (1 ) Added to "restart_mod.f".  Also added parallel loops. (bmy, 6/25/02)
!  (2 ) Now reference AD from "dao_mod.f" (bmy, 9/18/02)
!  (3 ) Now exit if N is out of range (bmy, 4/29/03)
!******************************************************************************
!
      ! References to F90 modules
      USE DAO_MOD, ONLY : AD

#     include "CMN_SIZE"  ! Size parameters
#     include "CMN"       ! TCVV, STT

      ! Arguments
      INTEGER, INTENT(IN)    :: NTRACER
      REAL*4,  INTENT(IN)    :: TRACER(IIPAR,JJPAR,LLPAR)
      INTEGER, INTENT(INOUT) :: NCOUNT(NNPAR)

      ! Local variables
      INTEGER                :: I, J, L, N
      
      !=================================================================
      ! COPY_STT begins here!
      !=================================================================

      ! Make sure N is a valid tracer number
      N = TRUE_TRACER_INDEX( NTRACER )

      ! Exit if N is out of range
      IF ( N < 1 .or. N > NTRACE ) RETURN

      ! Convert from [v/v] to [kg] and store in STT
!$OMP PARALLEL DO
!$OMP+DEFAULT( SHARED )
!$OMP+PRIVATE( I, J, L )
      DO L = 1, LLPAR
      DO J = 1, JJPAR
      DO I = 1, IIPAR
         STT(I,J,L,N) = TRACER(I,J,L) * AD(I,J,L) / TCVV(N) 
      ENDDO
      ENDDO
      ENDDO
!$OMP END PARALLEL DO

      ! Increment the # of records found for tracer N
      NCOUNT(N) = NCOUNT(N) + 1

      END SUBROUTINE COPY_STT

!------------------------------------------------------------------------------

      SUBROUTINE COPY_STT_FOR_CO_OH( NTRACER, TRACER, NCOUNT )
!
!******************************************************************************
!  Subroutine COPY_STT_FOR_CO_OH copies data from the TRACER array into the 
!  STT array for the CO run with parameterized OH, readjusting the
!  tracer number accordingly. (bmy, 6/25/02, 9/18/02)
!
!  Arguments as Input:
!  ============================================================================
!  (1 ) NTRACER (INTEGER) : Tracer number
!  (2 ) NCOUNT  (INTEGER) : Ctr array - # of data blocks read for each tracer
!  (3 ) TRACER  (REAL*4 ) : Tracer concentrations [v/v]
!
!  NOTES:
!  (1 ) Added to "restart_mod.f". (bmy, 6/25/02)
!  (2 ) Now reference AD from "dao_mod.f" (bmy, 9/18/02)
!******************************************************************************
!
      ! References to F90 modules
      USE DAO_MOD, ONLY : AD

#     include "CMN_SIZE"     ! Size parameters
#     include "CMN"          ! TCVV, AD, STT

      ! Arguments
      INTEGER, INTENT(IN)    :: NTRACER
      REAL*4,  INTENT(IN)    :: TRACER(IIPAR,JJPAR,LLPAR)
      INTEGER, INTENT(INOUT) :: NCOUNT(NNPAR)
   
      ! Local variables
      INTEGER                :: I, J, L

#if   defined( LGEOSCO )

#     include "CMN_CO_BUDGET" 

      !=================================================================
      ! COPY_STT_FOR_CO_OH begins here!
      !=================================================================

      ! CO is tracer #4 in a full-chemistry restart file
      IF ( NTRACER == 4 ) THEN

!$OMP PARALLEL DO
!$OMP+DEFAULT( SHARED )
!$OMP+PRIVATE( I, J, L )
         DO L = 1, LLPAR
         DO J = 1, JJPAR
         DO I = 1, IIPAR
 
            ! Convert from [v/v] to [kg CO]
            STT(I,J,L,N) = TRACER(I,J,L) * AD(I,J,L) / TCVV_CO

            ! Save initial CO budget in TCO(:,:,:,1)
            TCO(I,J,L,1) = TRACER(I,J,L) 
            
            ! 
            TCO(I,J,L,2:12) = 0d0
         ENDDO
         ENDDO
         ENDDO
!$OMP END PARALLEL DO

         ! Update count
         NCOUNT(1) = NCOUNT(1) + 1
      ENDIF
#endif
      
      ! Return to READ_RESTART_FILE
      END SUBROUTINE COPY_STT_FOR_CO_OH

!------------------------------------------------------------------------------

      SUBROUTINE COPY_STT_FOR_OX( NTRACER, TRACER, NCOUNT )
!
!******************************************************************************
!  Subroutine COPY_STT_FOR_OX copies data from the TRACER array into the 
!  STT array for the single-tracer or tagged Ox run, readjusting the
!  tracer number accordingly. (bmy, 6/25/02, 9/18/02)
!
!  Arguments as Input:
!  ============================================================================
!  (1 ) NTRACER (INTEGER) : Tracer number
!  (2 ) NCOUNT  (INTEGER) : Ctr array - # of data blocks read for each tracer
!  (3 ) TRACER  (REAL*4 ) : Tracer concentrations [v/v]
!
!  NOTES:
!  (1 ) Added to "restart_mod.f".  Also added parallel loops. (bmy, 6/25/02)
!  (2 ) Now reference AD from "dao_mod.f" (bmy, 9/18/02)
!******************************************************************************
!
      ! References to F90 modules
      USE DAO_MOD, ONLY : AD

#     include "CMN_SIZE"     ! Size parameters
#     include "CMN"          ! TCVV, STT
#     include "CMN_SETUP"    ! LSPLIT 

      ! Arguments
      INTEGER, INTENT(IN)    :: NTRACER
      REAL*4,  INTENT(IN)    :: TRACER(IIPAR,JJPAR,LLPAR)
      INTEGER, INTENT(INOUT) :: NCOUNT(NNPAR)

      ! Local variables
      INTEGER                :: I, J, L
 
      !=================================================================
      ! COPY_STT_FOR_OX begins here!
      !
      ! Here we are reading from a full-chemistry restart
      ! file, where Ox is tracer #2
      !=================================================================
      IF ( NTRACER == 2 ) THEN

!$OMP PARALLEL DO
!$OMP+DEFAULT( SHARED )
!$OMP+PRIVATE( I, J, L )
         DO L = 1, LLPAR
         DO J = 1, JJPAR
         DO I = 1, IIPAR
            STT(I,J,L,1) = TRACER(I,J,L) * AD(I,J,L) / TCVV(1)

            ! Also intialize tagged tracers
            IF ( LSPLIT ) THEN
               STT(I,J,L,12)   = STT(I,J,L,1)
               STT(I,J,L,2:11) = 0d0
               STT(I,J,L,13)   = 0d0
            ENDIF
         ENDDO
         ENDDO
         ENDDO
!$OMP END PARALLEL DO

         ! Update count: tracer 1 only
         NCOUNT(1) = NCOUNT(1) + 1
      
      !=================================================================
      ! Here we are reading from a tagged Ox restart file
      ! with tracer numbers starting at 41
      !=================================================================
      ELSE IF ( NTRACER > 40 .and. NTRACER < 60 ) THEN
         CALL COPY_STT( NTRACER, TRACER, NCOUNT )
         
      ENDIF

      ! Return to READ_RESTART_FILE
      END SUBROUTINE COPY_STT_FOR_OX

!------------------------------------------------------------------------------

      SUBROUTINE CHECK_DATA_BLOCKS( NTRACE, NCOUNT )
!
!******************************************************************************
!  Subroutine CHECK_DATA_BLOCKS checks to see if we have multiple or 
!  missing data blocks for a given tracer. (bmy, 6/25/02, 10/15/02)
!
!  Arguments as Input:
!  ============================================================================
!  (1 ) NTRACE (INTEGER) : Number of tracers
!  (2 ) NCOUNT (INTEGER) : Ctr array - # of data blocks found per tracer
!
!  NOTES:
!  (1 ) Added to "restart_mod.f".  Also now use F90 intrinsic REPEAT to
!        write a long line of "="'s to the screen. (bmy, 6/25/02)
!  (2 ) Now reference GEOS_CHEM_STOP from "error_mod.f", which frees all
!        allocated memory before stopping the run. (bmy, 10/15/02)
!******************************************************************************
!      
      ! References to F90 modules
      USE ERROR_MOD, ONLY : GEOS_CHEM_STOP

#     include "CMN_SIZE"  ! Size parameters

      ! Arguments
      INTEGER, INTENT(IN) :: NTRACE, NCOUNT(NNPAR)
  
      ! Local variables
      INTEGER             :: N

      !=================================================================
      ! CHECK_DATA_BLOCKS begins here! 
      !=================================================================

      ! Loop over all tracers
      DO N = 1, NTRACE

         ! Stop if a tracer has more than one data block 
         IF ( NCOUNT(N) > 1 ) THEN 
            WRITE( 6, 100 ) N
            WRITE( 6, 120 ) 
            WRITE( 6, '(a)' ) REPEAT( '=', 79 )
            CALL GEOS_CHEM_STOP
         ENDIF
         
         ! Stop if a tracer has no data blocks 
         IF ( NCOUNT(N) == 0 ) THEN
            WRITE( 6, 110 ) N
            WRITE( 6, 120 ) 
            WRITE( 6, '(a)' ) REPEAT( '=', 79 )
            CALL GEOS_CHEM_STOP
         ENDIF
      ENDDO

      ! FORMAT statements
 100  FORMAT( 'More than one record found for tracer : ', i4 )
 110  FORMAT( 'No records found for tracer : ',           i4 ) 
 120  FORMAT( 'STOP in CHECK_DATA_BLOCKS (restart_mod.f)'    )

      ! Return to calling program
      END SUBROUTINE CHECK_DATA_BLOCKS

!------------------------------------------------------------------------------

      END MODULE RESTART_MOD