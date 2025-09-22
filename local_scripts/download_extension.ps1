param (
    [Parameter(Mandatory=$true)] [string] $ExtensionIdentifier,
    [Parameter(Mandatory=$false)] [string] $OutDir = ".\downloads",
    [Parameter(Mandatory=$true)] [string] $ProxyUrl = "",
    [Parameter(Mandatory=$true)] [System.Management.Automation.PSCredential] $ProxyCredential
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

Write-Output "Downloading $ExtensionIdentifier"
$MarketplaceUrl = "https://marketplace.visualstudio.com/items?itemName=$ExtensionIdentifier"
# Write-Output "$MarketplaceUrl"
$HTML = (Invoke-WebRequest -Uri $MarketplaceUrl -Proxy "$ProxyUrl" -ProxyCredential $ProxyCredential).Content

if ($HTML -match '<script[^>]*class="jiContent"[^>]*>(.*?)</script>') {
    $Details = ($matches[1]).Trim() | Convertfrom-Json
}

$ExtensionName      = $Details.Resources.ExtensionName
$ExtensionPublisher = $Details.Resources.PublisherName
$ExtensionVersion   = $Details.Versions[0].version

$null = New-Item -Type Directory -Force $OutDir
$TargetFile = Join-Path $OutDir "\$ExtensionPublisher.$ExtensionName.$ExtensionVersion.vsix"

. "$PSScriptRoot\download_using_proxy.ps1" -uri "$($Details.AssetUri)/Microsoft.VisualStudio.Services.VSIXPackage" -OutFile "$TargetFile" -ProxyUrl "$ProxyUrl" -ProxyCredential $ProxyCredential
