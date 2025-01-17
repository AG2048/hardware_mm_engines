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

## Input/Output Specifications
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

### Matrix C
This matrix will be stored in Groups of "Blocks" of `N` by `N` matrices. Each Group contains `ROWS_PROCESSORS` by `COLS_PROCESSORS` Blocks. The Groups are in row major order from top left to bottom right, The Blocks (within each group) are in row major order from top left to bottom right, and the matrices within each block are in row major order from top left to bottom right. 
```
1  2  3  4  5  6  7  8
9  10 11 12 13 14 15 16
17 18 19 20 21 22 23 24
25 26 27 28 29 30 31 32
33 34 35 36 37 38 39 40
41 42 43 44 45 46 47 48
49 50 51 52 53 54 55 56
57 58 59 60 61 62 63 64
```
Assuming `N=2` `ROWS_PROCESSORS=2` `ROWS_PROCESSORS=2`:
```
1 2 9 10 3 4 11 12 17 18 25 26 19 20 27 28 5 6 13 14 7 8 15 16 21 22 29 30 23 24 31 32 33 34 41 42 35 36 43 44 49 50 57 58 51 52 59 60 37 38 45 46 39 40 47 48 53 54 61 62 55 56 63 64
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
Specifications for what matrix can be used as input, and how they would be read in. 
#### M
When reading matrix A, the design would load in the matrix in groups of `N` by `M` and matrix B in groups of `M` by `N`. So far, the implementation has only included the scenario where `M=matrix_length`. 

This parameter should be a power of 2. (Also `N` probably should be an integer multiple of `PARALLEL_DATA_STREAMING_SIZE`)
#### MAX_MATRIX_LENGTH
The maximum matrix size the design should be capable to compute. Used to allocate number of bits to store counters for matrix input / output.

This parameter should be a power of 2. 

### Memory Information
Information about the external memory that will provide the design with information.
#### MEMORY_ADDRESS_BITS
The number of bits of memory address the memory have.

#### MEMORY_SIZE 
The total size of memory, this parameter is likely not used...

not used, should be removed
#### PARALLEL_DATA_STREAMING_SIZE
Assume the memory can simultaneously write multiple values to the NoC, this parameter is the number of values that can be read to `memory_buffer` or `output_memory_writer` at the same time.

This parameter should be a power of 2. 

### Calculated Parameter Bits Storage Parameters
Mainly parameters calculated using other parameters, used to allocate bits. Does not need to be specified, as they are calculated directly. 
#### MATRIX_LENGTH_BITS
#### PROCESSOR_ROWS_BITS
#### PROCESSOR_COLS_BITS
#### INPUT_BUFFER_COUNTER_BITS
`$clog2(MAX_MATRIX_LENGTH + 1)` Keeping track of how many cols of a row block or how many rows of a col block 
May be subject to change from `M` implementation
#### INPUT_BUFFER_MEMORY_INPUT_COUNTER_BITS
`$clog2(MAX_MATRIX_LENGTH * N + 1)` Keeping track of total number of bits read from memory, used by `memory_buffer` to initialize counter
#### INPUT_BUFFER_REPEATS_COUNTER_BITS
`$clog2((MAX_MATRIX_LENGTH / N) + 1)` Each `memory_buffer` will repeat sending its stored data a certain number of times, this parameter stores the counter bits. 

#### INPUT_BUFFER_INSTRUCTION_COUNTER_BITS 
Internal parameters by `controller` to keep track of "which rows" to ask each `memory_buffer` to read from

#### OUTPUT_BUFFER_INSTRUCTION_COUNTER_BITS 
Internal parameters by `controller` to keep track of which `output_memory_writer` will write to what address. 


## Modules Description

### Processor
#### Parameters
`DATA_WIDTH`, `N`, `MULTIPLY_DATA_WIDTH`, `ACCUM_DATA_WIDTH`, `PROCESSOR_ROWS_BITS`, `PROCESSOR_COLS_BITS` are standard parameters. 

`ROW_ID`, `COL_ID` is a parameter given uniquely to each `processor` when instantiating a module. The module only receives `a_input` when the `COL_ID` matches, and only receives `b_input` when the `ROW_ID` matches. 
#### Input / Output
...

#### How it functions
While idle, receive row or col inputs separately into `input_delay_register`, begin passing the values into a systolic array regardless of if all data has been input or not. This requires both A and B input to be valid at the same time to ensure data is reached in the systolic array correctly. 

Process (shift) the data already stored if: all inputs are ready and valid, or if the input is already done (just passing the residual values leftover in `input_delay_register`. However, DO NOT pass data if the result is valid, as this indicate the previous round of calculation is still stored in the systolic array. 

Once the process is complete, `result_valid` will become true to indicate the result stored on the array is valid. This signal informs the `output_streaming_registers` to accept the value stored, so the result `N` by `N` matrix can be streamed out row by row. 

Once the data is loaded onto `output_streaming_registers`, `output_valid` signal becomes true once there are something stored in the `output_streaming_registers`. The `processor` only resets on the edge of `result_valid` and `!output_valid` (when the computation finished and the result will be offloaded to the output module). The data remains on the systolic array while `output_valid` is true. 

`output_streaming_registers` is an `N` by `N` grid of registers that stores the result of `processor` and stream them out row by row or col by col. It keeps track of how many rows it has streamed out to maintain record of how many rows it has left to stream. 

`input_delay_register` is a staircase-like register structure that delays the input based on their row or col to allow for systolic-array computation. 

`processing_unit` is a unit of the systolic array that multiplies North and West inputs and accumulates them. 

### Memory Buffer
#### Parameters

#### Input / Output

#### How it functions
Receives instructions form the controller: what address to read from, how long is, and how many times this module should repeat broadcasting this data to all of its corresponding processors. 

When received instructions, it keeps counter for each of those tasks, and decrement repeats counter if this clock cycle successfully wrote to the last processor for a given repeat. 

Reading from memory uses the address input, `PARALLEL_DATA_STREAMING_SIZE` by `PARALLEL_DATA_STREAMING_SIZE` into an internal buffer.

While the memory is being read, if enough memory has been read to cover for the next `N` values to stream, write those to `processor`. Write one by one to each processor by their ID (checking ID-specific ready, and assert the ID as a number along with the valid signal, we had to ensure the ID is set the same time as valid)

Since the `processor` is not told the length of the array, the buffer will assert a `last` signal with the last number to tell the `processor` that this is the last value to receive and may begin processing

### Output Memory Writer
#### Parameters

#### Input / Output

#### How it functions
To a certain degree, undecided. This could just receive a signal from controller telling its address to store, and it will inform the controller it's finished so it may receive a new address. Once the address is stored, it remains in idle state until the processor gives it the output data. 

### Controller
#### Parameters

#### Input / Output

#### How it functions
Receives the begin processing instruction.
Assigns address and matrix length to input buffer and output writers. 
Re-assign new address when the buffer/writer completed its previous task. Requires some soft logic / a lot of calculations. 
Informs the completion of all computations via a done flag. 

## Bugs / Errors

### Incorrect definition of `M`
`M` should be corresponding to matrix length, not `N` (in input buffers)

### memory_buffer does not have ROW_ID / COL_ID implemented
right now the processor_input_id output is not used, it could be just tied to the ID counter. 

## Edits / Improvements

### Output Bits Truncation
When using `MULTIPLY_DATA_WIDTH` and `ACCUM_DATA_WIDTH`, it may be beneficiary to maintain the higher bits for precision reasons, and the lower bits could be thrown out to minimize errors. 

### Input Matrices Less Than Full Length
Currently, it is assumed that `M` parameter is equal to the `N` parameter, meaning that the design will load and store the entire matrix row/col block onto the board. However, it may be possible to allow a row block or a col block to be sent in shorter segments and computes done in multiple accumulation cycles. 

If `M != N` is implemented, then we might need to rework `memory_buffer` structure and the control signal that goes to it via `controller`. 

Some calculated parameters such as `INPUT_BUFFER_COUNTER_BITS` might need to be revised due to reduced length

`M` could be redefined to be the number of multiples of `N` each buffer should read, and set `M*N*N` as the buffer size, and only read up to `M*N*N` numbers at once, but could stop early if no more number is to be read. 

**It is possible to not modify the M parameter, and instead let controller tell an effective `M` to the memory_buffer as the matrix_length**

### Figure out input shape
Input shape may not be convenient as of this point, when corresponding to output shapes (there may be a few index reversal along the way?), so make the input buffer and output writer consistent in shape. 

### Processor `last` input must be simultaneous
`processor` should not have to hold up both row and col operations while waiting for them to input. Right now both input has to be simultaneous (maybe this is not resolveable due to the design of the processor)

### output_streaming_registers
could just for this to be row by row always. 

### memory_buffer can be slightly optimized
processor_input_valid could have also just OR'd with if repeat count >= 1 or something if that's efficient. 

### memory_buffer
It can probabably broadcast to ALL the processors with an indivisual ready/valid line to allow for parallel data streaming

### State machine approach to controller
^
