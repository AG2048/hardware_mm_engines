# Sum Stationary Integration
`hdl` stores the `.sv` files for the modules

`test_<module>` stores the `cocotb` testbench for individual modules
# Testing Procedure

## Processor
Ensure that when matrices of shape `N` by `X` multiplied by `X` by `N` is input properly (in the reversed col-major order and reversed row-major order), for any reasonable `X`, the matrix output result is correct.

Also, ensure write to processor and read from processor can proceed in a latency-insensitive manner. 

## Memory Buffer
Make a fake memory that when requested, provides `PARALLEL_DATA_STREAMING_SIZE` values together beginning at the requested address. 

Provide an arbitrary address, length, repeats. Check if the device outputs correct values. 

Check if the first output is at the earliest possible cycle. 

Check if the device can buffer repeated attempts, and can buffer new values after one attempt. 

## Output Writer

Provide appropriate address, check if capable of writing to that memory address when a "fake" processor gives it input. 

Capable of holding and doing nothing while no input is given to the writer. 

## Controller
Give memory address, test if control signals given are appropriate. (Let each module wait a random of 1-100 cycles between operation)
