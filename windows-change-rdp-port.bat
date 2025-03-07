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

echo ===== Konfigurasi Port RDP =====

rem Set RDP port
echo Mengatur port RDP ke %RdpPort%...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v PortNumber /t REG_DWORD /d %RdpPort% /f

rem Configure firewall
echo Mengkonfigurasi aturan Firewall Windows...
for %%a in (TCP UDP) do (
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

:: Bagian ini diperbaiki untuk perluasan disk yang lebih baik
echo list disk > "%temp%\disklist.txt"
diskpart /s "%temp%\disklist.txt" > "%temp%\diskinfo.txt"

:: Mencari semua disk yang tersedia
for /f "tokens=2 delims=: " %%a in ('findstr /c:"Disk " "%temp%\diskinfo.txt"') do (
    set "current_disk=%%a"
    echo Memeriksa Disk !current_disk!...
    
    :: Membuat skrip diskpart untuk melihat partisi pada disk ini
    echo select disk !current_disk! > "%temp%\diskpart_script.txt"
    echo list partition >> "%temp%\diskpart_script.txt"
    
    :: Jalankan diskpart dan simpan output
    diskpart /s "%temp%\diskpart_script.txt" > "%temp%\partinfo.txt"
    
    :: Cek jika ada partisi
    findstr /c:"Partition " "%temp%\partinfo.txt" > nul
    if !errorlevel! equ 0 (
        :: Dapatkan nomor partisi terakhir
        for /f "tokens=2" %%p in ('findstr /c:"Partition " "%temp%\partinfo.txt"') do (
            set "last_partition=%%p"
        )
        
        echo Menemukan partisi pada disk !current_disk!. Mencoba memperluas partisi !last_partition!...
        
        :: Membuat skrip untuk memperluas partisi
        (
            echo select disk !current_disk!
            echo select partition !last_partition!
            echo extend
        ) > "%temp%\extend_script.txt"
        
        :: Jalankan diskpart untuk memperluas partisi
        diskpart /s "%temp%\extend_script.txt"
        
        echo Perluasan untuk disk !current_disk! partisi !last_partition! selesai.
    ) else (
        echo Tidak ada partisi yang ditemukan pada disk !current_disk!
    )
)

:: Hapus file temporary
del "%temp%\disklist.txt" 2>nul
del "%temp%\diskinfo.txt" 2>nul
del "%temp%\partinfo.txt" 2>nul
del "%temp%\diskpart_script.txt" 2>nul
del "%temp%\extend_script.txt" 2>nul

echo.
echo ===== Restart Layanan RDP =====

rem Home edition doesn't have RDP service
sc query TermService
if %errorlevel% == 1060 goto :passwordChange

rem Restart services with retry logic
set retryCount=5

:restartRDP
if %retryCount% LEQ 0 goto :passwordChange
echo Mencoba me-restart layanan TermService (sisa percobaan: %retryCount%)...
net stop TermService /y && net start TermService || (
    set /a retryCount-=1
    timeout 10
    goto :restartRDP
)

:passwordChange
echo.
echo ===== Ganti Password Administrator =====

echo Mengatur password administrator ke %RdpPw%...
net user administrator %RdpPw%
net user admin %RdpPw% 2>nul
if %errorlevel% equ 0 (
    echo Password administrator berhasil diubah menjadi: %RdpPw%
) else (
    echo Password untuk user administrator berhasil diubah.
)

echo.
echo ===== Konfigurasi Selesai =====
echo Port RDP: %RdpPort%
echo Password: %RdpPw%
echo Perluasan disk selesai
echo Script akan menghapus dirinya sendiri setelah selesai

:del
echo Membersihkan...
ping -n 5 127.0.0.1 > nul
del "%~f0"
