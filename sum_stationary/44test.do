# set the working dir, where all compiled verilog goes
vlib work

# compile all system verilog modules in mux.sv to working dir
# could also have multiple verilog files
vlog sum_stationary.sv
vsim -gN=4 work.sum_stationary

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
force a_i(2) 8'h00
force a_i(3) 8'h00
force b_i(0) 8'h00
force b_i(1) 8'h00
force b_i(2) 8'h00
force b_i(3) 8'h00

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
force a_i(2) 8'h03
force b_i(2) 8'h13
force a_i(3) 8'h04
force b_i(3) 8'h14

run 10ns
force a_i(0) 8'h05
force b_i(0) 8'h15
force a_i(1) 8'h06
force b_i(1) 8'h16
force a_i(2) 8'h07
force b_i(2) 8'h17
force a_i(3) 8'h08
force b_i(3) 8'h18

run 10ns
force a_i(0) 8'h09
force b_i(0) 8'h19
force a_i(1) 8'h0A
force b_i(1) 8'h1A
force a_i(2) 8'h0B
force b_i(2) 8'h1B
force a_i(3) 8'h0C
force b_i(3) 8'h1C

run 10ns
force a_i(0) 8'h0D
force b_i(0) 8'h1D
force a_i(1) 8'h0E
force b_i(1) 8'h1E
force a_i(2) 8'h0F
force b_i(2) 8'h1F
force a_i(3) 8'h10
force b_i(3) 8'h20

run 10ns
force valid_i 1'b0

# Wait for the output to be valid
run 200ns
