
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
