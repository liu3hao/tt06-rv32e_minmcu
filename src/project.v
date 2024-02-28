/*
 * Copyright (c) 2023 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`define default_netname none

localparam I_TYPE_INSTR = 7'h13;
localparam R_TYPE_INSTR = 7'h33;
localparam I_TYPE_LOAD_INSTR = 7'h03;

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

    // Not used yet.
    assign uio_oe = 0;
    assign uio_out = 0;
    assign uo_out[7:3] = 0;

    localparam STATE_FETCH_INSTRUCTION = 2'b00;
    localparam STATE_PARSE_INSTRUCTION = 2'b01;

    reg [31:0] prog_counter;

    reg [31:0] fetched_data;
    reg [31:0] fetched_instruction;
    reg [23:0] fetch_address;

    reg [1:0] state;

    wire mem_request_done;
    reg start_mem_request;

    reg [31:0] current_instruction;

    mem_controller mem_controller1 (
        .sclk(uo_out[0]),
        .mosi(uo_out[1]),
        .cs(uo_out[2]),
        .miso(ui_in[0]),

        .is_data_fetch(
            opcode == I_TYPE_LOAD_INSTR && state == STATE_PARSE_INSTRUCTION
        ),
        .read_bytes(
            state == STATE_FETCH_INSTRUCTION ? 3'd4
            : load_num_bytes
        ),

        .target_address(fetch_address),

        .fetched_instruction(fetched_instruction),
        .fetched_data(fetched_data),

        .start_request(start_mem_request),
        .request_done(mem_request_done),

        .clk(clk),
        .rst_n(rst_n)
    );

    registers reg1 (
        .write_register(state == STATE_PARSE_INSTRUCTION ? instr_rd: 5'd0),
        .write_value(
            (opcode == I_TYPE_LOAD_INSTR) ? (
                (instr_func3 == 0) ? {fetched_data[7] == 1 ? 24'hffffff : 24'd0, fetched_data[7:0] }
                : (instr_func3 == 3'd1) ? {fetched_data[15] == 1 ? 16'hffff : 16'd0, fetched_data[15:0]}
                : (instr_func3 == 3'd2) ? fetched_data
                : (instr_func3 == 3'd4) ? {24'd0, fetched_data[7:0]}
                : (instr_func3 == 3'd5) ? {16'd0, fetched_data[15:0]}
                : 0)
            : (instr_rd != 5'b0) ? alu_result
            : 0),

        .r_sel1(instr_rs1),
        .r_value1(rs1),

        .r_sel2(instr_rs2),
        .r_value2(rs2),

        .clk(clk),
        .rst_n(rst_n)
    );

    wire [6:0] opcode;
    wire [4:0] instr_rs1;
    wire [4:0] instr_rs2;
    wire [4:0] instr_rd;

    wire [2:0] instr_func3;
    wire [6:0] instr_func7;

    wire [11:0] i_type_imm;
    wire [31:0] i_type_imm_sign_extended;

    assign opcode =        current_instruction[6:0];
    assign instr_rd =      current_instruction[11:7];
    assign instr_func3 =   current_instruction[14:12];
    assign instr_rs1 =     current_instruction[19:15];
    assign instr_rs2 =     current_instruction[24:20];
    assign instr_func7 =   current_instruction[31:25];

    assign i_type_imm =     current_instruction[31:20];
    assign i_type_imm_sign_extended =
        {i_type_imm[11] == 1'b1 ? 20'hfffff : 20'd0, i_type_imm};

    wire [31:0] rs1;
    wire [31:0] rs2;
    wire [31:0] rd;

    wire [31:0] alu_result;

    wire [31:0] load_address;
    assign load_address = rs1 + i_type_imm_sign_extended;

    wire [2:0] load_num_bytes;
    assign load_num_bytes = (instr_func3 == 3'd0 || instr_func3 == 3'd4) ? 3'd1
                            : (instr_func3 == 3'd1 || instr_func3 == 3'd5) ? 3'd2
                            : (instr_func3 == 3'd2) ? 3'd4
                            : 3'd0;

    alu alu1 (
        .value1(rs1),
        .value2(
            (opcode == I_TYPE_INSTR && instr_func3 != 3'b001 && instr_func3 != 3'b101) ?
                i_type_imm_sign_extended
                : (opcode == I_TYPE_INSTR && (instr_func3 == 3'b001 || instr_func3 == 3'b101)) ? // Shift operations
                    {27'b0, instr_rs2}
                : rs2),

        .func_type(instr_func3),
        .f7_bit( (opcode == I_TYPE_INSTR && instr_func3 != 3'b001 && instr_func3 != 3'b101) ? 1'b0
                    : ((instr_func7 == 7'b0100000) ? 1'b1 : 1'b0)
        ),
        .result(alu_result)
    );

    always @ (posedge clk) begin
        if (rst_n == 0) begin
            state <= STATE_FETCH_INSTRUCTION;
            prog_counter <= 0;
            current_instruction <= 0;
            fetch_address <= 0;
            start_mem_request <= 0;

        end else begin
            if (state == STATE_FETCH_INSTRUCTION) begin
                if (mem_request_done == 0) begin
                    fetch_address <= prog_counter[23:0];
                    start_mem_request <= 1;
                end else begin
                    // Got something!
                    state <= STATE_PARSE_INSTRUCTION;
                    current_instruction <= fetched_instruction;
                    start_mem_request <= 0; // Clear the fetch request
                end
            end else if (state == STATE_PARSE_INSTRUCTION) begin

                // At least 1 clock cycle has passed.
                // ALU operations will be completed.

                // parse the opcode
                if (opcode == I_TYPE_INSTR || opcode == R_TYPE_INSTR) begin
                    current_instruction <= 0;

                end else if (opcode == I_TYPE_LOAD_INSTR) begin
                    // If it's a load instruction, then need to do some fetches

                    if (mem_request_done == 0) begin
                        start_mem_request <= 1;
                        fetch_address <= load_address[23:0];
                    end else begin
                        // Fetch is done
                        current_instruction <= 0;
                        start_mem_request <= 0;
                    end

                end else begin
                     // For now, skip back to fetch more data
                    start_mem_request <= 0;
                    prog_counter <= prog_counter + 4;
                    state <= STATE_FETCH_INSTRUCTION;
                end
            end
        end
    end

endmodule
