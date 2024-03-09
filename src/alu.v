module alu #(
    parameter size=32
    ) (
    input wire [size-1:0] value1,
    input wire [size-1:0] value2,

    input wire [2:0] func_type,
    input wire f7_bit,

    output wire [size-1:0] result
);

    localparam FUNC_ADD_SUB = 3'b000;
    localparam FUNC_SLL =     3'b001;
    localparam FUNC_SLT =     3'b010;
    localparam FUNC_SLTU =    3'b011;
    localparam FUNC_XOR =     3'b100;
    localparam FUNC_SRL_SRA = 3'b101;
    localparam FUNC_OR =      3'b110;
    localparam FUNC_AND =     3'b111;

    wire signed [size-1:0] signed_value1;
    wire signed [size-1:0] signed_value2;

    assign signed_value1 = value1;
    assign signed_value2 = value2;

    // For shifts, value2 uses least significant 5 bits for a max of 32 values
    assign result = (func_type == FUNC_ADD_SUB) ?
                        ((f7_bit == 0) ? (value1 + value2): (value1 - value2))
                    : (func_type == FUNC_SLL) ?  (value1 << (value2[4:0]))
                    : (func_type == FUNC_SLT) ?  (signed_value1 < signed_value2 ? 1 : 0)
                    : (func_type == FUNC_SLTU) ? (value1 < value2 ? 1 : 0)
                    : (func_type == FUNC_XOR) ?  (value1 ^ value2)
                    : (func_type == FUNC_SRL_SRA && f7_bit == 0) ? (value1 >> (value2[4:0]))
                    : (func_type == FUNC_SRL_SRA && f7_bit == 1) ?
                        (value1 >> value2[4:0]) | (
                            (value1[size-1] == 0) ? 32'b0 :
                                ~(32'hffffffff >> value2[4:0])
                        )
                    : (func_type == FUNC_OR) ? (value1 | value2)
                    : (value1 & value2); // (func_type == FUNC_AND)

endmodule
