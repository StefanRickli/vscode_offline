
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$Directory = .\pick_version.ps1 -ParentPath (Resolve-Path ".") -Take 5 -SortBy LastWriteTime
Push-Location $Directory

try {
    $ExtensionList = ((Get-Content "extensions.json") | ConvertFrom-Json).PSObject.Properties["jumphost"].Value

    foreach ($ExtensionIdentifier in $ExtensionList) {
        $extension = (Get-ChildItem ".\extensions\${ExtensionIdentifier}.*.vsix")[0]
        code --install-extension "${extension}"
    }
}
finally {
    Pop-Location
}
