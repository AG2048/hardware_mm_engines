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
    """
    Class: LIReader
    Purpose: Read data from the DUT.
    How to use:
        1. Initialize the class with:
            - dut: the DUT handle (not really used)
            - clk: the clock handle
            - signals: a dict of signal handles that will be read from (do signals['signal_name'].value) or just use the _sample() method
                In the memory buffer case, the signals would be: processor_id, processor_input_data, last. 
                Do note that the "B" input buffers kinda does not need the "last" signal, but we are just testing the overall functionality.
            - valid: the handle to the valid signal
            - ready: the handle to the ready signal
                Note that one LI Reader is meant to serve as one processor unit. So to test broadcasting, we need multiple LI Readers.
        2. Call start() to start the monitor
        3. simply read from self.values to get the data that was read.
    """
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


class LIWriter:
    """
    Class: LIWriter
    Purpose: Write data to the DUT.
    How to use: 
        1. Initialize the class with:
            - dut: the DUT handle (not really used)
            - clk: the clock handle
            - signals: the handle to the signals that will be written to (do signals.value = whatever we want to write)
                (Can create multiple signals handle for different wires)
            - valid: the handle to the valid signal
            - ready: the handle to the ready signal
        2. Call start() to start the monitor
        3. Instruct data to be written:
            - set_status(data, valid=True/False)
            - This will store the data and valid signals to a queue. 
            - If valid is True, it will wait until ready signal and write the corresponding data
            - If valid is False, it will wait for a random number of cycles with the data.
            - If the queue is empty, it will write 0s with valid=False
    """
    def __init__(self, dut: SimHandleBase, clk: SimHandleBase, address_input_signal: SimHandleBase, length_input_signal: SimHandleBase, repeats_input_signal: SimHandleBase, valid: SimHandleBase, ready: SimHandleBase):
        self.values = Queue[Tuple[int, bool, bool]]()
        self._dut = dut
        self._clk = clk
        self._address_input_signal = address_input_signal
        self._length_input_signal = length_input_signal
        self._repeats_input_signal = repeats_input_signal
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
    
    def set_status(self, input_data_and_valid):
        """
        input_data_and_valid would be tuples:
        ([int address, int length, int repeats], Bool valid),
        symbolize the data it will be displaying at each clock edge. 
        True data will wait until ready to be delivered.
        False data will remain false for 1 clock edge
        """
        self.values.put_nowait(input_data_and_valid)

    async def _run(self) -> None:
        """
        Goal: iterate thru values, and write. If true, do proper wait. If False, wait a random number of cycles.
        """
        # Initialize the input values. 
        if self.values.empty():
            input_value, do_input = [0, 0, 0], False
        else:
            input_value, do_input = await self.values.get()
        
        while True:
            # Set signals to our values.
            self._address_input_signal.value = input_value[0]
            self._length_input_signal.value = input_value[1]
            self._repeats_input_signal.value = input_value[2]
            self._valid.value = do_input

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
                input_value, do_input = [0, 0, 0], False
            else:
                # try:
                input_value, do_input = await self.values.get()
                # except Exception as e:
                #     print(f"An error occurred: {e}")
                #     raise Exception(str(self.values.get()))