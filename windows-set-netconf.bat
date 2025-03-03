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

rem Buat file script diskpart sementara
set "diskpart_script=%TEMP%\extend_disk.txt"
echo list volume > "%diskpart_script%"
echo select volume C >> "%diskpart_script%"
echo extend >> "%diskpart_script%"
echo exit >> "%diskpart_script%"

rem Jalankan diskpart dengan script
diskpart /s "%diskpart_script%"

rem Hapus file script sementara
del "%diskpart_script%"

echo.
echo Konfigurasi disk selesai.
echo.

rem Konfigurasi jaringan dimulai dari sini
echo Memulai konfigurasi jaringan...

rem 禁用 IPv6 地址标识符的随机化，防止 IPv6 和后台面板不一致
netsh interface ipv6 set global randomizeidentifiers=disabled

rem 检查是否定义了 MAC 地址
if defined mac_addr (
    for /f %%a in ('wmic nic where "MACAddress='%mac_addr%'" get InterfaceIndex ^| findstr [0-9]') do set id=%%a
    if defined id (
        echo Antarmuka jaringan dengan MAC %mac_addr% ditemukan dengan ID !id!
        
        rem 配置静态 IPv4 地址和网关
        if defined ipv4_addr if defined ipv4_gateway (
        rem gwmetric 默认值为 1，自动跃点需设为 0
            echo Mengkonfigurasi alamat IPv4 statis dan gateway...
            netsh interface ipv4 set address !id! static !ipv4_addr! gateway=!ipv4_gateway! gwmetric=0
        )

        rem 配置静态 IPv4 DNS 服务器
        for %%i in (1, 2) do (
            if defined ipv4_dns%%i (
                echo Mengkonfigurasi server DNS IPv4 !ipv4_dns%%i!...
                netsh interface ipv4 add | findstr "dnsservers"
                if ErrorLevel 1 (
                    rem vista
                    netsh interface ipv4 add dnsserver !id! !ipv4_dns%%i! %%i
                ) else (
                    rem win7
                    netsh interface ipv4 add dnsservers !id! !ipv4_dns%%i! %%i no
                )
            )
        )

        rem 配置 IPv6 地址和网关
        if defined ipv6_addr if defined ipv6_gateway (
            echo Mengkonfigurasi alamat IPv6 dan gateway...
            netsh interface ipv6 set address !id! !ipv6_addr!
            netsh interface ipv6 add route prefix=::/0 !id! !ipv6_gateway!
        )

        rem 配置 IPv6 DNS 服务器
        for %%i in (1, 2) do (
            if defined ipv6_dns%%i (
                echo Mengkonfigurasi server DNS IPv6 !ipv6_dns%%i!...
                netsh interface ipv6 add | findstr "dnsservers"
                if ErrorLevel 1 (
                    rem vista
                    netsh interface ipv6 add dnsserver !id! !ipv6_dns%%i! %%i
                ) else (
                    rem win7
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

rem 删除此脚本
del "%~f0"
