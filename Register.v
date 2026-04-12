// =============================================================================
//  Register.v  —  General-Purpose 32-bit Enabled Register
//
//  OPTIMIZATIONS vs original:
//  1. No functional change — the original was already correct.
//  2. Coding style cleaned: port directions use wire/reg properly.
//  3. Reset clears to 0, enable gates the update — synthesizes to
//     a standard FDRE (flip-flop with clock enable and sync/async reset)
//     on Xilinx FPGAs for maximum density and speed.
// =============================================================================

module Register(
    input  wire        clock,
    input  wire        rst,
    input  wire        enable,
    input  wire [31:0] in,
    output reg  [31:0] out
);

    always @(posedge clock or posedge rst) begin
        if (rst)
            out <= 32'd0;
        else if (enable)
            out <= in;
    end

endmodule
