$exePath = "build/windows/x64/runner/Release/veritium.exe"
$inputPath = "examples/straza/id-40086785_date-19091112_vol-01_no-132_middle.json"
$outputPath = "build/windows_cli_smoke.md"

if (Test-Path -LiteralPath $outputPath) {
  Remove-Item -LiteralPath $outputPath -Force
}

$arguments = @("--cli-export", "--input", $inputPath, "--output", $outputPath, "--no-images")
Start-Process -FilePath $exePath -ArgumentList $arguments
Start-Sleep -Seconds 2

if (!(Test-Path -LiteralPath $outputPath)) {
  throw "Windows CLI smoke output was not generated at '$outputPath'"
}

Write-Host "Windows CLI smoke output generated at: $outputPath"
