# Help
#############################################################################

<#
.SYNOPSIS
Script for enabling powershell to run MVS 2010 commands.

.DESCRIPTION


.PARAMETER

.INPUTS
None. You cannot pipe to this script.

.OUTPUTS
None. This script does not generate any output.

.NOTES
AUTHOR: Janne Beate Bakeng, SINTEF
DATE: 17.04.2012

 Requirements:
 - Microsoft Visual Studio 2010
 - Powershell

.EXAMPLE
C:\PS> EnableMVSEnvironment.ps1

#>




# Functions
#############################################################################
Function EnableMVSEnvironment () {
    #Set environment variables for Visual Studio Command Prompt
    pushd 'c:\Program Files (x86)\Microsoft Visual Studio 10.0\VC'
    cmd /c "vcvarsall.bat&set" |
    foreach {
      if ($_ -match "=") {
        $v = $_.split("="); set-item -force -path "ENV:\$($v[0])"  -value "$($v[1])"
      }
    }
    popd
    write-host "`nVisual Studio 2010 Command Prompt variables set." -ForegroundColor Yellow
}