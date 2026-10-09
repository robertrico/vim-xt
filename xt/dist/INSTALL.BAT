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
PATH C:\VIM;%PATH%
C:
CD \VIM\SMOKE
ECHO Running the smoke test ...
SMOKE
:WHERE
ECHO Run INSTALL from the directory that holds VIM.EXE and SMOKE\.
GOTO END
:FAILED
ECHO Copy to C:\VIM failed.
:END
