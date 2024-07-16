/*  Controller
 *    Memory buffers
 *    Processors
 *    Output memory writer
 *
 *  Procedure:
 *    Give A address, B address, C address, Matrix Dimension (assume NxN * NxN)
 *    Output: done when C is written
 *  Using address and dimension, send:
 *    A addr + offset to A1, A addr + offset*2 to A2, ... 
 *    B addr + offset to B1...
 *    A cycle: matrix_len / N, B cycle: 1
 *    Once data is given, these units will read from memory and pump data into processors. 
 *    **WE HAVE TO RE-GIVE DATA AFTER THEIR CYCLE ENDED** Detect by: always valid new data, but memory routers are not ready until next cycle
 *  Read from output memory writer:
 *    based on output memory writer's address, assign them an address in the output memory (C)
 *    assign them new address when they are ready
 *    These units just simply: read address, read output data, send data to memory, wait for new address. 
 */

module controller #(
  parameter int DATA_WIDTH = 8,           // Using 8-bit integers 
  parameter int N = 4,                    // What's the width of the processing units
  parameter int M = 4,                    // This is how much memory is supposed to be stored by the memory buffer (TODO: currently we make it same as N, but will be different)
  parameter int MEMORY_ADDRESS_BITS = 64  // Used to communicate with the memory
  parameter int PARALLEL_DATA_STREAMING_SIZE = 4, // Memory can output 4 numbers at same time TODO: always divisor of SIZE...
  parameter int MAX_MATRIX_LENGTH = 4096,  // Assume the max matrix we will do is 4k
  parameter int MULTIPLY_DATA_WIDTH = 2 * DATA_WIDTH, // Data width for multiplication operations
  parameter int ACCUM_DATA_WIDTH = 16, // How many additional bits to reserve for accumulation, can change

  parameter int ROWS_PROCESSORS = 1, // How many rows of processing units are there (number of A input buffers)
  parameter int COLS_PROCESSORS = 1, // How many cols of processing units are there (number of B input buffers)
  parameter int NUM_PROCESSORS = ROWS_PROCESSORS * COLS_PROCESSORS // also how many output memory writers there are
) (
  input   logic                           clk,            // Clock signal
  input   logic                           reset,          // To clear buffer and restore counter
  input   logic [MEMORY_ADDRESS_BITS-1:0] a_memory_addr,
  input   logic [MEMORY_ADDRESS_BITS-1:0] b_memory_addr,
  input   logic [MEMORY_ADDRESS_BITS-1:0] c_memory_addr,
  input   logic                           instruction_valid,
  output  logic                           instruction_ready,
  output  logic                           done            // When the result in C is correct
);

some signals to be defined:
  a memory addr, b memory addr, c memory addr registers
  in_operation
// Communicate with the control module delivering address to buffer
  input   logic                           a_address_valids[ROWS_PROCESSORS],
  output  logic                           a_address_readys[ROWS_PROCESSORS],
  input   logic [MEMORY_ADDRESS_BITS-1:0] a_address_inputs[ROWS_PROCESSORS],

  input   logic                           b_address_valids[COLS_PROCESSORS],
  output  logic                           b_address_readys[COLS_PROCESSORS],
  input   logic [MEMORY_ADDRESS_BITS-1:0] b_address_inputs[COLS_PROCESSORS],

  input   logic                           c_address_valids[ROWS_PROCESSORS][COLS_PROCESSORS],
  output  logic                           c_address_readys[ROWS_PROCESSORS][COLS_PROCESSORS],
  input   logic [MEMORY_ADDRESS_BITS-1:0] c_address_inputs[ROWS_PROCESSORS][COLS_PROCESSORS],

  repeat for length, and cycle     (not for C)

  general block:
    ff: clear A,B,C memory addr registers, in_operation = False, done = False
    if input valid and ready, load in 3 values and set in_operation to true.
    if done: in_operation is false
    if (that C flag counter == 0, done <= 1)

    input ready: when in_operation is false

  A blocks:
    ff: if ready and valid, send corresponding values. (values = calculated value, or we can store it to a register to speed up logic)

    valid: when in operation, and the value is correct

    when general input ready/valid, initialize some values (reset values)
  B blocks:

  C blocks:
    ff: if ready and valid, send corresponding values. 
    have a flag register for "all C writer that are finally done" (or a counter works, just count down for every C output writer that claims ready, but is done)



endmodule