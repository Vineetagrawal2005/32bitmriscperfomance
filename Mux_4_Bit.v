module Mux_4_Bit(
    input  wire [31:0] input_0,
    input  wire [31:0] input_1,
    input  wire [31:0] input_2,
    input  wire [31:0] input_3,
    input  wire [1:0]  selector,
    output reg  [31:0] mux_Out
);

always @(*) begin
    case(selector)
        2'b00: mux_Out = input_0;
        2'b01: mux_Out = input_1;
        2'b10: mux_Out = input_2;
        2'b11: mux_Out = input_3;
        default: mux_Out = 32'd0;
    endcase
end

endmodule