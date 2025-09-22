param (
    [Parameter(Mandatory=$true)] [string] $uri,
    [Parameter(Mandatory=$true)] [string] $OutFile,
    [Parameter(Mandatory=$true)] [string] $ProxyUrl,
    [Parameter(Mandatory=$true)] [System.Management.Automation.PSCredential] $ProxyCredential
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$RefreshInterval = 3 # [s]

$TempFile = "${OutFile}.tmp"
# Write-Output "$TempFile, $OutFile"

Invoke-WebRequest -uri "$uri" `
                  -OutFile "$TempFile" `
                  -Proxy "$ProxyUrl" `
                  -ProxyCredential $ProxyCredential

$HTML = [string](Get-Content "$TempFile")

if ($HTML | Select-String -Pattern "/mwg-internal" -NotMatch) {
    Move-Item -Path "$TempFile" -Destination "$OutFile" -Force
    Return
}

# Write-Output "Waiting for McAfee"
if ($HTML -match 'script src="([^"]+).js"') {
    $McAfeePath = $matches[1]
    if ($McAfeePath -match '^(/[^/]+/[^/]+)') {
        $DLPath = $matches[1]
    } else {
        Throw "Could not find McAfee base path"
    }

    $UriObject = [System.Uri]$uri
    $TargetHost = $UriObject.Host
    $Scheme = $UriObject.Scheme
    $Base = "${Scheme}://${TargetHost}${DLPath}/progress"
    # Write-Output "Base = $Base"

    if ($HTML -match 'meta id="progresspageid" content="([^"]+)"') {
        $ProgressPageId = $matches[1]
    } else {
        Throw "Could not find progresspageid"
    }

    $ProgressPage = "$Base" + "?id=" + "$ProgressPageId"
    # Write-Output "ProgressPage = $ProgressPage"

    $parts = 0,0,0,0,0
    for ($i = 0; $i -lt 1000; $i + 1) {
        $Elapsed = [string]$parts[4]
        Write-Progress -Activity "Waiting for McAfee Scan..." -Status "Elapsed: ${Elapsed}s" -PercentComplete -1

        Start-Sleep $RefreshInterval
        $TimeEpoch = [DateTimeOffset]::Now.ToUnixTimeSeconds()

        $ProgressUri = "$ProgressPage&a=1&$TimeEpoch"
        # Write-Output "GET $ProgressUri"
        $Progress = Invoke-WebRequest -uri "$ProgressUri" `
                        -Proxy "$ProxyUrl" `
                        -ProxyCredential $ProxyCredential
        # Write-Output $Progress.Content
        $parts = $Progress.Content.Split(";")
        if ($parts[3] -match 1) {
            Break
        }
    }
    if ($i -eq 1000) {
        Write-Progress -Activity "Waiting for McAfee Scan..." -Completed
        Throw "Timout while waiting for McAfee Virus Scan"
    }

    Write-Progress -Activity "Waiting for McAfee Scan..." -Completed

    $DownloadUri = "$ProgressPage&dl"
    Invoke-WebRequest -uri "$DownloadUri" `
                    -OutFile "$OutFile" `
                    -Proxy "$ProxyUrl" `
                    -ProxyCredential $ProxyCredential
    
    Remove-Item "$TempFile"

} else {
    Throw "Could not find first JS file URL"
}
