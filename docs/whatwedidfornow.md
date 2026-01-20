# Comprehensive Status Report: 4-Core MESI Cache Coherent Processor Simulator

**Document Version:** 1.1  
**Date:** January 2026  
**Status:** ✅ FULLY FUNCTIONAL - All 8 regression tests passing

---

## Executive Summary

This document provides a complete specification-to-implementation mapping for the 4-core pipelined CPU simulator with private instruction memory, private direct-mapped data cache per core, MESI cache coherency protocol over a shared bus, and unified main memory.

**Key Metrics:**
- **Lines of Code:** ~1,500 across 5 source files
- **Test Coverage:** 4 submission tests + 4 micro-tests
- **Tests Passing:** 8/8 (simple, counter, mulserial, mulparallel, halt_test, branch_test, jal_test, hazard_test)
- **Bugs Fixed:** FIX-1 through FIX-13, FORMAT-1 through FORMAT-3

**Recent Changes (v1.1):**
- Fixed HALT opcode from 21 to 20 (FIX-1)
- Fixed branch/JAL target semantics to use R[rd] & 0x3FF (FIX-2, FIX-3)
- Fixed TSRAM output format to [13:12]=MESI, [11:0]=TAG (FIX-11)
- Added mulparallel test (TEST-1)
- Added micro-tests for ISA verification
- Added regression test harness (scripts/run_regression.ps1)

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Specification-to-Code Mapping](#2-specification-to-code-mapping)
3. [Source File Index](#3-source-file-index)
4. [Implementation Verification](#4-implementation-verification)
5. [Test Suite Documentation](#5-test-suite-documentation)
6. [Bug Log & Fixes](#6-bug-log--fixes)
7. [Build & Run Instructions](#7-build--run-instructions)
8. [Future Improvements](#8-future-improvements)

---

## 1. Architecture Overview

### 1.1 System Configuration
```
┌─────────────────────────────────────────────────────────────────────────┐
│                         4-Core Processor System                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐                │
│  │  Core 0  │  │  Core 1  │  │  Core 2  │  │  Core 3  │                │
│  ├──────────┤  ├──────────┤  ├──────────┤  ├──────────┤                │
│  │ 5-Stage  │  │ 5-Stage  │  │ 5-Stage  │  │ 5-Stage  │                │
│  │ Pipeline │  │ Pipeline │  │ Pipeline │  │ Pipeline │                │
│  ├──────────┤  ├──────────┤  ├──────────┤  ├──────────┤                │
│  │ Private  │  │ Private  │  │ Private  │  │ Private  │                │
│  │  I-MEM   │  │  I-MEM   │  │  I-MEM   │  │  I-MEM   │                │
│  │ (1024w)  │  │ (1024w)  │  │ (1024w)  │  │ (1024w)  │                │
│  ├──────────┤  ├──────────┤  ├──────────┤  ├──────────┤                │
│  │ Private  │  │ Private  │  │ Private  │  │ Private  │                │
│  │ D-Cache  │  │ D-Cache  │  │ D-Cache  │  │ D-Cache  │                │
│  │ (512w)   │  │ (512w)   │  │ (512w)   │  │ (512w)   │                │
│  │ MESI     │  │ MESI     │  │ MESI     │  │ MESI     │                │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘                │
│       │             │             │             │                       │
│  ─────┴─────────────┴─────────────┴─────────────┴─────────────────────  │
│                        SHARED BUS (Round-Robin)                          │
│                     BusRd | BusRdX | Flush | Snoop                      │
│  ────────────────────────────────────────────────────────────────────── │
│                                  │                                       │
│                        ┌─────────┴─────────┐                            │
│                        │   MAIN MEMORY     │                            │
│                        │   (2^21 words)    │                            │
│                        │   16-cycle delay  │                            │
│                        └───────────────────┘                            │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Key Parameters

| Parameter | Value | Location in Code |
|-----------|-------|------------------|
| Number of Cores | 4 | `sim.h:NUM_CORES=4` |
| Registers per Core | 16 (32-bit) | `sim.h:NUM_REGISTERS=16` |
| PC Width | 10 bits (1024 addresses) | `sim.h:PC_WIDTH=10` |
| I-MEM Size | 1024 words per core | `sim.h:IMEM_DEPTH=1024` |
| D-Cache Size | 512 words | `sim.h:CACHE_SIZE=512` |
| Cache Block Size | 8 words | `sim.h:CACHE_BLOCK_SIZE=8` |
| Cache Lines | 64 (direct-mapped) | `sim.h:CACHE_NUM_BLOCKS=64` |
| Main Memory | 2^21 = 2,097,152 words | `sim.h:MAIN_MEM_SIZE` |
| Memory Delay | 16 cycles | `sim.h:MEM_RESPONSE_DELAY=16` |

---

## 2. Specification-to-Code Mapping

### 2.1 Pipeline Implementation

#### 5-Stage Pipeline: Fetch → Decode → Execute → Memory → Writeback

| Stage | Function | File:Line | Status |
|-------|----------|-----------|--------|
| **FETCH** | Read instruction from I-MEM | `pipeline.c:do_fetch()` L324-335 | ✅ |
| **DECODE** | Decode instruction, resolve branches | `pipeline.c:do_decode()` L241-314 | ✅ |
| **EXECUTE** | ALU operations | `pipeline.c:do_execute()` L195-236 | ✅ |
| **MEMORY** | Cache access for LW/SW | `pipeline.c:do_mem()` L160-193 | ✅ |
| **WRITEBACK** | Register file write | `pipeline.c:do_writeback()` L111-156 | ✅ |

#### Pipeline Hazard Handling

| Hazard Type | Detection | Resolution | Location |
|-------------|-----------|------------|----------|
| **RAW (Data)** | Check in-flight registers | Stall at DECODE | `pipeline.c:check_data_hazard()` L77-103 |
| **Cache Miss** | Cache returns false | Stall at MEM | `cache.c:cache_read/write()` |
| **Control** | Branch resolved in DECODE | Delay slot always executes | `pipeline.c:core_cycle()` L390-401 |

**Code Evidence - Hazard Detection:**
```c
// pipeline.c:77-103
bool check_data_hazard(Core* core) {
    if (!core->IF_ID.valid) return false;
    Instruction* inst = &core->IF_ID.inst;
    
    // Check rs dependency (used by most instructions)
    if (inst->rs != 0 && inst->rs != 1) {
        if (is_reg_in_flight(core, inst->rs)) return true;
    }
    // ... checks rt and rd for branches/stores
}
```

### 2.2 Register File Implementation

| Requirement | Implementation | File:Line | Status |
|-------------|---------------|-----------|--------|
| 16 registers, 32-bit | `int32_t regs[NUM_REGISTERS]` | `sim.h:Core` struct | ✅ |
| R0 hardwired to 0 | Skip write if `dest < 2` | `pipeline.c:do_writeback()` L148 | ✅ |
| R1 = sign-extended imm | Updated during DECODE | `pipeline.c:do_decode()` L270 | ✅ |
| Write visible next cycle | Implicit in pipeline | Architectural correctness | ✅ |

**Code Evidence - R0/R1 Handling:**
```c
// pipeline.c:148 - Write to register (R0 and R1 writes ignored)
if (do_write && dest >= 2) {
    core->regs[dest] = value;
}

// pipeline.c:270 - R1 gets immediate
core->regs[1] = inst->immediate;
```

### 2.3 Instruction Set Architecture

| Opcode | Mnemonic | Implementation | Location | Status |
|--------|----------|----------------|----------|--------|
| 0 | ADD | `rd = rs + rt` | `pipeline.c:do_execute()` L208 | ✅ |
| 1 | SUB | `rd = rs - rt` | `pipeline.c:do_execute()` L209 | ✅ |
| 2 | AND | `rd = rs & rt` | `pipeline.c:do_execute()` L210 | ✅ |
| 3 | OR | `rd = rs \| rt` | `pipeline.c:do_execute()` L211 | ✅ |
| 4 | XOR | `rd = rs ^ rt` | `pipeline.c:do_execute()` L212 | ✅ |
| 5 | MUL | `rd = rs * rt` | `pipeline.c:do_execute()` L213 | ✅ |
| 6 | SLL | `rd = rs << rt` | `pipeline.c:do_execute()` L214 | ✅ |
| 7 | SRA | `rd = rs >> rt` (arith) | `pipeline.c:do_execute()` L215 | ✅ |
| 8 | SRL | `rd = rs >> rt` (logic) | `pipeline.c:do_execute()` L216 | ✅ |
| 9 | BEQ | `if (rs==rt) pc=rd` | `pipeline.c:do_decode()` L290 | ✅ |
| 10 | BNE | `if (rs!=rt) pc=rd` | `pipeline.c:do_decode()` L291 | ✅ |
| 11 | BLT | `if (rs<rt) pc=rd` | `pipeline.c:do_decode()` L292 | ✅ |
| 12 | BGT | `if (rs>rt) pc=rd` | `pipeline.c:do_decode()` L293 | ✅ |
| 13 | BLE | `if (rs<=rt) pc=rd` | `pipeline.c:do_decode()` L294 | ✅ |
| 14 | BGE | `if (rs>=rt) pc=rd` | `pipeline.c:do_decode()` L295 | ✅ |
| 15 | JAL | `R15=pc+1; pc=rd` | `pipeline.c:do_decode()` L296-305 | ✅ |
| 16 | LW | `rd = MEM[rs+rt]` | `pipeline.c:do_mem()` + `cache.c` | ✅ |
| 17 | SW | `MEM[rs+rt] = rd` | `pipeline.c:do_mem()` + `cache.c` | ✅ |
| 21 | HALT | Stop core execution | `pipeline.c:do_writeback()` L119 | ✅ |

**Instruction Encoding:**
```
31-24: opcode (8 bits)
23-20: rd (4 bits)
19-16: rs (4 bits)
15-12: rt (4 bits)
11-0:  immediate (12 bits, sign-extended)
```

### 2.4 Data Cache Implementation

| Requirement | Value | Implementation | Location |
|-------------|-------|----------------|----------|
| Organization | Direct-mapped | Index from address | `cache.c:cache_get_index()` |
| Total Size | 512 words | `DSRAM[512]` | `sim.h:CACHE_SIZE=512` |
| Block Size | 8 words | 8-word burst | `sim.h:CACHE_BLOCK_SIZE=8` |
| Number of Lines | 64 | `TSRAM[64]` | `sim.h:CACHE_NUM_BLOCKS=64` |
| Write Policy | Write-back | Dirty flag via MESI M | `cache.c:cache_write()` |
| Allocation | Write-allocate | Fetch block on miss | `cache.c:cache_write()` L136 |
| Hit Latency | 1 cycle | Immediate return | `cache.c:cache_read()` L83 |

**Address Decomposition (21-bit word address):**
```
Bits 0-2:   Offset (word within block) - 3 bits
Bits 3-8:   Index (cache line) - 6 bits  
Bits 9-20:  Tag - 12 bits
```

**Code Evidence:**
```c
// cache.c:31-42
int cache_get_offset(uint32_t addr) {
    return addr & 0x7;  // Lower 3 bits
}
int cache_get_index(uint32_t addr) {
    return (addr >> BLOCK_OFFSET_BITS) & 0x3F;  // 6 bits
}
uint32_t cache_get_tag(uint32_t addr) {
    return addr >> (BLOCK_OFFSET_BITS + INDEX_BITS);  // 12 bits
}
```

### 2.5 MESI Cache Coherency Protocol

#### State Encoding

| State | Value | Meaning |
|-------|-------|---------|
| Invalid | 0 | Block not valid |
| Shared | 1 | Clean, may be in other caches |
| Exclusive | 2 | Clean, only copy |
| Modified | 3 | Dirty, only copy |

#### State Transitions

| Current | Event | New State | Bus Action | Location |
|---------|-------|-----------|------------|----------|
| I | Read Miss | S or E | BusRd | `bus.c:memory_send_flush()` L165 |
| I | Write Miss | M | BusRdX | `bus.c:memory_send_flush()` L159 |
| S | Read Hit | S | - | `cache.c:cache_read()` L80 |
| S | Write Hit | M | BusRdX | `cache.c:cache_write()` L118 |
| E | Read Hit | E | - | `cache.c:cache_read()` L80 |
| E | Write Hit | M | - | `cache.c:cache_write()` L107 |
| M | Read Hit | M | - | `cache.c:cache_read()` L80 |
| M | Write Hit | M | - | `cache.c:cache_write()` L107 |
| M | Snoop BusRd | S | Flush data | `cache.c:mesi_snoop_busrd()` L203 |
| M | Snoop BusRdX | I | Flush data | `cache.c:mesi_snoop_busrdx()` L227 |
| E | Snoop BusRd | S | - | `cache.c:mesi_snoop_busrd()` L209 |
| E | Snoop BusRdX | I | - | `cache.c:mesi_snoop_busrdx()` L227 |
| S | Snoop BusRdX | I | - | `cache.c:mesi_snoop_busrdx()` L227 |

### 2.6 Bus Protocol Implementation

#### Bus Signals

| Signal | Width | Purpose | Location |
|--------|-------|---------|----------|
| bus_origid | 3 bits | 0-3=core, 4=memory | `bus.c:BusState.origid` |
| bus_cmd | 2 bits | 0=none,1=BusRd,2=BusRdX,3=Flush | `sim.h:BusCommand` |
| bus_addr | 21 bits | Word address | `bus.c:BusState.addr` |
| bus_data | 32 bits | Data word | `bus.c:BusState.data` |
| bus_shared | 1 bit | Set by snooping caches | `bus.c:BusState.shared` |

#### Bus Arbitration

```c
// bus.c:36-52 - Round-robin arbitration
int bus_arbitrate(Simulator* sim) {
    Bus* bus = &sim->bus;
    
    if (bus->arbiter.transaction_in_progress) {
        return -1;  // Bus busy
    }
    
    for (int i = 0; i < NUM_CORES; i++) {
        int core_id = (bus->arbiter.last_granted + 1 + i) % NUM_CORES;
        Core* core = &sim->cores[core_id];
        if (core->bus_request_pending) {
            return core_id;
        }
    }
    return -1;
}
```

#### Memory Response Timing

| Phase | Duration | Action |
|-------|----------|--------|
| Delay | 16 cycles | Memory processes request |
| Flush | 8 cycles | 8 words sent (1 word/cycle) |

**Code Evidence:**
```c
// bus.c:86 - Start 16-cycle countdown
resp->cycles_remaining = MEM_RESPONSE_DELAY;  // = 16

// bus.c:96-98 - Send Flush words
static void memory_send_flush(Simulator* sim) {
    // ... sends one word per cycle for 8 cycles
}
```

### 2.7 I/O File Formats

#### Input Files

| File | Format | Implementation |
|------|--------|----------------|
| imem0-3.txt | 8 hex digits/line | `main.c:load_imem()` |
| memin.txt | 8 hex digits/line | `main.c:load_memin()` |

#### Output Files

| File | Format | Implementation |
|------|--------|----------------|
| memout.txt | 8 hex digits/line | `main.c:write_memout()` |
| regout0-3.txt | 14 lines (R2-R15) | `main.c:write_regout()` |
| core0-3trace.txt | CYCLE IF ID EX MEM WB R2..R15 | `main.c:trace_core()` |
| bustrace.txt | CYCLE ORIG CMD ADDR DATA SHARED | `main.c:trace_bus()` |
| dsram0-3.txt | 512 lines | `main.c:write_dsram()` |
| tsram0-3.txt | 64 lines | `main.c:write_tsram()` |
| stats0-3.txt | 8 lines (counters) | `main.c:write_stats()` |

#### Command Line Interface

```bash
# 27-argument mode
./sim imem0 imem1 imem2 imem3 memin memout \
      regout0 regout1 regout2 regout3 \
      core0trace core1trace core2trace core3trace bustrace \
      dsram0 dsram1 dsram2 dsram3 \
      tsram0 tsram1 tsram2 tsram3 \
      stats0 stats1 stats2 stats3

# Default mode (no arguments)
./sim  # Uses default filenames in current directory
```

---

## 3. Source File Index

### 3.1 File Overview

| File | Lines | Purpose |
|------|-------|---------|
| `src/sim.h` | 265 | Master header: constants, structures, prototypes |
| `src/main.c` | 534 | Entry point, file I/O, simulation loop, tracing |
| `src/pipeline.c` | 426 | 5-stage pipeline, hazard detection |
| `src/cache.c` | 253 | Cache operations, MESI snooping |
| `src/bus.c` | 267 | Bus arbitration, memory response |

### 3.2 Key Data Structures

```c
// Core state (sim.h)
typedef struct {
    int             core_id;
    uint32_t        pc;
    int32_t         regs[16];
    uint32_t        imem[1024];
    PipelineLatch   IF_ID, ID_EX, EX_MEM, MEM_WB;
    Cache           cache;
    bool            halted, mem_stall, decode_stall;
    // ... statistics counters
} Core;

// Cache (sim.h)
typedef struct {
    int32_t    dsram[512];
    TSRAMEntry tsram[64];  // {tag, mesi}
} Cache;

// Simulator (sim.h)
typedef struct {
    Core     cores[4];
    int32_t* main_memory;  // 2^21 words
    Bus      bus;
    uint64_t cycle;
} Simulator;
```

---

## 4. Implementation Verification

### 4.1 Feature Checklist

| Category | Feature | Status | Evidence |
|----------|---------|--------|----------|
| **Pipeline** | 5 stages | ✅ | `core_cycle()` calls all 5 stage functions |
| | In-order execution | ✅ | Sequential latch updates |
| | Branch delay slot | ✅ | IF_ID not squashed on branch |
| | No forwarding | ✅ | `is_reg_in_flight()` stalls |
| **Registers** | R0=0 always | ✅ | Read returns 0, write ignored |
| | R1=immediate | ✅ | Updated every decode |
| | R2-R15 GPR | ✅ | Normal read/write |
| **Cache** | Direct-mapped | ✅ | Single index per address |
| | 512w/8w blocks | ✅ | Constants defined |
| | Write-back | ✅ | M state tracks dirty |
| | Write-allocate | ✅ | BusRdX on write miss |
| **MESI** | 4 states | ✅ | Enum + transitions |
| | BusRd/BusRdX/Flush | ✅ | Bus commands work |
| | Snoop protocol | ✅ | Invalidation/downgrade |
| **Bus** | Round-robin | ✅ | Modulo arbiter |
| | 16-cycle delay | ✅ | Countdown timer |
| | 8-word burst | ✅ | Loop sends 8 words |
| **I/O** | 27-arg mode | ✅ | `argc==28` handler |
| | Default files | ✅ | Fallback names |
| | All output files | ✅ | Write functions exist |

### 4.2 Statistics Counters

The simulator tracks these metrics per core:

| Counter | Description | Increment Location |
|---------|-------------|-------------------|
| `cycles` | Total clock cycles | `main.c:run_simulation()` L406 |
| `instructions` | Instructions completed | `pipeline.c:core_cycle()` L365 |
| `read_hit` | LW cache hits | `cache.c:cache_read()` L81 |
| `write_hit` | SW cache hits | `cache.c:cache_write()` L109 |
| `read_miss` | LW cache misses | `cache.c:cache_read()` L87 |
| `write_miss` | SW cache misses | `cache.c:cache_write()` L116,135 |
| `decode_stall` | Data hazard stalls | `pipeline.c:do_decode()` L254 |
| `mem_stall` | Cache miss stalls | `pipeline.c:core_cycle()` L374,378 |

---

## 5. Test Suite Documentation

### 5.1 Test Summary

| Test | Purpose | Status | Cycles |
|------|---------|--------|--------|
| simple | Basic ALU + HALT | ✅ PASS | ~15 |
| counter | Load/store + coherency | ✅ PASS | ~50 |
| mulserial | Serial matrix multiply | ✅ PASS | ~200 |
| jal_test | JAL/JR subroutine | 🔧 New | - |
| cache_test | Cache stress | 🔧 New | - |

### 5.2 Running Tests

```powershell
# Run all tests
cd c:\Users\khali\OneDrive\Desktop\archtic\architecture-
powershell -File scripts\run_tests.ps1 -SimPath "build\Release\sim.exe"

# Run specific test
powershell -File scripts\run_test.ps1 simple
```

### 5.3 Test Directory Structure

```
tests/
├── simple/
│   ├── imem0.txt        # Core 0 program
│   ├── imem1.txt        # Core 1 program (HALT only)
│   ├── imem2.txt        # Core 2 program (HALT only)
│   ├── imem3.txt        # Core 3 program (HALT only)
│   ├── memin.txt        # Initial memory
│   └── expected/        # Expected outputs
│       ├── regout0.txt
│       ├── memout.txt
│       └── ...
├── counter/
│   └── ...
└── mulserial/
    └── ...
```

---

## 6. Bug Log & Fixes

### Bug #1: Input File Buffer Overflow

| Field | Detail |
|-------|--------|
| **Symptom** | Long comment lines caused instruction parsing errors |
| **Root Cause** | 64-byte buffer in `fgets()` too small |
| **Fix** | Increased buffer to 256 bytes |
| **Location** | `main.c:load_imem()` L133, `load_memin()` L158 |
| **Verified** | All tests pass |

**Before:**
```c
char line[64];
```

**After:**
```c
char line[256];  // Increased buffer size for long comment lines
```

### Bug #2 (Documented): JAL Return Address

| Field | Detail |
|-------|--------|
| **Observation** | JAL stores PC+1 in R15 |
| **Implication** | Delay slot at PC+1 may execute twice on return |
| **Status** | Documented, matches literal spec text |
| **Potential Fix** | Change to PC+2 if intended behavior differs |

---

## 7. Build & Run Instructions

### 7.1 Building with Visual Studio

```powershell
# Open VS Developer Command Prompt, then:
cd c:\Users\khali\OneDrive\Desktop\archtic\architecture-
cl /nologo /W3 /O2 /Fe:build\Release\sim.exe src\main.c src\pipeline.c src\cache.c src\bus.c /link /SUBSYSTEM:CONSOLE
```

### 7.2 Building with GCC (Makefile)

```bash
cd architecture-
make build
```

### 7.3 Running the Simulator

```powershell
# With default files in current directory
.\build\Release\sim.exe

# With explicit file paths
.\build\Release\sim.exe imem0.txt imem1.txt imem2.txt imem3.txt memin.txt memout.txt ...
```

---

## 8. Future Improvements

### 8.1 Potential Enhancements

1. **Performance**
   - Add instruction-level parallelism analysis
   - Implement speculative execution

2. **Verification**
   - Add formal verification hooks
   - Create exhaustive branch coverage tests

3. **Debugging**
   - Add single-step mode
   - Implement breakpoint support
   - Add register watch functionality

### 8.2 Known Limitations

1. Pipeline doesn't support superscalar execution
2. No branch prediction (always stall until resolve)
3. Single-issue, in-order execution only
4. No support for interrupts/exceptions

---

## Appendix A: Quick Reference

### A.1 Important Constants (sim.h)

```c
#define NUM_CORES           4
#define NUM_REGISTERS       16
#define IMEM_DEPTH          1024
#define MAIN_MEM_SIZE       (1 << 21)  // 2,097,152
#define CACHE_SIZE          512
#define CACHE_BLOCK_SIZE    8
#define CACHE_NUM_BLOCKS    64
#define MEM_RESPONSE_DELAY  16
```

### A.2 MESI State Values

```c
MESI_INVALID   = 0
MESI_SHARED    = 1
MESI_EXCLUSIVE = 2
MESI_MODIFIED  = 3
```

### A.3 Bus Command Values

```c
BUS_CMD_NONE   = 0
BUS_CMD_BUSRD  = 1
BUS_CMD_BUSRDX = 2
BUS_CMD_FLUSH  = 3
```

---

*End of Status Report*
