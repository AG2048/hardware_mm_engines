# set the working dir, where all compiled verilog goes
vlib work

# compile all system verilog modules in mux.sv to working dir
# could also have multiple verilog files
vlog sum_stationary.sv
vsim -gN=8 work.sum_stationary

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
force a_i(2) 8'h0
force a_i(3) 8'h0
force a_i(4) 8'h0
force a_i(5) 8'h0
force a_i(6) 8'h0
force a_i(7) 8'h0

force b_i(0) 8'h0
force b_i(1) 8'h0
force b_i(2) 8'h0
force b_i(3) 8'h0
force b_i(4) 8'h00
force b_i(5) 8'h00
force b_i(6) 8'h00
force b_i(7) 8'h00

# Run the simulation to apply reset
run 20ns
force reset_i 1'b1
run 20ns
force reset_i 1'b0


# Initialize 8x8 matrix inputs
# Matrix A values: 0, 1, 2, ..., 63
# Matrix B values: 64, 65, 66, ..., 127
# For the purpose of this example, initializing only first few values, extend similarly

run 10ns

force valid_i 1'b1

force a_i(0) 8'd0
force a_i(1) 8'd1
force a_i(2) 8'd2
force a_i(3) 8'd3
force a_i(4) 8'd4
force a_i(5) 8'd5
force a_i(6) 8'd6
force a_i(7) 8'd7

force b_i(0) 8'd64
force b_i(1) 8'd65
force b_i(2) 8'd66
force b_i(3) 8'd67
force b_i(4) 8'd68
force b_i(5) 8'd69
force b_i(6) 8'd70
force b_i(7) 8'd71


run 10ns

force valid_i 1'b1

force a_i(0) 8'd8
force a_i(1) 8'd9
force a_i(2) 8'd10
force a_i(3) 8'd11
force a_i(4) 8'd12
force a_i(5) 8'd13
force a_i(6) 8'd14
force a_i(7) 8'd15

force b_i(0) 8'd72
force b_i(1) 8'd73
force b_i(2) 8'd74
force b_i(3) 8'd75
force b_i(4) 8'd76
force b_i(5) 8'd77
force b_i(6) 8'd78
force b_i(7) 8'd79

run 10ns

force valid_i 1'b0

force a_i(0) 8'd127
force a_i(1) 8'd127
force a_i(2) 8'd127
force a_i(3) 8'd127
force a_i(4) 8'd127
force a_i(5) 8'd127
force a_i(6) 8'd127
force a_i(7) 8'd127

force b_i(0) 8'd127
force b_i(1) 8'd127
force b_i(2) 8'd127
force b_i(3) 8'd127
force b_i(4) 8'd127
force b_i(5) 8'd127
force b_i(6) 8'd127
force b_i(7) 8'd127

run 10ns

force valid_i 1'b1

force a_i(0) 8'd16
force a_i(1) 8'd17
force a_i(2) 8'd18
force a_i(3) 8'd19
force a_i(4) 8'd20
force a_i(5) 8'd21
force a_i(6) 8'd22
force a_i(7) 8'd23

force b_i(0) 8'd80
force b_i(1) 8'd81
force b_i(2) 8'd82
force b_i(3) 8'd83
force b_i(4) 8'd84
force b_i(5) 8'd85
force b_i(6) 8'd86
force b_i(7) 8'd87

run 10ns

force valid_i 1'b0

force a_i(0) 8'd127
force a_i(1) 8'd127
force a_i(2) 8'd127
force a_i(3) 8'd127
force a_i(4) 8'd127
force a_i(5) 8'd127
force a_i(6) 8'd127
force a_i(7) 8'd127

force b_i(0) 8'd127
force b_i(1) 8'd127
force b_i(2) 8'd127
force b_i(3) 8'd127
force b_i(4) 8'd127
force b_i(5) 8'd127
force b_i(6) 8'd127
force b_i(7) 8'd127

run 10ns

force valid_i 1'b1

force a_i(0) 8'd24
force a_i(1) 8'd25
force a_i(2) 8'd26
force a_i(3) 8'd27
force a_i(4) 8'd28
force a_i(5) 8'd29
force a_i(6) 8'd30
force a_i(7) 8'd31

force b_i(0) 8'd88
force b_i(1) 8'd89
force b_i(2) 8'd90
force b_i(3) 8'd91
force b_i(4) 8'd92
force b_i(5) 8'd93
force b_i(6) 8'd94
force b_i(7) 8'd95

run 10ns

force valid_i 1'b0

force a_i(0) 8'd127
force a_i(1) 8'd127
force a_i(2) 8'd127
force a_i(3) 8'd127
force a_i(4) 8'd127
force a_i(5) 8'd127
force a_i(6) 8'd127
force a_i(7) 8'd127

force b_i(0) 8'd127
force b_i(1) 8'd127
force b_i(2) 8'd127
force b_i(3) 8'd127
force b_i(4) 8'd127
force b_i(5) 8'd127
force b_i(6) 8'd127
force b_i(7) 8'd127

run 10ns

force valid_i 1'b0

force a_i(0) 8'd127
force a_i(1) 8'd127
force a_i(2) 8'd127
force a_i(3) 8'd127
force a_i(4) 8'd127
force a_i(5) 8'd127
force a_i(6) 8'd127
force a_i(7) 8'd127

force b_i(0) 8'd127
force b_i(1) 8'd127
force b_i(2) 8'd127
force b_i(3) 8'd127
force b_i(4) 8'd127
force b_i(5) 8'd127
force b_i(6) 8'd127
force b_i(7) 8'd127

run 10ns

force valid_i 1'b1

force a_i(0) 8'd32
force a_i(1) 8'd33
force a_i(2) 8'd34
force a_i(3) 8'd35
force a_i(4) 8'd36
force a_i(5) 8'd37
force a_i(6) 8'd38
force a_i(7) 8'd39

force b_i(0) 8'd96
force b_i(1) 8'd97
force b_i(2) 8'd98
force b_i(3) 8'd99
force b_i(4) 8'd100
force b_i(5) 8'd101
force b_i(6) 8'd102
force b_i(7) 8'd103

run 10ns

force valid_i 1'b0

force a_i(0) 8'd127
force a_i(1) 8'd127
force a_i(2) 8'd127
force a_i(3) 8'd127
force a_i(4) 8'd127
force a_i(5) 8'd127
force a_i(6) 8'd127
force a_i(7) 8'd127

force b_i(0) 8'd127
force b_i(1) 8'd127
force b_i(2) 8'd127
force b_i(3) 8'd127
force b_i(4) 8'd127
force b_i(5) 8'd127
force b_i(6) 8'd127
force b_i(7) 8'd127
run 10ns

force valid_i 1'b1

force a_i(0) 8'd40
force a_i(1) 8'd41
force a_i(2) 8'd42
force a_i(3) 8'd43
force a_i(4) 8'd44
force a_i(5) 8'd45
force a_i(6) 8'd46
force a_i(7) 8'd47

force b_i(0) 8'd104
force b_i(1) 8'd105
force b_i(2) 8'd106
force b_i(3) 8'd107
force b_i(4) 8'd108
force b_i(5) 8'd109
force b_i(6) 8'd110
force b_i(7) 8'd111
run 10ns

force valid_i 1'b0

force a_i(0) 8'd127
force a_i(1) 8'd127
force a_i(2) 8'd127
force a_i(3) 8'd127
force a_i(4) 8'd127
force a_i(5) 8'd127
force a_i(6) 8'd127
force a_i(7) 8'd127

force b_i(0) 8'd127
force b_i(1) 8'd127
force b_i(2) 8'd127
force b_i(3) 8'd127
force b_i(4) 8'd127
force b_i(5) 8'd127
force b_i(6) 8'd127
force b_i(7) 8'd127

run 10ns

force valid_i 1'b1

force a_i(0) 8'd48
force a_i(1) 8'd49
force a_i(2) 8'd50
force a_i(3) 8'd51
force a_i(4) 8'd52
force a_i(5) 8'd53
force a_i(6) 8'd54
force a_i(7) 8'd55

force b_i(0) 8'd112
force b_i(1) 8'd113
force b_i(2) 8'd114
force b_i(3) 8'd115
force b_i(4) 8'd116
force b_i(5) 8'd117
force b_i(6) 8'd118
force b_i(7) 8'd119


run 10ns

force valid_i 1'b1

force a_i(0) 8'd56
force a_i(1) 8'd57
force a_i(2) 8'd58
force a_i(3) 8'd59
force a_i(4) 8'd60
force a_i(5) 8'd61
force a_i(6) 8'd62
force a_i(7) 8'd63

force b_i(0) 8'd120
force b_i(1) 8'd121
force b_i(2) 8'd122
force b_i(3) 8'd123
force b_i(4) 8'd124
force b_i(5) 8'd125
force b_i(6) 8'd126
force b_i(7) 8'd127



run 10ns
force valid_i 1'b0
# Wait for the output to be valid
run 300ns
