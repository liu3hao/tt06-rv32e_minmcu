/*
 * Copyright (c) 2023 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`define default_netname none

localparam I_TYPE_LOAD_INSTR =  7'h03;
localparam I_TYPE_INSTR =       7'h13;
localparam U_TYPE_AUIPC_INSTR = 7'h17;
localparam S_TYPE_INSTR =       7'h23;
localparam R_TYPE_INSTR =       7'h33;
localparam U_TYPE_LUI_INSTR =   7'h37;
localparam B_TYPE_INSTR =       7'h63;
localparam I_TYPE_JUMP_INSTR =  7'h67;  // JALR
localparam J_TYPE_INSTR =       7'h6F;  // JAL

module tt_um_rv32e_cpu # (
        parameter address_size = 16+2
    )(
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
    // assign uio_oe = 8'b00000001;
    assign uio_oe[2:0] = 0;
    assign uio_out[2:1] = 0;
    assign uo_out[0] = 0;

    localparam STATE_FETCH_INSTRUCTION =    5'b00001;
    localparam STATE_READ_REGISTERS    =    5'b00010;
    localparam STATE_PARSE_INSTRUCTION =    5'b00100;
    localparam STATE_WRITE_REGISTER    =    5'b01000;
    localparam STATE_MOVE_PROG_COUNTER =    5'b10000;

    reg [4:0] state; // State of the CPU

    // 3 byte program counter, because the instruction address
    // is only 3-bytes long, add 1 extra bit for flash/RAM chip access.
    reg [address_size-1:0] prog_counter;

    reg [31:0] mem_fetched_value;

    wire mem_request_done;
    reg mem_start_request;

    reg [31:0] current_instruction; // Stores curent instruction fetched from mem in lsb order

    // If high, then the CPU has stopped parsing further instructions
    reg halted;

    reg reg_shift;                      // If 1, then register file will shift
    reg [3:0] reg_counter;              // Count up to 15 for shifting into register file
    reg [31:0] full_reg_write_value;    // Holds full word to be stored in registers

    wire [2:0] mem_num_bytes = (state == STATE_FETCH_INSTRUCTION) ? 3'd4
                            : (instr_func3 == 3'd2) ? 3'd4
                            : (instr_func3 == 3'd0 || instr_func3 == 3'd4) ? 3'd1
                            : (instr_func3 == 3'd1 || instr_func3 == 3'd5) ? 3'd2
                            : 3'd0;

    mem_bus #(.address_size(address_size)) mem_external1(
        .sclk(uo_out[5]),
        .mosi(uo_out[3]),

        .cs1(uo_out[4]),
        .cs2(uio_out[0]),

        .miso(ui_in[2]),

        .num_bytes(mem_num_bytes),

        .inputs({ui_in[6:3], ui_in[1:0]}),      // input only pins
        .outputs({uo_out[7:6], uo_out[2:1]}),   // output only pins

        .io_direction(uio_oe[7:3]),             // direction for io pins
        .io_outputs(uio_out[7:3]),              // io pins output
        .io_inputs(uio_in[7:3]),                // io pins input

        .is_write(
            state == STATE_PARSE_INSTRUCTION & opcode == S_TYPE_INSTR
        ),
        .write_value(rs2),

        .target_address(
            // Memory space is limited to 3 bytes and 1 extra bit.
            alu_result[address_size-1:0]
        ),

        .fetched_value(mem_fetched_value),

        .start_request(mem_start_request),
        .request_done(mem_request_done),

        .clk(clk),
        .rst_n(rst_n)
    );

    reg [31:0] mem_fetch_value2;

    always_comb begin
        case (instr_func3)
            0: mem_fetch_value2 = {{24{mem_fetched_value[7]}}, mem_fetched_value[7:0]};
            1: mem_fetch_value2 = {{16{mem_fetched_value[7]}}, mem_fetched_value[7:0], mem_fetched_value[15:8]};
            2: mem_fetch_value2 = {mem_fetched_value[7:0], mem_fetched_value[15:8], mem_fetched_value[23:16], mem_fetched_value[31:24]};
            4: mem_fetch_value2 = {24'd0, mem_fetched_value[7:0]};
            default:    mem_fetch_value2 = {16'd0, mem_fetched_value[7:0], mem_fetched_value[15:8]};
        endcase
    end

    registers reg1 (
        .write_register(instr_rd),
        .write_value(full_reg_write_value[1:0]),

        .r_sel1(instr_rs1),
        .r_value1(rs1_bit),

        .r_sel2(instr_rs2),
        .r_value2(rs2_bit),

        .wr_en(state == STATE_WRITE_REGISTER & opcode != S_TYPE_INSTR & opcode != B_TYPE_INSTR),
        .shift(reg_shift),

        .clk(clk),
        .rst_n(rst_n)
    );

    reg [31:0] rs1;
    reg [31:0] rs2;

    wire [1:0] rs1_bit;
    wire [1:0] rs2_bit;

    wire [6:0] opcode;
    wire [3:0] instr_rs1;
    wire [3:0] instr_rs2;
    wire [3:0] instr_rd;

    wire [2:0] instr_func3;
    wire [6:0] instr_func7;

    wire [11:0] i_type_imm;
    wire [31:0] i_type_imm_sign_extended;

    // wire [6:0] s_type_imm1;
    wire [4:0] s_type_imm2;
    wire [31:0] s_type_imm_sign_extended;

    wire [31:0] j_type_imm_sign_extended;

    wire [31:0] u_type_imm;
    wire [31:0] b_type_imm;

    wire [19:0] msb_sign_extend;

    // rv32e only has 16 regs, so can ignore the last reg bit
    assign opcode =        current_instruction[30:24];
    assign instr_rd =      {current_instruction[18:16], current_instruction[31]};
    assign instr_func3 =   current_instruction[22:20];
    assign instr_rs1 =     {current_instruction[10:8], current_instruction[23]};
    assign instr_rs2 =     current_instruction[15:12];
    assign instr_func7 =   current_instruction[7:1];

    assign i_type_imm =    {current_instruction[7:0], current_instruction[15:12]};

    assign msb_sign_extend = {20{current_instruction[7]}};

    assign i_type_imm_sign_extended = { msb_sign_extend, i_type_imm};

    // assign s_type_imm1 =   current_instruction[31:25]; // same as instr_func7
    assign s_type_imm2 =   {current_instruction[19:16], current_instruction[31]};
    assign s_type_imm_sign_extended = { msb_sign_extend, instr_func7, s_type_imm2};

    assign j_type_imm_sign_extended = { msb_sign_extend[11:0],
            current_instruction[11:8],
            current_instruction[23:20],
            current_instruction[12],
            current_instruction[6:0],
            current_instruction[15:13],
            1'b0};

    assign u_type_imm = {current_instruction[7:0],
                         current_instruction[15:8],
                         current_instruction[23:20],
                         12'b0};
    assign b_type_imm = {msb_sign_extend,
                         current_instruction[31],
                         current_instruction[6:1],
                         current_instruction[19:16], 1'b0};

    wire [31:0] alu_result;

    reg [31:0] alu_value1;
    reg [31:0] alu_value2;
    reg [2:0] alu_func_type;
    reg alu_f7_bit;

    wire alu_result_lsb = full_reg_write_value[0]; // Store ALU result lsb

    alu alu1 (
        .value1(alu_value1),
        .value2(alu_value2),
        .func_type(alu_func_type),
        .f7_bit(alu_f7_bit),
        .result(alu_result)
    );

    always_comb begin
        alu_func_type = 0;
        alu_f7_bit    = 0;

        case (state)
            STATE_FETCH_INSTRUCTION: begin
                alu_value1 = {{32-address_size{1'b0}}, prog_counter};
                alu_value2 = 0;
            end
            STATE_PARSE_INSTRUCTION: begin

                case (opcode)
                    U_TYPE_AUIPC_INSTR, J_TYPE_INSTR, I_TYPE_JUMP_INSTR: begin
                        alu_value1 = {{32-address_size{1'b0}}, prog_counter};
                    end
                    U_TYPE_LUI_INSTR:   alu_value1 = 0;

                    // For B_TYPE, set alu_value1 to rs1
                    default:            alu_value1 = rs1;
                endcase

                case (opcode)
                    I_TYPE_LOAD_INSTR:
                        alu_value2 = i_type_imm_sign_extended;
                    I_TYPE_INSTR:
                        if (instr_func3 == 3'b001 || instr_func3 == 3'b101) begin
                            alu_value2 = {28'b0, instr_rs2};
                        end else begin
                            alu_value2 = i_type_imm_sign_extended;
                        end
                    S_TYPE_INSTR:                         alu_value2 = s_type_imm_sign_extended;
                    J_TYPE_INSTR, I_TYPE_JUMP_INSTR:      alu_value2 = 32'd4;
                    U_TYPE_AUIPC_INSTR, U_TYPE_LUI_INSTR: alu_value2 = u_type_imm;

                    // For B_TYPE, set alu_value2 to rs2
                    default:                              alu_value2 = rs2;
                endcase

                case (opcode)
                    R_TYPE_INSTR, I_TYPE_INSTR: begin
                        alu_func_type = instr_func3;
                        alu_f7_bit    =  (opcode == I_TYPE_INSTR && instr_func3 != 3'b001 && instr_func3 != 3'b101) ? 1'b0
                                        : instr_func7[5];
                    end
                    B_TYPE_INSTR: begin
                        case (instr_func3)
                            3'd4, 3'd5: alu_func_type = 3'b010;
                            3'd6, 3'd7: alu_func_type = 3'b011;
                            default:    alu_func_type = 3'b000;
                        endcase
                    end
                    default: begin
                        alu_func_type = 3'd0;
                        alu_f7_bit =    1'd0;
                    end
                endcase
            end
            STATE_MOVE_PROG_COUNTER: begin
                alu_value1 = {{32-address_size{1'b0}}, prog_counter};
                alu_value2 = 32'd4;

                case (opcode)
                    I_TYPE_JUMP_INSTR: begin
                        alu_value1 = rs1;
                        alu_value2 = i_type_imm_sign_extended;
                    end
                    J_TYPE_INSTR: alu_value2 = j_type_imm_sign_extended;
                    B_TYPE_INSTR: begin
                        alu_value2 = 32'd4;
                        case (instr_func3)
                            3'd0: begin
                                if (rs1 == rs2) begin
                                    alu_value2 = b_type_imm;
                                end
                            end
                            3'd1: begin
                                if (rs1 != rs2) begin
                                    alu_value2 = b_type_imm;
                                end
                            end
                            3'd4, 3'd6: begin
                                if (alu_result_lsb) begin
                                    alu_value2 = b_type_imm;
                                end
                            end
                            3'd5, 3'd7: begin
                                // If bit is 0, then greater or equal is true
                                if (~alu_result_lsb) begin
                                    alu_value2 = b_type_imm;
                                end
                            end
                            default: alu_value2 = 32'd4;
                        endcase
                    end
                    default: alu_value2 = 32'd4;
                endcase
            end
            default: begin
                alu_value1 = 0;
                alu_value2 = 0;
            end
        endcase
    end

    always @ (posedge clk) begin
        if (rst_n == 0) begin
            prog_counter <= 0;
            state <= STATE_FETCH_INSTRUCTION;
            mem_start_request <= 0;
            current_instruction <= 0;
            halted <= 0;

            rs1 <= 0;
            rs2 <= 0;
            reg_shift <= 0;

        end else if (halted == 0) begin

            case(state)
                STATE_FETCH_INSTRUCTION: begin
                    if (mem_request_done == 0) begin
                        mem_start_request <= 1;
                    end else begin
                        // Mem request completed, parse instruction
                        state <= STATE_READ_REGISTERS;
                        current_instruction <= mem_fetched_value;

                        // Clear the fetch request for any load/store operations
                        mem_start_request <= 0;

                        reg_counter <= 0;
                        full_reg_write_value <= 0;
                        reg_shift <= 0;     // Prepare to read out register values
                    end
                end

                STATE_READ_REGISTERS: begin
                    if (reg_shift == 1) begin
                        // Read out registers first before reading alu results
                        rs1 <= (rs1 >> 2) | {rs1_bit, 30'd0};
                        rs2 <= (rs2 >> 2) | {rs2_bit, 30'd0};
                        reg_counter <= reg_counter + 1;
                    end else begin
                        reg_shift <= 1;
                    end

                    if (reg_counter == 4'd15) begin
                        reg_counter <= 0;
                        reg_shift <= 0;
                        state <= STATE_PARSE_INSTRUCTION;
                    end
                end

                STATE_PARSE_INSTRUCTION: begin
                    if ((opcode == I_TYPE_LOAD_INSTR || opcode == S_TYPE_INSTR) && mem_request_done == 0) begin
                        // If it's a load/store instruction, then start mem request
                        mem_start_request <= 1;
                    end else begin
                        // If not a load/store instruction, or if mem request is done, then move on.
                        state <= STATE_WRITE_REGISTER;
                        full_reg_write_value <= (opcode == I_TYPE_LOAD_INSTR) ? mem_fetch_value2: alu_result;
                        reg_shift <= 1;
                        mem_start_request <= 0;
                    end
                end

                STATE_WRITE_REGISTER: begin
                    full_reg_write_value <= (full_reg_write_value >> 2) | {full_reg_write_value[1:0], 30'd0};

                    reg_counter <= reg_counter + 1;

                     if (reg_counter == 4'd15) begin
                        state <= STATE_MOVE_PROG_COUNTER;
                        reg_shift <= 0;
                    end
                end

                STATE_MOVE_PROG_COUNTER: begin
                    prog_counter <= alu_result[address_size-1:0];
                    state <= STATE_FETCH_INSTRUCTION;
                    mem_start_request <= 0; // Prepare to fetch next instruction

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

module mem_bus #(
        parameter address_size = 16 + 2
    )(
    input  wire miso,  // Main spi signals
    output wire sclk,
    output wire mosi,

    output wire cs1,
    output wire cs2,

    input wire [2:0] num_bytes,

    input wire [5:0] inputs,
    output wire [3:0] outputs,

    output wire [4:0] io_direction,
    output wire [4:0] io_outputs,
    input wire [4:0] io_inputs,

    // Limit to 3 address bytes, and 1 extra byte for whether it is
    // flash or RAM access.
    input  wire [address_size-1:0] target_address,
    output wire [31:0] fetched_value,

    input wire is_write,
    input wire [31:0] write_value,

    input wire start_request,
    output wire request_done,

    input wire clk,
    input wire rst_n
);

    wire is_mem = ~target_address[address_size-1];

    reg io_request_done;
    reg [7:0] io_value;

    // If the MSB is 0, then select the SPI flash/ram
    wire mem_start_request = start_request & is_mem;
    wire mem_request_done;

    wire [31:0] mem_fetched_value;

    assign request_done = is_mem ? mem_request_done : io_request_done;
    assign fetched_value = is_mem ? mem_fetched_value : {24'd0, io_value};

    mem_external #(.address_size(address_size)) mem1(
        .miso(miso),
        .sclk(sclk),
        .mosi(mosi),

        .cs1(cs1),
        .cs2(cs2),

        .num_bytes(num_bytes),
        .target_address(target_address),
        .fetched_value (mem_fetched_value),

        .is_write(is_write),
        .write_value(write_value),

        .start_request(mem_start_request),
        .request_done(mem_request_done),

        .clk(clk)
    );

    reg [3:0] outputs_bits;     // output only pins
    reg [5:0] input_bits;       // input only pins

    reg [4:0] io_direction_bits;    // io pins direction
    reg [4:0] io_inputs_bits;       // io pins input value
    reg [4:0] io_outputs_bits;      // io pins output value

    always @ (posedge clk) begin
        if (~rst_n) begin
            outputs_bits <= 0;
            io_request_done <= 0;
            input_bits <= 0;

            io_inputs_bits <= 0;
            io_outputs_bits <= 0;
            io_direction_bits <= 0;

        end else begin
            if (start_request) begin
                if (~io_request_done) begin

                    if (is_write) begin
                        case (target_address[7:0])
                            0: outputs_bits <= write_value[3:0];
                            2: io_direction_bits <= write_value[4:0];
                            4: io_outputs_bits <= write_value[4:0];
                            default: ;
                        endcase
                    end else begin
                        case (target_address[7:0])
                            0: io_value <= {4'd0, outputs_bits};
                            1: io_value <= {2'd0, input_bits};
                            2: io_value <= {3'd0, io_direction_bits};
                            3: io_value <= {3'd0, io_inputs_bits};
                            4: io_value <= {3'd0, io_outputs_bits};
                            default: ;
                        endcase
                    end
                    io_request_done <= 1;
                end
            end else begin
                io_request_done <= 0;
            end

            // always update the input bits
            input_bits <= inputs;
            io_inputs_bits <= ~io_direction_bits & io_inputs;
        end
    end

    assign outputs = outputs_bits;
    assign io_direction = io_direction_bits;
    assign io_outputs = io_outputs_bits;

endmodule
