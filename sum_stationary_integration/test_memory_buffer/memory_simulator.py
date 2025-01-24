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

class MemoryReadController:
    def __init__(self, dut: SimHandleBase, clk: SimHandleBase, 
                 read_readys: SimHandleBase, read_valids: SimHandleBase, read_addresses: SimHandleBase, read_datas: SimHandleBase,
                 num_ports: int, parallel_num_ports: int, memory_size: int, memory_dict: Dict[int, int]):
        # TODO: there should be a memory array here. 
        self._dut = dut
        self._clk = clk
        
        self._read_readys = read_readys
        self._read_valids = read_valids
        self._read_addresses = read_addresses
        self._read_datas = read_datas

        self._num_ports = num_ports
        self._parallel_num_ports = parallel_num_ports

        self._port_index = 0

        # Initialize memory to all 0
        self._memory_size = memory_size
        self._memory = memory_dict

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

    def set_memory(self, memory: Dict[int, int]):
        """Set the memory to the array / list that will be passed in
        
        Shape: {0: 12, 1: 1231241241, ...}
        """
        for key, value in memory.items():
            self._memory[key] = value

    def alter_memory(self, address: int, value: int):
        self._memory[address] = value

    async def _run(self) -> None:
        """
        After edge, check if ready at _port_index is true. If so, set data, set valid to the address, and pass through. Then increment the index
        We assume the user when reading at index "i", it reads i, i+1, i+2, i+3... to i+Parallel_num_ports-1
        """
        while True:
            await RisingEdge(self._clk)
            if self._read_readys[self._port_index].value.binstr == "1":
                for i in range(self._num_ports):
                    self._read_valids[i].value = 0
                self._read_valids[self._port_index].value = 0
                address = self._read_addresses[self._port_index].value.integer
                for i in range(self._parallel_num_ports):
                    self._read_datas[self._port_index + i].value = self.memory[address + i]
            self._port_index = (self._port_index + 1) % self._num_ports


class MemoryWriteController:
    def __init__(self, dut: SimHandleBase, clk: SimHandleBase, 
                 write_readys: SimHandleBase, write_valids: SimHandleBase, write_addresses: SimHandleBase, write_datas: SimHandleBase,
                 num_ports: int, parallel_num_ports: int, memory_size: int, memory_dict: Dict[int, int]):
        # TODO: there should be a memory array here. 
        self._dut = dut
        self._clk = clk
        
        self._write_readys = write_readys
        self._write_valids = write_valids
        self._write_addresses = write_addresses
        self._write_datas = write_datas

        self._num_ports = num_ports
        self._parallel_num_ports = parallel_num_ports

        self._port_index = 0

        # Initialize memory to all 0
        self._memory_size = memory_size
        self._memory = memory_dict

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

    def set_memory(self, memory: Dict[int, int]):
        """Set the memory to the array / list that will be passed in
        
        Shape: {0: 12, 1: 1231241241, ...}
        """
        for key, value in memory.items():
            self._memory[key] = value

    def alter_memory(self, address: int, value: int):
        self._memory[address] = value

    def get_memory(self):
        return self._memory

    async def _run(self) -> None:
        """
        After edge, (first write data if ready and valid at port id), increment port id check if write_valid at index. If so, set write ready.
        
        """
        while True:
            await RisingEdge(self._clk)
            if self._write_readys[self._port_index].value.binstr == "1" and self._write_valids[self._port_index].value.binstr == "1":
                self._memory[self._write_addresses[self._port_index]] = self._write_datas[self._port_index]

            self._port_index  = (self._port_index + 1) % self._num_ports

            for i in range(self._num_ports):
                self._write_readys[i].value = 1 if i == self._port_index else 0