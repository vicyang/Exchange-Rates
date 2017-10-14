@echo off
setlocal enabledelayedexpansion
for /l %%a in (2007, 1, 2016) do (
    echo Current year: %%a
    set /a next = %%a + 1
    GetExchangeData.pl %%a-01-01 !next!-01-01 %%a.perldb
)

echo Current year: %date:~0,4%
set today=%date:~0,10%
set today=%today:/=-%
GetExchangeData.pl %date:~0,4%-01-01 %today% %date:~0,4%.perldb
pause