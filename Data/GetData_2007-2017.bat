@echo off
setlocal enabledelayedexpansion
for /l %%a in (2007, 1, 2017) do (
    echo Current year: %%a
    set /a next = %%a + 1
    if not exist %%a.perldb.bin (
        GetExchangeData_bin.pl %%a-01-01 %%a-12-31 %%a.perldb.bin
    ) else (
        echo File already exists.
    )
)
pause