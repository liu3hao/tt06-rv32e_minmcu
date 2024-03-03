/*
 * Copyright (c) 2023 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

localparam STATE_START = 0;
localparam STATE_READ_ADDR = 1;
localparam STATE_READ_ADDR_DONE = 2;

localparam SPI_STATE_CS_CLK_IDLE = 0;
localparam SPI_STATE_ENABLE_CS_DELAY_CLK = 1;
localparam SPI_STATE_CLK_DELAY_DISABLE_CS = 2;

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
    spi_clk clk1 (
        .spi_clk_state(spi_state),
        .refclk(clk),
        .outclk(sclk),
        .cs(clk1_cs)
    );

    // Depending on the target addres range, select the CS pin.
    assign cs1 = (target_address[31:24] == 8'h00) ? clk1_cs : 1;
    assign cs2 = (target_address[31:24] == 8'h01) ? clk1_cs : 1;

    // Maximum 4 bytes to write, 4 bytes to read
    reg [7:0] spi_clk_counter;

    reg prev_sclk;

    always @(posedge clk) begin
        if (rst_n == 0) begin
            state <= STATE_START;
            spi_state <= SPI_STATE_CS_CLK_IDLE;
            spi_tx_buffer <= 0; // Clear buffers
            spi_rx_buffer <= 0;
            prev_sclk <= 0;

        end else begin
            if (start_request == 1) begin
                if (state == STATE_START) begin
                    state <= STATE_READ_ADDR;
                    spi_clk_counter <= 0;
                    spi_state <= SPI_STATE_ENABLE_CS_DELAY_CLK;

                    // Use 3 byte address mode for now

                    // Prepare the tx buffer, the MSB is transmitted first
                    spi_tx_buffer <= {
                        is_write ? 8'h02: 8'h03,
                        target_address[23:0],
                        is_write ? write_value : 32'd0
                    };

                end else if (state == STATE_READ_ADDR) begin

                    prev_sclk <= sclk;

                    if (sclk == 1 && prev_sclk == 0) begin
                        // Read MISO on the rising edge of the clock
                        spi_rx_buffer <= (spi_rx_buffer << 1) | {31'b0, miso};

                    end else if (sclk == 0 && prev_sclk == 1) begin
                        // Shift out the bits on the falling edge of the clock.
                        spi_tx_buffer   <= (spi_tx_buffer << 1);
                        spi_clk_counter <= spi_clk_counter + 1;

                        if (spi_clk_counter + 1 >= ({5'd0, SPI_CMD_BYTES} + {5'd0, num_bytes}) * 8) begin
                            spi_state <= SPI_STATE_CLK_DELAY_DISABLE_CS;
                        end
                    end

                    // If the CS is back to 1, then change the state to show
                    // that the read is completed.
                    if (spi_state == SPI_STATE_CLK_DELAY_DISABLE_CS && clk1_cs == 1) begin
                        state <= STATE_READ_ADDR_DONE;
                        spi_state <= SPI_STATE_CS_CLK_IDLE;
                    end
                end
            end else if (start_request == 0) begin
                // Stop everything and go back to the initial state
                state <= STATE_START;
                spi_state <= SPI_STATE_CS_CLK_IDLE;
                prev_sclk <= 0;
            end
        end
    end

    // MSB is transmitted first, need to check if high impedance state is needed
    assign mosi = (state == STATE_READ_ADDR && clk1_cs == 0) ?
                    spi_tx_buffer[SPI_TX_BUFFER_SIZE-1] : 0;

    assign request_done = start_request && state == STATE_READ_ADDR_DONE;
    assign target_data = (state == STATE_READ_ADDR_DONE && start_request == 1)
                            ? spi_rx_buffer : 0;

endmodule

module spi_clk #(
    parameter size = 2
) (
    input wire [1:0] spi_clk_state,
    input wire refclk,
    output wire outclk,
    output wire cs
);
    reg [size-1:0] counter;
    reg [3:0] cs_delay;

    always @(posedge refclk) begin

        if (spi_clk_state == SPI_STATE_CS_CLK_IDLE) begin
            counter  <= 0;
            cs_delay <= 0;

        end else if (spi_clk_state == SPI_STATE_ENABLE_CS_DELAY_CLK) begin
            if (cs_delay > 4) begin
                counter <= counter + 1;
            end else begin
                cs_delay <= cs_delay + 1;
            end
        end else if (spi_clk_state == SPI_STATE_CLK_DELAY_DISABLE_CS) begin
            if (cs_delay < 8) begin
                cs_delay <= cs_delay + 1;
            end
        end
    end

    assign outclk = (spi_clk_state == SPI_STATE_ENABLE_CS_DELAY_CLK
                        && cs_delay > 4 && !counter[size-1]);

    assign cs = !(spi_clk_state == SPI_STATE_ENABLE_CS_DELAY_CLK ||
                (spi_clk_state == SPI_STATE_CLK_DELAY_DISABLE_CS && cs_delay < 8));

endmodule
