## Processor
- make each processor send data to next via a small buffer in front - so input buffer doesn't have to wait for EVERYONE

- the module uses processor's valid signal, but have to define separtae a_ready and b_ready signals.
- It loads in data when it's empty, and loads new when data is ejected to BOTH next processor, AND its own processor.
- it also uses ready/valid with its own processor. 


- Another option is for input buffer to send value to individual processors one by one

- Don't overcomplicate things. - data routing itself is "supposed" to be long...

- for now, add a "destination field" into my data sending. 
- Ready (have to be "OR'd" together - ) (each receiver will have their own ready signal), Valid (can broadcast), DestID (so processor know if this ). 
- Same valid and DestID bus, each send their own READY signal
- Processor: Ready+Valid+ID is myself = load data.
- Sender: If Ready on that ID + VALID, send data. 
- NOC should just "work", we can use RAD-sim to detect deadlock issues. (which is a later debug issue)

## Controller
Fix memory unit parameter values.

Have to handle how multiple sub-units may need to read from the memory at the same time / close to the same time?

## Memory sample:
could have multiple ports for reading/writing for this case?


## Overall
I think we have to specify that input size has to be at least as wide as N*COLS_processor? or something similar. 

Or something in the code that "freezes" certain tiles, or reuse certain tiles if the input matrix is small?
- This reuse tile things just uses the "extra cols" or "extra rows" to input some value that will be added later, so things go faster. 



Controller: - split controller and top_level (now they are basically a same thing)

## Memory: 
- test with memory manager in testbench.

## Summary TODO: 
- Input buffer - use "ID" for data sending approach. 
- Memory: make testbench do the round robin data distribution
- Controller - split it from TOP level

## NoC communication:
- memory buffer - to memory -> processor
- output memory - to memory -> processor
- processor - by itself -> NoC <- buffers
- Controller - be its own block (may have signals that's not on NoC, since it's mostly 1bit wide)
NoC is good for LARGE data sets. not for 1 bit


## New parameters to deal with:
### Processor:
```
parameter int PROCESSOR_ROWS_BITS = 4, // Giving each processor an ID, this is used to respond to input valid
parameter int PROCESSOR_COLS_BITS = 4, // Giving each processor an ID, this is used to respond to input valid
parameter int ROW_ID = 0,
parameter int COL_ID = 0,
```
```
input   logic [PROCESSOR_COLS_BITS]                             input_col_id,   // Col destination of the A input
input   logic [PROCESSOR_ROWS_BITS]                             input_row_id,   // Row destination of the B input
```
where we replaced all a_input_valid with a_input_valid && col_id == COL_ID
### Input Buffer
```
parameter int NUM_PROCESSORS_TO_BROADCAST = 4, // Assuming 4 processors in the same row / col. (with ID: 0, 1, 2, 3...)
parameter int PROCESSORS_ID_COUNTER_BITS = 4, // Number of bits to record what ID to broadcast to
```
```
input   logic                                   processor_input_ready[NUM_PROCESSORS_TO_BROADCAST], // ready for processor input, each processor has unique ready signal
output  logic [PROCESSORS_ID_COUNTER_BITS-1:0]  processor_input_id, // ID to write to
```

### Controller
```
parameter int INPUT_BUFFER_INSTRUCTION_COUNTER_BITS = $clog2(MAX_MATRIX_LENGTH*MAX_MATRIX_LENGTH/ROWS_PROCESSORS/COLS_PROCESSORS/N/N + 1), // TODO: bits required to count number of instructions already sent to each input buffer (max_matrix_len^2 / (row_processors*col processors*N^2))
```