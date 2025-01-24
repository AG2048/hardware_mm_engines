# This file is public domain, it can be freely copied without restrictions.
# SPDX-License-Identifier: CC0-1.0

TOPLEVEL_LANG ?= verilog
SIM ?= modelsim

PWD=$(shell pwd)

# Matrix parameters
DATA_WIDTH ?= 8
N ?= 4
MULTIPLY_DATA_WIDTH ?= 16
ACCUM_DATA_WIDTH ?= 3


VERILOG_SOURCES = $(PWD)/../hdl/processor.sv

# Set module parameters
ifeq ($(SIM),icarus)
		COMPILE_ARGS += -Pprocessor.DATA_WIDTH=$(DATA_WIDTH) -Pprocessor.N=$(N) -Pprocessor.MULTIPLY_DATA_WIDTH=$(MULTIPLY_DATA_WIDTH) -Pprocessor.ACCUM_DATA_WIDTH=$(ACCUM_DATA_WIDTH)
else ifneq ($(filter $(SIM),questa modelsim riviera activehdl),)
		SIM_ARGS += -gDATA_WIDTH=$(DATA_WIDTH) -gN=$(N) -gMULTIPLY_DATA_WIDTH=$(MULTIPLY_DATA_WIDTH) -gACCUM_DATA_WIDTH=$(ACCUM_DATA_WIDTH)
else ifeq ($(SIM),vcs)
		COMPILE_ARGS += -pvalue+processor/DATA_WIDTH=$(DATA_WIDTH) -pvalue+processor/N=$(N) -pvalue+processor/MULTIPLY_DATA_WIDTH=$(MULTIPLY_DATA_WIDTH) -pvalue+processor/ACCUM_DATA_WIDTH=$(ACCUM_DATA_WIDTH)
else ifeq ($(SIM),verilator)
		COMPILE_ARGS += -GDATA_WIDTH=$(DATA_WIDTH) -GN=$(N) -GMULTIPLY_DATA_WIDTH=$(MULTIPLY_DATA_WIDTH) -GACCUM_DATA_WIDTH=$(ACCUM_DATA_WIDTH)
else ifneq ($(filter $(SIM),ius xcelium),)
		EXTRA_ARGS += -defparam "processor.DATA_WIDTH=$(DATA_WIDTH)" -defparam "processor.A_ROWS=$(A_ROWS)" -defparam "processor.B_COLUMNS=$(B_COLUMNS)" -defparam "processor.A_COLUMNS_B_ROWS=$(A_COLUMNS_B_ROWS)"
endif

ifneq ($(filter $(SIM),riviera activehdl),)
		COMPILE_ARGS += -sv2k12
endif


# Fix the seed to ensure deterministic tests
export RANDOM_SEED := 123456789

TOPLEVEL    := processor
MODULE      := processor_tb

include $(shell cocotb-config --makefiles)/Makefile.sim


# Profiling

DOT_BINARY ?= dot

test_profile.pstat: sim

callgraph.svg: test_profile.pstat
	$(shell cocotb-config --python-bin) -m gprof2dot -f pstats ./$< | $(DOT_BINARY) -Tsvg -o $@

.PHONY: profile
profile:
	COCOTB_ENABLE_PROFILING=1 $(MAKE) callgraph.svg