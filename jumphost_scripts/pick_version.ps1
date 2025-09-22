
param(
    [Parameter(Mandatory)] [string] $ParentPath,
    [int] $Take = 5,
    [ValidateSet('LastWriteTime','CreationTime')] [string] $SortBy = 'LastWriteTime'
)

if (-not (Test-Path -LiteralPath $ParentPath)) {
    throw "Parent path not found: $ParentPath"
}

$dirs = Get-ChildItem -LiteralPath $ParentPath -Directory -ErrorAction Stop |
        Sort-Object -Property $SortBy -Descending |
        Select-Object -First $Take

if (-not $dirs) {
    throw "No subdirectories found under: $ParentPath"
}

# Build ChoiceDescription[] with hotkeys A, B, C, ...
$choices = for ($i = 0; $i -lt $dirs.Count; $i++) {
    $d = $dirs[$i]
    $hotkey = [char]([byte][char]'A' + $i)
    $label  = "&$hotkey $($d.Name)"
    $help   = "{0}: {1}  ({2})" -f $SortBy, $d.$SortBy.ToString('yyyy-MM-dd HH:mm'), $d.FullName
    [System.Management.Automation.Host.ChoiceDescription]::new($label, $help)
}

$caption = "Pick a Version"
$message = "Choose one of the $($dirs.Count) most recent versions in `"$ParentPath`":"
$default = 0

$resultIndex = $Host.UI.PromptForChoice($caption, $message, $choices, $default)
$dirs[$resultIndex]  # return the DirectoryInfo object
