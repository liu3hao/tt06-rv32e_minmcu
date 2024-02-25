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

localparam SPI_TX_BUFFER_SIZE = 32;

module mem_read (
    input  wire miso,  // Main spi signals
    output wire sclk,
    output wire mosi,
    output wire cs,

    input  wire [23:0] target_address,
    output wire [31:0] target_data,

    input  wire start_fetch,    // Toggle from 0 to 1 to start fetch
    output wire fetch_done,

    input wire clk,   // system clock
    input wire rst_n  // global reset signal reset_n - low to reset
);

    // Determines the state of the mem fetch module.
    reg [1:0] state;

    reg [SPI_TX_BUFFER_SIZE - 1:0] spi_tx_buffer;
    reg [SPI_TX_BUFFER_SIZE - 1:0] spi_rx_buffer;

    reg [1:0] spi_state;  // SPI CLK and CS state

    spi_clk clk1 (
        .spi_clk_state(spi_state),
        .refclk(clk),
        .outclk(sclk),
        .cs(cs)
    );

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
            if (start_fetch == 1) begin
                if (state == STATE_START) begin
                    state <= STATE_READ_ADDR;
                    spi_clk_counter <= 0;
                    spi_state <= SPI_STATE_ENABLE_CS_DELAY_CLK;
                    spi_tx_buffer <= {8'h03, target_address};

                end else if (state == STATE_READ_ADDR) begin

                    prev_sclk <= sclk;

                    if (sclk == 1 && prev_sclk == 0) begin
                        // Read MISO on the rising edge of the clock
                        spi_rx_buffer <= (spi_rx_buffer << 1) | {31'b0, miso};
                    end else if (sclk == 0 && prev_sclk == 1) begin
                        // Shift out the bits on the falling edge of the clock.
                        spi_tx_buffer   <= (spi_tx_buffer << 1);

                        spi_clk_counter <= spi_clk_counter + 1;
                        if (spi_clk_counter + 1 >= 64) begin
                            spi_state <= SPI_STATE_CLK_DELAY_DISABLE_CS;
                        end
                    end

                    // If the CS is back to 1, then change the state to show
                    // that the read is completed.
                    if (spi_state == SPI_STATE_CLK_DELAY_DISABLE_CS && cs == 1) begin
                        state <= STATE_READ_ADDR_DONE;
                        spi_state <= SPI_STATE_CS_CLK_IDLE;
                    end
                end
            end else if (start_fetch == 0) begin
                // Stop everything and go back to the initial state
                state <= STATE_START;
                spi_state <= SPI_STATE_CS_CLK_IDLE;
                prev_sclk <= 0;
            end
        end
    end

    // MSB is transmitted first, need to check if high impedance state is needed
    assign mosi = (state == STATE_READ_ADDR && cs == 0) ?
                    spi_tx_buffer[SPI_TX_BUFFER_SIZE-1] : 0;

    assign fetch_done = start_fetch && state == STATE_READ_ADDR_DONE;
    assign target_data = (state == STATE_READ_ADDR_DONE && start_fetch == 1)
                            ? spi_rx_buffer : 0;

endmodule

module spi_clk #(
    parameter int size = 2
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
