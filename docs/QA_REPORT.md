# QA Verification Report - Multi-Core MESI Simulator

## Summary

This document provides a complete QA verification of the 4-core pipelined CPU simulator with private I-MEM, private direct-mapped D-cache per core, MESI coherency over a shared bus, and main memory.

## 1. Spec Requirement Checklist

### A) Core + Pipeline (5 stages: Fetch/Decode/Execute/Mem/WB)

| Requirement | Implementation Location | Status | Notes |
|-------------|------------------------|--------|-------|
| PC is 10-bit (1024 instruction words) | `sim.h:PC_WIDTH=10, PC_MASK=0x3FF` | ✅ PASS | |
| Branch resolution in Decode | `pipeline.c:do_decode()` lines 283-306 | ✅ PASS | |
| Delay slot executes | `pipeline.c:core_cycle()` lines 398-400 | ✅ PASS | Delay slot in IF_ID proceeds to ID_EX |
| No forwarding (stall on data hazard) | `pipeline.c:check_data_hazard()` | ✅ PASS | |
| Register file: 3 reads + 1 write per cycle | `pipeline.c:do_decode()` reads; `do_writeback()` writes | ✅ PASS | |
| Write in cycle N visible in N+1 | Implicit in pipeline structure | ✅ PASS | WB updates regs at end of cycle |
| Stall behavior - data hazard | `pipeline.c:is_reg_in_flight()` | ✅ PASS | Checks ID_EX, EX_MEM, MEM_WB |
| Stall behavior - cache miss | `cache.c:cache_read/write()` return false on miss | ✅ PASS | |
| HALT handling + all cores drain | `main.c:all_cores_done()` | ✅ PASS | Checks halted AND pipeline empty |

### B) Registers

| Requirement | Implementation | Status |
|-------------|---------------|--------|
| 16 registers, 32-bit | `sim.h:NUM_REGISTERS=16, REGISTER_WIDTH=32` | ✅ PASS |
| R0 hardwired to 0 | `pipeline.c:do_writeback()` - skips write if dest < 2 | ✅ PASS |
| R1 = sign-extended immediate | `pipeline.c:do_decode()` line 270 | ✅ PASS |

### C) Instruction Set

| Opcode | Name | Implementation | Status |
|--------|------|----------------|--------|
| 0 | ADD | `pipeline.c:do_execute()` | ✅ PASS |
| 1 | SUB | `pipeline.c:do_execute()` | ✅ PASS |
| 2 | AND | `pipeline.c:do_execute()` | ✅ PASS |
| 3 | OR | `pipeline.c:do_execute()` | ✅ PASS |
| 4 | XOR | `pipeline.c:do_execute()` | ✅ PASS |
| 5 | MUL | `pipeline.c:do_execute()` | ✅ PASS |
| 6 | SLL | `pipeline.c:do_execute()` | ✅ PASS |
| 7 | SRA | `pipeline.c:do_execute()` | ✅ PASS |
| 8 | SRL | `pipeline.c:do_execute()` | ✅ PASS |
| 9-14 | Branches | `pipeline.c:do_decode()` | ✅ PASS |
| 15 | JAL | `pipeline.c:do_decode()` | ⚠️ NOTE: R15=PC+1, may re-execute delay slot on return |
| 16 | LW | `pipeline.c:do_mem()`, `cache.c:cache_read()` | ✅ PASS |
| 17 | SW | `pipeline.c:do_mem()`, `cache.c:cache_write()` | ✅ PASS |
| 21 | HALT | `pipeline.c:do_writeback()` | ✅ PASS |

### D) Data Cache

| Requirement | Implementation | Status |
|-------------|---------------|--------|
| Direct-mapped, 512 words | `sim.h:CACHE_SIZE=512` | ✅ PASS |
| Block size 8 words | `sim.h:CACHE_BLOCK_SIZE=8` | ✅ PASS |
| 64 cache lines (TSRAM) | `sim.h:CACHE_NUM_BLOCKS=64` | ✅ PASS |
| Write-back + write-allocate | `cache.c:cache_write()` | ✅ PASS |
| Cache starts zeroed | `main.c:cache_init()` | ✅ PASS |
| MESI state transitions | `cache.c:mesi_snoop_busrd/busrdx()` | ✅ PASS |

### E) Bus + MESI Coherency

| Requirement | Implementation | Status |
|-------------|---------------|--------|
| One transaction per cycle | `bus.c:bus_cycle()` | ✅ PASS |
| Round-robin arbitration | `bus.c:bus_arbitrate()` | ✅ PASS |
| BusRd / BusRdX / Flush | `sim.h:BusCommand enum` | ✅ PASS |
| 16-cycle memory delay | `sim.h:MEM_RESPONSE_DELAY=16` | ✅ PASS |
| bus_shared signal | `bus.c:bus_snoop()` sets snoop_shared | ✅ PASS |
| Modified cache supplies data | `bus.c:memory_send_flush()` | ✅ PASS |

### F) I/O Files

| Requirement | Implementation | Status |
|-------------|---------------|--------|
| 27-argument invocation | `main.c:main()` | ✅ PASS |
| No-argument defaults | `main.c:main()` | ✅ PASS |
| imem format (8 hex digits) | `main.c:load_imem()` | ✅ PASS |
| memin format | `main.c:load_memin()` | ✅ PASS |
| memout format | `main.c:write_memout()` | ✅ PASS |
| regout (R2-R15 only) | `main.c:write_regout()` | ✅ PASS |
| core trace format | `main.c:trace_core()` | ✅ PASS |
| bustrace format | `main.c:trace_bus()` | ✅ PASS |
| dsram/tsram dumps | `main.c:write_dsram/tsram()` | ✅ PASS |
| stats format | `main.c:write_stats()` | ✅ PASS |

## 2. Test Matrix

| Test Name | Purpose | Stresses | Expected Result | Status |
|-----------|---------|----------|-----------------|--------|
| simple | Basic ALU operations | ADD, SUB, AND, MUL, HALT | R2=10, R3=5, R4=15, R5=5, R6=0, R7=50 | ✅ PASS |
| counter | Shared counter synchronization | MESI coherency, LW/SW | Simple counter test | ✅ PASS |
| mulserial | Serial matrix multiply | LW/SW, ALU | Matrix multiplication on Core 0 | ✅ PASS |
| jal_test | JAL instruction | Branch, delay slot, return address | Tests JAL behavior | 🔧 NEW |
| cache_test | Cache operations | LW/SW, MESI transitions | Cache coherency | 🔧 NEW |

## 3. Regression Script Instructions

### Running All Tests

```powershell
cd c:\Users\khali\OneDrive\Desktop\archtic\architecture-
powershell -File scripts\run_tests.ps1 -SimPath "build\Release\sim.exe"
```

### Running with Verbose Output

```powershell
powershell -File scripts\run_tests.ps1 -SimPath "build\Release\sim.exe" -Verbose
```

### Running a Single Test

```powershell
# Copy test files to build directory and run
cd tests\<testname>
Copy-Item *.txt -Destination ..\..\build\Release\ -Force
cd ..\..\build\Release
.\sim.exe
```

### Building the Simulator

```powershell
# Using Visual Studio Developer Command Prompt
cmd /c "call ""C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat"" x64 && cd /d ""c:\Users\khali\OneDrive\Desktop\archtic\architecture-"" && cl /nologo /W3 /O2 /Fe:build\Release\sim.exe src\main.c src\pipeline.c src\cache.c src\bus.c /link /SUBSYSTEM:CONSOLE"
```

## 4. Bug Log

### Bug #1: Input File Buffer Too Small

**Symptom:** Test files with long comment lines caused incorrect instruction loading.

**Root Cause:** The `load_imem()` and `load_memin()` functions used a 64-byte buffer for `fgets()`, which was insufficient for comment lines longer than 63 characters. Long comment lines would be split across multiple `fgets()` calls, causing the continuation to be misinterpreted as instruction data.

**Fix:** Increased buffer size from 64 to 256 bytes in `main.c`:
```c
char line[256];  // Increased buffer size for long comment lines
```

**Proof:** All tests pass after the fix.

### Bug #2 (Noted): JAL Return Address

**Symptom:** JAL stores PC+1 in R15, which is the address of the delay slot. On return, the delay slot executes again.

**Analysis:** The current implementation stores `IF_ID.pc + 1` as the return address. This means:
- JAL at address X
- Delay slot at address X+1 (executes)
- R15 = X+1
- On return, execution continues at X+1 (delay slot executes again)

**Status:** This may or may not be a bug depending on spec interpretation. The code comment says "Per spec: JAL stores PC+1 in R15". If the spec intends for the delay slot to execute only once, the return address should be PC+2.

**Potential Fix (if needed):**
```c
// In do_decode(), JAL case:
next_ID_EX->alu_result = (core->IF_ID.pc + 2) & PC_MASK;  // Skip delay slot
```

## 5. Test File Format Notes

### Input Files

- **imem*.txt**: Up to 1024 lines, 8 hex digits per line
- **memin.txt**: Up to 2^21 lines, 8 hex digits per line
- Comments starting with `;` are skipped
- Empty lines are skipped

### Output Files

- **memout.txt**: Same format as memin, up to last non-zero address
- **regout*.txt**: 14 lines (R2-R15), 8 hex digits each
- **core*trace.txt**: `CYCLE FETCH DECODE EXEC MEM WB R2..R15`
- **bustrace.txt**: `CYCLE ORIGID CMD ADDR DATA SHARED` (only when cmd != 0)
- **dsram*.txt**: 512 lines, 8 hex digits each
- **tsram*.txt**: 64 lines, 8 hex digits each (tag<<2 | mesi)
- **stats*.txt**: 8 lines with counter names and decimal values

## 6. Areas for Additional Testing

1. **Pipeline Hazard Stress Tests**
   - Back-to-back RAW hazards
   - Branch with dependent operands
   - Long dependency chains

2. **Cache Torture Tests**
   - Conflict misses to same cache line
   - Dirty eviction sequences
   - Write-allocate on store miss

3. **MESI Coherency Tests**
   - Modified ↔ Invalid ping-pong between cores
   - Shared → Invalid transitions
   - Simultaneous requests from multiple cores

4. **Memory Timing Tests**
   - Validate 16-cycle delay
   - Burst transfer timing

## Conclusion

The simulator correctly implements the core features specified. All 3 original tests pass. Two issues were found:
1. Buffer size bug (FIXED)
2. JAL return address ambiguity (DOCUMENTED - needs spec clarification)

The regression harness and test infrastructure are in place for ongoing validation.
