#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputFile,

    [ValidateRange(1, 10240)]
    [int]$MaxSizeMB = 200,

    [string]$OutputDir,

    [string]$Prefix,

    [switch]$Force
)

$ffmpegCommand = Get-Command ffmpeg -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
$ffprobeCommand = Get-Command ffprobe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1

if ($null -eq $ffmpegCommand -or $null -eq $ffprobeCommand) {
    throw 'ffmpeg e ffprobe devem estar instalados e disponiveis no PATH.'
}

$ffmpeg = $ffmpegCommand.Source
$ffprobe = $ffprobeCommand.Source

$inputItem = Get-Item -LiteralPath $InputFile -ErrorAction Stop

if ($inputItem.PSIsContainer) {
    throw "O caminho informado e uma pasta: $InputFile"
}

$inputPath = $inputItem.FullName
$extension = [System.IO.Path]::GetExtension($inputPath)

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $outputDirectory = $inputItem.DirectoryName
}
else {
    $outputDirectory = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDir)

    if (Test-Path -LiteralPath $outputDirectory -PathType Leaf) {
        throw "O caminho de saida nao e uma pasta: $OutputDir"
    }

    if (-not (Test-Path -LiteralPath $outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }
}

if ([string]::IsNullOrWhiteSpace($Prefix)) {
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($inputPath)
}
else {
    if ($Prefix -match '[\\/:*?"<>|]') {
        throw 'O prefixo contem caracteres invalidos.'
    }

    $baseName = $Prefix
}

$invariantCulture = [System.Globalization.CultureInfo]::InvariantCulture
$floatStyle = [System.Globalization.NumberStyles]::Float

$durationText = & $ffprobe -v error -show_entries format=duration -of 'default=noprint_wrappers=1:nokey=1' -- $inputPath 2>$null
$totalSeconds = 0.0

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($durationText)) {
    throw "Nao foi possivel obter a duracao do video: $inputPath"
}

$durationValue = ([string]$durationText).Trim()

if (-not [double]::TryParse($durationValue, $floatStyle, $invariantCulture, [ref]$totalSeconds) -or $totalSeconds -le 0) {
    throw "Duracao invalida retornada pelo ffprobe: $durationValue"
}

$bitrateText = & $ffprobe -v error -show_entries format=bit_rate -of 'default=noprint_wrappers=1:nokey=1' -- $inputPath 2>$null
$totalBitrate = 0.0

if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($bitrateText)) {
    $bitrateValue = ([string]$bitrateText).Trim()
    [void][double]::TryParse($bitrateValue, $floatStyle, $invariantCulture, [ref]$totalBitrate)
}

if ($totalBitrate -le 0) {
    $totalBitrate = ($inputItem.Length * 8) / $totalSeconds
}

if ($totalBitrate -le 0) {
    throw 'Nao foi possivel calcular a taxa de bits do video.'
}

$maxSizeBytes = [int64]$MaxSizeMB * 1024 * 1024
$targetSeconds = ($maxSizeBytes * 8) / $totalBitrate
$segmentSeconds = [math]::Floor($targetSeconds * 0.75)

if ($segmentSeconds -lt 1) {
    $segmentSeconds = 1
}

$segmentTimeText = $segmentSeconds.ToString('0.###', $invariantCulture)
$partNamePattern = '^{0}-part\d+{1}$' -f [regex]::Escape($baseName), [regex]::Escape($extension)
$existingParts = @(
    Get-ChildItem -LiteralPath $outputDirectory -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -ne $inputPath -and $_.Name -match $partNamePattern }
)

if ($existingParts.Count -gt 0) {
    if (-not $Force) {
        throw "Ja existem partes com esse nome em $outputDirectory. Use -Force para substitui-las."
    }

    $existingParts | Remove-Item -Force
}

$patternBaseName = $baseName.Replace('%', '%%')
$outputPattern = Join-Path $outputDirectory ('{0}-part%03d{1}' -f $patternBaseName, $extension)

Write-Host ("Dividindo '{0}' em partes de ate {1} MB..." -f $inputItem.Name, $MaxSizeMB) -ForegroundColor Cyan
Write-Host ('Duracao: {0:N1}s | Duracao alvo por parte: {1}s' -f $totalSeconds, $segmentTimeText)

$arguments = @(
    '-hide_banner'
    '-loglevel', 'error'
    '-nostdin'
    '-i', $inputPath
    '-map', '0'
    '-c', 'copy'
    '-f', 'segment'
    '-segment_time', $segmentTimeText
    '-segment_start_number', '1'
    '-reset_timestamps', '1'
    $outputPattern
)

if ($Force) {
    $arguments += '-y'
}
else {
    $arguments += '-n'
}

& $ffmpeg @arguments

if ($LASTEXITCODE -ne 0) {
    throw "ffmpeg falhou ao dividir o video (codigo $LASTEXITCODE)."
}

$parts = @(
    Get-ChildItem -LiteralPath $outputDirectory -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -ne $inputPath -and $_.Name -match $partNamePattern } |
        Sort-Object Name
)

if ($parts.Count -eq 0) {
    throw 'Nenhuma parte foi gerada.'
}

$results = [System.Collections.Generic.List[object]]::new()

foreach ($part in $parts) {
    $partDurationText = & $ffprobe -v error -show_entries format=duration -of 'default=noprint_wrappers=1:nokey=1' -- $part.FullName 2>$null
    $partSeconds = 0.0

    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($partDurationText)) {
        $partDurationValue = ([string]$partDurationText).Trim()
        [void][double]::TryParse($partDurationValue, $floatStyle, $invariantCulture, [ref]$partSeconds)
    }

    $partSizeMB = [math]::Round($part.Length / 1MB, 1)
    $partNumber = 0

    if ($part.BaseName -match '-part(\d+)$') {
        $partNumber = [int]$Matches[1]
    }

    if ($part.Length -gt $maxSizeBytes) {
        Write-Warning ('A parte {0} ficou com {1} MB, acima do limite de {2} MB.' -f $partNumber, $partSizeMB, $MaxSizeMB)
    }

    $results.Add([pscustomobject]@{
        Parte           = $partNumber
        Arquivo         = $part.FullName
        DuracaoSegundos = [math]::Round($partSeconds, 1)
        TamanhoMB       = $partSizeMB
    })
}

$results = @($results | Sort-Object Parte)
$totalSizeMB = [math]::Round((($results | Measure-Object -Property TamanhoMB -Sum).Sum), 1)
$overLimit = @($parts | Where-Object { $_.Length -gt $maxSizeBytes })

Write-Host ''
Write-Host ('Concluido: {0} parte(s) gerada(s) em {1}' -f $results.Count, $outputDirectory) -ForegroundColor Green
$results | Format-Table Parte, Arquivo, DuracaoSegundos, TamanhoMB -AutoSize
Write-Host ('Tamanho total: {0} MB' -f $totalSizeMB)

if ($overLimit.Count -gt 0) {
    Write-Warning 'Algumas partes excederam o limite. Reduza -MaxSizeMB ou use um video com keyframes mais frequentes.'
}
