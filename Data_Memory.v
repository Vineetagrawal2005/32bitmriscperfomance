// =============================================================================
//  Data_Memory.v  —  Optimized Data Memory (Harvard — Separate from IMEM)
//
//  OPTIMIZATIONS vs original:
//  1. Read changed from always @(*) to a pure assign statement.
//     - always @(*) with a reg output introduces delta-cycle scheduling
//       overhead in simulation and can infer a latch if the sensitivity
//       list is incomplete in some tools.
//     - assign maps to a direct wire connection from the RAM output port,
//       which is the synthesizer's natural read-port representation.
//  2. Address indexing retained as adr[7:2] (256 word-addressed entries,
//     matching the 256-entry RAM declaration).  Extended to adr[9:2]
//     only if RAM is enlarged to 1024 entries.
//  3. Reset loop and synchronous write path are unchanged.
// =============================================================================

module Data_Memory(
    input  wire        clock,
    input  wire        rst,
    input  wire        sig_MemWrite,
    input  wire [31:0] adr,
    input  wire [31:0] wd,
    output wire [31:0] rd          // changed from reg to wire (assign read)
);

    reg [31:0] ram [0:255];
    integer i;

    // -------------------------------------------------------------------------
    //  Synchronous write with asynchronous reset
    // -------------------------------------------------------------------------
    always @(posedge clock or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 256; i = i + 1)
                ram[i] <= 32'd0;
        end
        else if (sig_MemWrite) begin
            ram[adr[7:2]] <= wd;
        end
    end

    // -------------------------------------------------------------------------
    //  Asynchronous (combinational) read — avoids the extra clock cycle
    //  that a registered read would require, keeping LW at 4 cycles total.
    // -------------------------------------------------------------------------
    assign rd = ram[adr[7:2]];

endmodule
