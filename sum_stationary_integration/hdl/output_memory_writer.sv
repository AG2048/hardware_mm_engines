/*  Output memory writer:
 *  Reads instruction (output memory address, and ready/valid for instructions, and ready/valid for memory writing)
 *  Writes ready/valid to processor
 *  Buffers 1 row/col of the output and writes to memory, also asserts the row/column output format.
 */

module output_memory_writer #(
  parameter int OUTPUT_DATA_WIDTH = 18,           // Using 8-bit integers 

  parameter int B_N = 2,                    // What's the width of the processing units
  parameter int N = 1 << B_N,                    // What's the width of the processing units

  parameter int B_MEMORY_ADDRESS_BITS = 6  // Used to communicate with the memory 2^6
  parameter int B_PARALLEL_DATA_STREAMING_SIZE = 2, // Memory can output 4 numbers at same time (2^2) TODO: always divisor of SIZE...

  parameter int MEMORY_ADDRESS_BITS = 1 << B_MEMORY_ADDRESS_BITS  // Used to communicate with the memory
  parameter int PARALLEL_DATA_STREAMING_SIZE = 1 << B_PARALLEL_DATA_STREAMING_SIZE, // Memory can output 4 numbers at same time TODO: always divisor of SIZE...
  
  parameter int COUNTER_BITS = $clog2(N-1 + 1) // We count from 0 to N-1 for cycles written
  parameter int MEMORY_INPUT_COUNTER_BITS = $clog2(MAX_MATRIX_LENGTH * N + 1) // For reading from memory, we read at most MAX_MATRIX_LENGTH * N values
) (
  input   logic                           clk,            // Clock signal
  input   logic                           reset,          // To clear buffer and restore counter

  // Communicate with the control module delivering instructions to buffer - To be connected to controller (send instructions on rising edge where valid and ready)
  input   logic                           instruction_valid, 
  output  logic                           instruction_ready,
  input   logic [MEMORY_ADDRESS_BITS-1:0] address_input, // The start address of the memory where the data will be sent to. (data will be to addr: address_input, address_input+1, address_input+2...)
  input   logic                           output_by_row_instruction, // 1 to output by row, 0 to output by col

  // Communicate with the control module saying that the write operation is completed. Use handshake because NoC possibly
  // TODO add this handshake
  input   logic                           completed_ready, 
  output  logic                           completed_valid,

  // Communicating with memory to write data (TODO: assuming memory read have no delay)
  output  logic                           write_valid,
  input   logic                           write_ready,
  output  logic [MEMORY_ADDRESS_BITS-1:0] write_address,
  output  logic [DATA_OUTPUT_DATA_WIDTHWIDTH-1:0]          write_data[PARALLEL_DATA_STREAMING_SIZE-1:0],

  // Communicating with the processor
  input   logic                           output_valid,
  output  logic                           output_by_row,  // Indicate if output should be done row wise or col wise
  output  logic                           output_ready,  
  input   logic [OUTPUT_DATA_WIDTH-1:0]   c_data_streaming[N]
);
  /************************
   * Read from controller *
   ************************/
  // Define Registers
  logic [MEMORY_ADDRESS_BITS-1:0] address_register; // remember the memory address after receiving from controller
  logic [COUNTER_BITS-1:0] processor_read_counter; // Counts how many times data is read from module (from 0 to N-1)
  logic output_by_row_instruction_register;
  logic in_operation_register; // Tell module if we should be reading from processor / writing to memory // TODO is this used?
  logic completed_register; // remember if all operations have been completed

  // Always FF Block
  always_ff @(posedge clk) begin : read_from_controller
    if (reset || (processor_read_counter == N-1 && memory_write_counter == N-PARALLEL_DATA_STREAMING_SIZE && write_valid && write_ready)) begin
      /* Reset when:
       *  We have finished reading the last value from processor
       *  we are currently ready to write the last bit of value to memory (N-StreamingSize)
       *  Ready and valid to write (the clock cycle the memory will have been written the value)
       */
      address_register <= '0;
      processor_read_counter <= '0;
      output_by_row_instruction_register <= '0;
      in_operation_register <= '0;
      // Set done flag to true or false
      if (reset) begin
        // Reset then we reset completed_register
        completed_register <= '0;
      end else begin
        // We reached here because we finished data transfer
        completed_register <= '1;
      end
    end else begin
      // Load data based on ready valid handshake
      if (instruction_valid && instruction_ready) begin
        address_register <= address_input;
        output_by_row_instruction_register <= output_by_row_instruction;
        in_operation_register <= '1;
      end
      if (output_valid && output_ready) begin
        // Increase the counter when we read from processor
        processor_read_counter <= processor_read_counter + 1;
      end
      if (completed_valid && completed_ready) begin
        // Controller had read that we are done with writing
        completed_register <= '0;
      end
    end 
  end
  // Read instruction if we are not DONE, and not in operation. 
  assign instruction_ready = !completed_register && !in_operation_register;
  // We valid completed when we completed...
  assign completed_valid = completed_register;

  /*******************************************
   * Read from Processor and Write to Memory *
   *******************************************/
  // Define a temp buffer for 1 row
  logic [OUTPUT_DATA_WIDTH-1:0] output_writer_buffer[N-1:0];

  // Define a register for memory write valid
  logic write_valid_register;

  // Memory writing also require a counter
  logic [COUNTER_BITS-1:0] memory_write_counter; // counts to N-1

  // Assert output by row or not
  assign output_by_row = output_by_row_instruction_register;

  always_ff @(posedge clk) begin : read_from_processor
    if (reset) begin
      for (int i = 0; i < N; i++) begin
        output_writer_buffer[i] <= '0;
      end
      write_valid_register <= '0;
      memory_write_counter <= '0;
    end else begin
      // Process output from processor
      if (output_ready && output_valid) begin
        // Increase the counter (if at end cycle back)
        for (int i = 0; i < N; i++) begin
          output_writer_buffer[i] <= c_data_streaming[i];
        end
        // Now there are contents in buffer, can write to memory
        write_valid_register <= '1;
      end

      // Write to memory and reset write_ready_register if necessary
      if (write_ready && write_valid) begin
        // Writing to memory, update counter after write
        memory_write_counter <= memory_write_counter + PARALLEL_DATA_STREAMING_SIZE;
        if (memory_write_counter == N-PARALLEL_DATA_STREAMING_SIZE) begin
          // Again, here we assume PARALLEL_DATA_STREAMING_SIZE is divisor of N
          // This indicates the write that just happened is the last one
          memory_write_counter <= '0;
          write_valid_register <= '0;
        end
      end
    end
  end

  // Only ready to read from processor if we are in operation, and buffer is empty (indicated by write not ready)
  assign output_ready = in_operation_register && write_valid_register == 0;

  assign write_valid = write_valid_register;

  // Write address is base address + offset
  assign write_address = address_register + memory_write_counter;

  // Assign write data lines
  for (int i = 0; i < PARALLEL_DATA_STREAMING_SIZE; i++) begin
    write_data[i] = output_writer_buffer[memory_write_counter + i];
  end
endmodule