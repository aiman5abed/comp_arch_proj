# Run a single test case
# Usage: .\run_test.ps1 <testname>

param(
    [Parameter(Mandatory=$true)]
    [string]$TestName
)

$SimExe = "build\Release\sim.exe"
$TestDir = "tests\$TestName"
$OutputDir = "output\$TestName"

# Check if simulator exists
if (-not (Test-Path $SimExe)) {
    Write-Host "Error: Simulator not found at $SimExe" -ForegroundColor Red
    Write-Host "Build first: MSBuild ide\sim.vcxproj /p:Configuration=Release /p:Platform=x64"
    exit 1
}

# Check if test exists
if (-not (Test-Path $TestDir)) {
    Write-Host "Error: Test '$TestName' not found in tests/" -ForegroundColor Red
    Write-Host "Available tests:" -ForegroundColor Yellow
    Get-ChildItem tests -Directory | ForEach-Object { Write-Host "  - $($_.Name)" }
    exit 1
}

Write-Host "Running test: $TestName" -ForegroundColor Cyan

# Create output directory
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

# Copy input files
Copy-Item "$TestDir\imem*.txt" $OutputDir -ErrorAction SilentlyContinue
Copy-Item "$TestDir\memin.txt" $OutputDir -ErrorAction SilentlyContinue

# Run simulator
Push-Location $OutputDir
Write-Host "Executing simulator..." -ForegroundColor Yellow
& "..\..\$SimExe"
$exitCode = $LASTEXITCODE
Pop-Location

if ($exitCode -ne 0) {
    Write-Host "Simulator failed with exit code $exitCode" -ForegroundColor Red
    exit $exitCode
}

Write-Host ""
Write-Host "Test complete! Outputs in: $OutputDir" -ForegroundColor Green

# Compare with expected if available
$ExpectedDir = "$TestDir\expected"
if (Test-Path $ExpectedDir) {
    Write-Host ""
    Write-Host "Comparing with expected outputs..." -ForegroundColor Yellow
    
    $files = Get-ChildItem $ExpectedDir -File
    $allMatch = $true
    $diffCount = 0
    
    foreach ($file in $files) {
        $expected = Get-Content "$ExpectedDir\$($file.Name)" -Raw -ErrorAction SilentlyContinue
        $actual = Get-Content "$OutputDir\$($file.Name)" -Raw -ErrorAction SilentlyContinue
        
        if ($expected -ne $actual) {
            Write-Host "  [DIFF] $($file.Name)" -ForegroundColor Red
            $allMatch = $false
            $diffCount++
        }
    }
    
    if ($allMatch) {
        Write-Host ""
        Write-Host "[PASS] All outputs match expected!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host ""
        Write-Host "[FAIL] $diffCount file(s) differ from expected" -ForegroundColor Red
        exit 1
    }
}
