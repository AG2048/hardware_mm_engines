# set the working dir, where all compiled verilog goes
vlib work

# compile all system verilog modules in mux.sv to working dir
# could also have multiple verilog files
vlog sum_stationary.sv

#load simulation using mux as the top level simulation module
vsim sum_stationary +N=4

#log all signals and add some signals to waveform window
log {/*}
log {c_data_streaming}
# add wave {/*} would add all items in top level simulation module
add wave {/*}
add wave {c_data_streaming}

# Create a clock signal
force -repeat 10ns clk 0 0ns, 1 5ns

# Initialize signals
force reset 1'b0
force a_input_valid 1'b0
force b_input_valid 1'b0
force a_data(0) 8'h00
force a_data(1) 8'h00
force a_data(2) 8'h00
force a_data(3) 8'h00
force b_data(0) 8'h00
force b_data(1) 8'h00
force b_data(2) 8'h00
force b_data(3) 8'h00

force output_ready 1'b0
force output_by_row 1'b0
force len_input 'h5

# Run the simulation to apply reset
run 20ns
force reset 1'b1
run 20ns
force reset 1'b0

# Apply test vectors
run 10ns
force a_input_valid 1'b1
force b_input_valid 1'b1
force a_data(0) 8'h01
force b_data(0) 8'h11
force a_data(1) 8'h02
force b_data(1) 8'h12
force a_data(2) 8'h03
force b_data(2) 8'h13
force a_data(3) 8'h04
force b_data(3) 8'h14
run 10ns
force a_input_valid 1'b0
force b_input_valid 1'b1
force a_data(0) 8'h88
force a_data(1) 8'h88
force a_data(2) 8'h88
force a_data(3) 8'h88
force b_data(0) 8'h15
force b_data(1) 8'h16
force b_data(2) 8'h17
force b_data(3) 8'h18


run 10ns
force a_input_valid 1'b0
force b_input_valid 1'b1
force a_data(0) 8'h88
force a_data(1) 8'h88
force a_data(2) 8'h88
force a_data(3) 8'h88
force b_data(0) 8'h15
force b_data(1) 8'h16
force b_data(2) 8'h17
force b_data(3) 8'h18

run 10ns
force a_input_valid 1'b1
force b_input_valid 1'b1
force a_data(0) 8'h05
force b_data(0) 8'h15
force a_data(1) 8'h06
force b_data(1) 8'h16
force a_data(2) 8'h07
force b_data(2) 8'h17
force a_data(3) 8'h08
force b_data(3) 8'h18
run 10ns
force a_input_valid 1'b1
force b_input_valid 1'b1
force a_data(0) 8'h88
force a_data(1) 8'h88
force a_data(2) 8'h88
force a_data(3) 8'h88
force b_data(0) 8'h88
force b_data(1) 8'h88
force b_data(2) 8'h88
force b_data(3) 8'h88

run 10ns
force a_input_valid 1'b0
force b_input_valid 1'b0
force a_data(0) 8'h88
force a_data(1) 8'h88
force a_data(2) 8'h88
force a_data(3) 8'h88
force b_data(0) 8'h88
force b_data(1) 8'h88
force b_data(2) 8'h88
force b_data(3) 8'h88

run 10ns
force a_input_valid 1'b1
force b_input_valid 1'b1
force a_data(0) 8'h09
force b_data(0) 8'h19
force a_data(1) 8'h0A
force b_data(1) 8'h1A
force a_data(2) 8'h0B
force b_data(2) 8'h1B
force a_data(3) 8'h0C
force b_data(3) 8'h1C

run 10ns
force a_data(0) 8'h0D
force b_data(0) 8'h1D
force a_data(1) 8'h0E
force b_data(1) 8'h1E
force a_data(2) 8'h0F
force b_data(2) 8'h1F
force a_data(3) 8'h10
force b_data(3) 8'h20

run 10ns
force a_input_valid 1'b0
force b_input_valid 1'b0
force a_data(0) 8'h88
force a_data(1) 8'h88
force a_data(2) 8'h88
force a_data(3) 8'h88
force b_data(0) 8'h88
force b_data(1) 8'h88
force b_data(2) 8'h88
force b_data(3) 8'h88

run 10ns
force a_input_valid 1'b0
force b_input_valid 1'b0
force a_data(0) 8'h88
force a_data(1) 8'h88
force a_data(2) 8'h88
force a_data(3) 8'h88
force b_data(0) 8'h88
force b_data(1) 8'h88
force b_data(2) 8'h88
force b_data(3) 8'h88

run 10ns
force a_input_valid 1'b1
force b_input_valid 1'b1
force a_data(0) 8'h01
force b_data(0) 8'h11
force a_data(1) 8'h02
force b_data(1) 8'h12
force a_data(2) 8'h03
force b_data(2) 8'h13
force a_data(3) 8'h04
force b_data(3) 8'h14

run 10ns
force a_input_valid 1'b0
force b_input_valid 1'b0

# Wait for the output to be valid
run 70ns

run 10ns

force a_input_valid 1'b1
force b_input_valid 1'b1

force a_data(0) 8'd64
force a_data(1) 8'd65
force a_data(2) 8'd66
force a_data(3) 8'd67

force b_data(0) 8'd100
force b_data(1) 8'd101
force b_data(2) 8'd102
force b_data(3) 8'd103


run 10ns

force a_input_valid 1'b1
force b_input_valid 1'b1

force a_data(0) 8'd68
force a_data(1) 8'd69
force a_data(2) 8'd70
force a_data(3) 8'd71

force b_data(0) 8'd104
force b_data(1) 8'd105
force b_data(2) 8'd106
force b_data(3) 8'd107

force output_ready 1'b1
force output_by_row 1'b1

run 10ns

force a_input_valid 1'b1
force b_input_valid 1'b1

force a_data(0) 8'd72
force a_data(1) 8'd73
force a_data(2) 8'd74
force a_data(3) 8'd75

force b_data(0) 8'd108
force b_data(1) 8'd109
force b_data(2) 8'd110
force b_data(3) 8'd111

run 10ns
force output_ready 1'b0
force output_by_row 1'b0

force a_input_valid 1'b0
force b_input_valid 1'b0
force a_data(0) 8'h88
force a_data(1) 8'h88
force a_data(2) 8'h88
force a_data(3) 8'h88
force b_data(0) 8'h88
force b_data(1) 8'h88
force b_data(2) 8'h88
force b_data(3) 8'h88
run 10ns
force a_input_valid 1'b0
force b_input_valid 1'b0
force a_data(0) 8'h88
force a_data(1) 8'h88
force a_data(2) 8'h88
force a_data(3) 8'h88
force b_data(0) 8'h88
force b_data(1) 8'h88
force b_data(2) 8'h88
force b_data(3) 8'h88
run 10ns

force a_input_valid 1'b1
force b_input_valid 1'b1
force output_ready 1'b1

force a_data(0) 8'd76
force a_data(1) 8'd77
force a_data(2) 8'd78
force a_data(3) 8'd79

force b_data(0) 8'd112
force b_data(1) 8'd113
force b_data(2) 8'd114
force b_data(3) 8'd115


run 10ns

force a_input_valid 1'b1
force b_input_valid 1'b1

force a_data(0) 8'd80
force a_data(1) 8'd81
force a_data(2) 8'd82
force a_data(3) 8'd83

force b_data(0) 8'd116
force b_data(1) 8'd117
force b_data(2) 8'd118
force b_data(3) 8'd119

force output_ready 1'b0
force output_by_row 1'b0

run 10ns
force a_input_valid 1'b0
force b_input_valid 1'b0

run 20ns
force output_ready 1'b0
force output_by_row 1'b0

force a_input_valid 1'b0
force b_input_valid 1'b0
force a_data(0) 8'h88
force a_data(1) 8'h88
force a_data(2) 8'h88
force a_data(3) 8'h88
force b_data(0) 8'h88
force b_data(1) 8'h88
force b_data(2) 8'h88
force b_data(3) 8'h88

run 20ns
force output_ready 1'b0
force output_by_row 1'b0

run 50ns
force output_ready 1'b1
force output_by_row 1'b0

run 100ns