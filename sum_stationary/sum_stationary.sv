// Matrix Multiplier DUT

/* Design Specification - Last Updated June 25
 * Inputs columns of A and rows of B sequantially by reverse order 
 *    (row N and col N input first) (but I guess this can be flipped if it's bad for future implementations)
 * Input ready to indicate when the CURRENT data is received and the device should start receiving new signals on next cycle
 *    (When both A and B inputs are valid, and we are not currently processing a previous matrix multiplication)
 * Data input as a row will be "delayed and shifted" by a shift register
 *    TODO (one option is to make the input to procesisng unit MUX'd with a flag of "reusing data") since if we reuse the 
 *     row output of one iteration again, there's no need to shift it again
 * Data propagates through the processing units
 *    North and west inputs are multiplied/accumulated/stored in the next edge. Original values are sent off to next unit.
 *    TODO (If we want tight input layout, we can program an "accept new" MUX to not let it clear but to latch in the new input)
 * Counter is used to determine current state of processing
 *    Start to be (2*N-1 + len_input-1), 2N-1 is cycle needed for result to reach from input to end. len_input-1 is needed to input all signals
 *    Before it reaches 2N-2, it's receiving new inputs.
 *    After it reaches 2N-2, all values should either be in registers on in the processing units, so we stop taking inputs
 *    When it reaches 0, result is valid.
 * When result valid: 
 *    Send data to output buffer and clear all contents. ONLY when output NOT VALID (output buffer is empty)
 *    TODO: consider splitting output_valid and an output_buffer_empty signal
 *    Reset count.
 * Output Buffer:
 *    Sends data out row by row or col by col based on the first OUTPUT_READY signal received when OUTPUT_VALID is first asserted. 
 */

 /* Development Plan
  * Fix input or output ordering - try to make input order and output order the same
  * Modify processing units to shorten the data path. 
  * MUX of the unit accepting register output OR data reusing? But this depends on how big the input is. 
  *   If it's a very wide matrix it can be bad - how to know how to size this data reuse?
  */

module sum_stationary #(
  parameter int DATA_WIDTH = 8,   // Using 8-bit integers 
  parameter int N = 4,            // Computing NxN matrix multiplications
  parameter int C_DATA_WIDTH = (2 * DATA_WIDTH) + $clog2(N),  // Compute max possible output bits
  parameter int COUNTER_BITS = 16 // Assume we only need to count for 16 bits of counter value (65535)
) (
  input                           clk,            // Clock signal
  input                           reset,          // Reset signal
  input                           a_input_valid,    // External input to module is correct/valid
  input                           b_input_valid,    // External input to module is correct/valid
  input                           output_ready,   // External device is ready to receive output
  output                          input_ready,    // Device ready to receive input
  output logic                    output_valid,   // Output is valid when all data is passed through
  input logic                     output_by_row,  // Indicate if output should be done row wise or col wise
  input        [COUNTER_BITS-1:0] len_input,      // Indicate how "wide" the multiplication is, along with first input_valid. TODO: how many bits should this have? (16 bits should be enough for an N=32 len=4096 matrix)
  input        [DATA_WIDTH-1:0]   a_data[N-1:0],  // Column inputs of A (right to left)
  input        [DATA_WIDTH-1:0]   b_data[N-1:0],  // Row inputs of B (bottom to top)
  output logic [C_DATA_WIDTH-1:0] c_data_streaming[N]    // Streaming data output of C
);

  // Define result valid signal
  logic [COUNTER_BITS-1:0] counter;  // Program executes in set number of cycles, count number of cycles
  logic is_first_input;  // Flag register recording if this is the first "result_valid"
  assign result_valid = counter == 0;  // Counter won't count down anymore (enable false) when result valid
  logic enable;
  always_ff @(posedge clk) begin
    if (reset || (result_valid && !output_valid)) begin
      // Store 3N-2 as default, value change when is_first_input AND input_valid
      counter <= 3 * N - 1;  // N-1 to shift data onto registers, N-1 to pass data through registers, N to compute
      is_first_input <= 1;
    end else if (enable && is_first_input) begin  // First time count differently
      counter <= 2*N-1 + len_input-1;  // 2*N-1 to pass from beginning of shift register to the end. len_input-1 to reach the beginning of shift register. -1 because this is already the first cycle.
      is_first_input <= 0;
    end else if (enable) begin  // Only count when data being input, OR all data is now in registers. Never when output_valid
      counter <= counter - 1;
    end
  end

  // Define enable signal -- shift data in registers and inside the systolic array
  assign enable = ((a_input_valid && b_input_valid) || (counter <= 2 * N - 1)) && !result_valid;  // Process data when data being input, OR all data is now in registers. Never when output_valid

  // Define input ready -- can input when counter is > 2*N-2
  assign input_ready = (counter > 2 * N - 1) && (a_input_valid && b_input_valid); // Adding both input valid to ensure not one device ends input early  
  // TODO: for tight input, input ready can be just: if output buffer finished last output yet AND if our new input reached the state for data to be output (because this way we assume data is "tight")

  // Define input data to the unit matrix
  logic [DATA_WIDTH-1:0] north_inputs [N-1:0];  // North Inputs have N inputs (B's row)
  logic [DATA_WIDTH-1:0] west_inputs [N-1:0];  // West Inputs have N inputs (A's column)
  input_delay_register #(
    .DATA_WIDTH(DATA_WIDTH),
    .N(N)
  ) west_delay_register (
    .clk(clk),
    .reset(reset || (result_valid && !output_valid)),
    .input_valid(a_input_valid),  // Only 1 valid is needed because shifting data is dependent on enable, not input valid
    .enable(enable),
    .data_i(a_data[N-1:0]),
    .data_o(west_inputs[N-1:0])
  );
  input_delay_register #(
    .DATA_WIDTH(DATA_WIDTH),
    .N(N)
  ) north_delay_register(
    .clk(clk),
    .reset(reset || (result_valid && !output_valid)),
    .input_valid(b_input_valid),
    .enable(enable),
    .data_i(b_data[N-1:0]),
    .data_o(north_inputs[N-1:0])
  );

  // Define NxN array of processing units
  logic [DATA_WIDTH-1:0] horizontal_interconnect[N:0][N:1]; // The input the i,j th unit will get from west, last is not used
  logic [DATA_WIDTH-1:0] vertical_interconnect[N:1][N:0]; // The input the i,j th unit will get from north, last is not used
  logic [C_DATA_WIDTH-1:0] c_data[N-1:0][N-1:0]; // Full computation of C to be buffered
  generate
    genvar i, j;
    for (i = 0; i < N; i++) begin : row
      for (j = 0; j < N; j++) begin : col
        processing_unit #(
          .DATA_WIDTH(DATA_WIDTH),
          .N(N)
        ) u_processing_unit (
          .clk(clk),
          .enable(enable),
          .reset(reset || (result_valid && !output_valid)),
          .west_i((j == 0) ? west_inputs[i] : horizontal_interconnect[i][j]),
          .north_i((i == 0) ? north_inputs[j] : vertical_interconnect[i][j]),
          .south_o(vertical_interconnect[i+1][j]),
          .east_o(horizontal_interconnect[i][j+1]),
          .result_o(c_data[i][j])
        );
      end
    end
  endgenerate

  // Output streaming unit
  output_streaming_registers #(
    .C_DATA_WIDTH(C_DATA_WIDTH),
    .N(N)
  ) u_output_streaming_registers (
    .clk(clk),
    .reset(reset),
    .result_valid(result_valid),   
    .output_by_row(output_by_row),  
    .output_ready(output_ready),   
    .output_valid(output_valid),   
    .c_data(c_data),   
    .output_data(c_data_streaming)
  );
endmodule

// Takes 2 values input. Multiply them and accumulate to old results. Stores the input and outputs them next cycle if enable.
module processing_unit #(
  parameter int DATA_WIDTH = 8,
  parameter int N = 4,
  parameter int C_DATA_WIDTH = (2 * DATA_WIDTH) + $clog2(N),
  parameter int PRODUCT_WIDTH = (2 * DATA_WIDTH)
) (
  input                           clk,      // Clock signal
  input                           enable,   // Send data to next, and calculate result to store it
  input                           reset,    // Reset signal
  input        [DATA_WIDTH-1:0]   west_i,   // West input
  input        [DATA_WIDTH-1:0]   north_i,  // North input
  output       [DATA_WIDTH-1:0]   south_o,  // South output
  output       [DATA_WIDTH-1:0]   east_o,   // East output
  output logic [C_DATA_WIDTH-1:0] result_o  // Result output
);
  // Output is stored in result_reg, while calculation is in result_calc wire before storing
  logic [C_DATA_WIDTH-1:0] result_calc;
  logic [C_DATA_WIDTH-1:0] result_reg;
  logic [PRODUCT_WIDTH-1:0] product_calc;
  logic [PRODUCT_WIDTH-1:0] product_reg;

  // Flag for product ready to be added with result reg
  logic product_calculated;

  // Calculate result comb
  assign result_calc = product_reg + result_reg;
  assign product_calc = north_i * west_i;
  // TODO: add a product_calc and a product_reg to improve clock cycle of the design. But may have to adjust how enable / counter works

  // Output is always result register
  assign result_o = result_reg;

  // Store value and output through other side
  logic [DATA_WIDTH-1:0] north_i_reg;
  logic [DATA_WIDTH-1:0] west_i_reg;
  assign south_o = north_i_reg;
  assign east_o = west_i_reg;

  // Store data when enable
  always_ff @(posedge clk) begin
    if (reset) begin
      north_i_reg <= '0;
      west_i_reg <= '0;
      result_reg <= '0;
      product_reg <= '0;
      product_calculated <= '0;
    end else begin
      if (enable) begin
        product_reg <= product_calc;
        product_calculated <= '1;
        north_i_reg <= north_i;
        west_i_reg <= west_i;
      end else begin
        product_calculated <= '0;
      end
      if (product_calculated) begin
        result_reg <= result_calc;
      end
    end
  end
endmodule

// Takes a row / col input from a matrix, and delay its input into the actual processing unit for systolic array
module input_delay_register #(
  parameter int DATA_WIDTH = 8,   // Data Width
  parameter int N = 4             // Matrix Side Length
) (
  input                           clk,            // Clock Signal
  input                           reset,          // Reset signal
  input                           input_valid,    // Load the data into the registers
  input                           enable,         // Shift the shift registers
  input        [DATA_WIDTH-1:0]   data_i[N-1:0],  // Input Data from outside modules
  output logic [DATA_WIDTH-1:0]   data_o[N-1:0]   // Output Data sent to systolic array units
);
  // Output data's first value is always direct pass thru
  assign data_o[0] = input_valid ? data_i[0] : '0;

  // Generate a "straircase" array of shift registers
  logic [DATA_WIDTH-1:0] shift_reg [N-1:1][N-2:0]; // Have registers except top left corner
  generate
    genvar i;
    for (i = 1; i < N; i++) begin : shift_reg_gen
      // Declare each shift_registers with a specific length
      logic [DATA_WIDTH-1:0] shift_reg_i [i-1:0]; // each has length 1,2,3,...,N-1

      // Implement shift register functionality
      always_ff @(posedge clk) begin
        if (reset) begin
          // Reset the shift register
          for (int j = 0; j < i; j++) begin
            shift_reg_i[j] <= {DATA_WIDTH{1'b0}};
          end
        end else if (enable) begin
          // Shift register operation
          for (int j = i-1; j > 0; j--) begin
            shift_reg_i[j] <= shift_reg_i[j-1];
          end
          shift_reg_i[0] <= input_valid ? data_i[i] : '0; // Shift in the input
        end
      end
      assign shift_reg[i][i-1:0] = shift_reg_i; // Assign internal shift register to the array
      assign data_o[i] = shift_reg_i[i-1]; // Connect the output
    end
  endgenerate
endmodule

module output_streaming_registers #(
  parameter int N = 4, // Computing NxN matrix multiplications
  parameter int C_DATA_WIDTH = 18
) (
  input                           clk, 
  input                           reset,
  input                           result_valid,   // From processing unit, informing if data is ready to be stored and streamed out
  input                           output_by_row,  // Along with first ready signal after output valid, indicates direction of output (only first one matters). 1 for row by row output, 0 for col by col output
  input                           output_ready,   // Informs that recipient is ready to receive data
  output logic                    output_valid,   // Output is valid the moment data is loaded into stream registers (data remains in registers) (also tells if buffer is empty or not)
  input        [C_DATA_WIDTH-1:0] c_data[N-1:0][N-1:0],   // The result NxN matrix
  output logic [C_DATA_WIDTH-1:0] output_data[N]  // Row of output streamed out
);
  // Define valid signal -- using counter
  logic [$clog2(N+1)-1:0] counter;  // Output shifts at most N times
  always_ff @(posedge clk) begin
    if (reset) begin
      counter <= 0;  // 0 indicate output streaming registers are empty
    end else if (result_valid && !output_valid) begin  // reset counter when result valid and output registers are empty
      counter <= N;
      // The first clock edge when valid and ready are read, counter == N at the edge
    end else if (output_valid && output_ready) begin  // count down when something is in counter and being read. 
      counter <= counter - 1; 
    end
  end
  assign output_valid = counter != 0;  // Output is valid when there's something (not all data is shifted out)

  // Row or column -- register for long-term storage, and a wire for "first time"
  logic output_by_row_register;
  logic output_by_row_wire;
  assign output_by_row_wire = counter == N ? output_by_row : output_by_row_register;  // First time use input, onward use register
  always_ff @(posedge clk) begin
    if (reset) begin
      output_by_row_register <= 0;
    end else if (output_valid && output_ready && counter == N) begin  // First (counter==N) valid and ready, read in the instruction
      output_by_row_register <= output_by_row;
    end
  end

  // Define Registers -- Has a 2D load, and shift with MUX-decided directions (left or up)
  logic [C_DATA_WIDTH-1:0] output_registers [N][N]; // N by N registers
  generate
    genvar i, j;
    for (i = 0; i < N; i++) begin : output_buffer_i
      for (j = 0; j < N; j++) begin : output_buffer_j
        always_ff @(posedge clk) begin
          if (reset) begin
            output_registers[i][j] <= 0;
          end else if (result_valid && !output_valid) begin
            output_registers[i][j] <= c_data[i][j];
          end else if (output_valid && output_ready) begin
            output_registers[i][j] <= output_by_row_wire ? (i < N-1 ? output_registers[i+1][j] : 0) : (j < N-1 ? output_registers[i][j+1] : 0);
          end
        end
      end
    end
  endgenerate

  // Output is first row or col of the output registers:
  always_comb begin
    if (output_by_row_wire) begin
      for (int j = 0; j < N; j++) begin
        output_data[j] = output_registers[0][j];
      end
    end else begin
      for (int i = 0; i < N; i++) begin
        output_data[i] = output_registers[i][0];
      end
    end
  end
endmodule