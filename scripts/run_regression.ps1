# =============================================================================
# Regression Test Harness
# =============================================================================
# Builds sim.exe, runs all tests, compares outputs byte-for-byte
# =============================================================================

param(
    [switch]$NoBuild,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# Paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$BuildDir = Join-Path $RootDir "build\Release"
$TestsDir = Join-Path $RootDir "tests"
$SimExe = Join-Path $BuildDir "sim.exe"

# Test list
$Tests = @("simple", "counter", "mulserial", "mulparallel")

# Micro-tests
$MicroTests = @("halt_test", "branch_test", "jal_test", "hazard_test")

# Colors
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Failure { Write-Host $args -ForegroundColor Red }
function Write-Info { Write-Host $args -ForegroundColor Cyan }

# =============================================================================
# Build
# =============================================================================

function Build-Simulator {
    Write-Info "Building simulator..."
    
    Push-Location $RootDir
    try {
        # Known MSBuild paths
        $msbuildPaths = @(
            "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe",
            "C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe",
            "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe",
            "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe"
        )
        
        $msbuildExe = $null
        foreach ($path in $msbuildPaths) {
            if (Test-Path $path) {
                $msbuildExe = $path
                break
            }
        }
        
        # Also check PATH
        if (-not $msbuildExe) {
            $msbuild = Get-Command MSBuild -ErrorAction SilentlyContinue
            if ($msbuild) { $msbuildExe = $msbuild.Source }
        }
        
        if ($msbuildExe) {
            & $msbuildExe ide\sim.vcxproj /p:Configuration=Release /p:Platform=x64 /v:minimal
            if ($LASTEXITCODE -ne 0) { throw "MSBuild failed" }
        } else {
            # Try cl.exe directly
            $cl = Get-Command cl -ErrorAction SilentlyContinue
            if ($cl) {
                if (-not (Test-Path $BuildDir)) { New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null }
                Push-Location $BuildDir
                & cl /O2 /I"$RootDir\include" /Fe:sim.exe "$RootDir\src\*.c"
                Pop-Location
                if ($LASTEXITCODE -ne 0) { throw "cl.exe compilation failed" }
            } else {
                throw "No C compiler found (MSBuild or cl.exe)"
            }
        }
        Write-Success "Build successful"
    }
    finally {
        Pop-Location
    }
}

# =============================================================================
# Run a single test
# =============================================================================

function Run-SingleTest {
    param(
        [string]$TestName,
        [string]$TestDir
    )
    
    Write-Info "Running test: $TestName"
    
    $ExpectedDir = Join-Path $TestDir "expected"
    
    # Check if test directory exists
    if (-not (Test-Path $TestDir)) {
        Write-Failure "  Test directory not found: $TestDir"
        return $false
    }
    
    # Copy input files to build directory
    $InputFiles = @("imem0.txt", "imem1.txt", "imem2.txt", "imem3.txt", "memin.txt")
    foreach ($file in $InputFiles) {
        $src = Join-Path $TestDir $file
        if (Test-Path $src) {
            Copy-Item $src $BuildDir -Force
        } else {
            # Create empty file if missing
            "" | Out-File (Join-Path $BuildDir $file) -Encoding ASCII
        }
    }
    
    # Run simulator
    Push-Location $BuildDir
    try {
        & $SimExe 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Failure "  Simulator returned error code: $LASTEXITCODE"
            return $false
        }
    }
    finally {
        Pop-Location
    }
    
    # Compare outputs
    $OutputFiles = @(
        "memout.txt",
        "regout0.txt", "regout1.txt", "regout2.txt", "regout3.txt",
        "core0trace.txt", "core1trace.txt", "core2trace.txt", "core3trace.txt",
        "bustrace.txt",
        "dsram0.txt", "dsram1.txt", "dsram2.txt", "dsram3.txt",
        "tsram0.txt", "tsram1.txt", "tsram2.txt", "tsram3.txt",
        "stats0.txt", "stats1.txt", "stats2.txt", "stats3.txt"
    )
    
    $AllMatch = $true
    
    foreach ($file in $OutputFiles) {
        $expected = Join-Path $ExpectedDir $file
        $actual = Join-Path $BuildDir $file
        
        if (-not (Test-Path $expected)) {
            if ($Verbose) { Write-Host "  [SKIP] $file (no expected file)" }
            continue
        }
        
        if (-not (Test-Path $actual)) {
            Write-Failure "  [FAIL] $file (not generated)"
            $AllMatch = $false
            continue
        }
        
        # Byte-for-byte comparison
        $expectedContent = Get-Content $expected -Raw
        $actualContent = Get-Content $actual -Raw
        
        # Normalize line endings for comparison
        $expectedContent = $expectedContent -replace "`r`n", "`n"
        $actualContent = $actualContent -replace "`r`n", "`n"
        
        if ($expectedContent -ne $actualContent) {
            Write-Failure "  [FAIL] $file"
            
            # Show first difference
            $expectedLines = $expectedContent -split "`n"
            $actualLines = $actualContent -split "`n"
            
            $maxLines = [Math]::Max($expectedLines.Count, $actualLines.Count)
            for ($i = 0; $i -lt $maxLines; $i++) {
                $eLine = if ($i -lt $expectedLines.Count) { $expectedLines[$i] } else { "<EOF>" }
                $aLine = if ($i -lt $actualLines.Count) { $actualLines[$i] } else { "<EOF>" }
                
                if ($eLine -ne $aLine) {
                    Write-Host "    Line $($i+1):"
                    Write-Host "      Expected: $eLine"
                    Write-Host "      Actual:   $aLine"
                    break
                }
            }
            
            $AllMatch = $false
        } else {
            if ($Verbose) { Write-Success "  [PASS] $file" }
        }
    }
    
    if ($AllMatch) {
        Write-Success "  PASSED"
    }
    
    return $AllMatch
}

# =============================================================================
# Main
# =============================================================================

Write-Host "=============================================="
Write-Host "Multi-Core MESI Simulator - Regression Tests"
Write-Host "=============================================="
Write-Host ""

# Build
if (-not $NoBuild) {
    Build-Simulator
}

if (-not (Test-Path $SimExe)) {
    Write-Failure "Simulator not found: $SimExe"
    exit 1
}

Write-Host ""
Write-Host "Running tests..."
Write-Host ""

$TotalTests = 0
$PassedTests = 0

# Run main tests
foreach ($test in $Tests) {
    $testDir = Join-Path $TestsDir $test
    if (Test-Path $testDir) {
        $TotalTests++
        if (Run-SingleTest -TestName $test -TestDir $testDir) {
            $PassedTests++
        }
    }
}

# Run micro-tests
foreach ($test in $MicroTests) {
    $testDir = Join-Path $TestsDir $test
    if (Test-Path $testDir) {
        $TotalTests++
        if (Run-SingleTest -TestName $test -TestDir $testDir) {
            $PassedTests++
        }
    }
}

Write-Host ""
Write-Host "=============================================="
if ($PassedTests -eq $TotalTests) {
    Write-Success "All tests passed: $PassedTests / $TotalTests"
    exit 0
} else {
    Write-Failure "Tests failed: $($TotalTests - $PassedTests) / $TotalTests"
    exit 1
}
