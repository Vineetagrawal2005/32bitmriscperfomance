
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
