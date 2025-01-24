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

# Data reader - that asserts ready when instructed to start read data, not ready when stop. Checks for valid signals before reading.
#   reader(ready=True/False) - and it logs whatever value it read
class LIReader:
    def __init__(self, dut: SimHandleBase, clk: SimHandleBase, signals: Dict[str, SimHandleBase], valid: SimHandleBase, ready: SimHandleBase):
        self.values = Queue[Dict[str, int]]()  # {'signal_name': value}, signals=dict(c_data_streaming=self.dut.c_data_streaming),
        self._dut = dut
        self._clk = clk
        self._sinals = signals
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
        """
        At rising edge (after the edge), check if valid AND ready. If so, read the value.
        If at the edge, not ready or not valid, then we wait until one of them changes, and wait till next edge. 
        If at edge ready and valid, we read values. 
        """
        while True:
            await RisingEdge(self._clk)
            if self._valid.value.binstr != "1" or self._ready.value.binstr != "1":
                # Only proceed if both are ready. Wait until some signal is updated
                await First(RisingEdge(self._valid), RisingEdge(self._ready))
                continue
            # Both valid and ready are true on a rising clock edge
            # raise Exception(f"putting values: {self._sample()}")
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
    def __init__(self, dut: SimHandleBase, clk: SimHandleBase, signals: SimHandleBase, valid: SimHandleBase, ready: SimHandleBase, last: SimHandleBase, sends_last: bool, input_length: int):
        self.values = Queue[Tuple[int, bool, bool]]()
        self._dut = dut
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
        ([data...], valid, last)
        """
        self.values.put_nowait(input_data_and_valid)

    async def _run(self) -> None:
        """
        Goal: iterate thru values, and write. If true, do proper wait. If False, wait a random number of cycles.
        """
        # Initialize the input values. 
        if self.values.empty():
            input_value, do_input, is_last = [0 for _ in range(self._input_length)], False, False
        else:
            input_value, do_input, is_last = await self.values.get()
        
        while True:
            # Set signals to our values.
            self._signals.value = input_value
            self._valid.value = do_input

            # If this writer does send the "last" signal, then we set the last signal. 
            if self._sends_last:
                self._last.value = is_last
            
            # if we are sending valid data, we are waiting for clock edge and ready signal. 
            if do_input:
                # We are writing
                # After rising edge, check if ready. If ready, then switch value
                # if not ready, wait until ready is asserted, then change value on next rising edge
                while True:
                    # wait for edge
                    await RisingEdge(self._clk)
                    # if we read ready (assume device have taken the data)
                    if self._ready.value.binstr == "1":
                        break
                    else:
                        # We didn't read ready signal, we wait until ready is set and then wait for clock edge. 
                        await RisingEdge(self._ready)
            else:
                # We are not writing
                # Generate random value (1-3 probably)
                # await rising edge for random time
                wait_cycles = randint(1, 3)
                for _ in range(wait_cycles):
                    await RisingEdge(self._clk)

            if self.values.empty():
                input_value, do_input, is_last = [0 for _ in range(self._input_length)], False, False
            else:
                # try:
                input_value, do_input, is_last = await self.values.get()
                # except Exception as e:
                #     print(f"An error occurred: {e}")
                #     raise Exception(str(self.values.get()))