# Processor Testbench

Using cocotb to test functionality of a single processor (one unit that takes an NxM * MxN matrix multiplication, where N is a parameter and M is any value).

Currently we use modelsim to run the simulation.

Change device parameters in `Makefile`, might have to remove sim_build directory after that to ensure the new parameter is run.

Currently I'm not sure what does the `parameters` argument in the `sum_stationary_tb.py` file does, the Makefile argument seems to override it.

The tests were done with:
- modelsim 10.7a
- cocotb 1.8.1
- python 3.8