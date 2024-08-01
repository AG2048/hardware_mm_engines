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
  parameter int MAX_MATRIX_LENGTH = 4096,  // Assume the max matrix we will do is 4k
  parameter int MULTIPLY_DATA_WIDTH = 2 * DATA_WIDTH, // Data width for multiplication operations
  parameter int ACCUM_DATA_WIDTH = 16, // How many additional bits to reserve for accumulation, can change

  parameter int ROWS_PROCESSORS = 1, // How many rows of processing units are there (number of A input buffers)
  parameter int COLS_PROCESSORS = 1, // How many cols of processing units are there (number of B input buffers)
  parameter int NUM_PROCESSORS = ROWS_PROCESSORS * COLS_PROCESSORS, // also how many output memory writers there are

  // Calculated parameters for input buffers
  parameter int INPUT_BUFFER_COUNTER_BITS = $clog2(MAX_MATRIX_LENGTH + 1) // We need to keep track of a count from 0 to MAX_MATRIX_LENGTH
  parameter int INPUT_BUFFER_MEMORY_INPUT_COUNTER_BITS = $clog2(MAX_MATRIX_LENGTH * N + 1) // For reading from memory, we read at most MAX_MATRIX_LENGTH * N values
  parameter int INPUT_BUFFER_REPEATS_COUNTER_BITS = $clog2((MAX_MATRIX_LENGTH/N) + 1), // keep track of how many full data repeats are sent. If we use this for B buffer, the value could become just 1 or 0... (probably keep the bit to a high value in case controller want to fast output A instead of B)

  parameter int MEMORY_ADDRESS_BITS = 64,  // Used to communicate with the memory
  parameter int MEMORY_SIZE = 1024, // size of memory
  parameter int PARALLEL_DATA_STREAMING_SIZE = 4 // Memory can output 4 numbers at same time TODO: always divisor of SIZE...
) (
  input   logic                           clk,            // Clock signal
  input   logic                           reset,          // To clear buffer and restore counter
  input   logic [MEMORY_ADDRESS_BITS-1:0] a_memory_addr,
  input   logic [MEMORY_ADDRESS_BITS-1:0] b_memory_addr,
  input   logic [MEMORY_ADDRESS_BITS-1:0] c_memory_addr,
  input   logic                           instruction_valid,
  output  logic                           instruction_ready,
  output  logic                           done,            // When the result in C is correct

  // TODO, temp using many memory bus for module I/O
  input   logic [DATA_WIDTH-1:0]          input_memory_a_read_bus[ROWS_PROCESSORS-1:0][PARALLEL_DATA_STREAMING_SIZE-1:0],
  input   logic [DATA_WIDTH-1:0]          input_memory_b_read_bus[COLS_PROCESSORS-1:0][PARALLEL_DATA_STREAMING_SIZE-1:0],
  input   logic [MULTIPLY_DATA_WIDTH+ACCUM_DATA_WIDTH-1:0] output_memory_read_bus[ROWS_PROCESSORS*COLS_PROCESSORS-1:0][PARALLEL_DATA_STREAMING_SIZE-1:0],
  output  logic [MEMORY_ADDRESS_BITS-1:0]          input_memory_a_read_address[ROWS_PROCESSORS-1:0],
  output  logic [MEMORY_ADDRESS_BITS-1:0]          input_memory_b_read_address[COLS_PROCESSORS-1:0],
  output  logic [MEMORY_ADDRESS_BITS-1:0] output_memory_read_address[ROWS_PROCESSORS*COLS_PROCESSORS-1:0],

  output  logic   input_memory_a_write_valids[ROWS_PROCESSORS-1:0],
  output  logic   input_memory_b_write_valids[COLS_PROCESSORS-1:0],
  input   logic   input_memory_a_write_readys[ROWS_PROCESSORS-1:0],
  input   logic   input_memory_b_write_readys[COLS_PROCESSORS-1:0],
  output  logic   output_memory_write_valids[ROWS_PROCESSORS*COLS_PROCESSORS-1:0],
  input   logic   output_memory_write_readys[ROWS_PROCESSORS*COLS_PROCESSORS-1:0],

  output  logic [DATA_WIDTH-1:0]          input_memory_a_write_bus[ROWS_PROCESSORS-1:0][PARALLEL_DATA_STREAMING_SIZE-1:0],
  output  logic [DATA_WIDTH-1:0]          input_memory_b_write_bus[COLS_PROCESSORS-1:0][PARALLEL_DATA_STREAMING_SIZE-1:0],
  output  logic [MULTIPLY_DATA_WIDTH+ACCUM_DATA_WIDTH-1:0] output_memory_write_bus[ROWS_PROCESSORS*COLS_PROCESSORS-1:0][PARALLEL_DATA_STREAMING_SIZE-1:0],
  output  logic [MEMORY_ADDRESS_BITS-1:0]          input_memory_a_write_address[ROWS_PROCESSORS-1:0],
  output  logic [MEMORY_ADDRESS_BITS-1:0]          input_memory_b_write_address[COLS_PROCESSORS-1:0],
  output  logic [MEMORY_ADDRESS_BITS-1:0] output_memory_write_address[ROWS_PROCESSORS*COLS_PROCESSORS-1:0],

);
  /*
  Blocks:

  Memory -- TODO: this is temporary to add memory as a submodule
    Define 3 memory modules. Define a wire for each I/O
  Input Buffer
    Define ROWS_PROCESSORS of A_input
    Define COLS_PROCESSORS of B_input
    Currently, define the "ready valid signal to that of 1 unit" TODO: later expand to multiple units on same row/col
    Define output to processor. 

    Need to define an internal counter / logic that tells each buffer which address to read from. 
  Processors
    Define processors. 
    TODO: right now we just AND together all the input ready signals. 
    connect input from buffer, output to output buffers
  Output Buffer
    Define output buffers, connect to memory
  */

  // /*****************
  //  * DEFINE MEMORY *
  //  *****************/
  // logic a_memory_write_valid, a_memory_write_ready;
  // logic [MEMORY_ADDRESS_BITS-1:0] a_memory_write_address, a_memory_read_address;
  // logic [DATA_WIDTH-1:0] a_memory_write_data[PARALLEL_DATA_STREAMING_SIZE-1:0], a_memory_read_data[PARALLEL_DATA_STREAMING_SIZE-1:0];
  // simple_memory #(
  //   .DATA_WIDTH(DATA_WIDTH),
  //   .PARALLEL_DATA_STREAMING_SIZE(PARALLEL_DATA_STREAMING_SIZE),
  //   .SIZE(MEMORY_SIZE), 
  //   .ADDRESS_BITS(MEMORY_ADDRESS_BITS) 
  // ) u_a_memory (
  //   .clk(clk),
  //   .write_valid(a_memory_write_valid),
  //   .write_ready(a_memory_write_ready),
  //   .write_address(a_memory_write_address),
  //   .write_data(a_memory_write_data),
  //   .read_address(a_memory_read_address),
  //   .read_data(a_memory_read_data)
  // );

  // logic b_memory_write_valid, b_memory_write_ready;
  // logic [MEMORY_ADDRESS_BITS-1:0] b_memory_write_address, b_memory_read_address;
  // logic [DATA_WIDTH-1:0] b_memory_write_data[PARALLEL_DATA_STREAMING_SIZE-1:0], b_memory_read_data[PARALLEL_DATA_STREAMING_SIZE-1:0];
  // simple_memory #(
  //   .DATA_WIDTH(DATA_WIDTH),
  //   .PARALLEL_DATA_STREAMING_SIZE(PARALLEL_DATA_STREAMING_SIZE),
  //   .SIZE(MEMORY_SIZE), 
  //   .ADDRESS_BITS(MEMORY_ADDRESS_BITS) 
  // ) u_b_memory (
  //   .clk(clk),
  //   .write_valid(b_memory_write_valid),
  //   .write_ready(b_memory_write_ready),
  //   .write_address(b_memory_write_address),
  //   .write_data(b_memory_write_data),
  //   .read_address(b_memory_read_address),
  //   .read_data(b_memory_read_data)
  // );

  // logic c_memory_write_valid, c_memory_write_ready;
  // logic [MEMORY_ADDRESS_BITS-1:0] c_memory_write_address, c_memory_read_address;
  // logic [DATA_WIDTH-1:0] c_memory_write_data[PARALLEL_DATA_STREAMING_SIZE-1:0], c_memory_read_data[PARALLEL_DATA_STREAMING_SIZE-1:0];
  // simple_memory #(
  //   .DATA_WIDTH(DATA_WIDTH),
  //   .PARALLEL_DATA_STREAMING_SIZE(PARALLEL_DATA_STREAMING_SIZE),
  //   .SIZE(MEMORY_SIZE), 
  //   .ADDRESS_BITS(MEMORY_ADDRESS_BITS) 
  // ) u_c_memory (
  //   .clk(clk),
  //   .write_valid(c_memory_write_valid),
  //   .write_ready(c_memory_write_ready),
  //   .write_address(c_memory_write_address),
  //   .write_data(c_memory_write_data),
  //   .read_address(c_memory_read_address),
  //   .read_data(c_memory_read_data)
  // );

  /***********************
   * DEFINE INPUT BUFFER *
   ***********************/
  // Instruction Variables TODO: have to define values to instruction valids and inputs
  logic a_input_buffer_instruction_valids[ROWS_PROCESSORS-1:0];
  logic a_input_buffer_instruction_readys[ROWS_PROCESSORS-1:0];
  logic [MEMORY_ADDRESS_BITS-1:0] a_input_buffer_address_inputs[ROWS_PROCESSORS-1:0];
  logic [INPUT_BUFFER_COUNTER_BITS-1:0] a_input_buffer_length_inputs[ROWS_PROCESSORS-1:0];
  logic [INPUT_BUFFER_REPEATS_COUNTER_BITS-1:0] a_input_repeats_inputs[ROWS_PROCESSORS-1:0];
  // Communicate with processor
  logic a_input_valid[ROWS_PROCESSORS-1:0];
  logic a_input_ready[ROWS_PROCESSORS-1:0]; // Value Assigned with processor
  logic [DATA_WIDTH-1:0] a_input_data[ROWS_PROCESSORS-1:0][N-1:0];
  logic a_input_last[ROWS_PROCESSORS-1:0];
  generate
    genvar a_input_buffer_index;
    for (a_input_buffer_index = 0; a_input_buffer_index < ROWS_PROCESSORS; a_input_buffer_index++) begin : a_input_buffers
      memory_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .N(N),
        .M(M),
        .MEMORY_ADDRESS_BITS(MEMORY_ADDRESS_BITS),
        .PARALLEL_DATA_STREAMING_SIZE(PARALLEL_DATA_STREAMING_SIZE),
        .MAX_MATRIX_LENGTH(MAX_MATRIX_LENGTH)
        // Ignoring "calculated" parameters
      ) u_a_memory_buffer (
        .clk(clk),
        .reset(reset),

        .instruction_valid(a_input_buffer_instruction_valids[a_input_buffer_index]),
        .instruction_ready(a_input_buffer_instruction_readys[a_input_buffer_index]),
        .address_input(a_input_buffer_address_inputs[a_input_buffer_index]),
        .length_input(a_input_buffer_length_inputs[a_input_buffer_index]),
        .repeats_input(a_input_repeats_inputs[a_input_buffer_index]),
        
        .memory_address(input_memory_a_read_address[a_input_buffer_index]),
        .memory_data(input_memory_a_read_bus[a_input_buffer_index]),

        .processor_input_valid(a_input_valid[a_input_buffer_index]),
        .processor_input_ready(a_input_ready[a_input_buffer_index]),
        .processor_input_data(a_input_data[a_input_buffer_index]),
        .last(a_input_last[a_input_buffer_index])
      )
    end
  endgenerate

  // Instruction Variables TODO: have to define values to instruction valids and inputs
  logic b_input_buffer_instruction_valids[COLS_PROCESSORS-1:0];
  logic b_input_buffer_instruction_readys[COLS_PROCESSORS-1:0];
  logic [MEMORY_ADDRESS_BITS-1:0] b_input_buffer_address_inputs[COLS_PROCESSORS-1:0];
  logic [INPUT_BUFFER_COUNTER_BITS-1:0] b_input_buffer_length_inputs[COLS_PROCESSORS-1:0];
  logic [INPUT_BUFFER_REPEATS_COUNTER_BITS-1:0] b_input_repeats_inputs[COLS_PROCESSORS-1:0];
  // Communicate with processor
  logic b_input_valid[COLS_PROCESSORS-1:0];
  logic b_input_ready[COLS_PROCESSORS-1:0]; // Value Assigned with processor
  logic [DATA_WIDTH-1:0] b_input_data[COLS_PROCESSORS-1:0][N-1:0];
  logic b_input_last[COLS_PROCESSORS-1:0];
  generate
    genvar b_input_buffer_index;
    for (b_input_buffer_index = 0; b_input_buffer_index < COLS_PROCESSORS; b_input_buffer_index++) begin : b_input_buffers
      memory_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .N(N),
        .M(M),
        .MEMORY_ADDRESS_BITS(MEMORY_ADDRESS_BITS),
        .PARALLEL_DATA_STREAMING_SIZE(PARALLEL_DATA_STREAMING_SIZE),
        .MAX_MATRIX_LENGTH(MAX_MATRIX_LENGTH)
        // Ignoring "calculated" parameters
      ) u_b_memory_buffer (
        .clk(clk),
        .reset(reset),

        .instruction_valid(b_input_buffer_instruction_valids[b_input_buffer_index]),
        .instruction_ready(b_input_buffer_instruction_readys[b_input_buffer_index]),
        .address_input(b_input_buffer_address_inputs[b_input_buffer_index]),
        .length_input(b_input_buffer_length_inputs[b_input_buffer_index]),
        .repeats_input(b_input_repeats_inputs[b_input_buffer_index]),
        
        .memory_address(input_memory_b_read_address[b_input_buffer_index]),
        .memory_data(input_memory_b_read_bus[b_input_buffer_index]),

        .processor_input_valid(b_input_valid[b_input_buffer_index]),
        .processor_input_ready(b_input_ready[b_input_buffer_index]),
        .processor_input_data(b_input_data[b_input_buffer_index]),
        .last(b_input_last[b_input_buffer_index])
      )
    end
  endgenerate

  /*********************
   * DEFINE PROCESSORS *
   *********************/
  // TODO: find a way for memory buffers to write to ALL processors at same time.
  // TODO: option: write a processor_relay_buffer. It stores result, and inject into processor WHEN:
  // TODO:    DATA_SENT_TO_NEXT. BOTH_A_AND_B_HAVE_VALUE
  
  // TODO: right now we are just testing 1 unit, so just regulairly tie ready and valid for now
  logic processor_input_ready_signals[ROWS_PROCESSORS-1:0][COLS_PROCESSORS-1:0];
  always_comb begin : input_ready_assign
    for (int i = 0; i < ROWS_PROCESSORS; i++) begin
      a_input_ready[i] = processor_input_ready_signals[i][0];
    end
    for (int j = 0; j < COLS_PROCESSORS; j++) begin
      a_input_ready[j] = processor_input_ready_signals[0][j];
    end
  end
  // TODO Above code need change for larger integration^

  logic processor_output_ready_signals[ROWS_PROCESSORS-1:0][COLS_PROCESSORS-1:0];
  logic processor_output_valid_signals[ROWS_PROCESSORS-1:0][COLS_PROCESSORS-1:0];
  logic [MULTIPLY_DATA_WIDTH + ACCUM_DATA_WIDTH - 1 : 0] processor_output_streaming_data[ROWS_PROCESSORS-1:0][COLS_PROCESSORS-1:0];

  generate
    genvar processor_i, processor_j;
    for (processor_i = 0; processor_i < ROWS_PROCESSORS; processor_i++) begin : processor_rows
      for (processor_j = 0; processor_j < COLS_PROCESSORS; processor_j++) begin : processor_cols
        sum_stationary #(
          .DATA_WIDTH(DATA_WIDTH),
          .N(N),
          .MULTIPLY_DATA_WIDTH(MULTIPLY_DATA_WIDTH),
          .ACCUM_DATA_WIDTH(ACCUM_DATA_WIDTH)
        ) u_processor (
          .clk(clk),
          .reset(reset),

          .a_input_valid(a_input_valid[processor_i]),
          .b_input_valid(b_input_valid[processor_j]),
          .output_ready(processor_output_ready_signals[processor_i][processor_j]),
          .input_ready(processor_input_ready_signals[processor_i][processor_j]),
          .output_valid(processor_output_valid_signals[processor_i][processor_j]),
          .output_by_row(processor_output_by_row[processor_i][processor_j]),
          .last(a_input_last[processor_i]), // Assuming only a will need the last signal
          .a_data(a_input_data[processor_i]),
          .b_data(b_input_data[processor_j]),
          .c_data_streaming(processor_output_streaming_data[processor_i][processor_j])
        )
      end
    end
  endgenerate

  /*************************
   * DEFINE OUTPUT_BUFFERS *
   *************************/
  // TODO: define a grid of output buffer per processor.
  logic output_buffer_instruction_valids[ROWS_PROCESSORS-1:0][COLS_PROCESSORS-1:0];
  logic output_buffer_instruction_readys[ROWS_PROCESSORS-1:0][COLS_PROCESSORS-1:0];
  logic [MEMORY_ADDRESS_BITS-1:0] output_buffer_address_inputs[ROWS_PROCESSORS-1:0][COLS_PROCESSORS-1:0];
  logic output_buffer_by_row_instructions[ROWS_PROCESSORS-1:0][COLS_PROCESSORS-1:0];

  logic output_buffer_completed_readys[ROWS_PROCESSORS-1:0][COLS_PROCESSORS-1:0];
  logic output_buffer_completed_valids[ROWS_PROCESSORS-1:0][COLS_PROCESSORS-1:0];

  logic processor_output_by_row[ROWS_PROCESSORS-1:0][COLS_PROCESSORS-1:0];

  generate
    genvar output_buffer_i, output_buffer_j;
    for (output_buffer_i = 0; output_buffer_i < ROWS_PROCESSORS; output_buffer_i++) begin : output_buffer_rows
      for (output_buffer_j = 0; output_buffer_j < COLS_PROCESSORS; output_buffer_j++) begin : output_buffer_cols
        output_memory_writer #(
          .OUTPUT_DATA_WIDTH(MULTIPLY_DATA_WIDTH + ACCUM_DATA_WIDTH),
          .N(N),
          .MEMORY_ADDRESS_BITS(MEMORY_ADDRESS_BITS),
          .PARALLEL_DATA_STREAMING_SIZE(PARALLEL_DATA_STREAMING_SIZE)
        ) u_output_memory_writer (
          .clk(clk),
          .reset(reset),

          .instruction_valid(output_buffer_instruction_valids[output_buffer_i][output_buffer_j]),
          .instruction_ready(output_buffer_instruction_readys[output_buffer_i][output_buffer_j]),
          .address_input(output_buffer_address_inputs[output_buffer_i][output_buffer_j]),
          .output_by_row_instruction(output_buffer_by_row_instructions[output_buffer_i][output_buffer_j]),

          .completed_ready(output_buffer_completed_readys[output_buffer_i][output_buffer_j]),
          .completed_valid(output_buffer_completed_valids[output_buffer_i][output_buffer_j]),

          .write_valid(output_memory_write_valids[output_buffer_i * ROWS_PROCESSORS + output_buffer_j]),
          .write_ready(output_memory_write_readys[output_buffer_i * ROWS_PROCESSORS + output_buffer_j]),
          .write_address(output_memory_write_address[output_buffer_i * ROWS_PROCESSORS + output_buffer_j]),
          .write_data(output_memory_write_bus[output_buffer_i * ROWS_PROCESSORS + output_buffer_j]),

          .output_ready(processor_output_ready_signals[output_buffer_i][output_buffer_j]),
          .output_valid(processor_output_valid_signals[output_buffer_i][output_buffer_j]),
          .output_by_row(processor_output_by_row[output_buffer_i][output_buffer_j]),
          .c_data_streaming(processor_output_streaming_data[output_buffer_i][output_buffer_j])
        )
      end
    end
  endgenerate

  

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