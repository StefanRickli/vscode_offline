
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$Directory = .\pick_version.ps1 -ParentPath (Resolve-Path ".") -Take 5 -SortBy LastWriteTime
Push-Location $Directory

try {
    $Version = (Get-Content "version.txt").Trim()
    $Installer = Get-ChildItem "VSCodeUserSetup-x64-${Version}.exe"

    Write-Output "Installing VS Code in the user environment"
    Start-Process $Installer.FullName -ArgumentList "/TASKS=addcontextmenufiles,addcontextmenufolders,addtopath /SILENT" -Wait

    Write-Output "Merging mandatory set of VS Code settings into current settings"
    try {
        $MandatorySettings = Get-Content "${PSScriptRoot}\mandatory_settings.json" | ConvertFrom-Json
    }
    catch {
        throw
    }
    $CurrentSettingsDir = Join-Path "$Env:AppData" "Code\User"
    $CurrentSettingsPath = Join-Path "$CurrentSettingsDir" "\settings.json"
    if (-not (Test-Path $CurrentSettingsPath)) {
        $null = New-Item "$CurrentSettingsDir" -ItemType Directory -Force
    }
    try {
        $CurrentSettings = Get-Content "$CurrentSettingsPath" | ConvertFrom-Json
    } catch [System.Management.Automation.ItemNotFoundException] {
        $CurrentSettings = @{}
    } catch {
        throw
    }

    $MandatorySettings.PSObject.Properties | ForEach-Object {
        $CurrentSettings | Add-Member -MemberType NoteProperty -Name $_.Name -Value $_.Value -Force
    }

    $CurrentSettings | ConvertTo-Json | Out-File $CurrentSettingsPath -Encoding utf8

    Write-Output "Done."

    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}
finally {
    Pop-Location
}
