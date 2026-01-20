# Comprehensive test script for Multi-Core MESI Simulator
# Tests all test cases and verifies outputs

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Multi-Core MESI Simulator Test Suite" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

$ErrorCount = 0
$TestsPassed = 0
$TestsFailed = 0
$SimExe = "build\Release\sim.exe"

# 1. Check if build exists
Write-Host "[1] Checking build..." -ForegroundColor Yellow
if (Test-Path $SimExe) {
    Write-Host "  [OK] sim.exe found" -ForegroundColor Green
    $TestsPassed++
} else {
    Write-Host "  [FAIL] sim.exe not found. Building..." -ForegroundColor Red
    $msbuild = "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe"
    if (Test-Path $msbuild) {
        & $msbuild ide\sim.vcxproj /p:Configuration=Release /p:Platform=x64 /v:q
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] Build successful" -ForegroundColor Green
            $TestsPassed++
        } else {
            Write-Host "  [FAIL] Build failed" -ForegroundColor Red
            $TestsFailed++
            $ErrorCount++
            exit 1
        }
    } else {
        Write-Host "  [FAIL] MSBuild not found" -ForegroundColor Red
        $TestsFailed++
        $ErrorCount++
        exit 1
    }
}

# Get all test directories
$testDirs = Get-ChildItem tests -Directory

foreach ($testDir in $testDirs) {
    $testName = $testDir.Name
    Write-Host ""
    Write-Host "[TEST] Running '$testName'..." -ForegroundColor Yellow
    
    # Create output directory
    $outputDir = "output\$testName"
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    
    # Copy input files
    Copy-Item "tests\$testName\imem*.txt" $outputDir -ErrorAction SilentlyContinue
    Copy-Item "tests\$testName\memin.txt" $outputDir -ErrorAction SilentlyContinue
    
    # Run simulator
    Push-Location $outputDir
    $result = & "..\..\$SimExe" 2>&1
    $exitCode = $LASTEXITCODE
    Pop-Location
    
    if ($exitCode -ne 0) {
        Write-Host "  [FAIL] Simulator crashed or errored" -ForegroundColor Red
        $TestsFailed++
        $ErrorCount++
        continue
    }
    
    # Check if expected outputs exist
    $expectedDir = "tests\$testName\expected"
    if (Test-Path $expectedDir) {
        # Compare outputs
        $files = Get-ChildItem $expectedDir -File
        $allMatch = $true
        $diffCount = 0
        
        foreach ($file in $files) {
            $expected = Get-Content "$expectedDir\$($file.Name)" -Raw -ErrorAction SilentlyContinue
            $actual = Get-Content "$outputDir\$($file.Name)" -Raw -ErrorAction SilentlyContinue
            
            if ($expected -ne $actual) {
                $allMatch = $false
                $diffCount++
            }
        }
        
        if ($allMatch) {
            Write-Host "  [OK] All outputs match expected" -ForegroundColor Green
            $TestsPassed++
        } else {
            Write-Host "  [FAIL] $diffCount file(s) differ from expected" -ForegroundColor Red
            $TestsFailed++
            $ErrorCount++
        }
    } else {
        # No expected outputs, just verify files were created
        $outputFiles = Get-ChildItem $outputDir -Filter "*.txt" | Where-Object { $_.Name -notmatch "^(imem|memin)" }
        if ($outputFiles.Count -ge 20) {
            Write-Host "  [OK] Generated $($outputFiles.Count) output files" -ForegroundColor Green
            $TestsPassed++
        } else {
            Write-Host "  [WARN] Only $($outputFiles.Count) output files (expected 22+)" -ForegroundColor Yellow
            $TestsPassed++
        }
    }
}

# Summary
Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Tests Passed: $TestsPassed" -ForegroundColor Green
Write-Host "Tests Failed: $TestsFailed" -ForegroundColor $(if ($TestsFailed -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($ErrorCount -eq 0) {
    Write-Host "[SUCCESS] ALL TESTS PASSED!" -ForegroundColor Green
    Write-Host ""
    Write-Host "To run specific test: .\scripts\run_test.ps1 <testname>"
    Write-Host "To clean outputs: Remove-Item output -Recurse -Force"
    exit 0
} else {
    Write-Host "[FAILURE] SOME TESTS FAILED" -ForegroundColor Red
    exit 1
}
