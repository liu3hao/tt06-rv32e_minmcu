
module registers (
    input wire [4:0] write_register,
    input wire [31:0] write_value,

    input wire [4:0] r_sel1,
    output wire [31:0] r_value1,

    input wire [4:0] r_sel2,
    output wire [31:0] r_value2,

    input wire clk,
    input wire rst_n
);
    wire [31:0] r0;
    assign r0 = 0;

    reg [31:0] r1, r2, r3, r4,
            r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15;

    always @ (posedge clk) begin
        if (rst_n == 0) begin
            // Reset all registers first
            r1 <= 0;
            r2 <= 0;
            r3 <= 0;
            r4 <= 0;
            r5 <= 0;
            r6 <= 0;
            r7 <= 0;
            r8 <= 0;
            r9 <= 0;
            r10 <= 0;
            r11 <= 0;
            r12 <= 0;
            r13 <= 0;
            r14 <= 0;
            r15 <= 0;

        end else begin
            case (write_register)
                5'd1:   r1 <= write_value;
                5'd2:   r2 <= write_value;
                5'd3:   r3 <= write_value;
                5'd4:   r4 <= write_value;
                5'd5:   r5 <= write_value;
                5'd6:   r6 <= write_value;
                5'd7:   r7 <= write_value;
                5'd8:   r8 <= write_value;
                5'd9:   r9 <= write_value;
                5'd10:  r10 <= write_value;
                5'd11:  r11 <= write_value;
                5'd12:  r12 <= write_value;
                5'd13:  r13 <= write_value;
                5'd14:  r14 <= write_value;
                5'd15:  r15 <= write_value;
                default: ;
            endcase
        end
    end

    assign r_value1 = (r_sel1 == 5'd0) ?     r0
                        : (r_sel1 == 5'd1) ? r1
                        : (r_sel1 == 5'd2) ? r2
                        : (r_sel1 == 5'd3) ? r3
                        : (r_sel1 == 5'd4) ? r4
                        : (r_sel1 == 5'd5) ? r5
                        : (r_sel1 == 5'd6) ? r6
                        : (r_sel1 == 5'd7) ? r7
                        : (r_sel1 == 5'd8) ? r8
                        : (r_sel1 == 5'd9) ? r9
                        : (r_sel1 == 5'd10) ? r10
                        : (r_sel1 == 5'd11) ? r11
                        : (r_sel1 == 5'd12) ? r12
                        : (r_sel1 == 5'd13) ? r13
                        : (r_sel1 == 5'd14) ? r14
                        : (r_sel1 == 5'd15) ? r15
                        : 32'b0;

    assign r_value2 = (r_sel2 == 5'd0) ?     r0
                        : (r_sel2 == 5'd1) ? r1
                        : (r_sel2 == 5'd2) ? r2
                        : (r_sel2 == 5'd3) ? r3
                        : (r_sel2 == 5'd4) ? r4
                        : (r_sel2 == 5'd5) ? r5
                        : (r_sel2 == 5'd6) ? r6
                        : (r_sel2 == 5'd7) ? r7
                        : (r_sel2 == 5'd8) ? r8
                        : (r_sel2 == 5'd9) ? r9
                        : (r_sel2 == 5'd10) ? r10
                        : (r_sel2 == 5'd11) ? r11
                        : (r_sel2 == 5'd12) ? r12
                        : (r_sel2 == 5'd13) ? r13
                        : (r_sel2 == 5'd14) ? r14
                        : (r_sel2 == 5'd15) ? r15
                        : 32'b0;

endmodule
