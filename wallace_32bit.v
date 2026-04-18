module wallace_32bit(
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,        // control from FSM
    input  wire        signed_mode,   // 1 = signed multiply
    input  wire [31:0] A,
    input  wire [31:0] B,

    output reg  [63:0] product
);

    wire [63:0] mult_result;

    // Signed / Unsigned selection
    wire signed [31:0] A_s = A;
    wire signed [31:0] B_s = B;

    assign mult_result = signed_mode ? (A_s * B_s) : (A * B);

    // Register output (important for timing)
    always @(posedge clk or posedge rst) begin
        if (rst)
            product <= 64'd0;
        else if (enable)
            product <= mult_result;
    end

endmodule