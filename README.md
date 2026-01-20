# Multi-Core MESI Simulator

Cycle-accurate simulator for a 4-core pipelined processor with MESI cache coherence protocol. Models a shared-memory multiprocessor with private caches, snooping-based coherence, and detailed performance tracing.

## 📁 Repository Structure

```
architecture-/
├── src/                    # Source code (.c files)
│   ├── main.c             # Entry point, I/O, simulation loop
│   ├── pipeline.c         # 5-stage pipeline implementation
│   ├── cache.c            # Cache operations & MESI protocol
│   └── bus.c              # Bus arbitration & memory controller
│
├── include/                # Header files
│   └── sim.h              # Main header (structures, constants, prototypes)
│
├── tests/                  # Test cases
│   ├── counter/           # Basic test with hazards
│   │   ├── imem*.txt      # Instruction memory inputs
│   │   ├── memin.txt      # Data memory input
│   │   └── expected/      # Reference outputs
│   ├── mulserial/         # Matrix multiplication test
│   └── simple/            # Simple test case
│
├── scripts/                # Build and test automation
│   ├── test_all.ps1       # Run all tests
│   ├── run_test.ps1       # Run single test
│   └── generate_tests.py  # Test generation utility
│
├── docs/                   # Documentation
│   ├── whatwedidfornow.md # Spec-to-code mapping & status
│   ├── ARCHITECTURE.md    # Detailed architecture diagrams
│   └── README_DETAILED.md # Extended documentation
│
├── ide/                    # IDE project files
│   ├── sim.sln            # Visual Studio solution
│   ├── sim.vcxproj        # Visual Studio project
│   └── build.bat          # Windows build script
│
├── build/                  # Build artifacts (gitignored)
│   └── Release/
│       └── sim.exe
│
├── Makefile               # GNU Make build file
├── .gitignore
└── README.md              # This file
```

## 🚀 Quick Start

### Prerequisites

**Windows (Visual Studio):**
- Visual Studio 2022 with C/C++ tools
- PowerShell 5.1+

**Linux/macOS (GCC):**
- GCC with C99 support
- GNU Make

### Build

**Windows:**
```powershell
MSBuild ide\sim.vcxproj /p:Configuration=Release /p:Platform=x64
```

**Linux/macOS:**
```bash
make build
```

Executable will be in `build/Release/sim.exe`

### Run Tests

**Run all tests:**
```powershell
.\scripts\test_all.ps1
```

**Run specific test:**
```powershell
.\scripts\run_test.ps1 counter
```

**Manual execution:**
```powershell
cd output\counter
..\..\build\Release\sim.exe
```

The simulator reads input files from the current directory and generates 22 output files.

### Clean

```powershell
# Clean build artifacts only
make clean

# Clean build + test outputs
make clean-all
```

## 🏗️ Architecture

**System Overview:**
- 4 cores with private I-MEM (1024 words) and data cache (512 words)
- Shared bus with round-robin arbitration
- Shared main memory (2^21 words)
- MESI cache coherence protocol

**Per-Core Features:**
- 5-stage pipeline: Fetch → Decode → Execute → Memory → Writeback
- Direct-mapped cache (8-word blocks, 64 lines)
- Write-back + write-allocate policy
- Data hazard detection (stall in Decode)
- Branch resolution in Decode with delay slot

**Memory Hierarchy:**
- L1 Cache: 512 words, direct-mapped, MESI coherence
- Main Memory: 2^21 words, 16-cycle latency
- Bus Transfer: 8-cycle burst (one word per cycle)

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed diagrams and protocol documentation.

## 📊 Output Files

Each test run generates 22 files per test:

| File Pattern | Description |
|--------------|-------------|
| `core0trace.txt` - `core3trace.txt` | Pipeline state every cycle |
| `bustrace.txt` | Bus transactions log |
| `memout.txt` | Final main memory state |
| `regout0.txt` - `regout3.txt` | Final register file values |
| `dsram0.txt` - `dsram3.txt` | Cache data dump |
| `tsram0.txt` - `tsram3.txt` | Cache tags + MESI states |
| `stats0.txt` - `stats3.txt` | Performance counters |

## 🧪 Test Cases

| Test | Description | Key Features |
|------|-------------|--------------|
| `counter` | Basic pipeline test | Data hazards, branches, delay slots |
| `mulserial` | Matrix multiply (2×3=6) | Cache operations, memory writes |
| `simple` | Minimal test | Basic functionality check |

## 📈 Performance Metrics

Statistics tracked per core (in `stats*.txt`):

```
cycles N                 # Total cycles executed
instructions M           # Instructions committed
read_hit X               # Cache read hits
read_miss Y              # Cache read misses
write_hit Z              # Cache write hits
write_miss W             # Cache write misses
decode_stall_cycles S    # Cycles stalled on data hazards
mem_stall_cycles T       # Cycles stalled on cache misses
```

**CPI (Cycles Per Instruction)** = cycles / instructions

## 🛠️ Development

### Adding a New Test

1. Create directory: `tests/newtest/`
2. Add inputs: `imem0.txt`, `imem1.txt`, `imem2.txt`, `imem3.txt`, `memin.txt`
3. Run once: `.\scripts\run_test.ps1 newtest`
4. Verify outputs, then save as expected:
   ```powershell
   mkdir tests\newtest\expected
   copy output\newtest\*.txt tests\newtest\expected\
   ```

### Modifying the Simulator

1. Edit source files in `src/`
2. Rebuild: `MSBuild ide\sim.vcxproj /p:Configuration=Release /p:Platform=x64`
3. Test: `.\scripts\test_all.ps1`
4. Verify all tests still pass

### Debugging

Build with debug symbols:
```bash
make debug
```

Or in Visual Studio, use Debug configuration.

## 📖 Documentation

- [ARCHITECTURE.md](docs/ARCHITECTURE.md) - Visual architecture diagrams, MESI state machine, bus protocol
- [README_DETAILED.md](docs/README_DETAILED.md) - Extended feature documentation
- Source code comments - Implementation details

## ✅ Verification

Run the test suite to verify functionality:

```powershell
PS> .\scripts\test_all.ps1

[1] Checking build...
  [OK] sim.exe found

[TEST] Running 'counter'...
  [OK] All outputs match expected

[TEST] Running 'mulserial'...
  [OK] All outputs match expected

=====================================
Test Summary
=====================================
Tests Passed: 3
Tests Failed: 0

[SUCCESS] ALL TESTS PASSED!
```

## 🔧 Troubleshooting

**Build fails with "cannot find sim.h":**
- Ensure you're building from the repository root
- Check that `src/sim.h` exists

**Simulator hangs:**
- Check for infinite loops in test program
- Safety limit: 1M cycles (configured in `src/main.c`)

**Outputs don't match expected:**
- Run `git diff tests/*/expected/` to see what changed
- Verify inputs haven't been modified
- Check if simulator logic changed

## 📝 License

Educational project for computer architecture coursework.

## 👥 Authors

Multi-core MESI simulator implementation for architecture studies.

---

**For detailed architecture diagrams and protocol specifications, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**
