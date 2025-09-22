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

if ("" -eq $Directory) {
    $Directory = .\pick_version.ps1 -ParentPath "." -Take 5 -SortBy LastWriteTime
}
Push-Location $Directory

try {
    $Version = (Get-Content "version.txt").Trim()

    $VSCodeServerArchive = (Get-ChildItem ".\vscode-server-linux-x64-${Version}.tar.gz")[0].Name

    $UserName = ($Env:UserName).ToUpper()
    $TargetUserHome = "/home/${UserName}"

    Write-Output "Uploading File to ${TargetHost}..."
    scp -q ".\${VSCodeServerArchive}" "${UserName}@${TargetHost}:${TargetUserHome}/${VSCodeServerArchive}"
    Write-Output "Done. Unpacking and installing on ${TargetHost}..."

    $Commit = (Get-Content "commit.txt").Trim()
    $TargetBinDir = "${TargetUserHome}/.vscode-server/bin/${Commit}"

    $Commands = @"
sudo -v || { echo "You cannot sudo without password! Abort."; exit 1; }

echo "Creating directory '${TargetBinDir}' ..."
mkdir -p "${TargetBinDir}" || exit 1

echo "Unpacking VS Code Server into bin directory..."
tar xf "${TargetUserHome}/${VSCodeServerArchive}" -C "${TargetBinDir}" --strip-components=1 || exit 1

echo "Creating entries in /etc/hosts (if not present)..."
sudo sed -i '/[[:space:]]mobile.events.data.microsoft.com$/d' /etc/hosts || exit 1
echo '8.8.8.8 mobile.events.data.microsoft.com' | sudo tee -a /etc/hosts || exit 1
sudo sed -i '/[[:space:]]marketplace.visualstudio.com$/d' /etc/hosts || exit 1
echo '8.8.8.8 marketplace.visualstudio.com' | sudo tee -a /etc/hosts || exit 1

echo "Done."
"@ -replace "`r", ""

    $Commands | ssh "$UserName@$TargetHost" 'bash -s'

}
finally {
    Pop-Location
}
