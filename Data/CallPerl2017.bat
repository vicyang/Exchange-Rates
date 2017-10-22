@echo off
setlocal enabledelayedexpansion
echo Select year: %date:~0,4%
set today=%date:~0,10%
set today=%today:/=-%
GetExchangeData.pl %date:~0,4%-01-01 %today% %date:~0,4%.perldb
pause