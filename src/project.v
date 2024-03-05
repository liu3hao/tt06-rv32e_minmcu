/*
 * Copyright (c) 2023 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`define default_netname none

localparam I_TYPE_INSTR =       7'h13;
localparam R_TYPE_INSTR =       7'h33;
localparam I_TYPE_LOAD_INSTR =  7'h03;
localparam S_TYPE_INSTR =       7'h23;
localparam J_TYPE_INSTR =       7'h6F;  // JAL
localparam I_TYPE_JUMP_INSTR =  7'h67;  // JALR
localparam U_TYPE_LUI_INSTR =   7'h37;
localparam U_TYPE_AUIPC_INSTR = 7'h17;
localparam B_TYPE_INSTR =       7'h63;

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
    assign uo_out[7:4] = 0;

    localparam STATE_FETCH_INSTRUCTION = 2'b00;
    localparam STATE_PARSE_INSTRUCTION = 2'b01;

    // 3 byte program counter, because the instruction address
    // is only 3-bytes long.
    reg [23:0] prog_counter;

    reg [31:0] fetched_data;
    reg [31:0] mem_address;

    reg [1:0] state; // State of the CPU

    wire mem_request_done;
    reg start_mem_request;

    reg mem_write;

    reg [31:0] current_instruction;

    // If high, then the CPU has stopped parsing further instructions
    reg halted;

    mem_controller mem_controller1 (
        .sclk(uo_out[0]),
        .mosi(uo_out[1]),

        .cs1(uo_out[2]),
        .cs2(uo_out[3]),

        .miso(ui_in[0]),

        .is_data_fetch(
            opcode == I_TYPE_LOAD_INSTR && state == STATE_PARSE_INSTRUCTION
        ),

        .num_bytes(
            state == STATE_FETCH_INSTRUCTION ? 3'd4
            : mem_num_bytes
        ),

        .is_write(mem_write),
        .write_value(
            (instr_func3 == 3'd0) ? { 24'd0, rs2[7:0]}
            : (instr_func3 == 3'd1) ? { 16'd0, rs2[15:0]}
            : (instr_func3 == 3'd2) ? rs2
            : 32'd0),

        .target_address(mem_address),

        .fetched_data(fetched_data),

        .start_request(start_mem_request),
        .request_done(mem_request_done),

        .clk(clk),
        .rst_n(rst_n)
    );

    registers reg1 (
        .write_register(state == STATE_PARSE_INSTRUCTION ? instr_rd: 4'd0),
        .write_value(
            (opcode == I_TYPE_LOAD_INSTR) ? (
                (instr_func3 == 0) ? {fetched_data[31] == 1 ? 24'hffffff : 24'd0, fetched_data[31:24] }
                : (instr_func3 == 3'd1) ? {fetched_data[31] == 1 ? 16'hffff : 16'd0, fetched_data[31:16]}
                : (instr_func3 == 3'd2) ? fetched_data
                : (instr_func3 == 3'd4) ? {24'd0, fetched_data[31:24]}
                : (instr_func3 == 3'd5) ? {16'd0, fetched_data[31:16]}
                : 0)
            : (opcode == J_TYPE_INSTR || opcode == I_TYPE_JUMP_INSTR) ? ({8'd0, prog_counter} + 4)
            : (opcode == U_TYPE_LUI_INSTR) ? u_type_imm
            : (opcode == U_TYPE_AUIPC_INSTR) ? ({8'd0, prog_counter} + u_type_imm)
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
    wire [3:0] instr_rs1;
    wire [3:0] instr_rs2;
    wire [3:0] instr_rd;

    wire [2:0] instr_func3;
    wire [6:0] instr_func7;

    wire [11:0] i_type_imm;
    wire [31:0] i_type_imm_sign_extended;

    wire [6:0] s_type_imm1;
    wire [4:0] s_type_imm2;
    wire [31:0] s_type_imm_sign_extended;

    wire [31:0] j_type_imm_sign_extended;

    wire [31:0] u_type_imm;
    wire [31:0] b_type_imm;

    assign opcode =        current_instruction[6:0];
    assign instr_rd =      current_instruction[10:7];
    assign instr_func3 =   current_instruction[14:12];
    assign instr_rs1 =     current_instruction[18:15]; // rv32e only has 16 regs
    assign instr_rs2 =     current_instruction[23:20];
    assign instr_func7 =   current_instruction[31:25];

    assign i_type_imm =     current_instruction[31:20];
    assign i_type_imm_sign_extended =
        {i_type_imm[11] == 1'b1 ? 20'hfffff : 20'd0, i_type_imm};

    assign s_type_imm1 = current_instruction[31:25];
    assign s_type_imm2 = current_instruction[11:7];
    assign s_type_imm_sign_extended =
        {s_type_imm1[6] == 1'b1 ? 20'hfffff : 20'd0, s_type_imm1, s_type_imm2};

    assign j_type_imm_sign_extended = {current_instruction[31] == 1'b1 ? 12'hfff : 12'h0,
            current_instruction[19:12], current_instruction[20], current_instruction[30:21], 1'b0};

    assign u_type_imm = {current_instruction[31:12], 12'b0};
    assign b_type_imm = {current_instruction[31] == 1 ? 20'hfffff: 20'h0, current_instruction[7],
                        current_instruction[30:25], current_instruction[11:8], 1'b0};

    wire [31:0] rs1;
    wire [31:0] rs2;
    wire [31:0] rd;

    // Can this be merged with rs1 and rs2?
    wire signed [31:0] signed_rs1;
    wire signed [31:0] signed_rs2;
    assign signed_rs1 = rs1;
    assign signed_rs2 = rs2;

    wire [31:0] alu_result;

    wire [31:0] op_address; // Stores address of the load/store operation from the instruction
    assign op_address = (opcode == I_TYPE_LOAD_INSTR || opcode == I_TYPE_JUMP_INSTR) ? (rs1 + i_type_imm_sign_extended)
                            : (opcode == S_TYPE_INSTR) ? (rs1 + s_type_imm_sign_extended)
                            : 32'd0;

    wire [2:0] mem_num_bytes;
    assign mem_num_bytes = (instr_func3 == 3'd0 || instr_func3 == 3'd4) ? 3'd1
                            : (instr_func3 == 3'd1 || instr_func3 == 3'd5) ? 3'd2
                            : (instr_func3 == 3'd2) ? 3'd4
                            : 3'd0;

    alu alu1 (
        .value1(rs1),
        .value2(
            (opcode == I_TYPE_INSTR && instr_func3 != 3'b001 && instr_func3 != 3'b101) ?
                i_type_imm_sign_extended
                : (opcode == I_TYPE_INSTR && (instr_func3 == 3'b001 || instr_func3 == 3'b101)) ? // Shift operations
                    {28'b0, instr_rs2}
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
            mem_address <= 0;
            start_mem_request <= 0;

            mem_write <= 0;
            halted <= 0;

        end else if (halted == 0) begin
            if (state == STATE_FETCH_INSTRUCTION) begin
                if (mem_request_done == 0) begin
                    mem_address <= {8'd0, prog_counter};
                    start_mem_request <= 1;
                end else begin
                    // Got something!
                    state <= STATE_PARSE_INSTRUCTION;
                    current_instruction <= fetched_data;
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
                        mem_write <= 0;
                        mem_address <= op_address;

                    end else begin
                        // Fetch is done
                        current_instruction <= 0;
                        start_mem_request <= 0;
                    end

                end else if (opcode == S_TYPE_INSTR) begin

                    if (mem_request_done == 0) begin
                        start_mem_request <= 1;
                        mem_write <= 1;
                        mem_address <= op_address;

                    end else begin
                        current_instruction <= 0;
                        start_mem_request <= 0;
                        mem_write <= 0;
                    end

                end else begin
                    // If opcode is 0 (because current instruction set to 0),
                    // or unrecognized, then fetch the next instruction.
                    prog_counter <= (opcode == I_TYPE_JUMP_INSTR) ? op_address[23:0]
                                    : prog_counter +
                                        (
                                            (opcode == J_TYPE_INSTR) ? j_type_imm_sign_extended[23:0]
                                            : (opcode == B_TYPE_INSTR && (
                                                (instr_func3 == 3'd0 && rs1 == rs2)
                                                || (instr_func3 == 3'd1 && rs1 != rs2)
                                                || (instr_func3 == 3'd4 && signed_rs1 < signed_rs2)
                                                || (instr_func3 == 3'd5 && signed_rs1 >= signed_rs2)
                                                || (instr_func3 == 3'd6 && rs1 < rs2)
                                                || (instr_func3 == 3'd7 && rs1 >= rs2)
                                            )) ? b_type_imm[23:0]
                                            : 4);

                    state <= STATE_FETCH_INSTRUCTION;
                    start_mem_request <= 0;

                    // In this situation, the PC will not change anymore, so
                    // the program is halted.
                    if (opcode == J_TYPE_INSTR && i_type_imm_sign_extended == 0) begin
                        halted <= 1;
                    end
                end
            end
        end
    end

endmodule
