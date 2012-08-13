# Help
#############################################################################

<#
.SYNOPSIS
Script that prepares a Windows machine for software development.

.DESCRIPTION
Downloads and installs:
-git
-svn
-cmake
-python

.PARAMETER 
None.

.INPUTS
None. You cannot pipe to this script.

.OUTPUTS
None. This script does not generate any output.

.NOTES
AUTHOR: Janne Beate Bakeng, SINTEF
DATE: 21.05.2012

.EXAMPLE
PS C:\> .GetTools.ps1

.TODO
-add vcvars64.bat to powershell profile???
-add icons to shortcuts
-add options:
  --normal/-n = git, svn, cmake, python
  --git/-g = git
  --svn/-s = svn
  --cmake/-c = cmake
  --python/-p = python
  --eclipse/-e = eclipse
  --qt/-q = qt
  (--mvs_express/-m = microsoft visual studio express)
#>
# Classes
#############################################################################

Add-Type @'
namespace GetTools{
    public class Tool{
        public Tool(
            string name, 
            string downloadUrl, 
            string saveAs, 
            string packageType, 
            string installedBinFolder, 
            string extractFolder, 
            string executableName 
            )
        {}
        
        public string get_name(){ return mName;}
        public string get_downloadUrl(){ return mDownloadUrl;}
        public string get_saveAs(){ return mSaveAs;}
        public string get_packageType(){ return mPackageType;}
        public string get_installedBinFolder(){ return mInstalledBinFolder;}
        
        private string mName; //name of the tool
        private string mDownloadUrl; //the url to the downloadable file
        private string mSaveAs; //what the downloaded file should be saved as
        private string mPackageType; //the download file type
        private string mInstalledBinFolder; //where the executable can be found after tool is installed
        private string mExecutableName; //name of the executable
        private string mExtractFolder; //if package type is extractable archive we need a extraction folder
    }
}
'@

# Functions
#############################################################################
Function Command-Exists ($tool) {
    #Qt, boost, CppUnit and 7-zip needs special handling
    if($tool -eq "7-Zip") #ok
        {$tool = "7z"}
    elseif($tool -eq "qt") #Qt not added to path?
        {$tool = "qmake"} #won't work
    elseif($tool -eq "boost")
        {$tool = "boost"} #no idea what to search for...
    elseif($tool -eq "CppUnit")
        {$tool = "cppunit"}#no idea what to search for...
    
    if (Get-Command $tool -errorAction SilentlyContinue)
    {
        Write-Host $tool " already exists" -ForegroundColor "green"
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
        {Write-Host "Downloaded " $tool "!" -ForegroundColor "Green"}
    else
        {Write-Host "Could not download " $tool ", you will have to do it manually!" -ForegroundColor "Red"}
        
    return $success
}

Function Download-Url ($tool, $url, $targetFile) {
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
        {Write-Host "Installed " $tool "!" -ForegroundColor "Green"}
    else
        {Write-Host "Could not install " $tool ", you will have to do it manually!" -ForegroundColor "Red"}
        
    return $success
}

Function Install-File ($tool, $targetFile, $packageType){

    Write-Host "Installing " $tool
    $defaultDesitantionFolder = 'C:\Program Files'
    
    $success = $false
    if($packageType -eq "NSIS package"){
        #piping to Out-Null seems to by-pass the UAC
        Start-Process $targetFile -ArgumentList "/S" -NoNewWindow -Wait | Out-Null
        $success = $true    
    }
    elseif($packageType -eq "Inno Setup package"){
        #piping to Out-Null seems to by-pass the UAC
        Start-Process $targetFile -ArgumentList "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-" -NoNewWindow -Wait | Out-Null
        $success = $true
    }
    elseif($packageType -eq "MSI"){
        Start-Process msiexec -ArgumentList "/i $targetFile /quiet /passive" -NoNewWindow -Wait
        $success = $true
    }
    elseif($packageType -eq "ZIP"){
        #TODO
        #always install zip-files in C:\Program Files\ for convenience
        $destinationFolder = (Get-Item $defaultDesitantionFolder).fullname
        $shell_app = new-object -com shell.application
        $zip_file = $shell_app.namespace($targetFile)
        $destination = $shell_app.namespace($destinationFolder)
        $destination.Copyhere($zip_file.items(),0x14) #0x4 hides dialogbox, 0x10 overwrites existing files, 0x14 combines both
        $success = $true
    }
    elseif($packageType -eq "TarGz"){
        $z ="7z.exe"

        #Destination folder cannot contain spaces for 7z to work with -o
        $destinationFolder = (Get-Item $defaultDesitantionFolder).fullname
         
        $targzSource = $targetFile
        & "$z" x -y $targzSource | Out-Null
        
        $tarSource = (Get-Item $targzSource).basename
        & "$z" x -y $tarSource "-o$destinationFolder" | Out-Null #Need to have double quotes around the -o parameter because of whitespaces in destination folder
   
        Remove-Item $tarSource
        
        $success = $true
    }
    else{
        Write-Host "Could not figure out which installer $tool has used, could not install $tool."
    }
    
    Write-Host "Installing done."
    
    return $success
}

# Adds a tools installed path to the system environment,
# both for this session and permanently
Function Add-To-Path($tool) {
    Write-Host "Adding $tool to system environment (Path)."

    $success = $false 
    
    for($i=0; $i -le $RequiredTools.Length -1;$i++){
        if($tool -eq $RequiredTools[$i][0])
        {
            $path = $RequiredTools[$i][4]
            Add-To-Path-Permanent($path)
            Add-To-Path-Session($path)
            $success = $true
            break
        }
    }
    
    if($success)
        {Write-Host "Added " $tool " to path!" -ForegroundColor "Green"}
    else
        {Write-Host "Could not add " $tool " to path, you will have to do it manually!" -ForegroundColor "Red"}
        
    return $success
}

# Adds a path to the environment for this session only
Function Add-To-Path-Session($path) {
    $env:path = $env:path + ";" + $path
}

# Adds a path permanently to the system environment
Function Add-To-Path-Permanent($path) {
    [System.Environment]::SetEnvironmentVariable("PATH", $Env:Path + ";" + $path, "Machine")
}

# Creates a shortcut to a batch file that run a tool with visual studio
# variables loaded.
Function Create-Batch-Exe-With-VCVars64($tool){
    #Will eclipse executed in 64 bit environment build 32 bit builds???

    if($tool -eq "cmake"){
        $tool = "cmake-gui"
    }
    
    #variables
    $batchName = "$tool-MSVC1064bit"
    $batchEnding = ".bat"
    $batchFolder = "$HOME\Batch_files"
    mkdir $batchFolder -force | Out-Null
    $batchPath = "$batchFolder\$batchName$batchEnding"
    $toolExe = (Get-Command $tool | Select-Object Name).Name
    $toolFolder = (Get-Item (Get-Command $tool | Select-Object Definition).Definition).directory.fullname
    $vcVarsFolder = ((Get-Item (Get-Command nmake).Definition).directory).GetDirectories("amd64")[0].fullname
    $vcVarsBat = "vcvars64.bat"
    $desktopFolder = "$HOME\Desktop\"
    $taskbarFolder = "$Home\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\Taskbar\"
    $shortcutFolder = $batchFolder
    
    #write content
    $stream = New-Object System.IO.StreamWriter("$batchPath")
    $stream.WriteLine("`@cd $vcVarsFolder")
    $stream.WriteLine("`@call $vcVarsBat > nul 2>&1")
    $stream.WriteLine("`@cd $toolFolder")
    $stream.WriteLine("`@start $toolExe > nul 2>&1")
    $stream.WriteLine("`@exit")
    $stream.Close()
    
    #create shortcut on taskbar
    $shortcutPath = "$shortcutFolder\$batchName.lnk"
    $objShell = New-Object -ComObject WScript.Shell
    $objShortCut = $objShell.CreateShortcut($shortcutPath)
    $objShortCut.TargetPath = 'cmd'
    $objShortCut.Arguments = "/c ""$batchPath"""
    $objShortCut.Save()
    
    Toggle-PinTo-Taskbar $shortcutPath
    
    return $true
}

# Un-/pins a file to the users taskbar
function Toggle-PinTo-Taskbar
{
  param([parameter(Mandatory = $true)]
        [string]$application)
 
  $al = $application.Length
  $appfolderpath = $application.SubString(0, $al - ($application.Split("\")[$application.Split("\").Count - 1].Length))
 
  $objshell = New-Object -ComObject "Shell.Application"
  $objfolder = $objshell.Namespace($appfolderpath)
  $appname = $objfolder.ParseName($application.SubString($al - ($application.Split("\")[$application.Split("\").Count - 1].Length)))
  $verbs = $appname.verbs()
 
  foreach ($verb in $verbs)
  {
    if ($verb.name -match "(&K)")
    {
      $verb.DoIt()
    }
  }
}

Function Configure-Git($name, $email){
    git config --global user.name $name
    git config --global user.email $email
    git config --global color.diff auto
    git config --global color.status auto
    git config --global color.branch auto
    git config --global core.autocrlf input
    git config --global core.filemode false #(ONLY FOR WINDOWS)
}

# Main
#############################################################################
Function main {

#Check that prerequirements are met
if(!(Command-Exists nmake)){
    Write-Host "You need to have Microsoft Visual Studio 2010 installed before running this script." -ForegroundColor Red
    return "error"
}

#Gather user input
Write-Host "Need some information to be able to setup git:" -ForegroundColor DarkYellow
$name = Read-Host "Your name"
$email = Read-Host "Your email address"

#Information 
#--------------
$ToolFolder = "$HOME\Desktop\DownloadedTools"
mkdir $ToolFolder -force | Out-Null

#Required tools
$7zip = New-Object GetTools.Tool("7-Zip", "http://downloads.sourceforge.net/sevenzip/7z920-x64.msi", "$ToolFolder\7-Zip-installer.msi", "MSI", "C:\Program Files\7-Zip", "", "");
$CppUnit = New-Object GetTools.Tool("CppUnit", "http://sourceforge.net/projects/cppunit/files/cppunit/1.12.1/cppunit-1.12.1.tar.gz/download", "$ToolFolder\CppUnit.tar.gz", "TarGz", "C:\Program Files\cppunit-1.12.1", "", "");
$jom = New-Object GetTools.Tool("jom", "ftp://ftp.qt.nokia.com/jom/jom.zip", "$ToolFolder\jom.zip", "ZIP", "C:\Program Files", "", "");
$git = New-Object GetTools.Tool("git", "http://msysgit.googlecode.com/files/Git-1.7.10-preview20120409.exe", "$ToolFolder\git-installer.exe", "Inno Setup package", "C:\Program Files (x86)\Git\cmd", "", "");
$svn = New-Object GetTools.Tool("svn", "http://www.sliksvn.com/pub/Slik-Subversion-1.7.5-x64.msi", "$ToolFolder\svn-installer.msi", "MSI", "C:\Program Files\SlikSvn\bin", "", "");
$cmake = New-Object GetTools.Tool("cmake", "http://www.cmake.org/files/v2.8/cmake-2.8.8-win32-x86.exe", "$ToolFolder\cmake-installer.exe", "NSIS package", "C:\Program Files (x86)\CMake 2.8\bin", "", "");
$python = New-Object GetTools.Tool("python", "http://www.python.org/ftp/python/2.7.3/python-2.7.3.msi", "$ToolFolder\python-installer.msi", "MSI", "C:\Python27", "", "");
$eclipse = New-Object GetTools.Tool("eclipse", "http://eclipse.mirror.kangaroot.net/technology/epp/downloads/release/indigo/SR2/eclipse-cpp-indigo-SR2-incubation-win32-x86_64.zip", "$ToolFolder\eclipse.zip", "ZIP", "C:\Program Files\eclipse", "", "");
$qt = New-Object GetTools.Tool("qt", "ftp://ftp.qt.nokia.com/qt/source/qt-win-opensource-4.8.1-vs2010.exe", "$ToolFolder\qt.exe", "NSIS package", "C:\Qt\4.8.1\bin", "", "");
$boost = New-Object GetTools.Tool("boost", "http://downloads.sourceforge.net/project/boost/boost/1.49.0/boost_1_49_0.zip?r=&ts=1340279004&use_mirror=dfn", "$ToolFolder\boost.zip", "ZIP", "C:\Program Files\boost_1_49_0", "", "");

#TODO
# add tools to array according to input parameters
$SelectedTools = @($7zip, $CppUnit, $jom, $git, $svn, $cmake, $python, $eclipse, $qt, $boost)

$RequiredTools = @(
                #(tool name, download link, target file, package type, installed bin folder )
                # 7-zip 9.2 (64bit)
                ("7-Zip", "http://downloads.sourceforge.net/sevenzip/7z920-x64.msi", "$ToolFolder\7-Zip-installer.msi", "MSI", "C:\Program Files\7-Zip"),
                # CppUnit 1.12.1
                ("CppUnit", "http://sourceforge.net/projects/cppunit/files/cppunit/1.12.1/cppunit-1.12.1.tar.gz/download", "$ToolFolder\CppUnit.tar.gz", "TarGz", "C:\Program Files\cppunit-1.12.1"),
                # Jom 1.0.11
                ("jom", "ftp://ftp.qt.nokia.com/jom/jom.zip", "$ToolFolder\jom.zip", "ZIP", "C:\Program Files"),
                # git 1.7.10
                ("git", "http://msysgit.googlecode.com/files/Git-1.7.10-preview20120409.exe", "$ToolFolder\git-installer.exe", "Inno Setup package", "C:\Program Files (x86)\Git\cmd"),
                # svn 1.7.5
                ("svn", "http://www.sliksvn.com/pub/Slik-Subversion-1.7.5-x64.msi", "$ToolFolder\svn-installer.msi", "MSI", "C:\Program Files\SlikSvn\bin"),
                # CMake 2.8.8
                ("cmake", "http://www.cmake.org/files/v2.8/cmake-2.8.8-win32-x86.exe", "$ToolFolder\cmake-installer.exe", "NSIS package", "C:\Program Files (x86)\CMake 2.8\bin"),
                # Python 2.7.3
                ("python", "http://www.python.org/ftp/python/2.7.3/python-2.7.3.msi", "$ToolFolder\python-installer.msi", "MSI", "C:\Python27"),
                # Eclipse Indigo (3.7.0) for C/C++ Developers
                ("eclipse", "http://eclipse.mirror.kangaroot.net/technology/epp/downloads/release/indigo/SR2/eclipse-cpp-indigo-SR2-incubation-win32-x86_64.zip", "$ToolFolder\eclipse.zip", "ZIP", "C:\Program Files\eclipse"),
                # Qt 4.7.2 - do we need this version? nope
                #("qt", "ftp://ftp.qt.nokia.com/qt/source/qt-everywhere-opensource-src-4.7.2.zip", "$ToolFolder\qt.zip", "ZIP", "C:\Program Files\Qt"),
                # Qt 4.8.1
                ("qt", "ftp://ftp.qt.nokia.com/qt/source/qt-win-opensource-4.8.1-vs2010.exe", "$ToolFolder\qt.exe", "NSIS package", "C:\Qt\4.8.1\bin"),
                # Boost 1.49.0
                ("boost", "http://downloads.sourceforge.net/project/boost/boost/1.49.0/boost_1_49_0.zip?r=&ts=1340279004&use_mirror=dfn", "$ToolFolder\boost.zip", "ZIP", "C:\Program Files\boost_1_49_0")
                )
                
#Download and install tools
for($i=0; $i -le $RequiredTools.Length -1;$i++)
{
    $tool = $RequiredTools[$i][0]
    
    if(Command-Exists $tool)
        {continue}
        
    Write-Host "Missing tool "$tool
    if(!(Download $tool))
        {continue}
    if(!(Install $tool))
        {continue}
    if(!(Add-To-Path $tool))
        {continue}
    
    if($tool -eq "git"){
        Configure-Git $name $email
    }
    
    if(($tool -eq "cmake") -or ($tool -eq "eclipse")){
        if(!(Create-Batch-Exe-With-VCVars64 $tool)){
            Write-Host "Could not create shortcut and batch file for $tool"
        }
    }
}
}