/*
 * Copyright (c) 2023 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`define default_netname none

localparam int STATE_START = 0;
localparam int STATE_READ_ADDR = 1;
localparam int STATE_READ_ADDR_DONE = 2;


localparam int SPI_STATE_IDLE = 0;
localparam int SPI_STATE_ENABLE_CS_DELAY_CLK = 1;
localparam int SPI_STATE_CLK_DELAY_DISABLE_CS = 2;

localparam int SPI_TX_BUFFER_SIZE = 32;

module tt_um_example (
    // input  wire [7:0] ui_in,    // Dedicated inputs
    // output wire [7:0] uo_out,   // Dedicated outputs

    // input  wire [7:0] uio_in,   // IOs: Input path
    // output wire [7:0] uio_out,  // IOs: Output path
    // output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    
    input wire miso,
    output wire sclk,
    output wire mosi,
    output wire cs,
    
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
    
    reg [2:0] state;

    reg [SPI_TX_BUFFER_SIZE - 1:0] spi_tx_buffer;
    reg [SPI_TX_BUFFER_SIZE - 1:0] spi_rx_buffer;

    reg [1:0] spi_state;

    spi_clk clk1 (spi_state, clk, sclk, cs);

    reg [7:0] spi_clk_counter;

    always @ (posedge clk) begin
        if (rst_n == 0) begin
            state <= STATE_START;
            spi_state <= SPI_STATE_IDLE;

            // Fill up tx buffer with some bytes first
            spi_tx_buffer <= {8'h88, 8'h12, 8'h34, 8'h56};
            spi_rx_buffer <= 0; // clear the SPI Rx buffer

        end else begin
            if (state == STATE_START) begin
                state <= STATE_READ_ADDR;
                spi_clk_counter <= 0;
                spi_state <= SPI_STATE_ENABLE_CS_DELAY_CLK;
            end
        end
    end

    always @ (posedge sclk) begin
        if (state == STATE_READ_ADDR) begin
            // spi_tx_buffer <= (spi_tx_buffer << 1);
            // Read MISO on the rising edge of the clock
            spi_rx_buffer <= (spi_rx_buffer << 1) | miso;
        end
    end

    always @ (negedge sclk) begin
        if (state == STATE_READ_ADDR) begin
            // Shift out the bits on the falling edge of the clock.
            spi_tx_buffer <= (spi_tx_buffer << 1);

            spi_clk_counter <= spi_clk_counter + 1;
            if (spi_clk_counter + 1 >= 64) begin
                spi_state <= SPI_STATE_CLK_DELAY_DISABLE_CS;
            end
        end
    end

    // the MSB is transmitted first.
    assign mosi = spi_tx_buffer[SPI_TX_BUFFER_SIZE-1];

endmodule

module spi_clk #(parameter int size=4) (
    input wire[1:0] spi_clk_state,
    input wire refclk,
    output wire outclk,
    output wire cs
);
    reg [size-1:0] counter;
    reg [3:0] cs_delay;

    always @ (posedge refclk) begin

        if (spi_clk_state == SPI_STATE_IDLE) begin
            counter <= 0;
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

endmodule;