# =============================================================================
# Test Runner for Multi-Core MESI Simulator
# =============================================================================
# Runs sim.exe on each test directory and compares outputs with expected files
# =============================================================================

param(
    [string]$SimPath = ".\sim.exe",
    [string]$TestsDir = ".\tests",
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# Output files to compare
$OutputFiles = @(
    "memout.txt",
    "regout0.txt", "regout1.txt", "regout2.txt", "regout3.txt",
    "core0trace.txt", "core1trace.txt", "core2trace.txt", "core3trace.txt",
    "bustrace.txt",
    "dsram0.txt", "dsram1.txt", "dsram2.txt", "dsram3.txt",
    "tsram0.txt", "tsram1.txt", "tsram2.txt", "tsram3.txt",
    "stats0.txt", "stats1.txt", "stats2.txt", "stats3.txt"
)

function Normalize-LineEndings {
    param([string]$Content)
    return $Content -replace "`r`n", "`n" -replace "`r", "`n"
}

function Compare-Files {
    param(
        [string]$Expected,
        [string]$Actual
    )
    
    if (-not (Test-Path $Expected)) {
        return @{ Match = $false; Error = "Expected file not found: $Expected" }
    }
    if (-not (Test-Path $Actual)) {
        return @{ Match = $false; Error = "Actual file not found: $Actual" }
    }
    
    $expContent = Normalize-LineEndings (Get-Content $Expected -Raw)
    $actContent = Normalize-LineEndings (Get-Content $Actual -Raw)
    
    if ($expContent -eq $actContent) {
        return @{ Match = $true }
    }
    
    # Find first difference
    $expLines = $expContent -split "`n"
    $actLines = $actContent -split "`n"
    
    $maxLines = [Math]::Max($expLines.Count, $actLines.Count)
    for ($i = 0; $i -lt $maxLines; $i++) {
        $expLine = if ($i -lt $expLines.Count) { $expLines[$i] } else { "<EOF>" }
        $actLine = if ($i -lt $actLines.Count) { $actLines[$i] } else { "<EOF>" }
        
        if ($expLine -ne $actLine) {
            return @{
                Match = $false
                Error = "First difference at line $($i + 1)"
                ExpectedLine = $expLine
                ActualLine = $actLine
            }
        }
    }
    
    return @{ Match = $true }
}

function Run-Test {
    param([string]$TestDir)
    
    $testName = Split-Path $TestDir -Leaf
    Write-Host "Running test: $testName" -ForegroundColor Cyan
    
    # Create temp directory for outputs
    $tempDir = Join-Path $env:TEMP "sim_test_$testName"
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $tempDir | Out-Null
    
    # Copy input files to temp dir
    Copy-Item (Join-Path $TestDir "imem*.txt") $tempDir
    Copy-Item (Join-Path $TestDir "memin.txt") $tempDir
    
    # Check for expected folder, use it if exists
    $expectedDir = Join-Path $TestDir "expected"
    if (-not (Test-Path $expectedDir)) {
        $expectedDir = $TestDir  # Fall back to test dir itself
    }
    
    # Run simulator
    Push-Location $tempDir
    try {
        $simOutput = & $SimPath 2>&1
        $exitCode = $LASTEXITCODE
        
        if ($Verbose) {
            Write-Host "Simulator output:" -ForegroundColor Gray
            $simOutput | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        }
        
        if ($exitCode -ne 0) {
            Write-Host "  FAILED: Simulator exited with code $exitCode" -ForegroundColor Red
            return $false
        }
        
        # Compare outputs
        $allMatch = $true
        foreach ($file in $OutputFiles) {
            $expected = Join-Path $expectedDir $file
            $actual = Join-Path $tempDir $file
            
            $result = Compare-Files -Expected $expected -Actual $actual
            
            if (-not $result.Match) {
                Write-Host "  MISMATCH: $file" -ForegroundColor Red
                Write-Host "    $($result.Error)" -ForegroundColor Yellow
                if ($result.ExpectedLine) {
                    Write-Host "    Expected: $($result.ExpectedLine)" -ForegroundColor Yellow
                    Write-Host "    Actual:   $($result.ActualLine)" -ForegroundColor Yellow
                }
                $allMatch = $false
            } elseif ($Verbose) {
                Write-Host "  OK: $file" -ForegroundColor Green
            }
        }
        
        if ($allMatch) {
            Write-Host "  PASSED" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  FAILED" -ForegroundColor Red
            return $false
        }
    }
    finally {
        Pop-Location
        # Cleanup temp dir
        if (-not $Verbose) {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host "  Temp dir: $tempDir" -ForegroundColor Gray
        }
    }
}

# Main
Write-Host "=" * 60
Write-Host "Multi-Core MESI Simulator Test Runner"
Write-Host "=" * 60
Write-Host ""

# Check simulator exists
$SimPath = Resolve-Path $SimPath -ErrorAction SilentlyContinue
if (-not $SimPath) {
    Write-Host "ERROR: Simulator not found. Please build sim.exe first." -ForegroundColor Red
    exit 1
}
Write-Host "Simulator: $SimPath"

# Find test directories
$testDirs = Get-ChildItem -Path $TestsDir -Directory | Where-Object {
    Test-Path (Join-Path $_.FullName "imem0.txt")
}

if ($testDirs.Count -eq 0) {
    Write-Host "ERROR: No test directories found in $TestsDir" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($testDirs.Count) test(s)"
Write-Host ""

# Run tests
$passed = 0
$failed = 0

foreach ($testDir in $testDirs) {
    if (Run-Test -TestDir $testDir.FullName) {
        $passed++
    } else {
        $failed++
    }
    Write-Host ""
}

# Summary
Write-Host "=" * 60
Write-Host "Results: $passed passed, $failed failed"
Write-Host "=" * 60

exit $failed
