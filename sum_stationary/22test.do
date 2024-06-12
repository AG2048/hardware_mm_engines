# set the working dir, where all compiled verilog goes
vlib work

# compile all system verilog modules in mux.sv to working dir
# could also have multiple verilog files
vlog sum_stationary.sv
vsim -gN=2 work.sum_stationary

#log all signals and add some signals to waveform window
log {/*}
log {c_o}
log {north_inputs}
log {west_inputs}
# add wave {/*} would add all items in top level simulation module
add wave {/*}
add wave {c_o}
add wave {north_inputs}
add wave {west_inputs}

# Create a clock signal
force -repeat 10ns clk 0 0ns, 1 5ns

# Initialize signals
force reset_i 1'b0
force valid_i 1'b0
force a_i(0) 8'h00
force a_i(1) 8'h00
force b_i(0) 8'h00
force b_i(1) 8'h00

# Run the simulation to apply reset
run 20ns
force reset_i 1'b1
run 20ns
force reset_i 1'b0

# Apply test vectors
run 10ns
force valid_i 1'b1
force a_i(0) 8'h01
force b_i(0) 8'h11
force a_i(1) 8'h02
force b_i(1) 8'h12

# Incorrect input
run 10ns
force valid_i 1'b0
force a_i(0) 8'h21
force b_i(0) 8'h31
force a_i(1) 8'h00
force b_i(1) 8'h11

# Incorrect input
run 10ns
force valid_i 1'b0
force a_i(0) 8'h77
force b_i(0) 8'h77
force a_i(1) 8'h77
force b_i(1) 8'h77

run 10ns
force valid_i 1'b1
force a_i(0) 8'h05
force b_i(0) 8'h15
force a_i(1) 8'h06
force b_i(1) 8'h16
run 10ns
force valid_i 1'b0
# Incorrect input
force a_i(0) 8'h77
force b_i(0) 8'h77
force a_i(1) 8'h77
force b_i(1) 8'h77
# Incorrect input
run 10ns
force valid_i 1'b0
force a_i(0) 8'h77
force b_i(0) 8'h77
force a_i(1) 8'h77
force b_i(1) 8'h77

# Wait for the output to be valid
run 200ns
