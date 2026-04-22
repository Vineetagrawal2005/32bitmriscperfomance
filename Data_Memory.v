module Data_Memory(
    input wire clock,
    input wire rst,
    input wire MemWrite,
    input wire MemRead,
    input wire [31:0] adr,
    input wire [31:0] wd,
    output wire [31:0] rd
);

    reg [31:0] ram [0:255];
    reg [31:0] rd_reg;

    integer i;
    initial begin
        for(i = 0; i < 256; i = i + 1)
            ram[i] = 0;
    end

    always @(posedge clock or posedge rst) begin
        if (rst)
            rd_reg <= 32'd0;
        else begin
            if (MemWrite)
                ram[adr[9:2]] <= wd;

            if (MemRead)
                rd_reg <= ram[adr[9:2]];
        end
    end

    assign rd = rd_reg;

endmodule