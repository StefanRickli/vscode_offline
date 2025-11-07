param (
    [Parameter(Mandatory = $true)] [string] $TargetHost,
    [Parameter(Mandatory = $false)] [string] $Directory
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

    $ExtensionList = ((Get-Content "extensions.json") | ConvertFrom-Json).PSObject.Properties["$TargetHost"].Value
    
    if ($null -eq $ExtensionList) {
        Write-Error "No extensions defined for host ${TargetHost}"
        Exit 1
    }

    $Extensions = $ExtensionList | ForEach-Object { Get-ChildItem ".\extensions\$($_)*.vsix" }

    $ArchiveName = "vscode-extensions-${Version}-${TargetHost}"

    $FileList = $Extensions.FullName

    $dummy = & "C:\Program Files\7-Zip\7z.exe" a -ttar ".\${ArchiveName}.tar" $FileList
    $dummy = & "C:\Program Files\7-Zip\7z.exe" a -tgzip ".\${ArchiveName}.tar.gz" ".\${ArchiveName}.tar"
    Remove-Item ".\${ArchiveName}.tar"

    $UserName = ($Env:UserName).ToUpper()
    $TargetUserHome = "/home/${UserName}"

    Write-Output "Uploading Files to ${TargetHost}"
    scp -q ".\${ArchiveName}.tar.gz" "${UserName}@${TargetHost}:${TargetUserHome}/"
    Write-Output "Installing extensions on ${TargetHost}..."

    $RemoteTempDir = "/tmp/vscode-${Version}-extensions"
    $Commit = (Get-Content "commit.txt").Trim()
    $CodeServerBin = "${TargetUserHome}/.vscode-server/bin/${Commit}/bin/code-server"

    $Commands = @"
"$CodeServerBin" --version &> /dev/null || { echo "Cannot find VSCode's code-server binary! Is it installed? Abort."; exit 1; }

echo "Unpacking files into '${RemoteTempDir}' ..."
mkdir -p "${RemoteTempDir}" || exit 1
tar xf "${TargetUserHome}/${ArchiveName}.tar.gz" -C "${RemoteTempDir}"

for file in "${RemoteTempDir}"/*; do
  if [[ -f "`$file" ]]; then
    sudo unshare -n -- sudo -u "${UserName}" "${CodeServerBin}"  --install-extension "`$file" || exit 1
  fi
done
echo "Successfully installed extensions."
"@ -replace "`r", ""

    $Commands | ssh "$UserName@$TargetHost" 'bash -s'
}
finally {
    Pop-Location
}
