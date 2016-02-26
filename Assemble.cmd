@rem 20-Jan-2016 @ DRA
@setlocal
@echo off

rem Must be run elevated
whoami /groups | find "S-1-16-12288" > nul
if errorlevel 1 goto ADK

rem Must be run from ADK prompt
if "%DandIRoot%" equ "" goto ADK

if "%1" equ "" goto ISO
if not exist "%1\sources\boot.wim" goto ISO
set FOUND=0
if exist %1\sources\install.esd set FOUND=1
if exist %1\sources\install.wim set FOUND=1

set ISO_FILE=Windows-10-1511-x64.iso
if %FOUND% equ 0 goto ISO
if "%~dp0" neq "%CD%\" goto Working
for %%f in (DVD\nul install.esd %ISO_FILE%) do if exist %%f goto Clear

rem Duplicate the DVD
robocopy %1 DVD\ /e /dcopy:T /a-:R

rem dism /Get-WimInfo /WimFile:{full-path} prints the index for both .wim and .esd files

rem Insert SATA driver into boot.wim
rem Assume that Microsoft Windows Setup (x64) is Index 2 of boot.wim (Microsoft Windows PE should be Index 1)
if not exist Mount\nul md Mount
set IMAGE=%~dp0Mount
dism /Mount-Image /ImageFile:%~dp0DVD\sources\boot.wim /Index:2 /MountDir:%IMAGE%
dism /Image:%IMAGE% /Add-Driver:%~dp05510\SATA\iaStorAC.inf /ForceUnsigned
dism /Unmount-Image /MountDir:%IMAGE% /Commit

rem If install.wim is compressed, extract it. Assume that Professional edition is Index 1
if exist %~dp0DVD\sources\install.esd (
  rem In order to decompress the .esd, it needs to be written into a normal wim
  dism /Capture-Image /ImageFile:%~dp0DVD\sources\install.wim /CaptureDir:%IMAGE% /Compress:max /Name:EmptyIndex
  rem It's not entirely clear why /Compress:recovery has to be specified here (but it does!)
  dism /Export-Image /SourceImageFile:%~dp0DVD\sources\install.esd /SourceIndex:1 /DestinationImageFile:%~dp0DVD\sources\install.wim /Compress:recovery
  del %~dp0DVD\sources\install.esd
  rem Remove the blank first entry
  dism /Delete-Image /ImageFile:%~dp0DVD\sources\install.wim /Index:1
)

rem Update install.wim
dism /Mount-Image /ImageFile:%~dp0DVD\sources\install.wim /Index:1 /MountDir:%IMAGE%
rem Insert drivers
dism /Add-Driver /Image:%IMAGE% /Driver:%~dp05510 /Recurse /ForceUnsigned
rem Insert updates
for %%f in (Updates\*.msu) do dism /Add-Package /Image:%IMAGE% /PackagePath:%~dp0%%f
rem Add .NET Framework 3.5 on-demand package
dism /Add-Package /Image:%IMAGE% /PackagePath:%~dp0DVD\sources\sxs\microsoft-windows-netfx3-ondemand-package.cab
dism /Unmount-Image /MountDir:%IMAGE% /Commit

rem Drivers and updates will make install.wim too large for a DVD - (re)compress to install.esd
dism /Export-Image /SourceImageFile:%~dp0DVD\sources\install.wim /SourceIndex:1 /DestinationImageFile:%~dp0DVD\sources\install.esd /Compress:recovery
del %~dp0DVD\sources\install.wim

rem Add the Setup script
copy %~dp0Autounattend.xml %~dp0DVD\

rem Create the .iso
oscdimg -lESD-ISO -m -o -u2 -udfver102 -bootdata:2#p0,e,b%~dp0DVD\boot\etfsboot.com#pEF,e,b%~dp0DVD\efi\microsoft\boot\efisys.bin %~dp0DVD %~dp0%ISO_FILE%

rd Mount

echo %~dp0DVD may be deleted; %ISO_FILE% has been written.

goto :EOF

:ADK
echo This script expects to be run from an elevated Deployment and Imaging Tools
echo Environment from the Windows Assessment and Deployment Kit ^(ADK^).
echo Visit https://msdn.microsoft.com/en-us/windows/hardware/dn913721.aspx#adkwin10
echo for more information.
goto :EOF

:ISO
echo Pass the location of the Windows 10 Setup DVD Files as the first parameter to
echo the script. It expects to find sources\boot.wim and either sources\install.wim
echo or sources\install.esd
goto :EOF

:Working
echo This script needs to be run from the directory in which it resides.
goto :EOF

:Clear
echo An existing DVD directory, install.esd or %ISO_FILE% file has been found in
echo %~dp0 - please delete them first.
goto :EOF
