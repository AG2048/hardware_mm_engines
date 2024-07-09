# This file is public domain, it can be freely copied without restrictions.
# SPDX-License-Identifier: CC0-1.0

TOPLEVEL_LANG ?= verilog
SIM ?= icarus

PWD=$(shell pwd)

# Matrix parameters
DATA_WIDTH ?= 8
N ?= 4    
MULTIPLY_DATA_WIDTH ?= 16
ACCUM_DATA_WIDTH ?= 16


VERILOG_SOURCES = $(PWD)/../hdl/matrix_multiplier.sv

# Set module parameters
ifeq ($(SIM),icarus)
		COMPILE_ARGS += -Pmatrix_multiplier.DATA_WIDTH=$(DATA_WIDTH) -Pmatrix_multiplier.A_ROWS=$(A_ROWS) -Pmatrix_multiplier.B_COLUMNS=$(B_COLUMNS) -Pmatrix_multiplier.A_COLUMNS_B_ROWS=$(A_COLUMNS_B_ROWS)
else ifneq ($(filter $(SIM),questa modelsim riviera activehdl),)
		SIM_ARGS += -gDATA_WIDTH=$(DATA_WIDTH) -gA_ROWS=$(A_ROWS) -gB_COLUMNS=$(B_COLUMNS) -gA_COLUMNS_B_ROWS=$(A_COLUMNS_B_ROWS)
else ifeq ($(SIM),vcs)
		COMPILE_ARGS += -pvalue+matrix_multiplier/DATA_WIDTH=$(DATA_WIDTH) -pvalue+matrix_multiplier/A_ROWS=$(A_ROWS) -pvalue+matrix_multiplier/B_COLUMNS=$(B_COLUMNS) -pvalue+matrix_multiplier/A_COLUMNS_B_ROWS=$(A_COLUMNS_B_ROWS)
else ifeq ($(SIM),verilator)
		COMPILE_ARGS += -GDATA_WIDTH=$(DATA_WIDTH) -GA_ROWS=$(A_ROWS) -GB_COLUMNS=$(B_COLUMNS) -GA_COLUMNS_B_ROWS=$(A_COLUMNS_B_ROWS)
else ifneq ($(filter $(SIM),ius xcelium),)
		EXTRA_ARGS += -defparam "matrix_multiplier.DATA_WIDTH=$(DATA_WIDTH)" -defparam "matrix_multiplier.A_ROWS=$(A_ROWS)" -defparam "matrix_multiplier.B_COLUMNS=$(B_COLUMNS)" -defparam "matrix_multiplier.A_COLUMNS_B_ROWS=$(A_COLUMNS_B_ROWS)"
endif

ifneq ($(filter $(SIM),riviera activehdl),)
		COMPILE_ARGS += -sv2k12
endif


# Fix the seed to ensure deterministic tests
export RANDOM_SEED := 123456789

TOPLEVEL    := sum_stationary
MODULE      := sum_stationary_tb

include $(shell cocotb-config --makefiles)/Makefile.sim


# Profiling

DOT_BINARY ?= dot

test_profile.pstat: sim

callgraph.svg: test_profile.pstat
	$(shell cocotb-config --python-bin) -m gprof2dot -f pstats ./$< | $(DOT_BINARY) -Tsvg -o $@

.PHONY: profile
profile:
	COCOTB_ENABLE_PROFILING=1 $(MAKE) callgraph.svg