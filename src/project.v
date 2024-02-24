/*
 * Copyright (c) 2023 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`define default_netname none

localparam I_TYPE_INSTR = 7'h13;
localparam R_TYPE_INSTR = 7'h33;

module tt_um_rv32e_cpu (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs

    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)

    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    localparam STATE_FETCH_DATA = 2'b00;
    localparam STATE_PARSE_DATA = 2'b01;

    reg [31:0] prog_counter;

    reg [31:0] fetched_data;
    reg [23:0] fetch_address;

    reg [1:0] state;

    wire fetch_done;
    reg start_fetch;

    // Not used yet.
    assign uio_oe = 0;
    assign uio_out = 0;

    assign uo_out[7:3] = 0;

    reg [31:0] current_instruction;

    mem_read mem_read1 (
        .sclk(uo_out[0]),
        .mosi(uo_out[1]),
        .cs(uo_out[2]),
        .miso(ui_in[0]),

        .target_address(fetch_address),
        .fetched_data(fetched_data),

        .start_fetch(start_fetch),
        .fetch_done(fetch_done),

        .clk(clk),
        .rst_n(rst_n)
    );

    wire [31:0] r0, r1, r2, r3, r4;

    registers reg1 (
        .r0(r0),
        .r1(r1),
        .r2(r2),
        .r3(r3),
        .r4(r4),

        .write_register(r_type_rd),
        .write_value(r_type_rd != 5'b0 ? alu_result : 0),

        .clk(clk),
        .rst_n(rst_n)
    );

    wire [6:0] opcode;
    wire [4:0] r_type_rs1;
    wire [4:0] r_type_rs2;
    wire [4:0] r_type_rd;

    wire [2:0] r_type_func3;
    wire [6:0] r_type_func7;

    wire [11:0] i_type_imm;

    assign opcode =         current_instruction[6:0];
    assign r_type_rd =      current_instruction[11:7];
    assign r_type_func3 =   current_instruction[14:12];
    assign r_type_rs1 =     current_instruction[19:15];
    assign r_type_rs2 =     current_instruction[24:20];
    assign r_type_func7 =   current_instruction[31:25];

    assign i_type_imm =     current_instruction[31:20];

    wire [31:0] rs1;
    wire [31:0] rs2;
    wire [31:0] rd;

    wire [31:0] alu_value1;
    wire [31:0] alu_value2;
    wire [31:0] alu_result;

    assign alu_value1 = rs1;
    assign alu_value2 = rs2;

    register_select rs1_sel (
        .r0(r0),
        .r1(r1),
        .r2(r2),
        .r3(r3),
        .r4(r4),
        .r_sel(r_type_rs1),
        .r_value(rs1)
    );

    register_select rs2_sel (
        .r0(r0),
        .r1(r1),
        .r2(r2),
        .r3(r3),
        .r4(r4),
        .r_sel(r_type_rs2),
        .r_value(rs2)
    );

    alu alu1 (
        .value1(rs1),
        .value2( opcode == I_TYPE_INSTR ?
            {i_type_imm[11] == 1'b1 ? 20'hfffff : 20'd0,
            i_type_imm}              // Sign extend this value
            : rs2),

        .func_type(r_type_func3),
        .f7_bit( opcode == I_TYPE_INSTR ? 1'b0 :
                    (r_type_func7 && 7'b0100000 ? 1'b1 : 1'b0)
        ),
        .result(alu_result)
    );

    always @ (posedge clk) begin
        if (rst_n == 0) begin
            state <= STATE_FETCH_DATA;
            prog_counter <= 0;
            current_instruction <= 0;

        end else begin
            if (state == STATE_FETCH_DATA) begin
                if (fetch_done == 0) begin
                    fetch_address <= prog_counter[23:0];
                    start_fetch <= 1;
                end else begin
                    // Got something!
                    state <= STATE_PARSE_DATA;
                    current_instruction <= fetched_data;
                end
            end else if (state == STATE_PARSE_DATA) begin

                // At least 1 clock cycle has passed.
                // ALU operations will be completed.

                // parse the opcode
                if (opcode == I_TYPE_INSTR || opcode == R_TYPE_INSTR) begin
                    current_instruction <= 0;

                end else begin
                     // For now, skip back to fetch more data
                    start_fetch <= 0;
                    prog_counter <= prog_counter + 4;
                    state <= STATE_FETCH_DATA;
                end
            end
        end
    end

endmodule
