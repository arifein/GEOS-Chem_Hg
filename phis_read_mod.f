! $Id: phis_read_mod.f,v 1.1 2003/06/30 20:26:10 bmy Exp $
      MODULE PHIS_READ_MOD
!
!******************************************************************************
!  Module PHIS_READ_MOD contains subroutines that unzip, open, and read the
!  GEOS-CHEM PHIS (geopotential heights) field from disk. (bmy, 6/16/03)
! 
!  Module Routines:
!  ============================================================================
!  (1 ) UNZIP_PHIS_FIELD : Unzips & copies met field files to a temp dir
!  (2 ) OPEN_PHIS_FIELD  : Opens met field files residing in the temp dir
!  (3 ) GET_PHIS_FIELDS  : Wrapper for routine READ_I6
!  (4 ) CHECK_TIME       : Tests if met field timestamps equal current time
!  (5 ) READ_PHIS        : Reads PHIS fields from disk
!  (6 ) PHIS_CHECK       : Checks if we have found all the PHIS field
! 
!  GEOS-CHEM modules referenced by phis_read_mod.f
!  ============================================================================
!  (1 ) bpch2_mod.f      : Module containing routines for binary punch file I/O
!  (2 ) dao_mod.f        : Module containing arrays for DAO met fields
!  (3 ) diag_mod.f       : Module containing GEOS-CHEM diagnostic arrays
!  (4 ) error_mod.f      : Module containing NaN and other error check routines
!  (5 ) file_mod.f       : Module containing file unit #'s and error checks
!  (6 ) time_mod.f       : Module containing routines for computing time & date
!  (7 ) transfer_mod.f   : Module containing routines to cast & resize arrays
!
!  NOTES:
!  (1 ) Adapted from "dao_read_mod.f" (bmy, 6/16/03)
!******************************************************************************
!
      IMPLICIT NONE

      !=================================================================
      ! MODULE PRIVATE DECLARATIONS -- keep certain internal variables 
      ! and routines from being seen outside "i6_read_mod.f"
      !=================================================================

      ! PRIVATE module routines
      PRIVATE :: CHECK_TIME, PHIS_CHECK, READ_PHIS

      !=================================================================
      ! MODULE ROUTINES -- follow below the "CONTAINS" statement 
      !=================================================================
      CONTAINS

!------------------------------------------------------------------------------

      SUBROUTINE UNZIP_PHIS_FIELD( OPTION, NYMD )
!
!*****************************************************************************
!  Subroutine UNZIP_PHIS_FIELDS invokes a FORTRAN system call to uncompress
!  GEOS-CHEM PHIS met field files and store the uncompressed data in a 
!  temporary directory, where GEOS-CHEM can read them.  The original data 
!  files are not disturbed.  (bmy, bdf, 6/15/98, 6/16/03)
!
!  Arguments as input:
!  ===========================================================================
!  (1 ) OPTION (CHAR*(*)) : Option
!  (2 ) NYMD   (INTEGER ) : Current value of YYYYMMDD (Year-Month-Day)
!
!  NOTES:
!  (1 ) Adapted from UNZIP_MET_FIELDS of "dao_read_mod.f" (bmy, 6/16/03)
!*****************************************************************************
!
      ! References to F90 modules
      USE BPCH2_MOD, ONLY : GET_RES_EXT
      USE ERROR_MOD, ONLY : ERROR_STOP
      USE TIME_MOD,  ONLY : EXPAND_DATE

#     include "CMN_SIZE"
#     include "CMN_SETUP"

      ! Arguments
      CHARACTER(LEN=*),  INTENT(IN) :: OPTION
      INTEGER, OPTIONAL, INTENT(IN) :: NYMD

      ! Local variables
      CHARACTER(LEN=255)            :: PHIS_FILE_GZ, PHIS_FILE
      CHARACTER(LEN=255)            :: UNZIP_BG,   UNZIP_FG
      CHARACTER(LEN=255)            :: REMOVE_ALL, REMOVE_DATE

      !=================================================================
      ! UNZIP_MET_FIELDS begins here!
      !=================================================================
      IF ( PRESENT( NYMD ) ) THEN
      
#if   defined( GEOS_1 )

         ! Location of zipped A-3 file in data dir (GEOS-1)
         PHIS_FILE_GZ = TRIM( DATA_DIR )    // TRIM( GEOS_1_DIR )     // 
     &                  'YYMM/YYMMDD.phis.' // GET_RES_EXT()          // 
     &                  TRIM( ZIP_SUFFIX )

         ! Location of unzipped A-3 file in temp dir (GEOS-1)
         PHIS_FILE    = TRIM( TEMP_DIR )    // 'YYMMDD.phis.'         // 
     &                  GET_RES_EXT()
         
         ! Remove A-3 files for this date from temp dir (GEOS-1)
         REMOVE_DATE  = TRIM( REMOVE_CMD )  // ' '                    // 
     &                  TRIM( TEMP_DIR   )  // 'YYMMDD.phis.'         // 
     &                  GET_RES_EXT()  

#elif defined( GEOS_STRAT )

         ! Location of zipped A-3 file in data dir (GEOS-STRAT)
         PHIS_FILE_GZ = TRIM( DATA_DIR )    // TRIM( GEOS_S_DIR )     // 
     &                  'YYMM/YYMMDD.phis.' // GET_RES_EXT()          // 
     &                  TRIM( ZIP_SUFFIX )

         ! Location of unzipped A-3 file in temp dir (GEOS-STRAT)
         PHIS_FILE    = TRIM( TEMP_DIR )    // 'YYMMDD.phis.'         // 
     &                  GET_RES_EXT()

         ! Remove A-3 files for this date from temp dir (GEOS-STRAT)
         REMOVE_DATE  = TRIM( REMOVE_CMD )  // ' '                    // 
     &                  TRIM( TEMP_DIR   )  // 'YYMMDD.phis.'         // 
     &                  GET_RES_EXT()  

#elif defined( GEOS_3 )

         ! Location of zipped A-3 file in data dir (GEOS-3)
         PHIS_FILE_GZ = TRIM( DATA_DIR )        // TRIM( GEOS_3_DIR ) // 
     &                  'YYYYMM/YYYYMMDD.phis.' // GET_RES_EXT()      // 
     &                   TRIM( ZIP_SUFFIX )

         ! Location of unzipped A-3 file in temp dir (GEOS-3)
         PHIS_FILE    = TRIM( TEMP_DIR )   // 'YYYYMMDD.phis.'        // 
     &                  GET_RES_EXT()

         ! Remove A-3 files for this date from temp dir (GEOS-3)
         REMOVE_DATE  = TRIM( REMOVE_CMD ) // ' '                     // 
     &                  TRIM( TEMP_DIR   ) // 'YYYYMMDD.phis.'        // 
     &                  GET_RES_EXT()  

#elif defined( GEOS_4 )

         ! Location of zipped A-3 file in data dir (GEOS-4)
         PHIS_FILE_GZ = TRIM( DATA_DIR )        // TRIM( GEOS_4_DIR ) // 
     &                  'YYYYMM/YYYYMMDD.phis.' // GET_RES_EXT()      // 
     &                  TRIM( ZIP_SUFFIX )

         ! Location of unzipped A-3 file in temp dir (GEOS-4)
         PHIS_FILE    = TRIM( TEMP_DIR )    // 'YYYYMMDD.phis.'       // 
     &                  GET_RES_EXT()

         ! Remove A-3 files for this date from temp dir (GEOS-3)
         REMOVE_DATE  = TRIM( REMOVE_CMD )  // ' '                    // 
     &                  TRIM( TEMP_DIR   )  // 'YYYYMMDD.phis.'       // 
     &                  GET_RES_EXT()  

#endif

         !==============================================================
         ! Replace tokens in character variables w/ year & month values
         !==============================================================
         CALL EXPAND_DATE( PHIS_FILE_GZ,  NYMD, 000000 )
         CALL EXPAND_DATE( PHIS_FILE,     NYMD, 000000 )
         CALL EXPAND_DATE( REMOVE_DATE,   NYMD, 000000 )

         !==============================================================
         ! Define the foreground and background UNZIP commands
         !==============================================================

         ! Foreground unzip
         UNZIP_FG = TRIM( UNZIP_CMD ) // ' ' // TRIM( PHIS_FILE_GZ ) // 
     &              TRIM( REDIRECT  ) // ' ' // TRIM( PHIS_FILE    )  

         ! Background unzip
         UNZIP_BG  = TRIM( UNZIP_FG ) // TRIM( BACKGROUND )
      ENDIF

      !=================================================================
      ! Define command to remove all PHIS files from the TEMP dir
      !=================================================================
      REMOVE_ALL = TRIM( REMOVE_CMD ) // ' '    // TRIM( TEMP_DIR  ) // 
     &             TRIM( WILD_CARD  ) //'.phis.'// TRIM( WILD_CARD ) 

      !=================================================================
      ! Perform an F90 system call to do the desired operation
      !=================================================================
      SELECT CASE ( TRIM( OPTION ) )
         
         ! Unzip A-3 fields in the Unix foreground
         CASE ( 'unzip foreground' )
            WRITE( 6, 100 ) TRIM( PHIS_FILE_GZ )
            CALL SYSTEM( TRIM( UNZIP_FG ) )

         ! Unzip A-3 fields in the Unix background
         CASE ( 'unzip background' )
            WRITE( 6, 100 ) TRIM( PHIS_FILE_GZ )
            CALL SYSTEM( TRIM( UNZIP_BG ) )

         ! Remove A-3 field for this date in temp dir
         CASE ( 'remove date' )
            WRITE( 6, 110 ) TRIM( PHIS_FILE )
            CALL SYSTEM( TRIM( REMOVE_DATE ) )
            
         ! Remove all A-3 fields in temp dir
         CASE ( 'remove all' )
            WRITE( 6, 120 ) TRIM( REMOVE_ALL )
            CALL SYSTEM( TRIM( REMOVE_ALL ) )

         ! Error -- bad option!
         CASE DEFAULT
            CALL ERROR_STOP( 'Invalid value for OPTION!', 
     &                       'UNZIP_PHIS_FIELDS (phis_read_mod.f)' )
            
      END SELECT

      ! FORMAT strings
 100  FORMAT( '     - Unzipping: ', a )
 110  FORMAT( '     - Removing: ', a )
 120  FORMAT( '     - About to execute command: ', a )

      ! Return to calling program
      END SUBROUTINE UNZIP_PHIS_FIELD

!------------------------------------------------------------------------------

      SUBROUTINE OPEN_PHIS_FIELD( NYMD, NHMS )
!
!******************************************************************************
!  Subroutine OPEN_PHIS_FIELDS opens the I-6 met fields file for date NYMD and 
!  time NHMS. (bmy, bdf, 6/15/98, 6/16/03)
!  
!  Arguments as input:
!  ===========================================================================
!  (1 ) NYMD (INTEGER)   : Current value of YYYYMMDD
!  (2 ) NHMS (INTEGER)   : Current value of HHMMSS
!
!  NOTES:
!  (1 ) Adapted from OPEN_MET_FIELDS of "dao_read_mod.f" (bmy, 6/13/03)
!******************************************************************************
!      
      ! References to F90 modules
      USE BPCH2_MOD, ONLY : GET_RES_EXT
      USE ERROR_MOD, ONLY : ERROR_STOP
      USE FILE_MOD,  ONLY : IU_PH, IOERROR
      USE TIME_MOD,  ONLY : EXPAND_DATE

#     include "CMN_SIZE"           ! Size parameters
#     include "CMN_SETUP"          ! GEOS directories

      ! Arguments
      INTEGER,          INTENT(IN) :: NYMD, NHMS

      ! Local variables
      LOGICAL, SAVE                :: FIRST = .TRUE.
      LOGICAL                      :: IT_EXISTS
      INTEGER                      :: IOS, IUNIT
      CHARACTER(LEN=255)           :: INPUT_DIR
      CHARACTER(LEN=255)           :: PATH

      !=================================================================
      ! OPEN_PHIS_FIELDS begins here!
      !=================================================================

      ! Open the A-3 file 0 GMT of each day, or on the first call
      IF ( NHMS == 000000 .or. FIRST ) THEN

#if   defined( GEOS_1 ) || defined( GEOS_STRAT )

         ! Location of A-3 file in temp dir (GEOS-1, GEOS-S)
         PATH = TRIM( TEMP_DIR )  // 'YYMMDD.phis.' // GET_RES_EXT()

#else

         ! Location of A-3 file in temp dir (GEOS-3, GEOS-4)
         PATH = TRIM( TEMP_DIR )  // 'YYYYMMDD.phis.' // GET_RES_EXT()

#endif

         ! Replace YYYYMMDD in PATH w/ actual date
         CALL EXPAND_DATE( PATH, NYMD, 000000 )

         ! Close previously opened A-3 file
         CLOSE( IU_PH )

         ! Make sure the file exists before we open it!
         ! Maybe make this a function in ERROR_MOD (bmy, 6/16/03)
         INQUIRE( IU_PH, EXIST=IT_EXISTS )
            
         IF ( .not. IT_EXISTS ) THEN
            CALL ERROR_STOP( 'Could not find file!', 
     &                       'OPEN_PHIS_FIELD (phis_read_mod.f)' )
         ENDIF

         ! Open the file
         OPEN( UNIT   = IU_PH,         FILE   = TRIM( PATH ),
     &         STATUS = 'OLD',         ACCESS = 'SEQUENTIAL',  
     &         FORM   = 'UNFORMATTED', IOSTAT = IOS )
               
         IF ( IOS /= 0 ) THEN
            CALL IOERROR( IOS, IU_PH, 'open_phis_fields:1' )
         ENDIF

         WRITE( 6, '( ''     - Opening: '', a )' ) TRIM( PATH )
         
         ! Set the proper first-time-flag false
         FIRST = .FALSE.

      ENDIF

      ! Return to calling program
      END SUBROUTINE OPEN_PHIS_FIELD

!------------------------------------------------------------------------------

      SUBROUTINE GET_PHIS_FIELD( NYMD, NHMS )
!
!******************************************************************************
!  Subroutine GET_PHIS_FIELD is a wrapper for routine READ_PHIS.  This routine
!  calls READ_PHIS properly for reading PHIS fields from GEOS-1, GEOS-STRAT, 
!  GEOS-3, or GEOS-4 met data sets at the START of a GEOS-CHEM run. 
!  (bmy, 6/16/03)
!
!  Arguments as Input:
!  ============================================================================
!  (1 ) NYMD (INTEGER) : YYYYMMDD
!  (2 ) NHMS (INTEGER) :  and HHMMSS of I-6 fields to be read from disk
!
!  NOTES:
!******************************************************************************
! 
      ! References to F90 modules
      USE DAO_MOD, ONLY : PHIS

      ! Arguments
      INTEGER, INTENT(IN) :: NYMD, NHMS 

      !=================================================================
      ! GET_PHIS_FIELD begins here!
      !=================================================================
      CALL READ_PHIS( NYMD=NYMD, NHMS=NHMS, PHIS=PHIS )

      ! Return to calling program
      END SUBROUTINE GET_PHIS_FIELD

!---------------------------------------------------------------------------

      FUNCTION CHECK_TIME( XYMD, XHMS, NYMD, NHMS ) RESULT( ITS_TIME )
!
!******************************************************************************
!  Function CHECK_TIME checks to see if the timestamp of the A-3 field just
!  read from disk matches the current time.  If so, then it's time to return
!  the A-3 field to the calling program. (bmy, 6/16/03)
!  
!  Arguments as Input:
!  ============================================================================
!  (1 ) XYMD (REAL*4 or INTEGER) : (YY)YYMMDD timestamp for A-3 field in file
!  (2 ) XHMS (REAL*4 or INTEGER) : HHMMSS     timestamp for A-3 field in file
!  (3 ) NYMD (INTEGER          ) : YYYYMMDD   at which A-3 field is to be read
!  (4 ) NHMS (INTEGER          ) : HHMMSS     at which A-3 field is to be read
!
!  NOTES:
!******************************************************************************
!
#     include "CMN_SIZE"

#if   defined( GEOS_1 ) || defined( GEOS_STRAT )

      ! Arguments
      REAL*4,  INTENT(IN) :: XYMD, XHMS 
      INTEGER, INTENT(IN) :: NYMD, NHMS

      ! Function value
      LOGICAL             :: ITS_TIME

      !=================================================================
      ! GEOS-1 and GEOS-STRAT: XYMD and XHMS are REAL*4
      !=================================================================
      IF ( INT(XYMD) == NYMD-19000000 .AND. INT(XHMS) == NHMS ) THEN
         ITS_TIME = .TRUE.
      ELSE
         ITS_TIME = .FALSE.
      ENDIF

#else

      ! Arguments 
      INTEGER, INTENT(IN) :: XYMD, XHMS, NYMD, NHMS
      
      ! Function value
      LOGICAL             :: ITS_TIME

      !=================================================================
      ! GEOS-3, GEOS-4: XYMD and XHMS are integers
      !=================================================================
      IF ( XYMD == NYMD .AND. XHMS == NHMS ) THEN
         ITS_TIME = .TRUE.
      ELSE
         ITS_TIME = .FALSE.
      ENDIF

#endif

      ! Return to calling program
      END FUNCTION CHECK_TIME

!------------------------------------------------------------------------------

      SUBROUTINE READ_PHIS( NYMD, NHMS, PHIS )
!
!******************************************************************************
!  Subroutine READ_PHIS reads DAO PHIS (surface geopotential heights) field 
!  from disk.  PHIS is an I-6 field, but is time-independent.  Thus READ_PHIS
!  only needs to be called once at the beginning of the model run.
!  (bmy, 5/8/98, 6/16/03)
!
!  Arguments as input:
!  ============================================================================
!  (1 ) NYMD   : YYMMDD
!  (2 ) NHMS   :  and HHMMSS of PHIS field to be read from disk
!
!  Arguments as output:
!  ============================================================================
!  (3 ) PHIS   : DAO field for surface geopotential height (= g0 * m)
!                in units of m^2 / s^2, where g0 = 9.8 m / s^2.
!
!  NOTES:
!  (1 ) Adapted from READ_PHIS from "dao_read_mod.f" (bmy, 6/16/03)
!******************************************************************************
!
      ! References to F90 modules
      USE DIAG_MOD,     ONLY : AD67
      USE FILE_MOD,     ONLY : IOERROR, IU_PH
      USE TRANSFER_MOD, ONLY : TRANSFER_2D

#     include "CMN_SIZE"   ! Size parameters
#     include "CMN_GCTM"   ! g0
#     include "CMN_DIAG"   ! ND67

      ! Arguments
      INTEGER, INTENT(IN)  :: NYMD, NHMS
      REAL*8,  INTENT(OUT) :: PHIS(IIPAR,JJPAR) 

      ! Local Variables
      INTEGER              :: NFOUND, IOS
      INTEGER, PARAMETER   :: N_PHIS = 1
      REAL*4               :: Q2(IGLOB,JGLOB)
      CHARACTER (LEN=8)    :: NAME

      ! XYMD, XHMS have to be REAL*4 for GEOS-1 and GEOS-STRAT
      ! but INTEGER for GEOS-3 and GEOS-4 (bmy, 6/16/03)
#if   defined( GEOS_1 ) || defined ( GEOS_STRAT )
      REAL*4               :: XYMD, XHMS 
#else
      INTEGER              :: XYMD, XHMS 
#endif

      !=================================================================
      ! READ_PHIS begins here!
      !=================================================================

      ! Zero number of PHIS fields we have found
      NFOUND = 0

      !=================================================================
      ! Read PHIS field from disk
      !=================================================================      
      DO

         ! PHIS field name
         READ( IU_PH, IOSTAT=IOS ) NAME

         ! IOS < 0: EOF, but make sure we have found everything
         IF ( IOS < 0 ) THEN
            CALL PHIS_CHECK( NFOUND, N_PHIS )
            EXIT
         ENDIF

         ! IOS > 0: True I/O error
         IF ( IOS > 0 ) CALL IOERROR( IOS, IU_PH, 'read_phis:1' )

         ! CASE statement for met fields
         SELECT CASE ( TRIM( NAME ) )

            !--------------------------------
            ! PHIS: geopotential heights
            !--------------------------------
            CASE ( 'PHIS' ) 
               READ( IU_PH, IOSTAT=IOS ) XYMD, XHMS, Q2
               IF ( IOS /= 0 ) CALL IOERROR( IOS, IU_PH, 'read_phis:2' )

               IF ( CHECK_TIME( XYMD, XHMS, NYMD, NHMS ) ) THEN
                  CALL TRANSFER_2D( Q2, PHIS )
                  NFOUND = NFOUND + 1
               ENDIF

            !--------------------------------
            ! Field not found
            !--------------------------------
            CASE DEFAULT
               WRITE( 6, '(a)' ) 'Searching for next field!'
         END SELECT

         !==============================================================
         ! If we have found all the fields for this time, then exit 
         ! the loop.  Otherwise, go on to the next iteration.
         !==============================================================
         IF ( CHECK_TIME( XYMD, XHMS, NYMD, NHMS ) .AND. 
     &        NFOUND == N_PHIS ) THEN
            WRITE( 6, 200 ) NYMD, NHMS 
 200        FORMAT( '     - Found PHIS met field for NYMD, NHMS = ', 
     &              i8.8, 1x, i6.6 )
            EXIT
         ENDIF                  
      ENDDO

      !=================================================================
      ! Divide PHIS by 9.8 m / s^2 to obtain surface heights in meters. 
      !
      ! ND67 diagnostic: Accumulating DAO surface fields:
      ! Field #15 in the ND67 diagnostic is the geopotential heights
      !=================================================================
      PHIS = PHIS / g0

      IF ( ND67 > 0 ) THEN
         AD67(:,:,15) = AD67(:,:,15) + PHIS
      ENDIF  

      ! Since we only read PHIS at the start of the run,
      ! close the file unit (bmy, 6/16/03)
      CLOSE( IU_PH )

      ! Return to calling program      
      END SUBROUTINE READ_PHIS

!------------------------------------------------------------------------------

      SUBROUTINE PHIS_CHECK( NFOUND, N_PHIS )
!
!******************************************************************************
!  Subroutine PHIS_CHECK prints an error message if not all of the A-3 met 
!  fields are found.  The run is also terminated. (bmy, 10/27/00, 6/16/03)
!
!  Arguments as Input:
!  ============================================================================
!  (1 ) NFOUND (INTEGER) : # of met fields read from disk
!  (2 ) N_PHIS (INTEGER) : # of met fields expected to be read from disk
!
!  NOTES
!  (1 ) Adapted from DAO_CHECK from "dao_read_mod.f" (bmy, 6/16/03)
!******************************************************************************
!
      ! References to F90 modules
      USE ERROR_MOD, ONLY : GEOS_CHEM_STOP

      ! Arguments
      INTEGER, INTENT(IN) :: NFOUND, N_PHIS

      !=================================================================
      ! PHIS_CHECK begins here!
      !=================================================================
      IF ( NFOUND /= N_PHIS ) THEN
         WRITE( 6, '(a)' ) REPEAT( '=', 79 )
         WRITE( 6, '(a)' ) 'ERROR -- not enough PHIS fields found!'      

         WRITE( 6, 120   ) N_PHIS, NFOUND
 120     FORMAT( 'There are ', i2, ' fields but only ', i2 ,
     &           ' were found!' )

         WRITE( 6, '(a)' ) '### STOP in PHIS_CHECK (dao_read_mod.f)'
         WRITE( 6, '(a)' ) REPEAT( '=', 79 )

         ! Deallocate arrays and stop (bmy, 10/15/02)
         CALL GEOS_CHEM_STOP
      ENDIF

      ! Return to calling program
      END SUBROUTINE PHIS_CHECK

!------------------------------------------------------------------------------

      END MODULE PHIS_READ_MOD