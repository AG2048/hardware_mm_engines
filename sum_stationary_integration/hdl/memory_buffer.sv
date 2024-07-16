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
  parameter int MEMORY_ADDRESS_BITS = 64  // Used to communicate with the memory
  parameter int MAX_MATRIX_LENGTH = 4096  // Assume the max matrix we will do is 4k
  parameter int COUNTER_BITS = $clog2(MAX_MATRIX_LENGTH + 1) // We need to keep track of a count
) (
  input   logic                       clk,            // Clock signal
  input   logic                       reset,

  input   logic address_valid,
  output logic address_ready,
  input logic [MEMORY_ADDRESS_BITS-1:0] address_input,

  input logic [DATA_WIDTH-1:0] input_data[N-1:0],

  output logic processing_unit_input_valid,
  input logic processing_unit_input_ready,
  output logic [DATA_WIDTH-1:0] processing_unit_input_data[N-1:0],
  output logic last
);
  logic [MEMORY_ADDRESS_BITS-1:0] address_register;
  logic [COUNTER_BITS-1:0] counter;
  logic [COUNTER_BITS-1:0] counter;
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