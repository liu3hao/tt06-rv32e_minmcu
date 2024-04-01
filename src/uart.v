
module uart (
    input wire start_tx,
    input [7:0] tx_value,
    output wire tx_done,
    output wire tx,

    output reg rx_available,
    input wire rx,
    output reg [7:0] rx_value,
    input wire rx_clear,

    input wire rst_n,
    input wire clk
);

    localparam STATE_UART_IDLE =         5'b00001;
    localparam STATE_UART_TX =           5'b00010;
    localparam STATE_UART_RX =           5'b00100;
    localparam STATE_UART_TX_DONE =      5'b01000;
    localparam STATE_UART_RX_AVAILABLE = 5'b10000;


    reg [4:0] state;
    reg [10:0] tx_output_buffer;
    reg [8:0] rx_input_buffer;

    reg inner_tx_done;
    reg [7:0] counter;

    reg uart_tx_clk;
    reg [31:0] clk_counter;

    reg uart_sample_clk;
    reg prev_uart_clk;


    always @ (posedge clk) begin
        if (rst_n == 0) begin
            state <= STATE_UART_IDLE;
            tx_output_buffer <= 0;
            inner_tx_done <= 0;
            counter <= 0;

            prev_uart_clk <= 0;
            uart_sample_clk <= 0;

            uart_tx_clk <= 1;
            clk_counter <= 0;

            rx_available <= 0;
            rx_input_buffer <= 0;
            rx_value <= 0;

        end else begin

            prev_uart_clk <= uart_tx_clk;

            case(state)
                STATE_UART_IDLE: begin
                   if(start_tx == 1) begin
                        state <= STATE_UART_TX;
                        counter <= 0;
                        tx_output_buffer <= {1'b1, tx_value, 2'b01};
                    end else if (rx == 0 && rx_clear == 0) begin
                        // Low was detected on the rx and rx_clear bit is set to 0
                        counter <= 0;
                        state <= STATE_UART_RX;
                    end
                end
                STATE_UART_TX: begin
                    clk_counter <= clk_counter + 1;

                    // Baud rate = 115200, which is about a counter value of 434 per period.
                    // So the rate to toggle the clock is 1/2 of this.
                    if (clk_counter == 217) begin
                        uart_tx_clk <= ~uart_tx_clk;
                        clk_counter <= 0;
                    end

                    // TODO: clean this part up
                    if (start_tx == 1 && inner_tx_done == 0 && (prev_uart_clk == 0 && uart_tx_clk == 1)) begin
                        tx_output_buffer <= (tx_output_buffer >> 1);
                        counter <= counter + 1;

                        if (counter >= 10) begin
                            state <= STATE_UART_TX_DONE;
                            inner_tx_done <= 1;
                        end
                    end
                end

                STATE_UART_RX: begin
                    // 1 uart period is 434 counts. So sample rate is 434/16 which is around 27
                    // counts.
                    clk_counter <= clk_counter + 1;

                    if ((counter == 0 && clk_counter == 217) || (counter != 0 && clk_counter == 434)) begin
                        rx_input_buffer <= {rx, 8'd0} | (rx_input_buffer >> 1);
                        clk_counter <= 0;
                        counter <= counter + 1;

                        if (counter >= 9) begin
                            state <= STATE_UART_RX_AVAILABLE;
                        end
                    end
                end

                STATE_UART_TX_DONE: begin
                    if (start_tx == 0) begin
                        state <= STATE_UART_IDLE;
                        inner_tx_done <= 0;
                    end
                end

                STATE_UART_RX_AVAILABLE: begin
                    rx_value <= rx_input_buffer[7:0];
                    rx_available <= 1;

                    if (rx_clear == 1) begin
                        rx_available <= 0;
                        state <= STATE_UART_IDLE;
                    end
                end

                default: ;
            endcase
        end
    end

    assign tx = (state == STATE_UART_IDLE || state == STATE_UART_TX_DONE) ? 1 : tx_output_buffer[0];
    assign tx_done = inner_tx_done;

endmodule
