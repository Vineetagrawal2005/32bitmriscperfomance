// =============================================================================
//  Program_Counter.v  —  Optimized Program Counter
//
//  OPTIMIZATIONS vs original:
//  1. Removed redundant `else pc_out <= pc_out` — in Verilog, a register
//     holds its value when not assigned.  The extra branch synthesizes to
//     a mux with identical inputs on both sides, wasting logic.
//  2. Reset to word-0 (32'd0) retained.
// =============================================================================

module Program_Counter(
    input  wire        clock,
    input  wire        rst,
    input  wire        pc_en,
    input  wire [31:0] pc_in,
    output reg  [31:0] pc_out
);

    always @(posedge clock or posedge rst) begin
        if (rst)
            pc_out <= 32'd0;
        else if (pc_en)
            pc_out <= pc_in;
        // else: hold — no explicit assignment needed
    end

endmodule
