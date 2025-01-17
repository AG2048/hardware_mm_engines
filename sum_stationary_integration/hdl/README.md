# Sum Stationary Integration

The design is made of the following major modules:
1. `processor.sv`
2. `memory_buffer.sv`
3. `output_memory_writer.sv`
4. `controller.sv`

On a high level, the design shall receive 3 memory addresses: `a_memory_addr`, `b_memory_addr`, and `c_memory_addr`. Additionally, it receives `matrix_length_input` which denotes both matrix A and B are of size `matrix_length_input` by `matrix_length_input`.  The design then takes the matrices stored at memory address `a_memory_addr` and `b_memory_addr` to perform matrix multiplication, and write the result at memory address `c_memory_addr`. 

The module consists of a grid of rows and cols of `processor` modules. There will be one `memory_buffer` per every row of `processor`, and there will be one `memory_buffer` per every col of processors. There will be one `output_memory_buffer` per `processor`. 

The `controller` module informs the `memory_buffer` to fetch from memory row blocks of the A matrix, while fetching col blocks of the B matrix. The `memory_buffer` then independently broadcast the memory content to the `processor` in the row / col of `processor` it corresponds to, sequentially. 

The `processor` module is fully controlled by the input it receives, and begins computing a smaller `N` by `N` portion of the output matrix. 

## Input Specifications
It is expected that the input matrices are stored at address `a_memory_addr`, `b_memory_addr`. The output matrix should have sufficient space allocated

### Matrix A
This matrix should be stored in groups of "Row Blocks" from the top to the bottom. Each Row Block is an `N` by `matrix_length` matrix (short and wide). Each block is stored in the order of column-major order, beginning from the top right, moving left. 
```
1  2  3  4
5  6  7  8
9  10 11 12
13 14 15 16
```
Should be stored in the order (assuming `N=2`):
```
4 8 3 7 2 6 1 5 12 16 11 15 10 14 8 13
```

### Matrix B
This matrix should be stored in groups of "Col Blocks" from the left to the right. Each Row Block is an `matrix_length` by `N` matrix (tall and thin). Each block is stored in the order of row-major order, beginning from the bottom left, moving up. 
```
1  2  3  4
5  6  7  8
9  10 11 12
13 14 15 16
```
Should be stored in the order (assuming `N=2`):
```
13 14 9 10 5 6 1 2 15 16 11 12 7 8 3 4
```

## Motivation

Using systolic arrays to compute matrix multiplication results in parallel, and minimize data travel within a module. 

Reuse data that can be stored on-chip, reduce off-chip memory access

## Design Parameters

### Data Width Related Parameters
These are parameters directly related to the input and output data width (number of bits to represent a fixed point value).

These parameters are used by all modules involving data processing and movement. **Currently the calculated results are defaulted to only use the lower bits**

#### DATA_WIDTH
The number of bits in the input data, default to 8
#### MULTIPLY_DATA_WIDTH
The number of bits to preserve after multiplying 2 values, before adding values together. Default to `2 * DATA_WIDTH`
#### ACCUM_DATA_WIDTH
The number of additional bits to `MULTIPLY_DATA_WIDTH` that is required to store the result of accumulating multiplication results. Currently set to 16, so that the total output data width is `MULTIPLY_DATA_WIDTH + ACCUM_DATA_WIDTH = 32` bits. 

### Processor Sizes Related Parameters
These parameters define the size and number of `processor` modules required for the design. They also affect the corresponding `memory_buffer` and `output_memory_writer` modules. 
#### N
The size of a `processor` block. Each `processor` block will produce an output block of size `N` by `N`. This also affects the streaming size of `memory_buffer` modules, as they are expected to stream `N` numbers to a `processor` module at once. Furthermore, `output_memory_writer` will also be writing `N` values batches to the memory. 

This parameter should be a power of 2. 
#### ROWS_PROCESSORS
The number of rows of `processor` modules that are present in the design. This also determines the number of `memory_buffer` module that are responsible for reading the A matrix into the design. 

This parameter should be a power of 2. 

#### COLS_PROCESSORS
The number of cols of `processor` modules that are present in the design. This also determines the number of `memory_buffer` module that are responsible for reading the B matrix into the design. 

This parameter should be a power of 2. 

#### NUM_PROCESSORS = ROWS_PROCESSORS * COLS_PROCESSORS
The total number of `processor` modules in the design, mainly used to ID the output buffers. 

### Matrix Input Specifications
Specifications for 
#### M

This parameter should be a power of 2. 
#### MAX_MATRIX_LENGTH

This parameter should be a power of 2. 


### Memory Information
#### MEMORY_ADDRESS_BITS
#### MEMORY_SIZE 

not used, should be removed
#### PARALLEL_DATA_STREAMING_SIZE

This parameter should be a power of 2. 

### Calculated Parameter Bits Storage Parameters
#### MATRIX_LENGTH_BITS
#### PROCESSOR_ROWS_BITS
#### PROCESSOR_COLS_BITS
#### INPUT_BUFFER_COUNTER_BITS
#### INPUT_BUFFER_MEMORY_INPUT_COUNTER_BITS
#### INPUT_BUFFER_REPEATS_COUNTER_BITS



## Modules Description

### Processor

### Memory Buffer

### Output Memory Writer

### Controller

## Edits / Improvements

### Output Bits Truncation
When using `MULTIPLY_DATA_WIDTH` and `ACCUM_DATA_WIDTH`, it may be beneficiary to maintain the higher bits for precision reasons, and the lower bits could be thrown out to minimize errors. 

### Input Matrices Less Than Full Length
Currently, it is assumed that `M` parameter is equal to the `N` parameter, meaning that the design will load and store the entire matrix row/col block onto the board. However, it may be possible to allow a row block or a col block to be sent in shorter segments and computes done in multiple accumulation cycles. 

If `M != N` is implemented, then we might need to rework `memory_buffer` structure and the control signal that goes to it via `controller`. 

### Figure out input shape
Input shape may not be convenient as of this point, when corresponding to output shapes (there may be a few index reversal along the way?), so make the input buffer and output writer consistent in shape. 
