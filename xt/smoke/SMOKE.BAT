@ECHO OFF
REM Vim smoke test.  Run in the directory holding these files, with
REM VIM.EXE and CMPF.EXE on the PATH.
REM Test 1: ex commands from -c.  Test 2: normal/insert mode from -s.
REM The verdict also goes to RESULT.TXT, for xt/smoke.sh on the host.
IF EXIST RESULT.TXT DEL RESULT.TXT
COPY IN1.TXT T1.TXT > NUL
VIM -u NONE -c "%%s/fox/cat/" -c "g/DELETE/d" -c "1m$" -c "wq" T1.TXT
CMPF T1.TXT EXP1.TXT > CMP1.TXT
IF ERRORLEVEL 1 GOTO FAIL1
COPY IN2.TXT T2.TXT > NUL
VIM -u NONE -s T2.KEY T2.TXT
CMPF T2.TXT EXP2.TXT > CMP2.TXT
IF ERRORLEVEL 1 GOTO FAIL2
ECHO SMOKE: PASS
ECHO SMOKE: PASS > RESULT.TXT
GOTO END
:FAIL1
TYPE CMP1.TXT
ECHO SMOKE: FAIL test 1
ECHO SMOKE: FAIL test 1 > RESULT.TXT
GOTO END
:FAIL2
TYPE CMP2.TXT
ECHO SMOKE: FAIL test 2
ECHO SMOKE: FAIL test 2 > RESULT.TXT
:END
