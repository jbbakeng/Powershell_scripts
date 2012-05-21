# Help
#############################################################################

<#
.SYNOPSIS


.DESCRIPTION
Downloads and installs:
-git
-svn
-cmake
-python

...and makes them available from ????

.PARAMETER SourcePath

.INPUTS
None. You cannot pipe to this script.

.OUTPUTS
None. This script does not generate any output.

.NOTES
AUTHOR: Janne Beate Bakeng, SINTEF
DATE: 21.05.2012

TODO:


.EXAMPLE
PS C:\Dev\Temp> ..\Powershell\PrepareConsoleEnvironment.ps1
#>


# Parameters
#############################################################################
#Param(
#    [Parameter(Mandatory=$true, position=0, HelpMessage="Specify if this should be a 64 bit build.")]
#    [alias('b64')]
#    [bool]$Bits64=$true
#    )
  

# Input check
#############################################################################


# Include
#############################################################################
#. C:\Dev\Powershell\Invoke-BatchFile.ps1


# Functions
#############################################################################
Function Command-Exists ($cmdName) {
    if (Get-Command $cmdName -errorAction SilentlyContinue)
    {
        Write-Host $cmdName " already exists" -ForegroundColor "green"
        return $true
    }
}

Function Download ($tool) { 

    $success = $false  
    
    for($i=0; $i -le $RequiredTools.Length -1;$i++){
        if($tool -eq $RequiredTools[$i][0])
        {
            $success = Download-Url $RequiredTools[$i][0] $RequiredTools[$i][1] $RequiredTools[$i][2]
        }
    }
    
    if($success)
        {Write-Host "Downloaded " $tool " successfully!" -ForegroundColor "Green"}
    else
        {Write-Host "Could not download " $tool ", you will have to do it manually!" -ForegroundColor "Red"}
        
    return $success
}

Function Download-Url ($tool, $url, $targetFile) {
    #Write-Host "Downloading " $tool " from " $url " to " $targetFile -ForegroundColor "Gray"

    $success = $false
    try{
        Write-Host "Downloading " $tool
        $webclient = New-Object Net.WebClient
        $webclient.DownloadFile($url, $targetFile)
        Write-Host "Download done."
        $success = $true
    }
    catch
    {
        Write-Host "Exception caught when trying to download " $tool " from " $url " to " $targetFile "." -ForegroundColor "Red"
    }
    finally
    {
        return $success
    }
}

Function Install ($tool){
    $success = $false 
    
    for($i=0; $i -le $RequiredTools.Length -1;$i++){
        if($tool -eq $RequiredTools[$i][0])
        {
            $success = Install-File $RequiredTools[$i][0] $RequiredTools[$i][2] $RequiredTools[$i][3]
        }
    }
    
    if($success)
        {Write-Host "Installed " $tool " successfully!" -ForegroundColor "Green"}
    else
        {Write-Host "Could not install " $tool ", you will have to do it manually!" -ForegroundColor "Red"}
        
    return $success
}

Function Install-File ($tool, $targetFile, $packageType){

if($packageType -eq "NSIS package"){
    #$targetFile /S
}
if($packageType -eq "Inno Setup package"){
    #$targetFile  /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-
}

}

# Main
#############################################################################
clear

$ToolFolder = "$HOME\Desktop\DownloadedTools\"
mkdir $ToolFolder -force
$RequiredTools = @(
                #(tool name, download link, target file, package type )
                #("nmake", "", "", "??"),
                ("git", "http://msysgit.googlecode.com/files/Git-1.7.10-preview20120409.exe", "$ToolFolder\git-installer.exe", "Inno Setup package"),
                ("cmake", "http://www.cmake.org/files/v2.8/cmake-2.8.8-win32-x86.exe", "$ToolFolder\cmake-installer.exe", "NSIS package")
                #("python", "", "$ToolFolder\Desktop\python-installer.exe", "??"), #check...
                )


#Download (and install?) tools
for($i=0; $i -le $RequiredTools.Length -1;$i++)
{
    $cmdName = $RequiredTools[$i][0]
    
    #if(Command-Exists $cmdName)
        #{continue}
        
    Write-Host "Missing tool: "$cmdName
    if(!(Download $cmdName))
    {continue}
    if(!(Install $cmdName))
    {continue}
}
