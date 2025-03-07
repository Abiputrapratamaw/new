@echo off
:: Jalankan sebagai Administrator
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

:: Ganti nama komputer ke AVOLA dengan metode yang lebih komprehensif
echo Mengganti nama komputer...

:: Metode 1: Menggunakan wmic
wmic computersystem where name="%computername%" call rename name="AVOLA"

:: Metode 2: Menggunakan PowerShell
powershell -Command "Rename-Computer -NewName 'AVOLA' -Force"

:: Metode 3: Mengatur nama komputer di Registry
reg add "HKLM\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName" /v ComputerName /t REG_SZ /d AVOLA /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName" /v ComputerName /t REG_SZ /d AVOLA /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v Hostname /t REG_SZ /d AVOLA /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v NV Hostname /t REG_SZ /d AVOLA /f

:: Cek dan hapus volume dengan label "installer"
(
    echo list volume
    echo exit
) | diskpart | findstr /i "installer" > temp.txt

if not exist temp.txt (
    echo Tidak ada volume dengan label "installer" ditemukan.
    goto END
)

for /f "tokens=2" %%a in (temp.txt) do (
    echo select volume %%a
    echo delete volume
) | diskpart
del temp.txt

:: Pastikan ada ruang kosong sebelum memperbesar volume utama
(
    echo list disk
    echo exit
) | diskpart > diskinfo.txt

findstr /i "Unallocated" diskinfo.txt >nul
if %errorlevel% neq 0 (
    echo Tidak ada ruang unallocated. Pastikan volume berhasil dihapus.
    goto END
)

:: Perpanjang volume utama
(
    echo list volume
    echo exit
) | diskpart | findstr /i "\<%C%\>" > temp2.txt

if not exist temp2.txt (
    echo Volume utama tidak ditemukan. Tidak dapat diperluas.
    goto END
)

for /f "tokens=2" %%a in (temp2.txt) do (
    echo select volume %%a
    echo extend
) | diskpart
del temp2.txt
del diskinfo.txt

:END
:: Tampilkan pesan konfirmasi
echo Proses selesai. Nama komputer telah diganti menjadi AVOLA.
echo Memulai restart dalam 10 detik...

:: Restart otomatis dalam 10 detik
shutdown /r /t 10 /c "Komputer akan restart untuk menerapkan perubahan nama"

:: Hapus file batch ini setelah selesai
del "%~f0"
