@echo off
mode con cp select=437 >nul
setlocal enabledelayedexpansion

rem Set RDP Port
set RdpPort=3389
rem set RdpPort=3333

echo ===== Konfigurasi Port RDP =====

rem Set RDP port
echo Mengatur port RDP ke %RdpPort%...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v PortNumber /t REG_DWORD /d %RdpPort% /f

rem Configure firewall
echo Mengkonfigurasi aturan Firewall Windows...
for %%a in (TCP, UDP) do (
    netsh advfirewall firewall add rule ^
        name="Remote Desktop - Custom Port (%%a-In)" ^
        dir=in ^
        action=allow ^
        service=any ^
        protocol=%%a ^
        localport=%RdpPort%
)

echo ===== Perluasan Disk Otomatis =====
echo Memperluas semua partisi secara otomatis untuk menggunakan seluruh ruang disk...

rem Membuat file script diskpart sementara
set "diskpart_script=%temp%\extend_disk.txt"

rem Mendapatkan informasi semua disk
echo list disk > "%diskpart_script%"
echo exit >> "%diskpart_script%"
echo Mencari semua disk yang tersedia:
diskpart /s "%diskpart_script%"

rem Mencari semua disk dan memperluas setiap partisi terakhir secara otomatis
echo Memperluas semua partisi disk yang mungkin:

rem Membuat file script untuk mendeteksi dan memperluas partisi
>"%diskpart_script%" (
    echo rescan
)

rem Mencari jumlah disk yang tersedia
for /f "tokens=2 delims=:" %%i in ('diskpart /s "%diskpart_script%" ^| findstr /C:"Disk "') do (
    set "disk_count=%%i"
)
set /a disk_count=%disk_count:~1%

rem Loop melalui setiap disk
for /L %%d in (0,1,%disk_count%) do (
    echo.
    echo Memeriksa disk %%d...
    
    >"%diskpart_script%" (
        echo select disk %%d
        echo list partition
        echo exit
    )
    
    rem Memeriksa apakah disk memiliki partisi
    set "has_partition=0"
    for /f "tokens=1,2,3" %%a in ('diskpart /s "%diskpart_script%" ^| findstr /B "  Partition"') do (
        set "has_partition=1"
        set "last_partition=%%c"
    )
    
    if "!has_partition!"=="1" (
        echo Menemukan partisi di disk %%d. Mencoba memperluas partisi !last_partition!...
        
        >"%diskpart_script%" (
            echo select disk %%d
            echo select partition !last_partition!
            echo extend
            echo exit
        )
        
        diskpart /s "%diskpart_script%"
    ) else (
        echo Tidak ada partisi yang ditemukan di disk %%d.
    )
)

rem Hapus file script sementara
del "%diskpart_script%"

echo.
echo ===== Restart Layanan RDP =====

rem Home edition doesn't have RDP service
sc query TermService
if %errorlevel% == 1060 goto :del

rem Restart services with retry logic
set retryCount=5

:restartRDP
if %retryCount% LEQ 0 goto :del
echo Mencoba me-restart layanan TermService (sisa percobaan: %retryCount%)...
net stop TermService /y && net start TermService || (
    set /a retryCount-=1
    timeout 10
    goto :restartRDP
)

echo.
echo ===== Konfigurasi Selesai =====
echo Port RDP: %RdpPort%
echo Perluasan disk selesai
echo Script akan menghapus dirinya sendiri setelah selesai

:del
echo Membersihkan...
del "%~f0"
