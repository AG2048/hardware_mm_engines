# set the working dir, where all compiled verilog goes
vlib work

# compile all system verilog modules in mux.sv to working dir
# could also have multiple verilog files
vlog sum_stationary.sv
vsim -gN=2 work.sum_stationary

#log all signals and add some signals to waveform window
log {/*}
log {c_o}
# add wave {/*} would add all items in top level simulation module
add wave {/*}
add wave {c_o}

# Create a clock signal
force -repeat 10ns clk_i 0 0ns, 1 5ns

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

run 10ns
force a_i(0) 8'h05
force b_i(0) 8'h15
force a_i(1) 8'h06
force b_i(1) 8'h16
run 10ns
force valid_i 1'b0

# Wait for the output to be valid
run 200ns
