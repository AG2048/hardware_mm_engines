# This file is public domain, it can be freely copied without restrictions.
# SPDX-License-Identifier: CC0-1.0

import math
import os
import sys
from pathlib import Path
from random import getrandbits, randint
from typing import Any, Dict, List, Tuple

import cocotb
from cocotb.binary import BinaryValue
from cocotb.clock import Clock
from cocotb.handle import SimHandleBase
from cocotb.queue import Queue
from cocotb.runner import get_runner
from cocotb.triggers import RisingEdge, First

# Set num samples to 3000 if not defined in Makefile
NUM_SAMPLES = int(os.environ.get("NUM_SAMPLES", 2))
if cocotb.simulator.is_running():
    DATA_WIDTH = int(cocotb.top.DATA_WIDTH)
    N = int(cocotb.top.N)      
    MULTIPLY_DATA_WIDTH = int(cocotb.top.MULTIPLY_DATA_WIDTH)
    ACCUM_DATA_WIDTH = int(cocotb.top.ACCUM_DATA_WIDTH)

# Data reader - that asserts ready when instructed to start read data, not ready when stop. Checks for valid signals before reading.
#   reader(ready=True/False) - and it logs whatever value it read
class LIReader:
    def __init__(self, clk: SimHandleBase, signals: Dict[str, SimHandleBase], valid: SimHandleBase, ready: SimHandleBase):
        self.values = Queue[Dict[str, int]]()
        self._clk = clk
        self._signals = signals
        self._valid = valid
        self._ready = ready
        self._coro = None

    def start(self) -> None:
        """Start monitor"""
        if self._coro is not None:
            raise RuntimeError("Monitor already started")
        self._coro = cocotb.start_soon(self._run())  # Start a coroutine

    def stop(self) -> None:
        """Stop monitor"""
        if self._coro is None:
            raise RuntimeError("Monitor never started")
        self._coro.kill()
        self._coro = None
    
    def set_status(self, ready: bool):
        """Set so that the next rising edge we read or not"""
        self._ready.value = 1 if ready else 0

    async def _run(self) -> None:
        while True:
            await RisingEdge(self._clk)
            if self._valid.value.binstr != "1" or self._ready.value.binstr != "1":
                # Only proceed if both are ready. Wait until some signal is updated
                await First(RisingEdge(self._valid), RisingEdge(self._ready))
                continue
            # Both valid and ready are true on a rising clock edge
            self.values.put_nowait(self._sample())

    def _sample(self) -> Dict[str, Any]:
        """
        Samples the data signals and builds a transaction object

        Return value is what is stored in queue. Meant to be overriden by the user.
        """
        return {name: handle.value for name, handle in self._signals.items()}

# Data writer - asserts valid when prepared,
#   writer(valid=True/False, value)
class LIWriter:
    def __init__(self, clk: SimHandleBase, signals: SimHandleBase, valid: SimHandleBase, ready: SimHandleBase, last: SimHandleBase, sends_last: bool, input_length: int):
        self.values = Queue[Tuple[int, bool, bool]]()
        self._clk = clk
        self._signals = signals
        self._valid = valid
        self._ready = ready
        self._last = last
        self._sends_last = sends_last
        self._input_length = input_length
        self._coro = None

    def start(self) -> None:
        """Start monitor"""
        if self._coro is not None:
            raise RuntimeError("Monitor already started")
        self._coro = cocotb.start_soon(self._run())  # Start a coroutine

    def stop(self) -> None:
        """Stop monitor"""
        if self._coro is None:
            raise RuntimeError("Monitor never started")
        self._coro.kill()
        self._coro = None
    
    def set_status(self, input_data_and_valid):
        """
        input_data_and_valid would be tuples:
        ([data...], True),
        symbolize the data it will be displaying at each clock edge. 
        True data will wait until ready to be delivered.
        False data will remain false for 1 clock edge

        (added last boolean to be the "last" signal)
        """
        self.values.put_nowait(input_data_and_valid)

    async def _run(self) -> None:
        """
        Goal: iterate thru values, and write. If true, do proper wait. If False, wait a random number of cycles.
        """
        if self.values.empty():
            input_value, do_input, is_last = [0 for i in range(self._input_length)], False
        else:
            input_value, do_input, is_last = await self.values.get()
        while True:
            self._signals.value = input_value
            self._valid.value = do_input
            if self._sends_last:
                self._last.value = is_last
            if do_input:
                # We are writing
                # If ready true, await rising edge
                # if not, await ready true, then await rising edge.
                while True:
                    if self._ready.value.binstr != "1":
                        await RisingEdge(self._clk)
                        break
                    else:
                        await RisingEdge(self._ready)
            else:
                # We are not writing
                # Generate random value (1-3 probably)
                # await rising edge for random time
                wait_cycles = randint(1, 3)
                for _ in range(wait_cycles):
                    await RisingEdge(self._clk)

            if self.values.empty():
                input_value, do_input, is_last = [0 for i in range(self._input_length)], False
            else:
                input_value, do_input, is_last = self.values.get()


# Tester:
#   init = define itself, add the writer/reader.
#   start() starts
#   end() ends

# In the test:
"""
start clock
define tester

assert reset value

start tester()

do sequence of tests:
    await rising edge
    assert signals
    await rising edge...
    assert signals

"""


class MatrixMultiplierTester:
    """
    Reusable checker of a matrix_multiplier instance

    Args
        matrix_multiplier_entity: handle to an instance of matrix_multiplier
    """

    def __init__(self, matrix_multiplier_entity: SimHandleBase):
        self.dut = matrix_multiplier_entity

        self.a_input_writer = LIWriter(
            clk=self.dut.clk, 
            signals=self.dut.a_data, 
            valid=self.dut.a_input_valid, 
            ready=self.dut.input_ready, 
            last=self.dut.last,
            sends_last=True,
            input_length=N
        )

        self.b_input_writer = LIWriter(
            clk=self.dut.clk, 
            signals=self.dut.b_data, 
            valid=self.dut.b_input_valid, 
            ready=self.dut.input_ready, 
            last=None,
            sends_last=False,
            input_length=N
        )

        self.output_reader = LIReader(
            clk=self.dut.clk_i, 
            signals=dict(c_data_streaming=self.dut.c_data_streaming),
            valid=self.dut.output_valid, 
            ready=self.dut.output_ready
        )

    def start(self) -> None:
        """Starts monitors, model, and checker coroutine"""
        # if self._checker is not None:
        #     raise RuntimeError("Monitor already started")
        self.a_input_writer.start()
        self.b_input_writer.start()
        self.output_reader.start()
        # self._checker = cocotb.start_soon(self._check())

    def stop(self) -> None:
        """Stops everything"""
        # if self._checker is None:
        #     raise RuntimeError("Monitor never started")
        self.a_input_writer.stop()
        self.b_input_writer.stop()
        self.output_reader.stop()
        # self._checker.kill()
        # self._checker = None


@cocotb.test(
    expect_error=IndexError
    if cocotb.simulator.is_running() and cocotb.SIM_NAME.lower().startswith("ghdl")
    else ()
)
async def multiply_test(dut):
    """Test multiplication of many matrices."""

    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    tester = MatrixMultiplierTester(dut)

    dut._log.info("Initialize and reset model")

    # Initial values
    dut.a_input_valid.value = 0
    dut.b_input_valid.value = 0
    dut.output_ready.value = 0
    dut.output_by_row.value = 1  # outputs row 0 first
    dut.last.value = 0
    dut.a_data.value = create_row(N, lambda x: 0)
    dut.b_data.value = create_row(N, lambda x: 0)

    # Reset DUT
    dut.reset.value = 1
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.reset.value = 0

    # start tester after reset so we know it's in a good state
    tester.start()

    dut._log.info("Test multiplication operations")

    # ready to listen:
    tester.output_reader.set_status(True)

    # Do multiplication operations
    test_matrix_write(tester, dut, num_samples=NUM_SAMPLES, outer_dimension=N, inner_dimension=N, 
                      input_steady=True, output_steady=True, 
                      input_not_steady_long_time=False, output_not_steady_long_time=False,
                      output_by_row=True)


def matrix_multiplication(a_matrix: List[List[int]], b_matrix: List[List[int]]) -> List[List[int]]:
        """Transaction-level model of the matrix multipler as instantiated"""
        # TODO not fixed
        outer_dimension = len(a_matrix)
        inner_dimension = len(a_matrix[0])
        return [
            [
                BinaryValue(
                    sum(
                        [
                            a_matrix[i][n]
                            * b_matrix[n][j]
                            for n in range(inner_dimension)
                        ]
                    ),
                    n_bits=MULTIPLY_DATA_WIDTH+ACCUM_DATA_WIDTH,
                    bigEndian=False,
                )
                for j in range(outer_dimension)
            ]
                for i in range(outer_dimension)
        ]
    


async def test_matrix_write(tester, dut, num_samples: int, outer_dimension: int, inner_dimension: int, 
                      input_steady: bool, output_steady: bool, 
                      input_not_steady_long_time: bool, output_not_steady_long_time: bool,
                      output_by_row: bool = True):
    """
    repeat num_samples time, do outer_dimension x inner_dimension * inner_dimension * outer_dimension matrix
    N = outer_dimension here

    Test: output always ready to listen, input all streamlined
    Test: Sprinkle random not_valid for input
    Test: Output ready have random pauses
    Test: input will be not valid for a long period of time
    Test: output will be not_ready for a long period of time
    """
    dut.output_by_row.value = output_by_row  # Output based on row or col
    expected_outputs = []
    # Generate matrix A and B based on input
    for i, (A, B) in enumerate(zip(gen_matrices(outer_dimension, inner_dimension, num_samples=num_samples), gen_matrices(inner_dimension, outer_dimension, num_samples=num_samples))):
        matrix_product_temp = matrix_multiplication(A, B)
        if not output_by_row:
            matrix_product_temp_transposed = [[matrix_product_temp[i][j] for i in outer_dimension] for j in outer_dimension]
        expected_outputs.append(matrix_product_temp if output_by_row else matrix_product_temp_transposed)
        # Fit all data to the input writer first (all num_samples)
        # add random gaps if input won't be all valid
        # A matrix input gen
        for col_index in range(inner_dimension-1, 0, -1):
            # get col in reverse order
            col = [a_row[col_index] for a_row in A]
            tester.a_input_writer.set_status((col, True, False))
            if not input_steady and not input_not_steady_long_time:
                # add random pauses here and there lasting 1-3 cycles
                for _ in range(randint(0, 1)):
                    tester.a_input_writer.set_status((create_row(outer_dimension), False, False))
            elif not input_steady and input_not_steady_long_time:
                # adding random pauses that are at least as long as an entire input cycle
                for _ in range(randint(0, inner_dimension)):
                    tester.a_input_writer.set_status((create_row(outer_dimension), False, False))
        tester.a_input_writer.set_status((A[-1], True, True))
        if not input_steady and not input_not_steady_long_time:
            # add random pauses here and there lasting 1-3 cycles
            for _ in range(randint(0, 1)):
                tester.a_input_writer.set_status((create_row(outer_dimension), False, False))
        elif not input_steady and input_not_steady_long_time:
            # adding random pauses that are at least as long as an entire input cycle
            for _ in range(randint(0, inner_dimension)):
                tester.a_input_writer.set_status((create_row(outer_dimension), False, False))
        
        # B matrix input gen
        for row in reversed(B)[:-1]:
            tester.b_input_writer.set_status((row, True, False))
            if not input_steady and not input_not_steady_long_time:
                # add random pauses here and there lasting 1-3 cycles
                for _ in range(randint(0, 1)):
                    tester.b_input_writer.set_status((create_row(outer_dimension), False, False))
            elif not input_steady and input_not_steady_long_time:
                # adding random pauses that are at least as long as an entire input cycle
                for _ in range(randint(0, inner_dimension)):
                    tester.b_input_writer.set_status((create_row(outer_dimension), False, False))
        tester.a_input_writer.set_status((B[0], True, True))
        if not input_steady and not input_not_steady_long_time:
            # add random pauses here and there lasting 1-3 cycles
            for _ in range(randint(0, 1)):
                tester.b_input_writer.set_status((create_row(outer_dimension), False, False))
        elif not input_steady and input_not_steady_long_time:
            # adding random pauses that are at least as long as an entire input cycle
            for _ in range(randint(0, inner_dimension)):
                tester.b_input_writer.set_status((create_row(outer_dimension), False, False))

    all_output_collected = False
    C = [[]]
    num_collected = 0
    long_output_pause_counter = 0
    outout_reader_status = True

    while not all_output_collected:
        if output_steady: 
            tester.outout_reader.set_status(True)
        elif not output_not_steady_long_time:
            if randint(0, 1) > 0:
                tester.outout_reader.set_status(True)
            else:
                tester.outout_reader.set_status(False)
        else:
            long_output_pause_counter += 1
            if long_output_pause_counter % inner_dimension == 0:
                tester.outout_reader.set_status(outout_reader_status)
                outout_reader_status = not outout_reader_status

        await RisingEdge(dut.clk)

        if not tester.output_reader.values.empty():
            if len(C[-1]) < inner_dimension:
                C[-1].append((await tester.output_reader.values.get())["c_data_streaming"])
            else:
                num_collected += 1
                if num_collected >= num_samples:
                    all_output_collected = True
                    continue
                C.append([])
    
    # Run comparison code
    successful = True
    for (expected_output, actual_result) in zip(expected_outputs, C):
        if expected_output != actual_result:
            failed = False
            print("Expected:")
            print(expected_output)
            print("Actual:")
            print(actual_result)
    print("Test Successful?", successful)


def create_matrix(func, rows, cols):
    return [[func(DATA_WIDTH) for row in range(rows)] for col in range(cols)]

def create_row(length, func=getrandbits):
    return [func(DATA_WIDTH) for _ in range(length)]

def gen_matrices(rows, cols, num_samples=NUM_SAMPLES, func=getrandbits):
    """Generate random matrix data for matrices of set dimensions"""
    for _ in range(num_samples):
        yield create_matrix(func, rows, cols)


def test_matrix_multiplier_runner():
    """Simulate the matrix_multiplier example using the Python runner.

    This file can be run directly or via pytest discovery.
    """
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")

    proj_path = Path(__file__).resolve().parent.parent

    verilog_sources = []
    vhdl_sources = []
    build_args = []

    verilog_sources = [proj_path / "hdl" / "sum_stationary.sv"]

    if sim in ["riviera", "activehdl"]:
        build_args = ["-sv2k12"]

    extra_args = []
    if sim == "ghdl":
        extra_args = ["--std=08"]

    parameters = {
        "DATA_WIDTH": int(os.getenv("DATA_WIDTH", "8")),
        "N": int(os.getenv("N", "4")),
        "MULTIPLY_DATA_WIDTH": int(os.getenv("MULTIPLY_DATA_WIDTH", "16")),
        "ACCUM_DATA_WIDTH": int(os.getenv("ACCUM_DATA_WIDTH", "16")),
    }

    # equivalent to setting the PYTHONPATH environment variable
    sys.path.append(str(proj_path / "tests"))

    runner = get_runner(sim)

    runner.build(
        hdl_toplevel="matrix_multiplier",
        verilog_sources=verilog_sources,
        vhdl_sources=vhdl_sources,
        build_args=build_args + extra_args,
        parameters=parameters,
        always=True,
    )

    runner.test(
        hdl_toplevel="matrix_multiplier",
        hdl_toplevel_lang=hdl_toplevel_lang,
        test_module="test_matrix_multiplier",
        test_args=extra_args,
    )


if __name__ == "__main__":
    test_matrix_multiplier_runner()