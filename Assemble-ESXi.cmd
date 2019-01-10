:: :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: ::
:: Copyright (c) 2019 MetaStack Solutions Ltd. See distribution terms at the end of this file.    ::
:: David Allsopp. 6-Jan-2019                                                                      ::
:: :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: ::
@rem Forked from Assemble.cmd ("temporary" script)
@setlocal
@echo off

rem Must be run elevated
whoami /groups | find "S-1-16-12288" > nul
if errorlevel 1 goto ADK

rem Must be run from ADK prompt
if "%DandIRoot%" equ "" goto ADK

rem @@DRA At this point - need to get a working drivers tree from the other script for the correct version of ESXi and need Server 2016 ISO in place

if "%1" equ "" goto ISO
if not exist "%1\sources\boot.wim" goto ISO
set FOUND=0
if exist %1\sources\install.esd set FOUND=1
if exist %1\sources\install.wim set FOUND=1

set WORK=D:\Working
if not exist "%WORK%\nul" md "%WORK%"
if not exist "%WORK%\Temp\nul" md "%WORK%\Temp"
set ISO_FILE=SW_DVD9_Win_Server_STD_CORE_2016_64Bit_English_-4_DC_STD_MLF_X21-70526-ESXi-10.3.5-10430147.iso
if %FOUND% equ 0 goto ISO
if "%~dp0" neq "%CD%\" goto Working
for %%f in (%WORK%\DVD\nul %WORK%\install.esd %WORK%\%ISO_FILE%) do if exist %%f goto Clear

rem Duplicate the DVD
robocopy "%~dp0ESXi-10.3.5-10430147\ " "%WORK%\Drivers\ " /mir
robocopy "%~dp0Updates-ESXi\ " "%WORK%\Updates\ " /mir
robocopy "%~dp0en-gb\ " "%WORK%\en-gb\ " /mir
robocopy %1 %WORK%\DVD\ /mir /dcopy:T /a-:R
copy /y "%~dp0Autounattend-ESXi.xml" "%WORK%\"

rem dism /Get-WimInfo /WimFile:{full-path} prints the index for both .wim and .esd files

echo %TIME%

rem Insert SATA driver into boot.wim
rem Assume that Microsoft Windows Setup (x64) is Index 2 of boot.wim (Microsoft Windows PE should be Index 1)
rem @@DRA Comments all wrong; also must ensure mount point is on a fixed disk, not a mapped drive
if not exist %WORK%\Mount\nul md %WORK%\Mount
set IMAGE=%WORK%\Mount
for /l %%I in (1,1,2) do (
  dism /Mount-Image /ImageFile:"%WORK%\DVD\sources\boot.wim" /Index:%%I /MountDir:"%IMAGE%"
  rem dism /Image:"%IMAGE%" /Add-Driver:"%WORK%\Drivers\pvscsi\pvscsi.inf" /ForceUnsigned
  rem dism /Image:"%IMAGE%" /Add-Driver:"%WORK%\Drivers\vmxnet3\vmxnet3.inf" /ForceUnsigned
  dism /Image:"%IMAGE%" /Add-Driver /Driver:"%WORK%\Drivers\pvscsi\pvscsi.inf" /Driver:"%WORK%\Drivers\vmxnet3\vmxnet3.inf"
  rem Only doing this in Index 2 in case there are other .cabs which should be installed to Image 1
  if %%I equ 2 (
    rem dism /Image:"%IMAGE%" /Remove-Package /PackageName:"Microsoft-Windows-WinPE-LanguagePack-Package~31bf3856ad364e35~amd64~en-US~10.0.14393.0"
    rem for %%P in (EnhancedStorage Scripting SecureStartup Setup Setup-Server SRT WDS-Tools WMI) do dism /Image:"%IMAGE%" /Remove-Package /PackageName:"WinPE-%%P-Package~31bf3856ad364e35~amd64~en-US~10.0.14393.0"
    dism /Image:"%IMAGE%" /Remove-Package /PackageName:"Microsoft-Windows-WinPE-LanguagePack-Package~31bf3856ad364e35~amd64~en-US~10.0.14393.0" /PackageName:"WinPE-EnhancedStorage-Package~31bf3856ad364e35~amd64~en-US~10.0.14393.0" /PackageName:"WinPE-Scripting-Package~31bf3856ad364e35~amd64~en-US~10.0.14393.0" /PackageName:"WinPE-SecureStartup-Package~31bf3856ad364e35~amd64~en-US~10.0.14393.0" /PackageName:"WinPE-Setup-Package~31bf3856ad364e35~amd64~en-US~10.0.14393.0" /PackageName:"WinPE-Setup-Server-Package~31bf3856ad364e35~amd64~en-US~10.0.14393.0" /PackageName:"WinPE-SRT-Package~31bf3856ad364e35~amd64~en-US~10.0.14393.0" /PackageName:"WinPE-WDS-Tools-Package~31bf3856ad364e35~amd64~en-US~10.0.14393.0" /PackageName:"WinPE-WMI-Package~31bf3856ad364e35~amd64~en-US~10.0.14393.0"
    rem @@DRA The cabinet files contain .mum files which will include the names of packages which are available - this would allow
    rem       us to detect all the en-gb packages and swap them for en-US
    rem dism /Image:"%IMAGE%" /Add-Package /PackagePath:"%WORK%\en-gb\lp.cab"
    rem for %%P in (EnhancedStorage Scripting SecureStartup Setup-Server SRT WDS-Tools WMI) do dism /Image:"%IMAGE%" /Add-Package /PackagePath:"%WORK%\en-gb\WinPE-%%P_en-gb.cab"
    dism /Image:"%IMAGE%" /Add-Package /PackagePath:"%WORK%\en-gb\lp.cab" /PackagePath:"%WORK%\en-gb\WinPE-EnhancedStorage_en-gb.cab" /PackagePath:"%WORK%\en-gb\WinPE-Scripting_en-gb.cab" /PackagePath:"%WORK%\en-gb\WinPE-SecureStartup_en-gb.cab" /PackagePath:"%WORK%\en-gb\WinPE-Setup-Server_en-gb.cab" /PackagePath:"%WORK%\en-gb\WinPE-SRT_en-gb.cab" /PackagePath:"%WORK%\en-gb\WinPE-WDS-Tools_en-gb.cab" /PackagePath:"%WORK%\en-gb\WinPE-WMI_en-gb.cab" /ScratchDir:"%WORK%\Temp"
    dism /Image:"%IMAGE%" /Distribution:"%WORK%\DVD" /Gen-LangINI
    copy /y "%WORK%\DVD\sources\lang.ini" "%WORK%\Mount\sources\"
    dism /Image:"%IMAGE%" /Set-AllIntl:en-GB
    dism /Image:"%IMAGE%" /Set-SetupUILang:en-GB /Distribution:"%WORK%\DVD"
    dism /Image:"%IMAGE%" /Set-TimeZone:"GMT Standard Time"
  )
  dism /Unmount-Image /MountDir:"%IMAGE%" /Commit
)

rem If install.wim is compressed, extract it. Assume that Professional edition is Index 1
if exist "%WORK%\DVD\sources\install.esd" (
  rem In order to decompress the .esd, it needs to be written into a normal wim
  dism /Capture-Image /ImageFile:"%WORK%\DVD\sources\install.wim" /CaptureDir:"%IMAGE%" /Compress:max /Name:EmptyIndex
  rem It's not entirely clear why /Compress:recovery has to be specified here (but it does!)
  dism /Export-Image /SourceImageFile:"%WORK%\DVD\sources\install.esd" /SourceIndex:1 /DestinationImageFile:"%WORK%\DVD\sources\install.wim" /Compress:recovery
  del "%WORK%\DVD\sources\install.esd"
  rem Remove the blank first entry
  dism /Delete-Image /ImageFile:"%WORK%\DVD\sources\install.wim" /Index:1
)

rem Update install.wim
rem @@DRA Should look up these indexes...
for /l %%I in (1,1,4) do (
  dism /Mount-Image /ImageFile:"%WORK%\DVD\sources\install.wim" /Index:%%I /MountDir:"%IMAGE%"
  rem Insert drivers
  rem dism /Image:"%IMAGE%" /Add-Driver /Driver:"%WORK%\Drivers" /Recurse /ForceUnsigned
  dism /Image:"%IMAGE%" /Add-Driver /Driver:"%WORK%\Drivers\efifw\efifw.inf" /Driver:"%WORK%\Drivers\mouse\vmmouse.inf" /Driver:"%WORK%\Drivers\mouse\vmusbmouse.inf" /Driver:"%WORK%\Drivers\pvscsi\pvscsi.inf" /Driver:"%WORK%\Drivers\video_wddm\vm3d.inf" /Driver:"%WORK%\Drivers\vmci\vmci.inf" /Driver:"%WORK%\Drivers\vmxnet3\vmxnet3.inf"
  dism /Image:"%IMAGE%" /Remove-Package /PackageName:"Microsoft-Windows-Server-LanguagePack-Package~31bf3856ad364e35~amd64~en-US~10.0.14393.0"
  rem Service Stack Updates
  rem dism /Image:"%IMAGE%" /Add-Package /PackagePath:"%WORK%\Updates\windows10.0-kb4132216-x64_9cbeb1024166bdeceff90cd564714e1dcd01296e.msu" /PackagePath:"%WORK%\Updates\windows10.0-kb4465659-x64_af8e00c5ba5117880cbc346278c7742a6efa6db1.msu" /ScratchDir:"%WORK%\Temp"
  rem Packages and updates
  dism /Image:"%IMAGE%" /Add-Package /PackagePath:"%WORK%\en-gb\x64fre_Server_en-gb_lp.cab" /PackagePath:"%WORK%\Updates\windows10.0-kb4091664-v6-x64_cb6f102b635f103e00988750ca129709212506d6.msu" /PackagePath:"%WORK%\Updates\windows10.0-kb4132216-x64_9cbeb1024166bdeceff90cd564714e1dcd01296e.msu" /PackagePath:"%WORK%\Updates\windows10.0-kb4465659-x64_af8e00c5ba5117880cbc346278c7742a6efa6db1.msu" /PackagePath:"%WORK%\Updates\windows10.0-kb4480961-x64_ada63f8d66b2c9994e03c3f5bffe56aff77edeb6.msu" /ScratchDir:"%WORK%\Temp"
  rem Insert updates
  rem @@DRA The ScratchDir should be parameterised and probably done everywhere (it's the cumulative update which is the problem)
  rem for %%f in (%WORK%\Updates\*.msu) do dism /Add-Package /Image:"%IMAGE%" /PackagePath:"%%f" /ScratchDir:"%WORK%\Temp"
  dism /Image:"%IMAGE%" /Set-AllIntl:en-GB
  rem Add .NET Framework 3.5 on-demand package
  rem @@@DRA Not doing this for now -- not sure why it was done in 2015 for the Windows 10 image
  rem dism /Image:"%IMAGE%" /Add-Package /PackagePath:"%WORK%\DVD\sources\sxs\microsoft-windows-netfx3-ondemand-package.cab"
  dism /Unmount-Image /MountDir:"%IMAGE%" /Commit
)

echo %TIME%

rem Drivers and updates will make install.wim too large for a DVD - (re)compress to install.esd
rem @@DRA Not doing this yet - don't know if it's needed (and updates not being installed)
rem dism /Export-Image /SourceImageFile:"%WORK%\DVD\sources\install.wim" /SourceIndex:1 /DestinationImageFile:"%WORK%\DVD\sources\install.esd" /Compress:recovery
rem del "%WORK%\DVD\sources\install.wim"

rem Add the Setup script (accepts the EULA and changes the San Policy to Online All)
findstr /v cpi "%WORK%\Autounattend-ESXi.xml" > "%WORK%\DVD\Autounattend.xml"

rem Create the .iso
oscdimg -lSSS_X64FREV_EN-US_DV9 -m -o -u2 -udfver102 -bootdata:"2#p0,e,b%WORK%\DVD\boot\etfsboot.com#pEF,e,b%WORK%\DVD\efi\microsoft\boot\efisys.bin" "%WORK%\DVD" "%WORK%\%ISO_FILE%"

echo %WORK% may be deleted; %ISO_FILE% has been written.

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
echo %WORK% - please delete them first.
goto :EOF

:: :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: ::
:: Redistribution and use in source and binary forms, with or without modification, are permitted ::
:: provided that the following conditions are met:                                                ::
::     1. Redistributions of source code must retain the above copyright notice, this list of     ::
::        conditions and the following disclaimer.                                                ::
::     2. Redistributions in binary form must reproduce the above copyright notice, this list of  ::
::        conditions and the following disclaimer in the documentation and/or other materials     ::
::        provided with the distribution.                                                         ::
::     3. Neither the name of MetaStack Solutions Ltd. nor the names of its contributors may be   ::
::        used to endorse or promote products derived from this software without specific prior   ::
::        written permission.                                                                     ::
::                                                                                                ::
:: This software is provided by the Copyright Holder 'as is' and any express or implied           ::
:: warranties, including, but not limited to, the implied warranties of merchantability and       ::
:: fitness for a particular purpose are disclaimed. In no event shall the Copyright Holder be     ::
:: liable for any direct, indirect, incidental, special, exemplary, or consequential damages      ::
:: (including, but not limited to, procurement of substitute goods or services; loss of use,      ::
:: data, or profits; or business interruption) however caused and on any theory of liability,     ::
:: whether in contract, strict liability, or tort (including negligence or otherwise) arising in  ::
:: any way out of the use of this software, even if advised of the possibility of such damage.    ::
:: :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: ::
