param (
    [Parameter(Mandatory = $true)] [string] $TargetHost,
    [Parameter(Mandatory = $false)] [string] $Directory = $null
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

try {
    $null = [System.Net.Dns]::GetHostAddresses("$TargetHost")
}
catch {
    Write-Error "$TargetHost could not be resolved. Typo?"
    Exit 1
}

# About Passwords for SSH:
# Seems like there is no way to give the vanilla SCP and SSH the password.
# Posh-SSH could do it but we want to avoid 3rd party software whenever possible.
# So, unfortunately, we need to pass the password for each invocation of SCP and SSH
# for the time being. (At least as long as we rely on password-based login methods.)

if ("" -eq $Directory) {
    $Directory = .\pick_version.ps1 -ParentPath "." -Take 5 -SortBy LastWriteTime
}
Push-Location $Directory

try {
    $Version = (Get-Content "version.txt").Trim()
    $Commit = (Get-Content "commit.txt").Trim()
    $RemoteTempDir = "/tmp/vscode-${Version}"
    $RemoteInstallScriptPath = ".\remote_scripts\install_vscode_server.sh"

    $PostInstallScripts = @()
    if (Test-Path "remote_post_install_scripts.json") {
        $PostInstallScriptsList = ((Get-Content "remote_post_install_scripts.json") | ConvertFrom-Json).PSObject.Properties["$TargetHost"].Value
        if (-not ($null -eq $PostInstallScriptsList)) {
            $PostInstallScripts = $PostInstallScriptsList | ForEach-Object { Get-ChildItem ".\remote_scripts\post_install\$($_)" }
        }
    }

    $ArchiveName = "vscode-server-${Version}-${TargetHost}"
    $VSCodeServerArchive = (Get-ChildItem ".\vscode-server-linux-x64-${Version}.tar.gz")[0].Name
    $FileList = @("$VSCodeServerArchive") + $RemoteInstallScriptPath + $PostInstallScripts.FullName

    Remove-Item -Force -ErrorAction Ignore @(".\${ArchiveName}.tar", ".\${ArchiveName}.tar.gz")

    Write-Output "Packing necessary files into '${ArchiveName}.tar.gz'"
    $dummy = & "C:\Program Files\7-Zip\7z.exe" a -ttar ".\${ArchiveName}.tar" $FileList
    $dummy = & "C:\Program Files\7-Zip\7z.exe" a -tgzip ".\${ArchiveName}.tar.gz" ".\${ArchiveName}.tar"

    $UserName = ($Env:UserName).ToUpper()
    $TargetUserHome = "/home/${UserName}"

    Write-Output "Uploading Files to ${TargetHost}..."
    scp -q ".\${ArchiveName}.tar.gz" "${UserName}@${TargetHost}:${TargetUserHome}/${VSCodeServerArchive}"
    Write-Output "Unpacking and installing on ${TargetHost}..."

    $TargetBinDir = "${TargetUserHome}/.vscode-server/bin/${Commit}"

    $RemoteBootstrap = @"
echo "Unpacking files into '${RemoteTempDir}' ..."
mkdir -p "${RemoteTempDir}" || exit 1
tar xf "${TargetUserHome}/${VSCodeServerArchive}" -C "${RemoteTempDir}" || exit 1

echo "Running vscode-server install script..."
chmod +x "${RemoteTempDir}/install_vscode_server.sh" || exit 1
"${RemoteTempDir}/install_vscode_server.sh" "${RemoteTempDir}" "${VSCodeServerArchive}" "${TargetBinDir}" || exit 1

echo "VS Code Server ${Version} installation successful."
"@ -replace "`r", ""

    $RemoteBootstrap | ssh "$UserName@$TargetHost" "bash -s"

}
finally {
    Pop-Location
}
