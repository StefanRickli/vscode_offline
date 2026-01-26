<#
.SYNOPSIS
get_version_commit_sha.ps1 maps a target VS Code Version to its Git commit SHA using GitHub's API.

This script closely follows the information in `docs\GitHub API how to get from tag to commit SHA.pdf`.
#>

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
