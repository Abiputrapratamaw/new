rem set mac_addr=11:22:33:aa:bb:cc

rem set ipv4_addr=192.168.1.2/24
rem set ipv4_gateway=192.168.1.1
rem set ipv4_dns1=192.168.1.1
rem set ipv4_dns2=192.168.1.2

rem set ipv6_addr=2222::2/64
rem set ipv6_gateway=2222::1
rem set ipv6_dns1=::1
rem set ipv6_dns2=::2

@echo off
mode con cp select=437 >nul
setlocal EnableDelayedExpansion

rem Memeriksa dan meminta hak admin
cd.>%windir%\GetAdmin
if exist %windir%\GetAdmin (
    del /f /q "%windir%\GetAdmin"
    echo Hak administrator diperoleh.
) else (
    echo Meminta hak administrator...
    echo CreateObject^("Shell.Application"^).ShellExecute "%~s0", "%*", "", "runas", 1 >> "%temp%\Admin.vbs"
    "%temp%\Admin.vbs"
    del /f /q "%temp%\Admin.vbs"
    exit /b 2
)

echo ===== Konfigurasi Jaringan dan Extend Disk =====

rem Extend disk untuk menggunakan seluruh ruang disk yang tersedia
echo.
echo Memperluas partisi disk untuk menggunakan seluruh ruang yang tersedia...
echo.

set systemDisk=%SystemDrive:~0,1%
for /f "tokens=2" %%d in ('echo list vol ^| diskpart ^| findstr "\<%systemDisk%\>"') do (echo select disk 0 & echo select vol %%d & echo extend) | diskpart

echo.
echo Konfigurasi disk selesai.
echo.

rem Konfigurasi jaringan dimulai dari sini
echo Memulai konfigurasi jaringan...

rem Menonaktifkan randomisasi identifier IPv6, mencegah ketidakkonsistenan antara IPv6 dan panel
netsh interface ipv6 set global randomizeidentifiers=disabled

rem Memeriksa apakah alamat MAC telah ditentukan
if defined mac_addr (
    for /f %%a in ('wmic nic where "MACAddress='%mac_addr%'" get InterfaceIndex ^| findstr [0-9]') do set id=%%a
    if defined id (
        echo Antarmuka jaringan dengan MAC %mac_addr% ditemukan dengan ID !id!
        
        rem Mengkonfigurasi alamat IPv4 statis dan gateway
        if defined ipv4_addr if defined ipv4_gateway (
            echo Mengkonfigurasi alamat IPv4 statis dan gateway...
            netsh interface ipv4 set address !id! static !ipv4_addr! gateway=!ipv4_gateway! gwmetric=0
        )

        rem Mengkonfigurasi server DNS IPv4
        for %%i in (1, 2) do (
            if defined ipv4_dns%%i (
                echo Mengkonfigurasi server DNS IPv4 !ipv4_dns%%i!...
                netsh interface ipv4 add | findstr "dnsservers" >nul
                if ErrorLevel 1 (
                    rem Vista
                    netsh interface ipv4 add dnsserver !id! !ipv4_dns%%i! %%i
                ) else (
                    rem Windows 7+
                    netsh interface ipv4 add dnsservers !id! !ipv4_dns%%i! %%i no
                )
            )
        )

        rem Mengkonfigurasi alamat IPv6 dan gateway
        if defined ipv6_addr if defined ipv6_gateway (
            echo Mengkonfigurasi alamat IPv6 dan gateway...
            netsh interface ipv6 set address !id! !ipv6_addr!
            netsh interface ipv6 add route prefix=::/0 !id! !ipv6_gateway!
        )

        rem Mengkonfigurasi server DNS IPv6
        for %%i in (1, 2) do (
            if defined ipv6_dns%%i (
                echo Mengkonfigurasi server DNS IPv6 !ipv6_dns%%i!...
                netsh interface ipv6 add | findstr "dnsservers" >nul
                if ErrorLevel 1 (
                    rem Vista
                    netsh interface ipv6 add dnsserver !id! !ipv6_dns%%i! %%i
                ) else (
                    rem Windows 7+
                    netsh interface ipv6 add dnsservers !id! !ipv6_dns%%i! %%i no
                )
            )
        )
    ) else (
        echo Antarmuka jaringan dengan MAC %mac_addr% tidak ditemukan.
    )
) else (
    echo Alamat MAC tidak ditentukan, melewati konfigurasi jaringan.
)

echo.
echo Konfigurasi selesai.
echo.
echo Script ini akan dihapus dalam 5 detik...
timeout /t 5 >nul

rem Menghapus script ini
del "%~f0"