module Register_File(
    input  wire        clock,
    input  wire        rst,
    input  wire [4:0]  a1,
    input  wire [4:0]  a2,
    input  wire [4:0]  a3,
    input  wire [31:0] wd3,
    input  wire        RegWrite,
    output wire [31:0] rd1,
    output wire [31:0] rd2
);

    reg [31:0] reg_File [0:31];
    integer i;

    // WRITE
    always @(posedge clock or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                reg_File[i] <= 32'd0;
        end
        else if (RegWrite && (a3 != 5'd0)) begin
            reg_File[a3] <= wd3;
        end
    end

    // READ (NO FORWARDING)
    assign rd1 = (a1 == 5'd0) ? 32'd0 : reg_File[a1];
    assign rd2 = (a2 == 5'd0) ? 32'd0 : reg_File[a2];

endmodule