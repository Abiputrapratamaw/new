@echo off
mode con cp select=437 >nul

rem Set RDP Port (uncomment and modify as needed)
set RdpPort=3389
rem set RdpPort=3333

echo ===== RDP Port Configuration =====

rem https://learn.microsoft.com/windows-server/remote/remote-desktop-services/clients/change-listening-port
rem HKLM\SYSTEM\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\FirewallRules

rem RemoteDesktop-Shadow-In-TCP
rem v2.33|Action=Allow|Active=TRUE|Dir=In|Protocol=6|App=%SystemRoot%\system32\RdpSa.exe|Name=@FirewallAPI.dll,-28778|Desc=@FirewallAPI.dll,-28779|EmbedCtxt=@FirewallAPI.dll,-28752|Edge=TRUE|Defer=App|

rem RemoteDesktop-UserMode-In-TCP
rem v2.33|Action=Allow|Active=TRUE|Dir=In|Protocol=6|LPort=3389|App=%SystemRoot%\system32\svchost.exe|Svc=termservice|Name=@FirewallAPI.dll,-28775|Desc=@FirewallAPI.dll,-28756|EmbedCtxt=@FirewallAPI.dll,-28752|

rem RemoteDesktop-UserMode-In-UDP
rem v2.33|Action=Allow|Active=TRUE|Dir=In|Protocol=17|LPort=3389|App=%SystemRoot%\system32\svchost.exe|Svc=termservice|Name=@FirewallAPI.dll,-28776|Desc=@FirewallAPI.dll,-28777|EmbedCtxt=@FirewallAPI.dll,-28752|

rem Set RDP port
echo Setting RDP port to %RdpPort%...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v PortNumber /t REG_DWORD /d %RdpPort% /f

rem Configure firewall
echo Configuring Windows Firewall rules...
rem Different Windows versions have different built-in RDP rules
rem All versions have: program=%SystemRoot%\system32\svchost.exe service=TermService
rem Windows 7 also has: program=System service=
rem The following is a union of both
for %%a in (TCP, UDP) do (
    netsh advfirewall firewall add rule ^
        name="Remote Desktop - Custom Port (%%a-In)" ^
        dir=in ^
        action=allow ^
        service=any ^
        protocol=%%a ^
        localport=%RdpPort%
)

echo ===== Disk Extension =====
echo Extending disks to use all available space...

rem List all disks and their information
echo Listing all available disks:
echo.
diskpart /s << EOF
list disk
list volume
exit
EOF

rem Execute disk extension automatically for all disks
echo.
echo Extending all disks to maximum capacity:
diskpart /s << EOF
list disk
select disk 0
list partition
list volume
rem For each partition that needs to be extended, uncomment and modify the following lines
rem select partition 2
rem extend
exit
EOF

rem Home edition doesn't have RDP service
sc query TermService
if %errorlevel% == 1060 goto :del

rem Restart services - can use sc or net
rem UmRdpService depends on TermService
rem sc stop can't handle dependencies, so sc stop TermService requires sc stop UmRdpService first
rem net stop can handle dependencies
rem sc stop is asynchronous, net stop is not asynchronous but has a timeout
rem After TermService runs, UmRdpService will run automatically

rem If the system is starting the RDP service, it will fail, so use goto loop
rem "The Remote Desktop Services service could not be stopped."

rem Some machines may enter an infinite loop, startup logo continuously cycles
rem Through netstat -ano you can see the port has been successfully modified, but the RDP service keeps restarting (PID keeps changing)
rem Therefore limit retry count to avoid infinite loops

set retryCount=5

echo ===== Restarting RDP Service =====
:restartRDP
if %retryCount% LEQ 0 goto :del
echo Attempting to restart TermService (attempts remaining: %retryCount%)...
net stop TermService /y && net start TermService || (
    set /a retryCount-=1
    timeout 10
    goto :restartRDP
)

echo ===== Configuration Complete =====
echo RDP Port: %RdpPort%
echo Disk extension completed
echo Script will self-delete after completion

:del
echo Cleaning up...
del "%~f0"
