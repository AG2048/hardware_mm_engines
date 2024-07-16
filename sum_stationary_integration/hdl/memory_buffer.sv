/*  
 *  Memory buffer:
 *  Parameters: DATA_WIDTH, N
 *  Receives: RAM address to read from, how long (inner dimension)
 *  Does: Load from RAM an N by inner_dimension array, and sends them to module one by one (with ready/valid), last signal on last value.
 *    Then wait for new instructions
 */

// Assumption: the memory can send N numbers at once.

module memory_buffer #(
  parameter int DATA_WIDTH = 8,           // Using 8-bit integers 
  parameter int N = 4,                    // What's the width of the processing units
  parameter int M = 4,                    // This is how much memory is supposed to be stored by buffer (TODO: currently we make it same as N, but will be different)
  parameter int MEMORY_ADDRESS_BITS = 64  // Used to communicate with the memory
  parameter int PARALLEL_DATA_STREAMING_SIZE = 4, // Memory can output 4 numbers at same time TODO: always divisor of SIZE...
  parameter int MAX_MATRIX_LENGTH = 4096  // Assume the max matrix we will do is 4k
  parameter int COUNTER_BITS = $clog2(MAX_MATRIX_LENGTH + 1) // We need to keep track of a count from 0 to MAX_MATRIX_LENGTH
  parameter int MEMORY_INPUT_COUNTER_BITS = $clog2(MAX_MATRIX_LENGTH * N + 1) // For reading from memory, we read at most MAX_MATRIX_LENGTH * N values
  parameter int CYCLE_COUNTER_BITS = $clog2((MAX_MATRIX_LENGTH/N) + 1) // keep track of how many full data cycles are sent. If we use this for B buffer, the value could become just 1 or 0... (probably keep the bit to a high value in case controller want to fast output A instead of B)
) (
  input   logic                           clk,            // Clock signal
  input   logic                           reset,          // To clear buffer and restore counter

  // Communicate with the control module delivering address to buffer
  input   logic                           address_valid,
  output  logic                           address_ready,
  input   logic [MEMORY_ADDRESS_BITS-1:0] address_input,
  // Communicate with the control module delivering length of operation to buffer
  input   logic                           length_valid,
  output  logic                           length_ready,
  input   logic [COUNTER_BITS-1:0]        length_input,
  // Communicate with the control module delivering number of full cycles the data should be sent to processor
  input   logic                           cycles_valid,
  output  logic                           cycles_ready,
  input   logic [CYCLE_COUNTER_BITS-1:0]  cycles_input,

  // Communicating with memory to read data
  output  logic [MEMORY_ADDRESS_BITS-1:0] memory_address,
  input   logic [DATA_WIDTH-1:0]          memory_data[PARALLEL_DATA_STREAMING_SIZE-1:0],

  // Communicating with the processor
  output  logic                           processor_input_valid,
  input   logic                           processor_input_ready,
  output  logic [DATA_WIDTH-1:0]          processor_input_data[N-1:0],
  output  logic                           last
);
  logic [MEMORY_ADDRESS_BITS-1:0] address_register;
  logic [MEMORY_INPUT_COUNTER_BITS-1:0] memory_reading_counter; // to count if we have read enough data from memory
  logic [COUNTER_BITS-1:0] processor_writing_counter; // to count if we have written enough data to processor
  logic [CYCLE_COUNTER_BITS-1:0] cycle_counter; // to count how many times the full data is sent

  // There shall be 2 main operations: Read from memory and Write to processor

  // Listen from controller: set reading ops to not ready when in operation, only when cycle counter reaches end we set ready.

  // Read from memory: 
  /* always_ff until read address, also read length
   * When both length and address is read:
   *    every clock edge, load address + memory_counter to load address + memory_counter + streaming size to our own memory (sequentially, to Index probably by memory_counter)
   *    stop when memory counter >= length * N
   *    (could consider count down if that's easier)
   */

  // Write to Processor:
  /* always ff until memory counter >= (processor_counter+1) * N (processor counter counts number of Nx1 vectors sent)
   * when there are sufficient data in buffer to start writing the next value, load values from processor_counter*N to (processor_counter+1)*N-1 -> processor_input_data
   * set input valid. 
   * if input valid && input ready, either do next value or input not valid
   * if processor_counter == length, also send last. 
   * (keep sending values, repeatedly) (Until, cycle count reaches threshold) (meaning we should load new data, and end current data)
   * (could consider count DOWN, and just reverse order to output)
   */

  always_ff @(posedge clk) begin
    if (reset) begin
      
    end else if (input_done) begin
      // Input is done, just decrease count and that's it
      counter <= counter - 1;
    end else if (last && input_ready && a_input_valid && b_input_valid) begin  
      // Last input is imposed, we begin countdown. Only count down after we sure data is in
      counter <= counter - 1;
      input_done <= 1;
    end 
  end
endmodule