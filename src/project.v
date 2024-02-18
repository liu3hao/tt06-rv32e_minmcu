/*
 * Copyright (c) 2023 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`define default_netname none

module tt_um_example (
    input  logic [7:0] ui_in,    // Dedicated inputs
    output logic [7:0] uo_out,   // Dedicated outputs
    input  logic [7:0] uio_in,   // IOs: Input path
    output logic [7:0] uio_out,  // IOs: Output path
    output logic [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  logic       ena,      // will go high when the design is enabled
    input  logic       clk,      // clock
    input  logic       rst_n     // reset_n - low to reset
);

    logic [7:0] counter;

    always_ff @ (posedge clk, posedge rst_n) begin
        if (rst_n == 0) counter <= 0;
        else counter <= counter + 1;
    end

    assign uo_out = counter; 
    assign uio_out = 8'b10101010;
    assign uio_oe =  8'b10101010;

endmodule
