# =============================================================================
# Makefile for Multi-Core MESI Simulator
# =============================================================================
# Build system for the 4-core MESI cache coherent processor simulator
# =============================================================================

# Compiler settings
CC = gcc
CFLAGS = -Wall -Wextra -O2 -std=c99 -Iinclude
LDFLAGS = 

# Directories
SRC_DIR = src
INC_DIR = include
BUILD_DIR = build/Release
OUTPUT_DIR = output

# Source files
SRCS = $(SRC_DIR)/main.c $(SRC_DIR)/pipeline.c $(SRC_DIR)/cache.c $(SRC_DIR)/bus.c
OBJS = $(BUILD_DIR)/main.o $(BUILD_DIR)/pipeline.o $(BUILD_DIR)/cache.o $(BUILD_DIR)/bus.o
TARGET = $(BUILD_DIR)/sim.exe

# Default target
all: build

# Build the simulator
build: $(BUILD_DIR) $(TARGET)
	@echo "Build complete: $(TARGET)"

# Create build directory
$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

# Link
$(TARGET): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $^

# Compile
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c $(INC_DIR)/sim.h | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c -o $@ $<

# Run all tests
test:
	@pwsh -File scripts/test_all.ps1

# Run single test
test-%:
	@pwsh -File scripts/run_test.ps1 $*

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@echo "Clean complete"

# Clean all (build + test outputs)
clean-all: clean
	@echo "Cleaning test outputs..."
	@rm -rf $(OUTPUT_DIR)
	@echo "Clean all complete"

# Debug build
debug: CFLAGS += -g -DDEBUG
debug: clean build

# Help
help:
	@echo "Multi-Core MESI Simulator - Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  make build      - Build the simulator (default)"
	@echo "  make test       - Run all tests"
	@echo "  make test-NAME  - Run specific test (e.g., make test-counter)"
	@echo "  make clean      - Remove build artifacts"
	@echo "  make clean-all  - Remove build + test outputs"
	@echo "  make debug      - Build with debug symbols"
	@echo "  make help       - Show this help"
	@echo ""
	@echo "For Windows (MSBuild):"
	@echo "  Use: MSBuild ide/sim.vcxproj /p:Configuration=Release /p:Platform=x64"

.PHONY: all build test clean clean-all debug help
