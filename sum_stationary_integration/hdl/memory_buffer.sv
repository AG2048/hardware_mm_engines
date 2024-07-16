/*  Memory buffer:
 *  Reads instruction (memory address, length of input, how many times this input is to be sent to processor(s))
 *  Reads from RAM according to instructions, loads value onto on-chip memory/buffer
 *  Writes the values to processor (with a "last" signal), cycle for num_cycle times
 */

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

  // Communicate with the control module delivering instructions to buffer - To be connected to controller (send instructions on rising edge where valid and ready)
  input   logic                           instruction_valid, 
  output  logic                           instruction_ready,
  input   logic [MEMORY_ADDRESS_BITS-1:0] address_input, // The start address of the memory where the data will be. (data will be at addr: address_input, address_input+1, address_input+2...)
  input   logic [COUNTER_BITS-1:0]        length_input, // How big is the input, we will send matrix multiplication of [N x length_input] * [length_input x N]
  input   logic [CYCLE_COUNTER_BITS-1:0]  cycles_input, // How many times the full buffer will be sent to processor before accepting new instructions. (for data reuse)

  // Communicating with memory to read data (TODO: assuming memory read have no delay)
  output  logic [MEMORY_ADDRESS_BITS-1:0] memory_address, // address we are telling the memory we are reading from
  input   logic [DATA_WIDTH-1:0]          memory_data[PARALLEL_DATA_STREAMING_SIZE-1:0], // the data bus of PARALLEL_DATA_STREAMING_SIZE values each of size DATA_WIDTH

  // Communicating with the processor
  output  logic                           processor_input_valid, // valid for processor input
  input   logic                           processor_input_ready, // ready for processor input
  output  logic [DATA_WIDTH-1:0]          processor_input_data[N-1:0], // the N len vector of row/col to be sent
  output  logic                           last // The signal sent alongside the last value in the operation to tell the module to "wrap up" computation
);
  /************************
   * Read from controller *
   ************************/
  // Define Registers
  logic [MEMORY_ADDRESS_BITS-1:0] address_register; // remember the memory address after receiving from controller
  logic [COUNTER_BITS-1:0] length_register; // remember the length of input matrix after receiving from controller
  logic [CYCLE_COUNTER_BITS-1:0] cycles_counter; // to count how many times the full data is sent (used to set ready signals with controller)
  // Always FF Block
  always_ff @(posedge clk) begin : read_from_controller
    if (reset || (cycles_counter == 1 && last && processor_input_valid && processor_input_ready)) begin
      /* Reset when:
       *  we are on last cycle
       *  we are writing the last value
       *  It's valid and ready
       */
      address_register <= '0;
      length_register <= '0;
      cycles_counter <= '0;
    end else begin
      // Load data based on ready valid handshake
      if (instruction_valid && instruction_ready) begin
        address_register <= address_input;
        length_register <= length_input;
        cycles_counter <= cycles_input;
      end else if (cycle_counter != 0) begin
        // Decrement cycles counter (decrease right after "last" is asserted)
        if (last && processor_input_valid && processor_input_ready) begin
          cycles_counter <= cycles_counter - 1;
        end
      end
    end 
  end
  // Receive new instructions when counter reaches 0
  assign instruction_ready = cycle_counter == 0;

  /********************
   * Read from memory *
   ********************/
  // Read from memory as long as we are operating. Only read until counter reaches length of values we need to read. 
  logic [MEMORY_INPUT_COUNTER_BITS-1:0] memory_reading_counter; // to count if we have read enough data from memory (always represent number of values written in buffer)
  logic [DATA_WIDTH-1:0] memory_buffer_registers[M * N - 1 : 0]; // Flat buffer, we send memory_buffer_registers[N * (i+1) - 1 : N * i]
  // We don't need to clear the memory registers on reset, just have to not access it
  always_ff @(posedge clk) begin : read_from_memory
    if (reset) begin
      memory_reading_counter <= '0;
    end else if (cycles_counter != 0) begin
      // In operation, check if enough memory has been read. If not, read it.
      if (memory_reading_counter < length_register * N) begin
        // TODO: we are really assuming N and M are integer multiples... of PARALLEL_DATA_STREAMING_SIZE
        memory_reading_counter <= memory_reading_counter + PARALLEL_DATA_STREAMING_SIZE; 
        memory_buffer_registers[memory_reading_counter+PARALLEL_DATA_STREAMING_SIZE-1 : memory_reading_counter] = memory_data[PARALLEL_DATA_STREAMING_SIZE-1:0];
      end
    end
  end
  assign memory_address = address_register + memory_reading_counter;

  /**********************
   * Write to processor *
   **********************/
  // Count number of vectors successfully written. Valid when there are sufficient number in buffer to output. Last when counter reached len_reg-1
  logic [COUNTER_BITS-1:0] processor_writing_counter; // to count if we have written enough data to processor, count the number of data successfully written in this cycle
  // TODO if this is critical path, consider using count down (add some sort of reset to processor_writing_counter <= length_register-1 when first set - instruction valid and ready maybe?)
  // TODO: down side: then the memory buffer registers' reading will be difficult. 
  always_ff @(posedge clk) begin : write_to_processor
    if (reset) begin
      processor_writing_counter <= 0;
    end else if (processor_input_ready && processor_input_valid) begin
      // Increase the counter (if at end cycle back)
      if (last) begin
        // cycle back
        processor_writing_counter <= 0;
      end else begin
        processor_writing_counter <= processor_writing_counter + 1;
      end
    end
  end
  assign processor_input_valid = memory_reading_counter >= (processor_writing_counter+1) * N;
  assign processor_input_data = memory_buffer_registers[(processor_writing_counter+1)*N - 1 : processor_writing_counter*N];
  assign last = processor_writing_counter == length_register-1; // when counter is len-1, the next number is last.
endmodule