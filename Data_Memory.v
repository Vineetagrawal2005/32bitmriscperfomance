module Data_Memory(
    input  wire        clock,
    input  wire        rst,
    input  wire        MemWrite,
    input  wire        MemRead,      // ✅ ADDED
    input  wire [31:0] adr,
    input  wire [31:0] wd,
    output wire [31:0] rd
);

    reg [31:0] ram [0:255];
    integer i;

    // -----------------------------
    // WRITE (synchronous)
    // -----------------------------
    always @(posedge clock or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 256; i = i + 1)
                ram[i] <= 32'd0;
        end
        else if (MemWrite) begin
            ram[adr[9:2]] <= wd;   // ✅ FIXED (match IMEM)
        end
    end

    // -----------------------------
    // READ (controlled)
    // -----------------------------
    // ✅ CORRECT (COMBINATIONAL READ)
    assign rd = ram[adr[9:2]];

endmodule