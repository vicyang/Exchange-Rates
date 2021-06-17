@echo off
setlocal enabledelayedexpansion

call :func 2020
exit

:func
  GetExchangeData_bin.pl %1-01-01 %1-12-31 %1.perldb.bin

pause