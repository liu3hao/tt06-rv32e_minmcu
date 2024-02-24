
module registers (
    output wire [31:0] r0, r1, r2, r3, r4,

    input wire [4:0] write_register,
    input wire [31:0] write_value,

    input wire clk,
    input wire rst_n
);

    reg [31:0] _r1, _r2, _r3, _r4;

    always @ (posedge clk) begin
        if (rst_n == 0) begin
            // Reset all registers first
            _r1 <= 0;
            _r2 <= 0;
            _r3 <= 0;
            _r4 <= 0;
        end else begin
            case (write_register)
                5'd1:   _r1 <= write_value;
                5'd2:   _r2 <= write_value;
                5'd3:   _r3 <= write_value;
                5'd4:   _r4 <= write_value;
                default: ;
            endcase
        end
    end

    assign r0 = 32'b0;
    assign r1 = _r1;
    assign r2 = _r2;
    assign r3 = _r3;
    assign r4 = _r4;

endmodule

module register_select (
    input wire [31:0] r0, r1, r2, r3, r4,

    input wire [4:0] r_sel,
    output wire [31:0] r_value
);

    assign r_value = (r_sel == 5'd0) ? r0
                        : (r_sel == 5'd1) ? r1
                        : (r_sel == 5'd2) ? r2
                        : (r_sel == 5'd3) ? r3
                        : (r_sel == 5'd4) ? r4
                        : 32'b0;

endmodule
