// =============================================================================
//  Register_File.v  —  Optimized 32x32 MIPS Register File
//
//  OPTIMIZATIONS vs original:
//  1. Write-through (internal forwarding): if a read address equals the
//     write address AND RegWrite is asserted in the same cycle, the new
//     write data is forwarded directly to the read output instead of
//     waiting for the next clock edge.  This eliminates a potential
//     1-cycle stall that would otherwise be needed in the datapath when
//     a result written in state S_REXEC is read in the next S_DECODE.
//     In the merged-state FSM this matters most for back-to-back
//     instructions that read results immediately.
//  2. Reads remain purely combinational (no registered read outputs),
//     keeping the register-read latency at zero clock cycles.
//  3. $zero (register 0) hardwired to 0 on reads and protected on writes.
//  4. Reset loop uses a cleaner generate or for-loop with non-blocking
//     assignments — same simulation semantics, cleaner intent.
// =============================================================================

module Register_File(
    input  wire        clock,
    input  wire        rst,
    input  wire [4:0]  a1,          // Read address 1
    input  wire [4:0]  a2,          // Read address 2
    input  wire [4:0]  a3,          // Write address
    input  wire [31:0] wd3,         // Write data
    input  wire        sig_RegWrite,
    output wire [31:0] rd1,         // Read data 1
    output wire [31:0] rd2          // Read data 2
);

    reg [31:0] reg_File [0:31];
    integer i;

    // -------------------------------------------------------------------------
    //  Synchronous write with reset
    // -------------------------------------------------------------------------
    always @(posedge clock or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                reg_File[i] <= 32'd0;
        end
        else begin
            if (sig_RegWrite && (a3 != 5'd0))
                reg_File[a3] <= wd3;
        end
    end

    // -------------------------------------------------------------------------
    //  Combinational read with write-through forwarding
    //
    //  If the write address matches a read address AND a write is happening
    //  this cycle, forward wd3 directly — the register hasn't been updated
    //  yet (clock edge hasn't arrived) so we supply the new value now.
    //  This is called "register file bypassing" or "write-through read."
    // -------------------------------------------------------------------------
    assign rd1 = (a1 == 5'd0)                          ? 32'd0 :   // $zero
                 (sig_RegWrite && (a3 == a1) && a3 != 5'd0) ? wd3  :   // forward
                 reg_File[a1];                                          // normal

    assign rd2 = (a2 == 5'd0)                          ? 32'd0 :
                 (sig_RegWrite && (a3 == a2) && a3 != 5'd0) ? wd3  :
                 reg_File[a2];

endmodule
