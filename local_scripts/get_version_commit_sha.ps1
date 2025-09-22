param (
    [Parameter(Mandatory=$true)] [string] $Version,
    [Parameter(Mandatory=$false)] [string] $Owner = "microsoft",
    [Parameter(Mandatory=$false)] [string] $Repo = "vscode",
    [Parameter(Mandatory=$true)] [string] $ProxyUrl,
    [Parameter(Mandatory=$true)] [System.Management.Automation.PSCredential] $ProxyCredential
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$ref = Invoke-RestMethod -Uri "https://api.github.com/repos/$Owner/$Repo/git/ref/tags/$Version" -Proxy $ProxyUrl -ProxyCredential $ProxyCredential

switch ($ref.object.type) {
    "commit" { $commitSha = $ref.object.sha }
    "tag" {
        $tagObj = Invoke-RestMethod -Uri "https://api.github.com/repos/$Owner/$Repo/git/tags/$($ref.object.sha)"
        $commitSha = $tagObj.object.sha
    }
}

$commitSha
