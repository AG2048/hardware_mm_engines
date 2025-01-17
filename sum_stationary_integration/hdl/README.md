# Sum Stationary Integration

The design is made of the following major modules:
1. `processor.sv`
2. `memory_buffer.sv`
3. `output_memory_writer.sv`
4. `controller.sv`

On a high level, the design shall receive 3 memory addresses: `a_memory_addr`, `b_memory_addr`, and `c_memory_addr`. The design then takes the matrices stored at memory address `a_memory_addr` and `b_memory_addr` to perform matrix multiplication, and write the result at memory address `c_memory_addr`. 

The module consists of a grid of rows and cols of `processor` modules. There will be one `memory_buffer` per every row of `processor`, and there will be one `memory_buffer` per every col of processors. There will be one `output_memory_buffer` per `processor`. 

The `controller` module informs the `memory_buffer` to fetch from memory row blocks of the A matrix, while fetching col blocks of the B matrix. The `memory_buffer` then independently broadcast the memory content to the `processor` in the row / col of `processor` it corresponds to, sequentially. 

The `processor` module is fully controlled by the input it receives, and begins computing a smaller `N` by `N` portion of the output matrix. 

## Motivation

Using systolic arrays to compute matrix multiplication results in parallel, and minimize data travel within a module. 

Reuse data that can be stored on-chip, reduce off-chip memory access

## Design Parameters

### Data Width Related Parameters

#### DATA_WIDTH
#### MULTIPLY_DATA_WIDTH
#### ACCUM_DATA_WIDTH

### Processor Sizes Related Parameters
#### N
#### ROWS_PROCESSORS
#### COLS_PROCESSORS
#### NUM_PROCESSORS = ROWS_PROCESSORS * COLS_PROCESSORS

### Matrix Input Specifications
#### M
#### MAX_MATRIX_LENGTH

### Memory Information
#### MEMORY_ADDRESS_BITS
#### MEMORY_SIZE 
#### PARALLEL_DATA_STREAMING_SIZE 

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
