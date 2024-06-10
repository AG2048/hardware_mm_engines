// This file is public domain, it can be freely copied without restrictions.
// SPDX-License-Identifier: CC0-1.0

// Matrix Multiplier DUT
`timescale 1ns/1ps

`ifdef VERILATOR  // make parameter readable from VPI
  `define VL_RD /*verilator public_flat_rd*/
`else
  `define VL_RD
`endif

// Define
module processing_unit #(
  parameter int DATA_WIDTH `VL_RD = 8,
  parameter int N `VL_RD = 4,
  parameter int C_DATA_WIDTH = (2 * DATA_WIDTH) + $clog2(N)
) (
  input                           clk_i,
  input                           enable_i,
  input                           reset_i,
  input        [DATA_WIDTH-1:0]   west_i,
  input        [DATA_WIDTH-1:0]   north_i,
  output       [DATA_WIDTH-1:0]   south_o,
  output       [DATA_WIDTH-1:0]   east_o,
  output logic [C_DATA_WIDTH-1:0] result_o
);
  logic [C_DATA_WIDTH-1:0] result_calc;
  logic [C_DATA_WIDTH-1:0] result_reg;

  assign result_calc = north_i * west_i + result_reg;
  assign result_o = result_reg;

  logic [DATA_WIDTH-1:0] north_i_reg;
  logic [DATA_WIDTH-1:0] west_i_reg;
  assign south_o = north_i_reg;
  assign east_o = west_i_reg;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      north_i_reg <= '0;
      west_i_reg <= '0;
      result_reg <= '0;
    end else begin
      if (enable_i) begin
        result_reg <= result_calc;
        north_i_reg <= north_i;
        west_i_reg <= west_i;
      end
    end
  end
endmodule

module sum_stationary #(
  parameter int DATA_WIDTH `VL_RD = 8,  // using 8-bit integers 
  parameter int N `VL_RD = 4, // Computing NxN matrix multiplications
  parameter int C_DATA_WIDTH = (2 * DATA_WIDTH) + $clog2(N)
) (
  input                           clk_i, 
  input                           reset_i,
  input                           valid_i,
  output logic                    valid_o,  // Output is valid when all data is passed through
  input        [DATA_WIDTH-1:0]   a_i[N],
  input        [DATA_WIDTH-1:0]   b_i[N],
  output logic [C_DATA_WIDTH-1:0] c_o[N*N]
);
  /*
  define "shift registers" that only gets triggered when enabled (size ranging from 0 to N-1)
    input of those tied to a_i's units
    output tied to processing units
  define array of processing units
  define an "enable" signal, that is tied to valid_i, 
  
  but enable is false when valid_o until reset
  valid_o tied to a counter of some sort (count from 2N-1 to 0, decrement only when "enable")
  */

  // Define valid signal
  logic [$clog2(3*N-1)-1:0] counter;
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      counter <= 3 * N - 2;
    end else if (valid_i || (counter <= 2 * N - 2) && ~valid_o) begin
      counter <= counter - 1;
    end
  end
  assign valid_o = counter == 0;

  // Define enable signal
  logic enable;
  assign enable = valid_i || (counter <= 2 * N - 2) && ~valid_o; // enable to propagate data when: input valid, input filled, output not valid. 

  // Define input data to the unit matrix
  logic [DATA_WIDTH-1:0] north_inputs [N-1:0];
  logic [DATA_WIDTH-1:0] west_inputs [N-1:0];
  assign west_inputs[0] = valid_i ? a_i[0] : '0;
  assign north_inputs[0] = valid_i ? b_i[0] : '0;

  // Define shift registers
  logic [DATA_WIDTH-1:0] west_shift_reg [N-1:1][]; // have registers except to left corner
  generate
      genvar i1;
      for (i1 = 1; i1 < N; i1++) begin : shift_reg_gen_west
          // Declare each shift_registers with a specific length
          logic [DATA_WIDTH-1:0] shift_reg_i [i1-1:0]; // each has length 1,2,3,...,N-1

          // Implement shift register functionality
          always_ff @(posedge clk_i) begin
              if (reset_i) begin
                  // Reset the shift register
                  for (int j1 = 0; j1 < i1; j1++) begin
                      shift_reg_i[j1] <= {DATA_WIDTH{1'b0}};
                  end
              end else begin
                  if (enable) begin
                      // Shift register operation
                      for (int j1 = i1-1; j1 > 0; j1--) begin
                          shift_reg_i[j1] <= shift_reg_i[j1-1];
                      end
                      shift_reg_i[0] <= valid_i ? a_i[i1] : '0; // Shift in the input
                  end
              end
          end
          assign west_shift_reg[i1] = shift_reg_i; // Assign internal shift register to the array
          assign west_inputs[i1] = shift_reg_i[i1-1]; // Connect the output
      end
  endgenerate

  logic [DATA_WIDTH-1:0] north_shift_reg [N-1:1][]; // have registers except to left corner
  generate
      genvar i2;
      for (i2 = 1; i2 < N; i2++) begin : shift_reg_gen_north
          // Declare each shift_registers with a specific length
          logic [DATA_WIDTH-1:0] shift_reg_i [i2-1:0]; // each has length 1,2,3,...,N-1

          // Implement shift register functionality
          always_ff @(posedge clk_i) begin
              if (reset_i) begin
                  // Reset the shift register
                  for (int j2 = 0; j2 < i2; j2++) begin
                      shift_reg_i[j2] <= {DATA_WIDTH{1'b0}};
                  end
              end else begin
                  if (enable) begin
                      // Shift register operation
                      for (int j2 = i2-1; j2 > 0; j2--) begin
                          shift_reg_i[j2] <= shift_reg_i[j2-1];
                      end
                      shift_reg_i[0] <= valid_i ? b_i[i2] : '0; // Shift in the input
                  end
              end
          end
          assign north_shift_reg[i2] = shift_reg_i; // Assign internal shift register to the array
          assign north_inputs[i2] = shift_reg_i[i2-1]; // Connect the output
      end
  endgenerate


  // Define NxN array of processing units
  logic [DATA_WIDTH-1:0] horizontal_interconnect[N:0][N:1]; // The input the i,j th unit will get from west, last is not used
  logic [DATA_WIDTH-1:0] vertical_interconnect[N:1][N:0]; // The input the i,j th unit will get from north, last is not used
  generate
    genvar i, j;
    for (i = 0; i < N; i++) begin : row
      for (j = 0; j < N; j++) begin : col
        processing_unit #(
          .DATA_WIDTH(DATA_WIDTH),
          .N(N)
        ) u_processing_unit (
        .clk_i(clk_i),
        .enable_i(enable),
        .reset_i(reset_i),
        .west_i((j == 0) ? west_inputs[i] : horizontal_interconnect[i][j]),
        .north_i((i == 0) ? north_inputs[j] : vertical_interconnect[i][j]),
        .south_o(vertical_interconnect[i+1][j]),
        .east_o(horizontal_interconnect[i][j+1]),
        .result_o(c_o[i*N+j])
        );
      end
    end
  endgenerate
endmodule