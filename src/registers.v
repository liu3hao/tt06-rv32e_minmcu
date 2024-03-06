
module registers (
    input wire [3:0] write_register,
    input wire [31:0] write_value,

    // up to 16 registers
    input wire [3:0] r_sel1,
    output wire [31:0] r_value1,

    input wire [3:0] r_sel2,
    output wire [31:0] r_value2,

    input wire clk,
    input wire rst_n
);
    reg [31:0] registers [15:0];   // Array of 16 32-bit registers

    // Reading data from registers
    assign r_value1 = registers[r_sel1];
    assign r_value2 = registers[r_sel2];

    // Writing data into registers
    generate
        genvar i;
        for (i = 0; i < 16; i = i + 1) begin: g_reset_regs
            always @(posedge clk) begin
                if (rst_n == 0) begin
                    registers[i] <= 0;
                end
            end
        end
    endgenerate

    always @(posedge clk) begin
        if (write_register != 0) begin
            registers[write_register] <= write_value;
        end
    end

endmodule


// module registers (
//     input wire [3:0] write_register,
//     input wire [31:0] write_value,

//     // up to 16 registers
//     input wire [3:0] r_sel1,
//     output wire [31:0] r_value1,

//     input wire [3:0] r_sel2,
//     output wire [31:0] r_value2,

//     input wire clk,
//     input wire rst_n
// );

//     wire [31:0] r0;
//     assign r0 = 0;

//     reg [31:0] r1, r2, r3, r4,
//             r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15;

//     always @ (posedge clk) begin
//         if (rst_n == 0) begin
//             // Reset all registers first
//             r1 <= 0;
//             r2 <= 0;
//             r3 <= 0;
//             r4 <= 0;
//             r5 <= 0;
//             r6 <= 0;
//             r7 <= 0;
//             r8 <= 0;
//             r9 <= 0;
//             r10 <= 0;
//             r11 <= 0;
//             r12 <= 0;
//             r13 <= 0;
//             r14 <= 0;
//             r15 <= 0;

//         end else begin
//             case (write_register)
//                 4'd1:   r1 <= write_value;
//                 4'd2:   r2 <= write_value;
//                 4'd3:   r3 <= write_value;
//                 4'd4:   r4 <= write_value;
//                 4'd5:   r5 <= write_value;
//                 4'd6:   r6 <= write_value;
//                 4'd7:   r7 <= write_value;
//                 4'd8:   r8 <= write_value;
//                 4'd9:   r9 <= write_value;
//                 4'd10:  r10 <= write_value;
//                 4'd11:  r11 <= write_value;
//                 4'd12:  r12 <= write_value;
//                 4'd13:  r13 <= write_value;
//                 4'd14:  r14 <= write_value;
//                 4'd15:  r15 <= write_value;
//                 default: ;
//             endcase
//         end
//     end

//     assign r_value1 =     (r_sel1 == 4'd0) ? r0
//                         : (r_sel1 == 4'd1) ? r1
//                         : (r_sel1 == 4'd2) ? r2
//                         : (r_sel1 == 4'd3) ? r3
//                         : (r_sel1 == 4'd4) ? r4
//                         : (r_sel1 == 4'd5) ? r5
//                         : (r_sel1 == 4'd6) ? r6
//                         : (r_sel1 == 4'd7) ? r7
//                         : (r_sel1 == 4'd8) ? r8
//                         : (r_sel1 == 4'd9) ? r9
//                         : (r_sel1 == 4'd10) ? r10
//                         : (r_sel1 == 4'd11) ? r11
//                         : (r_sel1 == 4'd12) ? r12
//                         : (r_sel1 == 4'd13) ? r13
//                         : (r_sel1 == 4'd14) ? r14
//                         : (r_sel1 == 4'd15) ? r15
//                         : 32'b0;

//     assign r_value2 =     (r_sel2 == 4'd0) ? r0
//                         : (r_sel2 == 4'd1) ? r1
//                         : (r_sel2 == 4'd2) ? r2
//                         : (r_sel2 == 4'd3) ? r3
//                         : (r_sel2 == 4'd4) ? r4
//                         : (r_sel2 == 4'd5) ? r5
//                         : (r_sel2 == 4'd6) ? r6
//                         : (r_sel2 == 4'd7) ? r7
//                         : (r_sel2 == 4'd8) ? r8
//                         : (r_sel2 == 4'd9) ? r9
//                         : (r_sel2 == 4'd10) ? r10
//                         : (r_sel2 == 4'd11) ? r11
//                         : (r_sel2 == 4'd12) ? r12
//                         : (r_sel2 == 4'd13) ? r13
//                         : (r_sel2 == 4'd14) ? r14
//                         : (r_sel2 == 4'd15) ? r15
//                         : 32'b0;

// endmodule
