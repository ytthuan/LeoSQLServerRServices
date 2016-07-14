@echo off

call :ensure_exists "DATA\airline10M.xdf" || exit /b 1
call :ensure_exists "DATA\airline-cleaned-10M.csv" || exit /b 1

sqlcmd -i createdb.sql
RScript --default-packages=methods createtables.R
sqlcmd -i createtablewithindex.sql
sqlcmd -i createcolumnartable.sql
sqlcmd -i createpagecompressedtable.sql
sqlcmd -i createrowcompressedtable.sql
sqlcmd -i createrdatatable.sql
REM Use -l option to give library path to where to install the package.
RScript -e "install.packages('RODBC', dep=TRUE)"
exit /b 0

:ensure_exists
	if exist "%~1" exit /b 0
	echo ERROR: %~1 does not exist
	exit /b 1

