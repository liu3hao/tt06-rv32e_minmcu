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
    // localparam FUNC_AND =     3'b111;

    wire signed [size-1:0] signed_value1;
    wire signed [size-1:0] signed_value2;

    assign signed_value1 = value1;
    assign signed_value2 = value2;

    reg [size-1:0] _result;

    // For shifts, value2 uses least significant 5 bits for a max of 32 values
    always_comb begin
        case (func_type)
            FUNC_ADD_SUB: _result = f7_bit ? (value1-value2) : (value1 + value2);
            FUNC_SLL:     _result = (value1 << value2[4:0]);
            FUNC_SLT:     _result = (signed_value1 < signed_value2 ? 1 : 0);
            FUNC_SLTU:    _result = (value1 < value2 ? 1 : 0);
            FUNC_XOR:     _result = (value1 ^ value2);
            FUNC_SRL_SRA: _result = (f7_bit) ? (value1 >> value2[4:0]) | (
                                (value1[size-1] == 0) ? 32'b0 :
                                    ~(32'hffffffff >> value2[4:0])
                            ) : (value1 >> (value2[4:0]));
            FUNC_OR:      _result = value1 | value2;
            default:      _result = value1 & value2; // FUNC_AND condition
        endcase
    end

    assign result = _result;

endmodule
