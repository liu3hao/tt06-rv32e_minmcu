
module registers (
    output wire [31:0] r0, r1, r2, r3, r4, r5, r6, r7, r8,
                       r9, r10, r11, r12, r13, r14, r15,

    input wire [4:0] write_register,
    input wire [31:0] write_value,

    input wire clk,
    input wire rst_n
);
    reg [31:0] _r1, _r2, _r3, _r4, _r5, _r6, _r7, _r8,
               _r9, _r10, _r11, _r12, _r13, _r14, _r15;

    always @ (posedge clk) begin
        if (rst_n == 0) begin
            // Reset all registers first
            _r1 <= 0;
            _r2 <= 0;
            _r3 <= 0;
            _r4 <= 0;
            _r5 <= 0;
            _r6 <= 0;
            _r7 <= 0;
            _r8 <= 0;
            _r9 <= 0;
            _r10 <= 0;
            _r11 <= 0;
            _r12 <= 0;
            _r13 <= 0;
            _r14 <= 0;
            _r15 <= 0;
        end else begin
            case (write_register)
                5'd1:   _r1 <= write_value;
                5'd2:   _r2 <= write_value;
                5'd3:   _r3 <= write_value;
                5'd4:   _r4 <= write_value;
                5'd5:   _r5 <= write_value;
                5'd6:   _r6 <= write_value;
                5'd7:   _r7 <= write_value;
                5'd8:   _r8 <= write_value;
                5'd9:   _r9 <= write_value;
                5'd10:  _r10 <= write_value;
                5'd11:  _r11 <= write_value;
                5'd12:  _r12 <= write_value;
                5'd13:  _r13 <= write_value;
                5'd14:  _r14 <= write_value;
                5'd15:  _r15 <= write_value;
                default: ;
            endcase
        end
    end

    assign r0 = 32'b0;
    assign r1 = _r1;
    assign r2 = _r2;
    assign r3 = _r3;
    assign r4 = _r4;
    assign r5 = _r5;
    assign r6 = _r6;
    assign r7 = _r7;
    assign r8 = _r8;
    assign r9 = _r9;
    assign r10 = _r10;
    assign r11 = _r11;
    assign r12 = _r12;
    assign r13 = _r13;
    assign r14 = _r14;
    assign r15 = _r15;

endmodule

module register_select (
    input wire [31:0] r0, r1, r2, r3, r4, r5, r6, r7, r8,
                       r9, r10, r11, r12, r13, r14, r15,

    input wire [4:0] r_sel,
    output wire [31:0] r_value
);

    assign r_value = (r_sel == 5'd0) ? r0
                        : (r_sel == 5'd1) ? r1
                        : (r_sel == 5'd2) ? r2
                        : (r_sel == 5'd3) ? r3
                        : (r_sel == 5'd4) ? r4
                        : (r_sel == 5'd5) ? r5
                        : (r_sel == 5'd6) ? r6
                        : (r_sel == 5'd7) ? r7
                        : (r_sel == 5'd8) ? r8
                        : (r_sel == 5'd9) ? r9
                        : (r_sel == 5'd10) ? r10
                        : (r_sel == 5'd11) ? r11
                        : (r_sel == 5'd12) ? r12
                        : (r_sel == 5'd13) ? r13
                        : (r_sel == 5'd14) ? r14
                        : (r_sel == 5'd15) ? r15
                        : 32'b0;

endmodule
