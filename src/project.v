/*
 * Copyright (c) 2023 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`define default_netname none

module tt_um_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs

    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // uio_in is used as the opcode command
    
    // set the bidir pins as all inputs
    assign uio_oe = 0;

    wire [3:0] opcode;

    wire[7:0] val1;
    wire[7:0] val2;
    reg [7:0] result;

    assign opcode = uio_in[7:4];

    assign val1 = ui_in[5:0];
    assign val2 = {ui_in[7:6], uio_in[3:0]};

    always@(*) begin
        if (opcode == 0) begin
            result = val1 + val2;
        end else if (opcode == 1) begin
            result = val1 - val2;
        end
    end
    
    assign uo_out = result;

endmodule
