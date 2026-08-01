param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 3600)]
    [int]$TimeoutSeconds,

    [Parameter(Mandatory = $true)]
    [string]$DefaultValue,

    [Parameter(Mandatory = $true)]
    [string]$ResultPath
)

$ErrorActionPreference = "Stop"
$status = "timeout"
$value = ""
$buffer = New-Object System.Text.StringBuilder
$deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)

try {
    while ([DateTime]::UtcNow -lt $deadline) {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)

            if ($key.Key -eq [ConsoleKey]::Enter) {
                $status = "input"
                break
            }

            if ($key.Key -eq [ConsoleKey]::Backspace) {
                if ($buffer.Length -gt 0) {
                    $null = $buffer.Remove($buffer.Length - 1, 1)
                    [Console]::Write("`b `b")
                }

                continue
            }

            if (-not [char]::IsControl($key.KeyChar)) {
                $null = $buffer.Append($key.KeyChar)
                [Console]::Write($key.KeyChar)
            }

            continue
        }

        Start-Sleep -Milliseconds 50
    }
}
catch {
    $status = "timeout"
}

[Console]::WriteLine()

if ($status -eq "input") {
    $value = $buffer.ToString().Trim()
}

if ([string]::IsNullOrWhiteSpace($value)) {
    $value = $DefaultValue
}

$encoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText(
    $ResultPath,
    ($status + "|" + $value),
    $encoding
)
