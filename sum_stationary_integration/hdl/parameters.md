# MMU Hardware Parameters

## sum_stationary (processor)
parameter int DATA_WIDTH = 8,   // Using 8-bit integers 
parameter int N = 4,            // Computing NxN matrix multiplications
parameter int MULTIPLY_DATA_WIDTH = 2 * DATA_WIDTH, // Data width for multiplication operations
parameter int ACCUM_DATA_WIDTH = 16, // How many additional bits to reserve for accumulation, can change TODO: should be clog(MAX_MATRIX_LEN+1)
parameter int COUNTER_BITS = $clog2(2 * N + 1) // We count from 2N to 0

## simple_memory
parameter int PARALLEL_DATA_STREAMING_SIZE = 4, // It can output 4 numbers at same time TODO: always divisor of SIZE...
parameter int SIZE = 1024,      // How many numbers of DATA_WIDTH it can store
parameter int ADDRESS_BITS = $clog2(SIZE + 1) // Address is corresponding to SIZE to 0 (i guess default is 64)

## memory_buffer
parameter int M = 4,                    // This is how much memory is supposed to be stored by buffer (TODO: currently we make it same as N, but will be different)
parameter int MAX_MATRIX_LENGTH = 4096  // Assume the max matrix we will do is 4k
parameter int COUNTER_BITS = $clog2(MAX_MATRIX_LENGTH + 1) // We need to keep track of a count from 0 to MAX_MATRIX_LENGTH
parameter int MEMORY_INPUT_COUNTER_BITS = $clog2(MAX_MATRIX_LENGTH * N + 1) // For reading from memory, we read at most MAX_MATRIX_LENGTH * N values
parameter int CYCLE_COUNTER_BITS = $clog2((MAX_MATRIX_LENGTH/N) + 1) // keep track of how many full data cycles are sent. If we use this for B buffer, the value could become just 1 or 0... (probably keep the bit to a high value in case controller want to fast output A instead of B)

## Notes:
I should probably make N % PARALLEL_DATA_STREAMING_SIZE == 0
