// Matrix Multiplier DUT

module sum_stationary #(
  parameter int DATA_WIDTH = 8,  // using 8-bit integers 
  parameter int N = 4, // Computing NxN matrix multiplications
  parameter int C_DATA_WIDTH = (2 * DATA_WIDTH) + $clog2(N)
) (
  input                           clk, 
  input                           reset_i,
  input                           valid_i,
  output logic                    valid_o,  // Output is valid when all data is passed through
  input        [DATA_WIDTH-1:0]   a_i[N-1:0],
  input        [DATA_WIDTH-1:0]   b_i[N-1:0],
  output logic [C_DATA_WIDTH-1:0] c_o[N][N]
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
  always_ff @(posedge clk) begin
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
  input_delay_register #(
    .DATA_WIDTH(DATA_WIDTH),
    .N(N)
  ) west_delay_register (
    .clk(clk),
    .reset_i(reset_i),
    .valid_i(valid_i),
    .enable(enable),
    .data_i(a_i[N-1:0]),
    .data_o(west_inputs[N-1:0])
  );
  input_delay_register #(
    .DATA_WIDTH(DATA_WIDTH),
    .N(N)
  ) north_delay_register(
    .clk(clk),
    .reset_i(reset_i),
    .valid_i(valid_i),
    .enable(enable),
    .data_i(b_i[N-1:0]),
    .data_o(north_inputs[N-1:0])
  );

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
        .clk(clk),
        .enable_i(enable),
        .reset_i(reset_i),
        .west_i((j == 0) ? west_inputs[i] : horizontal_interconnect[i][j]),
        .north_i((i == 0) ? north_inputs[j] : vertical_interconnect[i][j]),
        .south_o(vertical_interconnect[i+1][j]),
        .east_o(horizontal_interconnect[i][j+1]),
        .result_o(c_o[i][j])
        );
      end
    end
  endgenerate
endmodule

// Takes 2 values input. Multiply them and accumulate to old results. Stores the input and outputs them next cycle if enable.
module processing_unit #(
  parameter int DATA_WIDTH = 8,
  parameter int N = 4,
  parameter int C_DATA_WIDTH = (2 * DATA_WIDTH) + $clog2(N)
) (
  input                           clk,
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

  always_ff @(posedge clk) begin
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

// Takes a row / col input from a matrix, and delay its input into the actual processing unit for systolic array
module input_delay_register #(
  parameter int DATA_WIDTH = 8,
  parameter int N = 4
) (
  input                           clk, 
  input                           reset_i,
  input                           valid_i,
  input                           enable,
  input        [DATA_WIDTH-1:0]   data_i[N-1:0],
  output logic [DATA_WIDTH-1:0]   data_o[N-1:0]
);
  // Output data's first value is always direct pass thru
  assign data_o[0] = valid_i ? data_i[0] : '0;
  logic [DATA_WIDTH-1:0] shift_reg [N-1:1][N-2:0]; // have registers except top left corner
  generate
      genvar i;
      for (i = 1; i < N; i++) begin : shift_reg_gen
          // Declare each shift_registers with a specific length
          logic [DATA_WIDTH-1:0] shift_reg_i [i-1:0]; // each has length 1,2,3,...,N-1

          // Implement shift register functionality
          always_ff @(posedge clk) begin
              if (reset_i) begin
                  // Reset the shift register
                  for (int j = 0; j < i; j++) begin
                      shift_reg_i[j] <= {DATA_WIDTH{1'b0}};
                  end
              end else begin
                  if (enable) begin
                      // Shift register operation
                      for (int j = i-1; j > 0; j--) begin
                          shift_reg_i[j] <= shift_reg_i[j-1];
                      end
                      shift_reg_i[0] <= valid_i ? data_i[i] : '0; // Shift in the input
                  end
              end
          end
          assign shift_reg[i][i-1:0] = shift_reg_i; // Assign internal shift register to the array
          assign data_o[i] = shift_reg_i[i-1]; // Connect the output
      end
  endgenerate
endmodule