`include "sum_stationary.sv"
`default_nettype none

module tb_sum_stationary;
    // Parameters
    localparam int DATA_WIDTH = 8;
    localparam int N = 4;
    localparam int C_DATA_WIDTH = (2 * DATA_WIDTH) + $clog2(N);

    // Testbench signals
    logic clk_i;
    logic reset_i;
    logic valid_i;
    logic valid_o;
    logic [DATA_WIDTH-1:0] a_i [N];
    logic [DATA_WIDTH-1:0] b_i [N];
    logic [C_DATA_WIDTH-1:0] c_o [N*N];

    // Instantiate the sum_stationary module
    sum_stationary #(
        .DATA_WIDTH(DATA_WIDTH),
        .N(N),
        .C_DATA_WIDTH(C_DATA_WIDTH)
    ) uut (
        .clk_i(clk_i),
        .reset_i(reset_i),
        .valid_i(valid_i),
        .valid_o(valid_o),
        .a_i(a_i),
        .b_i(b_i),
        .c_o(c_o)
    );

    // Clock period parameter
    localparam CLK_PERIOD = 10;

    // Clock generation
    always #(CLK_PERIOD / 2) clk_i = ~clk_i;

    // Simulation control
    initial begin
        // Dump waveform data
        $dumpfile("tb_sum_stationary.vcd");
        $dumpvars(0, tb_sum_stationary);

        // Initialize signals
        reset_i = 1'b0;
        valid_i = 1'b0;
        for (int j = 0; j < N; j++) begin
            a_i[j] = {DATA_WIDTH{1'b0}};
            b_i[j] = {DATA_WIDTH{1'b0}};
        end

        // Apply reset
        #(CLK_PERIOD * 2) reset_i = 1'b1;
        #(CLK_PERIOD * 2) reset_i = 1'b0;

        // Apply test vectors
        @(posedge clk_i);  // Wait for the rising edge of the clock
        valid_i = 1'b1;

        // First set of inputs
        a_i[0] = 8'h01; b_i[0] = 8'h11;
        a_i[1] = 8'h02; b_i[1] = 8'h12;
        a_i[2] = 8'h03; b_i[2] = 8'h13;
        a_i[3] = 8'h04; b_i[3] = 8'h14;

        @(posedge clk_i);  // Wait for the next rising edge of the clock
        a_i[0] = 8'h05; b_i[0] = 8'h15;
        a_i[1] = 8'h06; b_i[1] = 8'h16;
        a_i[2] = 8'h07; b_i[2] = 8'h17;
        a_i[3] = 8'h08; b_i[3] = 8'h18;

        @(posedge clk_i);  // Wait for the next rising edge of the clock
        a_i[0] = 8'h09; b_i[0] = 8'h19;
        a_i[1] = 8'h0A; b_i[1] = 8'h1A;
        a_i[2] = 8'h0B; b_i[2] = 8'h1B;
        a_i[3] = 8'h0C; b_i[3] = 8'h1C;

        @(posedge clk_i);  // Wait for the next rising edge of the clock
        a_i[0] = 8'h0D; b_i[0] = 8'h1D;
        a_i[1] = 8'h0E; b_i[1] = 8'h1E;
        a_i[2] = 8'h0F; b_i[2] = 8'h1F;
        a_i[3] = 8'h10; b_i[3] = 8'h20;

        @(posedge clk_i);  // Wait for the next rising edge of the clock
        valid_i = 1'b0;

        // Wait for the output to be valid
        wait (valid_o == 1'b1);
        @(posedge clk_i);

        // Finish simulation
        $finish;
    end
endmodule

`default_nettype wire
