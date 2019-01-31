:: :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: ::
:: Copyright (c) 2019 MetaStack Solutions Ltd. See distribution terms at the end of this file.    ::
:: David Allsopp. 6-Jan-2019                                                                      ::
:: :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: ::
@rem Forked from Assemble.cmd ("temporary" script)
@setlocal
@echo off

:: Set this to be non-empty to leave Windows Defender enabled during the process.
set LEAVE_DEFENDER=

rem Must be run elevated
whoami /groups | find "S-1-16-12288" > nul
if errorlevel 1 goto ADK

rem Must be run from ADK prompt
if "%DandIRoot%" equ "" goto ADK

rem @@DRA At this point - need to get a working drivers tree from the other script for the correct version of ESXi and need Server 2016 ISO in place

set WORK=D:\Working

if "%1" equ "/job" goto Job_%2

if "%1" equ "" goto ISO
if not exist "%1\sources\boot.wim" goto ISO
set FOUND=0
if exist %1\sources\install.esd set FOUND=1
if exist %1\sources\install.wim set FOUND=1

:: if exist doesn't support quotes for directory testing...
pushd "%WORK%\Temp" && popd || md "%WORK%\Temp"
set ISO_FILE=SW_DVD9_Win_Server_STD_CORE_2016_64Bit_English_-4_DC_STD_MLF_X21-70526-ESXi-10.3.5-10430147-KB4480977.iso
if %FOUND% equ 0 goto ISO
if "%~dp0" neq "%CD%\" goto Working
for %%f in (%WORK%\DVD\nul %WORK%\install.esd %WORK%\%ISO_FILE%) do if exist %%f goto Clear

:: This errors if Windows Defender is disabled
for /f "delims=" %%D in ('powershell -Command "(Get-MpComputerStatus).AntivirusEnabled"') do set DEFENDER=%%D
if "%DEFENDER%" equ " " goto Continue
for /f "delims=" %%D in ('powershell -Command "(Get-MpPreference).DisableRealtimeMonitoring"') do set DEFENDER=%%D
if "%LEAVE_DEFENDER%" equ "" goto Continue
if "%DEFENDER%" equ "True" goto Continue
pushd "%WORK%"
set XD='%CD%'
:: This will result in either True (%WORK% included in exclusions), False (%WORK% not included in
:: exclusions), or empty (no exclusions defined)
for /f "delims=" %%D in ('powershell -Command "(Get-MpPreference).ExclusionPath.Contains(%XD%)"') do set DEFENDER_EXCLUSION=%%D
popd
if "%DEFENDER_EXCLUSION%" equ "True" (
  echo Warning - Windows Defender is running
  echo This is likely to result in a 3-5%% performance hit
) else (
  echo Warning - Windows Defender is running and %WORK% is not excluded
  echo This is likely to result in a 30-35%% performance hit
)
echo You can either manually disable Windows Defender, or set LEAVE_DEFENDER=
echo in this script.
set DEFENDER=
timeout /t 5
:Continue
if "%DEFENDER%" equ "False" powershell -Command "Set-MpPreference -DisableRealtimeMonitoring $true"

rem Duplicate the DVD
robocopy "%~dp0ESXi-10.3.5-10430147\ " "%WORK%\Drivers\ " /mir
robocopy "%~dp0Updates-ESXi\ " "%WORK%\Updates\ " /mir
robocopy "%~dp0en-gb\ " "%WORK%\en-gb\ " /mir
robocopy %1 %WORK%\DVD\ /mir /dcopy:T /a-:R
copy /y "%~dp0Autounattend-ESXi.xml" "%WORK%\"

rem dism /Get-WimInfo /WimFile:{full-path} prints the index for both .wim and .esd files

rem Insert SATA driver into boot.wim
rem Assume that Microsoft Windows Setup (x64) is Index 2 of boot.wim (Microsoft Windows PE should be Index 1)
rem @@DRA Comments all wrong; also must ensure mount point is on a fixed disk, not a mapped drive
rem @@DRA This should be probed...
set BOOT_IMAGE_COUNT=2
for /l %%I in (1,1,%BOOT_IMAGE_COUNT%) do (
  call :Mount "%WORK%\DVD\sources\boot.wim" %%I "%WORK%\Mount-%%I"
)
echo %TIME% Mounting boot images done
set /a T=%BOOT_IMAGE_COUNT%-1
for /l %%I in (1,1,%T%) do start /b cmd /d /c "%0" /job Boot %%I

call :InjectBootDrivers %BOOT_IMAGE_COUNT%
set IMAGE=%WORK%\Mount-%BOOT_IMAGE_COUNT%
rem Only doing this in Index 2 in case there are other .cabs which should be installed to Image 1
echo %TIME% Removing en-US packages from Boot Image 2
dism /Quiet /Image:"%IMAGE%" /Remove-Package ^
     /PackageName:"Microsoft-Windows-WinPE-LanguagePack-Package~31bf3856ad364e35~amd64~en-US~10.0.14393.0" ^
     /PackageName:"WinPE-EnhancedStorage-Package~31bf3856ad364e35~amd64~en-US~10.0.14393.0" ^
     /PackageName:"WinPE-Scripting-Package~31bf3856ad364e35~amd64~en-US~10.0.14393.0" ^
     /PackageName:"WinPE-SecureStartup-Package~31bf3856ad364e35~amd64~en-US~10.0.14393.0" ^
     /PackageName:"WinPE-Setup-Package~31bf3856ad364e35~amd64~en-US~10.0.14393.0" ^
     /PackageName:"WinPE-Setup-Server-Package~31bf3856ad364e35~amd64~en-US~10.0.14393.0" ^
     /PackageName:"WinPE-SRT-Package~31bf3856ad364e35~amd64~en-US~10.0.14393.0" ^
     /PackageName:"WinPE-WDS-Tools-Package~31bf3856ad364e35~amd64~en-US~10.0.14393.0" ^
     /PackageName:"WinPE-WMI-Package~31bf3856ad364e35~amd64~en-US~10.0.14393.0"
rem @@DRA The cabinet files contain .mum files which will include the names of packages which are available - this would allow
rem       us to detect all the en-gb packages and swap them for en-US
echo %TIME% Adding en-GB packages to Boot Image 2
dism /Quiet /Image:"%IMAGE%" /Add-Package /ScratchDir:"%WORK%\Temp" ^
     /PackagePath:"%WORK%\en-gb\lp.cab" ^
     /PackagePath:"%WORK%\en-gb\WinPE-EnhancedStorage_en-gb.cab" ^
     /PackagePath:"%WORK%\en-gb\WinPE-Scripting_en-gb.cab" ^
     /PackagePath:"%WORK%\en-gb\WinPE-SecureStartup_en-gb.cab" ^
     /PackagePath:"%WORK%\en-gb\WinPE-Setup-Server_en-gb.cab" ^
     /PackagePath:"%WORK%\en-gb\WinPE-SRT_en-gb.cab" ^
     /PackagePath:"%WORK%\en-gb\WinPE-WDS-Tools_en-gb.cab" ^
     /PackagePath:"%WORK%\en-gb\WinPE-WMI_en-gb.cab"
echo %TIME% Regenerating lang.ini
dism /Quiet /Image:"%IMAGE%" /Distribution:"%WORK%\DVD" /Gen-LangINI
echo %TIME% Copying lang.ini to boot image
copy /y "%WORK%\DVD\sources\lang.ini" "%IMAGE%\sources\" >nul
echo %TIME% Setting locale to en-GB
dism /Quiet /Image:"%IMAGE%" /Set-AllIntl:en-GB
dism /Quiet /Image:"%IMAGE%" /Set-SetupUILang:en-GB /Distribution:"%WORK%\DVD"
echo %TIME% Setting Time Zone to GMT
dism /Quiet /Image:"%IMAGE%" /Set-TimeZone:"GMT Standard Time"

call :WaitJobs %T%

if "%DEFENDER%" equ "False" powershell -Command "Set-MpPreference -DisableRealtimeMonitoring $true"
for /l %%I in (1,1,%BOOT_IMAGE_COUNT%) do (
  call :Unmount "%WORK%\Mount-%%I"
)

move "%WORK%\DVD\sources\boot.wim" "%WORK%\Temp\bloated.wim" > nul
echo %TIME% Compacting boot.wim
for /l %%I IN (1,1,%BOOT_IMAGE_COUNT%) do dism /Quiet /Export-Image /SourceImageFile:"%WORK%\Temp\bloated.wim" /SourceIndex:%%I /DestinationImageFile:"%WORK%\DVD\sources\boot.wim"
del "%WORK%\Temp\bloated.wim"

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
set IMAGE_COUNT=4
set /a T=%IMAGE_COUNT%-1

for /l %%I in (1,1,%IMAGE_COUNT%) do (
  call :Mount "%WORK%\DVD\sources\install.wim" %%I "%WORK%\Mount-%%I"
)
echo %TIME% Mounting installation images done

for /l %%I in (1,1,%T%) do start /b cmd /d /c "%0" /job Image %%I
call :ProcessImage %IMAGE_COUNT%

call :WaitJobs %T%

if "%DEFENDER%" equ "False" powershell -Command "Set-MpPreference -DisableRealtimeMonitoring $true"
for /l %%I in (1,1,%IMAGE_COUNT%) do (
  call :Unmount "%WORK%\Mount-%%I"
)

move "%WORK%\DVD\sources\install.wim" "%WORK%\Temp\bloated.wim" > nul
echo %TIME% Compacting install.wim
for /l %%I IN (1,1,%IMAGE_COUNT%) do dism /Quiet /Export-Image /SourceImageFile:"%WORK%\Temp\bloated.wim" /SourceIndex:%%I /DestinationImageFile:"%WORK%\DVD\sources\install.wim"
del "%WORK%\Temp\bloated.wim"

rem Drivers and updates will make install.wim too large for a DVD - (re)compress to install.esd
rem @@DRA Not doing this yet - don't know if it's needed (and updates not being installed)
rem dism /Export-Image /SourceImageFile:"%WORK%\DVD\sources\install.wim" /SourceIndex:1 /DestinationImageFile:"%WORK%\DVD\sources\install.esd" /Compress:recovery
rem del "%WORK%\DVD\sources\install.wim"

rem Add the Setup script (accepts the EULA and changes the San Policy to Online All)
findstr /v cpi "%WORK%\Autounattend-ESXi.xml" > "%WORK%\DVD\Autounattend.xml"

echo %TIME% Generating new ISO
:: https://support.microsoft.com/en-gb/help/947024/how-to-create-an-iso-image-for-uefi-platforms-for-a-windows-pe-cd-rom
:: contains a full explanation of the call.
:: TL;DR no size limit; optimized; UDF 1.02 only; BIOS & EFI boot options
oscdimg -lSSS_X64FREV_EN-US_DV9 -m -o -u2 -udfver102 -bootdata:"2#p0,e,b%WORK%\DVD\boot\etfsboot.com#pEF,e,b%WORK%\DVD\efi\microsoft\boot\efisys.bin" "%WORK%\DVD" "%WORK%\%ISO_FILE%"

if "%DEFENDER%" equ "False" powershell -Command "Set-MpPreference -DisableRealtimeMonitoring $false"

echo %TIME% %WORK% may be deleted; %ISO_FILE% has been written.

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

:InjectBootDrivers
echo %TIME% Injecting boot drivers into %WORK%\Mount-%1
dism /Quiet /Image:"%WORK%\Mount-%1" /Add-Driver ^
     /Driver:"%WORK%\Drivers\pvscsi\pvscsi.inf" ^
     /Driver:"%WORK%\Drivers\vmxnet3\Win8\vmxnet3.inf"
goto :EOF

:Job_Boot
call :InjectBootDrivers %3
echo Done>Job-Done-%3
goto :EOF

:WaitJobs
for /l %%I in (1,1,%1) do (
  call :WaitJob %%I
  del Job-Done-%%I
)
goto :EOF

:WaitJob
:Loop
if exist Job-Done-%1 goto :EOF
timeout /nobreak /t 1 > nul
goto Loop

:Job_Image
call :ProcessImage %3
echo Done>Job-Done-%3
goto :EOF

:ProcessImage
set IMAGE=%WORK%\Mount-%1
echo %TIME% Injecting drivers into Install image %1
dism /Quiet /Image:"%IMAGE%" /Add-Driver ^
     /Driver:"%WORK%\Drivers\efifw\efifw.inf" ^
     /Driver:"%WORK%\Drivers\mouse\vmmouse.inf" ^
     /Driver:"%WORK%\Drivers\mouse\vmusbmouse.inf" ^
     /Driver:"%WORK%\Drivers\pvscsi\pvscsi.inf" ^
     /Driver:"%WORK%\Drivers\video_wddm\vm3d.inf" ^
     /Driver:"%WORK%\Drivers\vmci\device\Win8\vmci.inf" ^
     /Driver:"%WORK%\Drivers\vmxnet3\Win8\vmxnet3.inf"
echo %TIME% Removing en-US from Install image %1
dism /Quiet /Image:"%IMAGE%" /Remove-Package ^
     /PackageName:"Microsoft-Windows-Server-LanguagePack-Package~31bf3856ad364e35~amd64~en-US~10.0.14393.0" ^
     /PackageName:"Microsoft-Windows-LanguageFeatures-Handwriting-en-us-Package~31bf3856ad364e35~amd64~~10.0.14393.0" ^
     /PackageName:"Microsoft-Windows-LanguageFeatures-OCR-en-us-Package~31bf3856ad364e35~amd64~~10.0.14393.0" ^
     /PackageName:"Microsoft-Windows-LanguageFeatures-Speech-en-us-Package~31bf3856ad364e35~amd64~~10.0.14393.0" ^
     /PackageName:"Microsoft-Windows-LanguageFeatures-TextToSpeech-en-us-Package~31bf3856ad364e35~amd64~~10.0.14393.0"
echo %TIME% Removing all non-GB LanguageFeatures-Basic packages from Install image %1
setlocal enabledelayedexpansion
set DISM=dism /Quiet /Image:"%IMAGE%" /Remove-Package
for /f "tokens=4" %%P in ('dism /Image:"%IMAGE%" /Get-Packages ^| findstr /R /C:"Package Identity : Microsoft-Windows-LanguageFeatures-Basic-"') do (
  for /f "tokens=5,6 delims=-" %%L in ('echo %%P') do (
    if "%%L-%%M" neq "en-gb" set DISM=!DISM! /PackageName:"%%P"
  )
)
%DISM%
endlocal
rem Add .NET Framework 3.5 on-demand package
rem @@@DRA Not doing this for now -- not sure why it was done in 2015 for the Windows 10 image
rem        If this is restored, it must go before the updates!
rem dism /Image:"%IMAGE%" /Add-Package /PackagePath:"%WORK%\DVD\sources\sxs\microsoft-windows-netfx3-ondemand-package.cab"
:: Order matters! Add:
::   - language pack (from Server 2016 Language Pack ISO)
::   - language Features on Demand (FOD - from Windows 10 LTSB 2016 FOD ISO - i.e. Windows 10 1607)
::       Note that if these are not added offline then they will be added automatically by Windows
::       Update and the cumulative update will need re-applying
::   - Service Stack Updates
::       At present, KB4132216 (17 May 2018) and KB4465659 (13 Nov 2018)
::       Note that although KB4465659 replaces KB4132216, it's not a cumulative update
::       These updates must be applied before any other updates
::   - Miscellaneous updates
::       Intel Microcode Update KB4091664 v6
::   - Latest Cumulative Update
echo %TIME% Adding en-GB and updates to Install image %1
dism /Quiet /Image:"%IMAGE%" /Add-Package /ScratchDir:"%WORK%\Temp" ^
     /PackagePath:"%WORK%\en-gb\x64fre_Server_en-gb_lp.cab" ^
     /PackagePath:"%WORK%\en-gb\Microsoft-Windows-LanguageFeatures-OCR-en-gb-Package.cab" ^
     /PackagePath:"%WORK%\en-gb\Microsoft-Windows-LanguageFeatures-Handwriting-en-gb-Package.cab" ^
     /PackagePath:"%WORK%\en-gb\Microsoft-Windows-LanguageFeatures-Speech-en-gb-Package.cab" ^
     /PackagePath:"%WORK%\en-gb\Microsoft-Windows-LanguageFeatures-TextToSpeech-en-gb-Package.cab" ^
     /PackagePath:"%WORK%\Updates\windows10.0-kb4132216-x64_9cbeb1024166bdeceff90cd564714e1dcd01296e.msu" ^
     /PackagePath:"%WORK%\Updates\windows10.0-kb4465659-x64_af8e00c5ba5117880cbc346278c7742a6efa6db1.msu" ^
     /PackagePath:"%WORK%\Updates\windows10.0-kb4091664-v6-x64_cb6f102b635f103e00988750ca129709212506d6.msu" ^
     /PackagePath:"%WORK%\Updates\windows10.0-kb4480977-x64_4630376d446938345665e2ce8379d96bb63a84c8.msu"
echo %TIME% Setting locale to en-GB in Install image %1
dism /Quiet /Image:"%IMAGE%" /Set-AllIntl:en-GB
echo %TIME% Copying KB890830 v5.68 to system root of Install image %1
copy "%WORK%\Updates\Windows-KB890830-x64-V5.68.exe" "%IMAGE%\" > nul
echo %TIME% Rebasing Install image %1
dism /Quiet /Image:"%IMAGE%" /Cleanup-Image /StartComponentCleanup /ResetBase
goto :EOF

:Mount
if not exist %3 md %3
echo %TIME% Mounting %1 index %2 in %3
dism /Quiet /Mount-Image /ImageFile:%1 /Index:%2 /MountDir:%3
goto :EOF

:Unmount
echo %TIME% Unmounting %1
dism /Quiet /Unmount-Image /MountDir:%1 /Commit
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
