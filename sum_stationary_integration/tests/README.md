# Processor Testbench

Using cocotb to test functionality of a single processor (one unit that takes an NxM * MxN matrix multiplication, where N is a parameter and M is any value).

Currently we use modelsim to run the simulation.

Change device parameters in `Makefile`, might have to remove sim_build directory after that to ensure the new parameter is run.

Currently I'm not sure what does the `parameters` argument in the `sum_stationary_tb.py` file does, the Makefile argument seems to override it.

Turned out `test_matrix_multiplier_runner()` is only for if you run the python file directly. But if you use `make` you don't need it.

My program just completely doesn't work unless its compiled by modelsim.

The tests were done with:
- modelsim 10.7a
- cocotb 1.8.1
- python 3.8

We can run by `make clean && make` to clear out the sim_build directory every re-run

Also consider if we can get the waveform so we can better verify the results. 