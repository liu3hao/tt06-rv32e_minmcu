/*
 * Copyright (c) 2023 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`define default_netname none

module tt_um_rv32e_cpu (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs

    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    
    // input wire miso,
    // output wire sclk,
    // output wire mosi,
    // output wire cs,
    
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

    always @ (posedge clk) begin
        if (rst_n == 0) begin
            state <= STATE_FETCH_DATA;
            prog_counter <= 0;

        end else begin
            if (state == STATE_FETCH_DATA) begin
                if (fetch_done == 0) begin
                    fetch_address <= prog_counter[23:0];
                    start_fetch <= 1;
                end else begin
                    // Got something!
                    state <= STATE_PARSE_DATA;
                end
            end else if (state == STATE_PARSE_DATA) begin
                // For now, skip back to fetch more data
                start_fetch <= 0;
                prog_counter <= prog_counter + 4;
                state <= STATE_FETCH_DATA;
            end
        end
    end

endmodule
