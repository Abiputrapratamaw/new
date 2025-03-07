@echo off
:: Cek apakah script sudah berjalan sebagai Administrator
cd.>%windir%\GetAdmin
if exist %windir%\GetAdmin (
    del /f /q "%windir%\GetAdmin"
) else (
    echo CreateObject^("Shell.Application"^).ShellExecute "%~s0", "%*", "", "runas", 1 >> "%temp%\Admin.vbs"
    "%temp%\Admin.vbs"
    del /f /q "%temp%\Admin.vbs"
    exit /b 2
)

mode con cp select=437 >nul

:: Ambil drive utama (biasanya C:)
set C=%SystemDrive:~0,1%

:: Hapus volume dengan label "installer"
(
    echo list volume
    echo exit
) | diskpart | findstr /i "installer" > temp.txt

for /f "tokens=2" %%a in (temp.txt) do (
    echo select volume %%a
    echo delete volume
) | diskpart
del temp.txt

:: Perpanjang volume utama
(
    echo list volume
    echo exit
) | diskpart | findstr /i "\<%C%\>" > temp2.txt

for /f "tokens=2" %%a in (temp2.txt) do (
    echo select volume %%a
    echo extend
) | diskpart
del temp2.txt

:: Hapus file batch ini setelah selesai
del "%~f0"
