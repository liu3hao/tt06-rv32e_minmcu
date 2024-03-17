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

    localparam STATE_FETCH_INSTRUCTION = 3'b001;
    localparam STATE_PARSE_INSTRUCTION = 3'b010;
    localparam STATE_WRITE_REGISTER =    3'b100;

    reg [2:0] state; // State of the CPU

    // 3 byte program counter, because the instruction address
    // is only 3-bytes long, add 1 extra bit for flash/RAM chip access.
    reg [24:0] prog_counter;

    reg [31:0] fetched_data;

    wire mem_request_done;
    reg mem_start_request;

    reg [31:0] current_instruction;

    // If high, then the CPU has stopped parsing further instructions
    reg halted;

    mem_external mem_external1 (
        .sclk(uo_out[0]),
        .mosi(uo_out[1]),

        .cs1(uo_out[2]),
        .cs2(uo_out[3]),

        .miso(ui_in[0]),

        .num_bytes(mem_num_bytes),

        .is_write(
            (state == STATE_PARSE_INSTRUCTION && opcode == S_TYPE_INSTR) ? 1'b1 : 1'b0
        ),
        .write_value(
            (instr_func3 == 3'd0) ? { 24'd0, rs2[7:0]}
            : (instr_func3 == 3'd1) ? { 16'd0, rs2[15:0]}
            : (instr_func3 == 3'd2) ? rs2
            : 32'd0),

        .target_address(
            // Memory space is limited to 3 bytes and 1 extra bit.
            (state == STATE_FETCH_INSTRUCTION) ? prog_counter : op_address
        ),

        .fetched_data(fetched_data),

        .start_request(mem_start_request),
        .request_done(mem_request_done),

        .clk(clk)
    );

    registers reg1 (
        .write_register(instr_rd),
        .write_value(
            (opcode == I_TYPE_LOAD_INSTR) ? (
                (instr_func3 == 0)      ? { {24{fetched_data[31]}}, fetched_data[31:24] }
                : (instr_func3 == 3'd1) ? { {16{fetched_data[31]}}, fetched_data[31:16] }
                : (instr_func3 == 3'd2) ? fetched_data
                : (instr_func3 == 3'd4) ? { 24'd0, fetched_data[31:24] }
                : (instr_func3 == 3'd5) ? { 16'd0, fetched_data[31:16] }
                : 0)
            : (opcode == J_TYPE_INSTR || opcode == I_TYPE_JUMP_INSTR) ? ({7'd0, prog_counter} + 4)
            : (opcode == U_TYPE_LUI_INSTR) ? u_type_imm
            : (opcode == U_TYPE_AUIPC_INSTR) ? ({7'd0, prog_counter} + u_type_imm)
            : (instr_rd != 4'b0) ? alu_result
            : 0),

        .r_sel1(instr_rs1),
        .r_value1(rs1),

        .r_sel2(instr_rs2),
        .r_value2(rs2),

        .wr_en((state == STATE_WRITE_REGISTER && opcode != S_TYPE_INSTR && opcode !== B_TYPE_INSTR) ? 1'b1: 1'b0),
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

    wire [19:0] msb_sign_extend;

    // rv32e only has 16 regs, so can ignore the last reg bit
    assign opcode =        current_instruction[6:0];
    assign instr_rd =      current_instruction[10:7];
    assign instr_func3 =   current_instruction[14:12];
    assign instr_rs1 =     current_instruction[18:15];
    assign instr_rs2 =     current_instruction[23:20];
    assign instr_func7 =   current_instruction[31:25];

    assign i_type_imm =    current_instruction[31:20];

    assign msb_sign_extend = {20{current_instruction[31]}};

    assign i_type_imm_sign_extended = { msb_sign_extend, i_type_imm};

    // assign s_type_imm1 =   current_instruction[31:25]; // same as instr_func7
    assign s_type_imm2 =   current_instruction[11:7];
    assign s_type_imm_sign_extended = { msb_sign_extend, instr_func7, s_type_imm2};

    assign j_type_imm_sign_extended = { msb_sign_extend[11:0],
            current_instruction[19:12], current_instruction[20], current_instruction[30:21], 1'b0};

    assign u_type_imm = {current_instruction[31:12], 12'b0};
    assign b_type_imm = {msb_sign_extend, current_instruction[7],
                        current_instruction[30:25], current_instruction[11:8], 1'b0};

    wire [31:0] rs1;
    wire [31:0] rs2;

    // Can this be merged with rs1 and rs2?
    wire signed [31:0] signed_rs1;
    wire signed [31:0] signed_rs2;
    assign signed_rs1 = rs1;
    assign signed_rs2 = rs2;

    wire [31:0] alu_result;

    // If this is false, then assume it is a store op address
    wire is_load = (opcode == I_TYPE_LOAD_INSTR || opcode == I_TYPE_JUMP_INSTR);

    wire [31:0] tmp_op_address_add = is_load ? i_type_imm_sign_extended : s_type_imm_sign_extended;
    wire [31:0] tmp_op_address = rs1 + tmp_op_address_add;

    wire [24:0] op_address;  // Stores address of the load/store operation from the instruction
    assign op_address = tmp_op_address[24:0];

    wire [2:0] mem_num_bytes;
    assign mem_num_bytes = (state == STATE_FETCH_INSTRUCTION) ? 3'd4
                            : (instr_func3 == 3'd2) ? 3'd4
                            : (instr_func3 == 3'd0 || instr_func3 == 3'd4) ? 3'd1
                            : (instr_func3 == 3'd1 || instr_func3 == 3'd5) ? 3'd2
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
                    : ((instr_func7 == 7'd32) ? 1'b1 : 1'b0)
        ),
        .result(alu_result)
    );

    wire b_jump = ((instr_func3 == 3'd0 && rs1 == rs2)
                            || (instr_func3 == 3'd1 && rs1 != rs2)
                            || (instr_func3 == 3'd4 && signed_rs1 < signed_rs2)
                            || (instr_func3 == 3'd5 && signed_rs1 >= signed_rs2)
                            || (instr_func3 == 3'd6 && rs1 < rs2)
                            || (instr_func3 == 3'd7 && rs1 >= rs2)
                        );

    wire [24:0] prog_counter_change = (opcode == J_TYPE_INSTR) ? j_type_imm_sign_extended[24:0]
                                        : (opcode == B_TYPE_INSTR && b_jump) ? b_type_imm[24:0]
                                        : 25'd4;

    always @ (posedge clk) begin
        if (rst_n == 0) begin
            prog_counter <= 0;
            state <= STATE_FETCH_INSTRUCTION;
            mem_start_request <= 0;
            current_instruction <= 0;
            halted <= 0;

        end else if (halted == 0) begin

            case(state)
                STATE_FETCH_INSTRUCTION: begin
                    if (mem_request_done == 0) begin
                        mem_start_request <= 1;
                    end else begin
                        // Mem request completed, parse instruction
                        state <= STATE_PARSE_INSTRUCTION;
                        current_instruction <= fetched_data;

                        // Clear the fetch request for any load/store operations
                        mem_start_request <= 0;
                    end
                end
                STATE_PARSE_INSTRUCTION: begin
                    if ((opcode == I_TYPE_LOAD_INSTR || opcode == S_TYPE_INSTR) && mem_request_done == 0) begin
                        // If it's a load/store instruction, then start mem request
                        mem_start_request <= 1;

                    end else begin
                        // When load/store is done, or if it is other ops, then
                        // move state to write register.
                        state <= STATE_WRITE_REGISTER;
                    end
                end
                STATE_WRITE_REGISTER: begin
                    prog_counter <= (opcode == I_TYPE_JUMP_INSTR) ? op_address
                                    : prog_counter + prog_counter_change;

                    state <= STATE_FETCH_INSTRUCTION;
                    mem_start_request <= 0; // Prepare to fetch next instruction
                    current_instruction <= 0;

                    // In this situation, the PC will not change anymore, so
                    // the program is halted.
                    if (opcode == J_TYPE_INSTR && i_type_imm_sign_extended == 0) begin
                        halted <= 1;
                    end
                end
                default: ;
            endcase
        end
    end

endmodule
