// This file is public domain, it can be freely copied without restrictions.
// SPDX-License-Identifier: CC0-1.0

// Matrix Multiplier DUT
`timescale 1ns/1ps
module hard_coded #(
  parameter int DATA_WIDTH = 8,  // using 8-bit integers 
  parameter int A_ROWS = 4,
  parameter int B_COLUMNS = 4,
  parameter int A_COLUMNS_B_ROWS = 4,  // These define an 4x4 * 4x4 matrix
  parameter int C_DATA_WIDTH = (2 * DATA_WIDTH) + $clog2(A_COLUMNS_B_ROWS)
) (
  input                           clk, 
  input                           reset_i,
  input                           valid_i,
  output logic                    valid_o,
  input        [DATA_WIDTH-1:0]   a_i[A_ROWS * A_COLUMNS_B_ROWS],
  input        [DATA_WIDTH-1:0]   b_i[A_COLUMNS_B_ROWS * B_COLUMNS],
  output logic [C_DATA_WIDTH-1:0] c_o[A_ROWS * B_COLUMNS]
);
  // C calculation uses C_DATA_WIDTH, each corresponding to output size
  logic [C_DATA_WIDTH-1:0] c_calc[A_ROWS * B_COLUMNS];

  // Combinational Logic for multiplying (this has a long data path)
  always @(*) begin : multiply
    logic [C_DATA_WIDTH-1:0] c_element;
    for (int i = 0; i < A_ROWS; i = i + 1) begin : C_ROWS
      for (int j = 0; j < B_COLUMNS; j = j + 1) begin : C_COLUMNS
        c_element = 0;
        for (int k = 0; k < A_COLUMNS_B_ROWS; k = k + 1) begin : DOT_PRODUCT
          c_element = c_element + (a_i[(i * A_COLUMNS_B_ROWS) + k] * b_i[(k * B_COLUMNS) + j]);
        end
        c_calc[(i * B_COLUMNS) + j] = c_element;
      end
    end
  end

  always @(posedge clk) begin : proc_reg
    if (reset_i) begin
      valid_o <= 1'b0;

      for (int idx = 0; idx < (A_ROWS * B_COLUMNS); idx++) begin
        c_o[idx] <= '0;
      end
    end else begin
      valid_o <= valid_i;  // Due to the "hard-wired" nature, output is valid always when input is valid (but it really depends on data length)
      // Considering that input may be given at the "end" of a clock cycle, while data path may take longer

      for (int idx = 0; idx < (A_ROWS * B_COLUMNS); idx++) begin
        c_o[idx] <= c_calc[idx];
      end
    end
  end

endmodule
