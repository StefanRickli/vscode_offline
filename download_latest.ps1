$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

. ".\load_env.ps1"

$RequiredEnvVars = @("PROXY_URL", "PROXY_USER", "PROXY_PROMPT")
$MissingVars = $requiredEnvVars | Where-Object { -not (Test-Path "Env:$($_)") }
if ($MissingVars) {
    Write-Host "Missing environment variables: $($MissingVars -join ', ')" -ForegroundColor Red
    exit 1  # Exit with error if any variables are missing
}

$ProxyUrl = $Env:PROXY_URL
$ProxyCredential = Get-Credential -UserName "${Env:PROXY_USER}" -Message "${Env:PROXY_PROMPT}"

$VersionsUrl = "https://update.code.visualstudio.com/api/releases/stable"
$VersionsArray = (Invoke-WebRequest -Uri $VersionsUrl -Proxy "$ProxyUrl" -ProxyCredential $ProxyCredential) | Convertfrom-Json
$LatestVersion = $VersionsArray[0]
$LatestCommit = (.\local_scripts\get_version_commit_sha.ps1 -Owner "microsoft" -Repo "vscode" -Version "$LatestVersion" -ProxyUrl "$ProxyUrl" -ProxyCredential $ProxyCredential).Trim()

$OutDir = ".\downloads\vscode-${LatestVersion}"
$null = New-Item -Type Directory -Force $OutDir
$OutDir = Resolve-Path $OutDir

Write-Output "Target Directory: '$OutDir'"

"$LatestCommit" | Out-File -FilePath (Join-Path "${OutDir}" "commit.txt")
"$LatestVersion" | Out-File -FilePath (Join-Path "${OutDir}" "version.txt")
Copy-Item ".\extensions.json" "$OutDir\"

Write-Output "Downloading VS Code $LatestVersion (sha256=$LatestCommit)..."
$VsCodeDownloadUrl = "https://update.code.visualstudio.com/${LatestVersion}/win32-x64-user/stable"
$OutFile = Join-Path $OutDir "\VSCodeUserSetup-x64-${LatestVersion}.exe"
.\local_scripts\download_using_proxy.ps1 -uri "$VsCodeDownloadUrl" -OutFile "$OutFile" -ProxyUrl $ProxyUrl -ProxyCredential $ProxyCredential

Write-Output "Downloading VS Code Server $LatestVersion..."
$vscode_server_url = "https://update.code.visualstudio.com/commit:${LatestCommit}/server-linux-x64/stable"
$OutFile = Join-Path $OutDir "\vscode-server-linux-x64-${LatestVersion}.tar.gz"
.\local_scripts\download_using_proxy.ps1 -uri "$vscode_server_url" -OutFile "$OutFile" -ProxyUrl $ProxyUrl -ProxyCredential $ProxyCredential

Write-Output "Downloading Extensions:"
$ExtensionLists = Get-Content ".\extensions.json" | Convertfrom-Json
$allExtensions = $ExtensionLists.PSObject.Properties.Value | ForEach-Object { $_ } | Select-Object -Unique

foreach ($ExtensionIdentifier in $allExtensions)
{
  .\local_scripts\download_extension.ps1 -ExtensionIdentifier "$ExtensionIdentifier" -OutDir "${OutDir}\extensions" -ProxyUrl "$ProxyUrl" -ProxyCredential $ProxyCredential
}

Write-Output "Packing everything into '${OutDir}.zip'"
$CompressArgs = @{
  LiteralPath = @("$OutDir") + (Get-ChildItem ".\jumphost_scripts").FullName
  CompressionLevel = "NoCompression"
  DestinationPath = ".\vscode-${LatestVersion}.zip"
  Force = $true
}
Compress-Archive @CompressArgs
