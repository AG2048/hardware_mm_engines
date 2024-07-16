/*
 *  Dummy Memory Module
 *  Always output corresponding data in read mode, regardless of clock cycle, with a "valid" signal when doing so
 *  Write mode: load data to corresponding address on next clock edge. 
 */

// Each memory can store a lot of data in linear table

module simple_memory #(
  parameter int DATA_WIDTH = 8,   // Using 8-bit integers 
  parameter int SIZE = 1024,      // How many numbers of DATA_WIDTH it can store
  parameter int ADDRESS_BITS = $clog2(SIZE + 1) // Address is corresponding to SIZE to 0
) (
  input   logic                       clk,            // Clock signal
  input   logic                       write_valid,
  output  logic                       write_ready,
  input   logic   [ADDRESS_BITS-1:0]  write_address,
  input   logic   [DATA_WIDTH-1:0]    write_data,

  // output  logic                       read_valid,
  // input   logic                       read_ready,
  input   logic   [ADDRESS_BITS-1:0]  read_address,
  output  logic   [DATA_WIDTH-1:0]    read_data,
);
  

endmodule