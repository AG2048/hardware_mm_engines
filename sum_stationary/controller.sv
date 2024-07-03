/* Module
 * Input:
 *    A address, A addr valid
 *    B address, B addr valid
 *    C address, C addr valid
 *    N, N valid
 * Output:
 *    A addr ready
 *    B addr ready
 *    C addr ready
 *    N ready
 *    result valid (computation completed and memory have received data)
 * Module interconnections:
 *    Parameters: 
 *      Num Row Processing Tiles
 *      Num Col Processing Tiles
 *      Processing Tiles Size
 *      Data Width (per input number)
 *    Memory Router (via NoC?):
 *      tell memory router to read data from memory of N length and broadcast to dedicated tiles

        OR

        pass all relevant memory address to each router and the router dynamically figures out what values to retrieve from memory
 *    Tiles
 *      Tiles can directly be connected to memory for output, so controller don't really directly control the tiles.
 *      
 */

/* Operation Procedure:
    User provide addr and N that are stored to the memory router of A, B, and maybe all the processing units?
      at this point N is also configured in the processing units (all of them) as input_length
    Memory router A - retrieve first row tile and start broadcasting - switch once all data is sent through N/n times
    Memory router B - retrieve first col tile and start broadcasting - switch once all data is sent through
      The routers just have to keep sending data, no need to stop at all. handled by the ready/valid signals
    Each processor's output should be to the same destination (just calculate by the processor's row-id and col-id + C addr)

    Is a router necessary here? since we are NoC connecting the values anyways, what if we just directly make each processing unit request col/row input? (I guess that would be redundent, but maybe it can be done for ONE of the row/col input?)
      as in, temp buffer the reused data, and just directly call the non-reused data from memory
 */

/* Modifications to processing unit:
    Now add a separate "setup" state to receive input_length. (with its own ready and valid pins)
    Only input ready once input_length is set

    Add a counter to how many sets of data are successfully inputted. This will help us know when we can start expecting new length
      Will also help with determining address to store result in memory

    If we do AXIMM for processing unit, must add addr, len, and associated values.
      Can also transmit corresponding tile ID?
 */

/* Memory router requirement
    ready/valid signal and remember memory address.
    (Mode of input should be a parameter, rows or cols, A or B)
    and a connection to all tiles.
    Have on-chip memory to store an entire row tile, OR a portion of it

    
