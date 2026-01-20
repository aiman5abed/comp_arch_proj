# Changelog

All notable changes to this project are documented in this file.

---

## [1.1.0] - 2026-01-12

### Fixed

#### ISA Corrections
- **FIX-1**: Changed HALT opcode from 21 to 20 in `include/sim.h`
- **FIX-2**: Fixed branch target to use `R[rd] & 0x3FF` (value in register, not rd field)
- **FIX-3**: Fixed JAL to store `pc+1` in R15 and jump to `R[rd] & 0x3FF`

#### Cache Corrections
- **FIX-11/FORMAT-3**: Fixed TSRAM output format to `[13:12]=MESI, [11:0]=TAG`
  - Changed from `((tag << 2) | mesi)` to `((mesi << 12) | tag)`

#### Test File Corrections
- Fixed all test imem files to use HALT opcode 0x14 instead of 0x15
- Fixed instruction encodings in simple test
- Created micro-tests for ISA verification

### Added

#### New Tests
- **TEST-1**: Added `mulparallel` test - parallel matrix-vector multiplication across 4 cores
  - Core 0: Result[0] = 30 (0x1E)
  - Core 1: Result[1] = 70 (0x46)
  - Core 2: Result[2] = 110 (0x6E)
  - Core 3: Result[3] = 150 (0x96)

#### Micro-Tests
- `halt_test`: Verifies HALT opcode = 20
- `branch_test`: Verifies branch target from R[rd]
- `jal_test`: Verifies JAL return address and jump target
- `hazard_test`: Verifies RAW hazard detection and stalling

#### Infrastructure
- `scripts/run_regression.ps1`: Automated regression test harness
  - Builds simulator using MSBuild
  - Runs all tests
  - Compares outputs byte-for-byte
  - Reports first mismatch on failure

### Changed
- Updated expected outputs for all tests to match corrected TSRAM format
- Regression harness now searches common MSBuild installation paths

---

## [1.0.0] - 2025-01-XX (Initial Release)

### Implemented
- 4-core MESI cache coherent processor simulator
- 5-stage pipeline (IF/ID/EX/MEM/WB)
- Private instruction memory per core (1024 words)
- Private direct-mapped data cache per core (256 entries, 8-word blocks)
- Shared main memory (2^21 words)
- MESI cache coherency protocol
- Bus arbitration (round-robin)
- Complete ISA: ADD, SUB, AND, OR, XOR, MUL, SLL, SRA, SRL, BEQ, BNE, BLT, BGT, BLE, BGE, JAL, LW, SW, HALT

### Tests
- counter: Shared counter test
- mulserial: Serial matrix multiplication
- simple: Basic ALU operations

---

## Format

Based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)

Types of changes:
- **Added** for new features
- **Changed** for changes in existing functionality
- **Deprecated** for soon-to-be removed features
- **Removed** for now removed features
- **Fixed** for any bug fixes
- **Security** for vulnerability fixes
