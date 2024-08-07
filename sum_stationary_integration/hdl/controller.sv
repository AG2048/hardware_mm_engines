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


// TODO: remove unused parameters

module controller #(
  parameter int DATA_WIDTH = 8,           // Using 8-bit integers 
  
  parameter int N = 4,                    // What's the width of the processing units
  parameter int M = 4,                    // This is how much memory is supposed to be stored by the memory buffer (TODO: currently we make it same as N, but will be different)
  parameter int MAX_MATRIX_LENGTH = 4096,  // Assume the max matrix we will do is 4k
  parameter int MULTIPLY_DATA_WIDTH = 2 * DATA_WIDTH, // Data width for multiplication operations
  parameter int ACCUM_DATA_WIDTH = 16, // How many additional bits to reserve for accumulation, can change
  parameter int MATRIX_LENGTH_BITS = $clog2(MAX_MATRIX_LENGTH+1), // bits to store max matrix length

  parameter int ROWS_PROCESSORS = 1, // How many rows of processing units are there (number of A input buffers)
  parameter int COLS_PROCESSORS = 1, // How many cols of processing units are there (number of B input buffers)
  parameter int NUM_PROCESSORS = ROWS_PROCESSORS * COLS_PROCESSORS, // also how many output memory writers there are

  // Calculated parameters for input buffers
  parameter int INPUT_BUFFER_COUNTER_BITS = $clog2(MAX_MATRIX_LENGTH + 1) // We need to keep track of a count from 0 to MAX_MATRIX_LENGTH
  parameter int INPUT_BUFFER_MEMORY_INPUT_COUNTER_BITS = $clog2(MAX_MATRIX_LENGTH * N + 1) // For reading from memory, we read at most MAX_MATRIX_LENGTH * N values
  parameter int INPUT_BUFFER_REPEATS_COUNTER_BITS = $clog2((MAX_MATRIX_LENGTH/N) + 1), // keep track of how many full data repeats are sent. If we use this for B buffer, the value could become just 1 or 0... (probably keep the bit to a high value in case controller want to fast output A instead of B)
  parameter int INPUT_BUFFER_INSTRUCTION_COUNTER_BITS = $clog2(MAX_MATRIX_LENGTH*MAX_MATRIX_LENGTH/ROWS_PROCESSORS/COLS_PROCESSORS/N/N + 1), // TODO: bits required to count number of instructions already sent to each input buffer (max_matrix_len^2 / (row_processors*col processors*N^2))
  // TODO: ^ the above instruction counter bits used division. Not sure if integer division will negatively affect the result. 

  parameter int MEMORY_ADDRESS_BITS = 64,  // Used to communicate with the memory
  parameter int MEMORY_SIZE = 1024, // size of memory
  parameter int PARALLEL_DATA_STREAMING_SIZE = 4 // Memory can output 4 numbers at same time TODO: always divisor of SIZE...
) (
  input   logic                           clk,            // Clock signal
  input   logic                           reset,          // To clear buffer and restore counter

  // User Input/Output
  input   logic [MEMORY_ADDRESS_BITS-1:0] a_memory_addr,
  input   logic [MEMORY_ADDRESS_BITS-1:0] b_memory_addr,
  input   logic [MEMORY_ADDRESS_BITS-1:0] c_memory_addr,
  input   logic [MATRIX_LENGTH_BITS-1:0]  matrix_length_input, // It's an NxN * NxN input 
  input   logic                           instruction_valid, // Tell if memory addr is received or not
  output  logic                           instruction_ready, // Tell if memory addr is received or not
  output  logic                           done,            // When the result in C is correct

  // Instruction to Input Buffer
  output  logic                                         a_input_buffer_instruction_valids[ROWS_PROCESSORS-1:0],
  input   logic                                         a_input_buffer_instruction_readys[ROWS_PROCESSORS-1:0],
  output  logic [MEMORY_ADDRESS_BITS-1:0]               a_input_buffer_address_inputs[ROWS_PROCESSORS-1:0],
  output  logic [INPUT_BUFFER_COUNTER_BITS-1:0]         a_input_buffer_length_inputs[ROWS_PROCESSORS-1:0],
  output  logic [INPUT_BUFFER_REPEATS_COUNTER_BITS-1:0] a_input_buffer_repeats_inputs[ROWS_PROCESSORS-1:0],

  output  logic                                         b_input_buffer_instruction_valids[COLS_PROCESSORS-1:0],
  input   logic                                         b_input_buffer_instruction_readys[COLS_PROCESSORS-1:0],
  output  logic [MEMORY_ADDRESS_BITS-1:0]               b_input_buffer_address_inputs[COLS_PROCESSORS-1:0],
  output  logic [INPUT_BUFFER_COUNTER_BITS-1:0]         b_input_buffer_length_inputs[COLS_PROCESSORS-1:0],
  output  logic [INPUT_BUFFER_REPEATS_COUNTER_BITS-1:0] b_input_buffer_repeats_inputs[COLS_PROCESSORS-1:0],

  // Instruction to Output Buffer
  output  logic                                         output_buffer_instruction_valids[ROWS_PROCESSORS-1:0][COLS_PROCESSORS-1:0],
  input   logic                                         output_buffer_instruction_readys[ROWS_PROCESSORS-1:0][COLS_PROCESSORS-1:0],
  output  logic [MEMORY_ADDRESS_BITS-1:0]               output_buffer_address_inputs[ROWS_PROCESSORS-1:0][COLS_PROCESSORS-1:0],
  output  logic                                         output_buffer_by_row_instructions[ROWS_PROCESSORS-1:0][COLS_PROCESSORS-1:0],

  output  logic                                         output_buffer_completed_readys[ROWS_PROCESSORS-1:0][COLS_PROCESSORS-1:0],
  input   logic                                         output_buffer_completed_valids[ROWS_PROCESSORS-1:0][COLS_PROCESSORS-1:0],
);
  /************************
   * GENERAL INSTRUCTIONS *
   ************************/
  logic done_register, in_operation_register, a_addr_register, b_addr_register, c_addr_register, matrix_length_register;
  always_ff @(posedge clk) begin
    if (reset) begin
      in_operation_register <= '0;
      done_register <= '0;
    end else begin
      if (instruction_ready && instruction_valid) begin
        // Read in new instruction, set in_ops to true
        in_operation_register <= '1;
        a_addr_register <= a_memory_addr;
        b_addr_register <= b_memory_addr;
        c_addr_register <= c_memory_addr;
        matrix_length_register <= matrix_length_input;
        done_register <= '0;
      end else if (...) begin // TODO: define the logic condition for this
        // If all output buffer have completed their last output task:
        in_operation_register <= '0;
        done_register <= '1;
      end
    end
  end
  assign instruction_ready = ~in_operation_register;
  assign done = done_register;

  /****************
   * INPUT BUFFER *
   ****************/
  /* TODO:
    instruction valid should be "in-progress"
    address / length / repeats inputs should be defined at same time (probably in an always_ff block at same time as valid)
    ^ should be register
  */
  /*
  define a counter for instructions sent (if instruction done then counter == 0)
  define a register to store "address to send"
  define register to store length
  register to store "repeats"

  instruction valid is always: in_operation_register && counter != 0

  for loop in alwaysff
    reset, clear... 
    if in_operation:
      if counter == 0:
        (we just started)
        set counter to value (how many instructions will there be? - currently assuming "M" is not used, max_matrix_len^2 / (row_processors*col processors*N^2))
        set output data to desired values
      else:
        (we are currently working)
        if ready && valid, decrease counter and set value to new
        but if: ready && valid && counter==1 (on our last value): 
  */

  // Define registers to store instructions "to be sent"
  logic [MEMORY_ADDRESS_BITS-1:0] a_input_buffer_address_registers[ROWS_PROCESSORS-1:0];
  logic [INPUT_BUFFER_COUNTER_BITS-1:0] a_input_buffer_length_registers[ROWS_PROCESSORS-1:0];
  logic [INPUT_BUFFER_REPEATS_COUNTER_BITS-1:0] a_input_buffer_repeats_registers[ROWS_PROCESSORS-1:0];

  // Define state variable registers that remmebers what state the instructions are in
  // (Started/Not Started, on step X)
  logic [INPUT_BUFFER_INSTRUCTION_COUNTER_BITS-1:0] a_input_buffer_instruction_counters[ROWS_PROCESSORS-1:0];
  logic a_input_buffer_started[ROWS_PROCESSORS-1:0];

  // Define the instruction valid to be: when we in operation, AND count is not 0 (count==0 indicates finished all instructions)
  always_comb begin : a_input_buffer_instr_valid_logic
    for (int a_input_buffer_instr_valid_logic_index = 0; a_input_buffer_instr_valid_logic_index < ROWS_PROCESSORS; a_input_buffer_instr_valid_logic_index++) begin
      // valid when: we are operating, and we have not used up all operations 
      // When count reaches 0, it will never be valid again, until "done" flag
      a_input_buffer_instruction_valids[a_input_buffer_instr_valid_logic_index] = in_operation_register && a_input_buffer_instruction_counters[a_input_buffer_instr_valid_logic_index] != 0;
    end
  end

  always_ff @(posedge clk) begin
    for (int a_input_buffer_index = 0; a_input_buffer_index < ROWS_PROCESSORS; a_input_buffer_index++) begin
      if (reset) begin
        a_input_buffer_address_registers[a_input_buffer_index] <= 0;
        a_input_buffer_length_registers[a_input_buffer_index] <= 0;
        a_input_buffer_repeats_registers[a_input_buffer_index] <= 0;

        a_input_buffer_instruction_counters[a_input_buffer_index] <= 0;
        a_input_buffer_started[a_input_buffer_index] <= 0;
      end else begin
        if (in_operation_register) begin
          if (a_input_buffer_instruction_counters[a_input_buffer_index] == 0 && a_input_buffer_started[a_input_buffer_index] == 0) begin
            // Operating but have not started sending instructions
            // Mark as started, set data to desired values
            a_input_buffer_instruction_counters[a_input_buffer_index] <= ;
            a_input_buffer_started[a_input_buffer_index] <= 1;

            a_input_buffer_address_registers[a_input_buffer_index] <= ;
            a_input_buffer_length_registers[a_input_buffer_index] <= ;
            a_input_buffer_repeats_registers[a_input_buffer_index] <= ;
          end else begin
            // if ready/valid, decrease counter. 
            // No need to care for counter here, because if counter is at the "end value", it won't be valid
            if (a_input_buffer_instruction_valids[a_input_buffer_index] && a_input_buffer_instruction_readys[a_input_buffer_index]) begin
              a_input_buffer_instruction_counters[a_input_buffer_index] <= a_input_buffer_instruction_counters[a_input_buffer_index] - 1;

              a_input_buffer_address_registers[a_input_buffer_index] <= ;
              a_input_buffer_length_registers[a_input_buffer_index] <= ;
              a_input_buffer_repeats_registers[a_input_buffer_index] <= ;
            end
          end
        end else begin
          // The entire computation is done, at this point counter should be 0 already
          // We should reset the "started" signal
          a_input_buffer_started[a_input_buffer_index] <= 0;
        end
      end
    end
  end

  /*************************
   * DEFINE OUTPUT_BUFFERS *
   *************************/

  // TODO: output buffer should have same code structure as input buffer. But have a separate FF block that records the "done" signals and count them. 


  /* TODO:
    ready should be "in-progress" - AND count not at max?
    increment a counter for each tile. 

    if count at max, set "buffer completely done" to true

  */
endmodule