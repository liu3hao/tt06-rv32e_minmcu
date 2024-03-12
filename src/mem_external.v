/*
 * Copyright (c) 2023 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

localparam STATE_START = 0;
localparam STATE_COMMAND_RUN = 1;
localparam STATE_COMMAND_DONE = 2;

localparam SPI_STATE_CS_CLK_IDLE =          2'd0;
localparam SPI_STATE_ENABLE_CS_DELAY_CLK =  2'd1;
localparam SPI_STATE_TRANSACTION =          2'd2;
localparam SPI_STATE_CLK_DELAY_DISABLE_CS = 2'd3;

localparam SPI_TX_BUFFER_SIZE = 64;
localparam SPI_RX_BUFFER_SIZE = 32;

localparam SPI_CMD_BYTES = 3'd4; //1 byte for code, 3 for address bytes

module mem_external (
    input  wire miso,  // Main spi signals
    output wire sclk,
    output wire mosi,

    output wire cs1,
    output wire cs2,

    input wire [2:0] num_bytes,

    input  wire [31:0] target_address,
    output wire [31:0] target_data,

    input wire is_write,
    input wire [31:0] write_value,

    input  wire start_request,    // Toggle from 0 to 1 to start fetch
    output wire request_done,

    input wire clk,   // system clock
    input wire rst_n  // global reset signal reset_n - low to reset
);

    // Determines the state of the mem fetch module.
    reg [1:0] state;

    // Max tx size is 8 bytes (4 for command, with 3 byte address
    // and 4 for word)
    reg [SPI_TX_BUFFER_SIZE - 1:0] spi_tx_buffer;

    // Only fetch up to 4 bytes for now
    reg [SPI_RX_BUFFER_SIZE - 1:0] spi_rx_buffer;

    reg [1:0] spi_state;  // SPI CLK and CS state

    wire clk1_cs;
    wire [7:0] address_msb;
    assign address_msb = target_address[31:24];

    // Depending on the target addres range, select the CS pin.
    assign cs1 = (address_msb == 8'h00) ? clk1_cs : 1;
    assign cs2 = (address_msb == 8'h01) ? clk1_cs : 1;

    // Maximum 4 bytes to write, 4 bytes to read
    reg [7:0] spi_clk_counter;

    always @(posedge clk) begin
        if (rst_n == 0) begin
            spi_rx_buffer <= 0;

        end else begin
            if (start_request == 1) begin
                if (state == STATE_START) begin
                    spi_rx_buffer <= 0;

                end else if (state == STATE_COMMAND_RUN && spi_state == SPI_STATE_TRANSACTION) begin
                    // Sample MISO on the very first clock edge too
                    spi_rx_buffer <= (spi_rx_buffer << 1) | {31'b0, miso};
                end
            end
        end
    end

    always @(negedge clk) begin
        if (rst_n == 0 || start_request == 0) begin
            state <= STATE_START;
            spi_state <= SPI_STATE_CS_CLK_IDLE;

            spi_tx_buffer <= 0;  // Clear buffers
            spi_clk_counter <= 0;

        end else if (start_request == 1) begin

            if (state == STATE_START) begin
                // Use 3 byte address mode for now
                state <= STATE_COMMAND_RUN;
                spi_state <= SPI_STATE_ENABLE_CS_DELAY_CLK;

                // Prepare the tx buffer, the MSB is transmitted first
                // If write_value is specified, then it needs to be transformed
                // for little-endian
                spi_tx_buffer <= {
                    is_write ? 8'h02 : 8'h03,
                    target_address[23:0],
                    is_write ? {write_value[7:0], write_value[15:8],
                        write_value[23:16], write_value[31:24]} : 32'd0
                };

                spi_clk_counter <= 0;

            end else if (state == STATE_COMMAND_RUN) begin
                if (spi_state == SPI_STATE_ENABLE_CS_DELAY_CLK) begin
                    spi_state <= SPI_STATE_TRANSACTION;

                end else if (spi_state == SPI_STATE_TRANSACTION) begin
                    // Shift out the bits on the falling edge of the clock.
                    spi_tx_buffer   <= (spi_tx_buffer << 1);
                    spi_clk_counter <= spi_clk_counter + 1;

                    if (spi_clk_counter + 1  >= ({5'd0, SPI_CMD_BYTES} + {5'd0, num_bytes}) << 3) begin
                        state <= STATE_COMMAND_DONE;
                        spi_state <= SPI_STATE_CS_CLK_IDLE;
                    end
                end
            end
        end
    end

    // MSB is transmitted first, need to check if high impedance state is needed
    assign mosi = clk1_cs == 0 ? spi_tx_buffer[SPI_TX_BUFFER_SIZE-1] : 0;

    assign request_done = (start_request == 1 && state == STATE_COMMAND_DONE);

    // SPI data is lowest byte address first (little-endian), so need to
    // transform the bytes
    assign target_data = request_done ?
                            {spi_rx_buffer[7:0],   spi_rx_buffer[15:8],
                             spi_rx_buffer[23:16], spi_rx_buffer[31:24]} : 0;

    assign sclk = (spi_state == SPI_STATE_TRANSACTION) ? clk : 0;

    // Set CS high, only in if in idle state
    assign clk1_cs = spi_state == SPI_STATE_CS_CLK_IDLE;

endmodule

module spi_clk(
    input wire [1:0] spi_clk_state,
    input wire clk,
    output wire[1:0] cs_delay
);

    // Controls amount of delay between chip select and clk, both at the
    // start and end of transactions
    reg [1:0] _cs_delay;

    always @(posedge clk) begin
        case (spi_clk_state)
            SPI_STATE_CS_CLK_IDLE, SPI_STATE_TRANSACTION: begin
                _cs_delay <= 0;
            end
            SPI_STATE_ENABLE_CS_DELAY_CLK, SPI_STATE_CLK_DELAY_DISABLE_CS: begin
                _cs_delay <= _cs_delay + 1;
            end
            default: ;
        endcase
    end

    assign cs_delay = _cs_delay;

endmodule
