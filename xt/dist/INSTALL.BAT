@ECHO OFF
REM Install Vim for the XT into C:\VIM and run the smoke test.
REM Run it from the directory that holds this file, e.g.  D:  CD \VIM  INSTALL
IF NOT EXIST VIM.EXE GOTO WHERE
IF NOT EXIST SMOKE\SMOKE.BAT GOTO WHERE
IF NOT EXIST C:\VIM\NUL MD C:\VIM
IF NOT EXIST C:\VIM\SMOKE\NUL MD C:\VIM\SMOKE
ECHO Copying to C:\VIM ...
COPY VIM.EXE C:\VIM > NUL
COPY CMPF.EXE C:\VIM > NUL
COPY MCB.EXE C:\VIM > NUL
COPY SMOKE\*.* C:\VIM\SMOKE > NUL
IF NOT EXIST C:\VIM\VIM.EXE GOTO FAILED
REM Vim's swap file for :! and :make goes in %TEMP% (else the current
REM directory).  Make C:\TEMP and use it if TEMP isn't set.
IF NOT EXIST C:\TEMP\NUL MD C:\TEMP
IF "%TEMP%"=="" SET TEMP=C:\TEMP
PATH C:\VIM;%PATH%
C:
CD \VIM\SMOKE
ECHO Running the smoke test ...
ECHO To keep it, add  SET TEMP=C:\TEMP  to AUTOEXEC.BAT
SMOKE
:WHERE
ECHO Run INSTALL from the directory that holds VIM.EXE and SMOKE\.
GOTO END
:FAILED
ECHO Copy to C:\VIM failed.
:END
