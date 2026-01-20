# Requirements Checklist

This document maps each spec requirement to its implementation location and verification test.

---

## ISA Requirements

| ID | Requirement | Implementation | Test |
|----|-------------|----------------|------|
| FIX-1 | HALT opcode = 20 | `include/sim.h:OP_HALT = 20` | halt_test |
| FIX-2 | Branch target = R[rd] & 0x3FF | `src/pipeline.c:do_decode()` line ~283 | branch_test |
| FIX-3 | JAL: R15 = pc+1, pc = R[rd] & 0x3FF | `src/pipeline.c:do_decode()` line ~299-305 | jal_test |

---

## Register File Requirements

| ID | Requirement | Implementation | Test |
|----|-------------|----------------|------|
| FIX-4 | Write visible next cycle only | `src/pipeline.c:check_hazards()` | hazard_test |

---

## Cache Requirements

| ID | Requirement | Implementation | Test |
|----|-------------|----------------|------|
| FIX-5 | DSRAM/TSRAM init to zero | `src/cache.c:cache_init()` memset | simple |
| FIX-11 | TSRAM format [13:12]=MESI [11:0]=TAG | `src/main.c:write_tsram()` | mulserial |
| FIX-12 | Word-addressed memory | All address calculations | all tests |

---

## Bus Protocol Requirements

| ID | Requirement | Implementation | Test |
|----|-------------|----------------|------|
| FIX-6 | ORIGID: cores 0-3, memory=4 | `include/sim.h:BUS_ORIG_MEMORY = 4` | mulserial |
| FIX-7 | One transaction per cycle, round-robin | `src/bus.c:bus_arbitrate()` | counter |
| FIX-8 | bus_shared signal for E/S state | `src/bus.c` + `src/cache.c:cache_snoop()` | mulserial |
| FIX-13 | M-owner flush updates memory | `src/bus.c:memory_send_flush()` line 126-127 | mulserial |

---

## Simulation Control Requirements

| ID | Requirement | Implementation | Test |
|----|-------------|----------------|------|
| FIX-9 | All cores halted + pipelines empty | `src/main.c:all_cores_done()` | all tests |
| FIX-10 | CLI: 27-arg and no-arg modes | `src/main.c:main()` argc handling | manual |

---

## Output Format Requirements

| ID | Requirement | Implementation | Test |
|----|-------------|----------------|------|
| FORMAT-1 | Core trace: decimal cycle, 3-hex/--- PCs, 8-hex regs | `src/main.c:trace_core()` | all tests |
| FORMAT-2 | Bus trace: 1-hex origid/cmd/shared, 6-hex addr, 8-hex data | `src/main.c:trace_bus()` | mulserial |
| FORMAT-3 | regout: R2-R15 only, 8-hex | `src/main.c:write_regout()` | all tests |

---

## Required Test Requirements

| ID | Requirement | Location | Status |
|----|-------------|----------|--------|
| TEST-1 | mulparallel test | `tests/mulparallel/` | ✅ PASS |
| TEST-2 | counter test (4x128 increments) | `tests/counter/` | ✅ PASS |
| TEST-3 | mulserial test (matrix multiply) | `tests/mulserial/` | ✅ PASS |

---

## Micro-Test Coverage

| Test | Verifies | Status |
|------|----------|--------|
| halt_test | HALT opcode = 20, termination | ✅ PASS |
| branch_test | Branch target from R[rd] | ✅ PASS |
| jal_test | JAL return address and jump | ✅ PASS |
| hazard_test | RAW hazard detection and stall | ✅ PASS |
| simple | Basic ALU operations | ✅ PASS |

---

## Regression Test Summary

```
Total Tests: 8
Passing: 8
Failing: 0
```

Run with: `scripts\run_regression.ps1`
