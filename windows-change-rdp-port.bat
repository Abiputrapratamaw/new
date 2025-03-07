@echo off
mode con cp select=437 >nul
setlocal enabledelayedexpansion

:: Cek apakah berjalan sebagai administrator
NET SESSION >nul 2>&1
if %errorLevel% neq 0 (
    echo Script ini membutuhkan hak administrator!
    echo Mengaktifkan permintaan hak administrator...
    
    :: Membuat file VBS sementara untuk mendapatkan hak admin
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    
    :: Jalankan file VBS dan keluar dari script saat ini
    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B
)

rem Set RDP Port
set RdpPort=22
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

rem Mencari semua disk dan memperluas setiap partisi terakhir secara otomatis
echo Memperluas semua partisi disk yang mungkin:

rem Membuat file script untuk scan disk
>"%diskpart_script%" (
    echo list disk
    echo exit
)

rem Dapatkan informasi disk
for /f "skip=8 tokens=2,3" %%i in ('diskpart /s "%diskpart_script%" ^| findstr /b /v "#"') do (
    set "disk_num=%%i"
    if not "!disk_num!"=="" (
        echo.
        echo Memeriksa disk !disk_num!...
        
        >"%diskpart_script%" (
            echo select disk !disk_num!
            echo list partition
            echo exit
        )
        
        rem Temukan partisi terakhir
        set "last_part="
        for /f "skip=6 tokens=2" %%a in ('diskpart /s "%diskpart_script%" ^| findstr /b /v "#"') do (
            set "last_part=%%a"
        )
        
        if defined last_part (
            echo Menemukan partisi terakhir: !last_part! di disk !disk_num!
            
            >"%diskpart_script%" (
                echo select disk !disk_num!
                echo select partition !last_part!
                echo extend
                echo exit
            )
            
            echo Mencoba memperluas partisi !last_part! di disk !disk_num!...
            diskpart /s "%diskpart_script%"
            echo Status perluasan selesai untuk disk !disk_num!
        ) else (
            echo Tidak ada partisi yang ditemukan di disk !disk_num!
        )
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

:passwordChange
echo.
echo ===== Ganti Password Administrator =====

echo Mengatur password administrator ke Kocak@@200...
net user administrator %RdpPw%
net user admin %RdpPw%
if %errorlevel% equ 0 (
    echo Password administrator berhasil diubah menjadi: Kocak@@200
) else (
    echo Gagal mengubah password administrator. Error code: %errorlevel%
)

echo.
echo ===== Konfigurasi Selesai =====
echo Port RDP: %RdpPort%
echo Perluasan disk selesai
echo Script akan menghapus dirinya sendiri setelah selesai

:del
echo Membersihkan...
del "%~f0"