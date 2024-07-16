/*
 *  Dummy Memory Module
 *  Always output corresponding data in read mode, regardless of clock cycle, with a "valid" signal when doing so
 *  Write mode: load data to corresponding address on next clock edge. 
 */

// Each memory can store a lot of data in linear table

// Output and input takes in value, and populates memory at: address, address+1, address+2, ..., address+PARALLEL_DATA_STREAMING_SIZE-1

module simple_memory #(
  parameter int DATA_WIDTH = 8,   // Using 8-bit integers 
  parameter int PARALLEL_DATA_STREAMING_SIZE = 4, // It can output 4 numbers at same time TODO: always divisor of SIZE...
  parameter int SIZE = 1024,      // How many numbers of DATA_WIDTH it can store
  parameter int ADDRESS_BITS = $clog2(SIZE + 1) // Address is corresponding to SIZE to 0
) (
  input   logic                       clk,            // Clock signal
  input   logic                       write_valid,
  output  logic                       write_ready,
  input   logic   [ADDRESS_BITS-1:0]  write_address,
  input   logic   [DATA_WIDTH-1:0]    write_data[PARALLEL_DATA_STREAMING_SIZE-1:0],

  // output  logic                       read_valid,
  // input   logic                       read_ready,
  input   logic   [ADDRESS_BITS-1:0]  read_address,
  output  logic   [DATA_WIDTH-1:0]    read_data[PARALLEL_DATA_STREAMING_SIZE-1:0],
);
  // The memory's data (we manually set first 16 to be 1-16)
  logic [DATA_WIDTH-1:0] memory_data[SIZE] = '{
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
    default: 0
  };

  // Read
  always_comb begin
    for (int i = 0; i < PARALLEL_DATA_STREAMING_SIZE; i++) begin
      read_data[i] = memory_data[read_address+i];
    end
  end

  // Write (write to write_address when write_valid is 1)
  always_ff @(posedge clk) begin
    write_ready <= '1;
    if (write_valid) begin
      for (int i = 0; i < PARALLEL_DATA_STREAMING_SIZE; i++) begin
        memory_data[write_address+i] = write_data[i];
      end
    end
  end
endmodule