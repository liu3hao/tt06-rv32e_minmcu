
module uart (
    input wire start_tx,
    input [7:0] tx_value,
    output wire tx_done,
    output wire tx,

    output wire rx_available,
    input wire rx,
    output reg [7:0] rx_value,
    input wire rx_clear,

    input wire clear_to_send,
    output wire request_to_send,

    input wire rst_n,
    input wire clk
);

    localparam STATE_UART_IDLE =         5'b00001;
    localparam STATE_UART_TX =           5'b00010;
    localparam STATE_UART_RX =           5'b00100;
    localparam STATE_UART_TX_DONE =      5'b01000;
    localparam STATE_UART_RX_AVAILABLE = 5'b10000;

    // localparam UART_COUNTER_BAUD_115200 = 217;  // clock of 50MHz
    // localparam UART_COUNTER_BAUD_115200 = 208;  // clock of 48MHz
    // localparam UART_COUNTER_BAUD_115200 = 52;   // clock of 12MHz

    localparam UART_COUNTER_BAUD_9600 =   12'd1250;
    // localparam UART_COUNTER_BAUD_115200 = 12'd104;

    reg [4:0] state;
    reg [9:0] buffer;

    reg [3:0] counter;

    reg uart_tx_clk;
    reg [11:0] clk_counter;

    reg uart_sample_clk;
    reg prev_uart_clk;

    always @ (posedge clk) begin
        if (rst_n == 0) begin
            state <= STATE_UART_IDLE;
            buffer <= 0;
            counter <= 0;

            prev_uart_clk <= 0;
            uart_sample_clk <= 0;

            uart_tx_clk <= 1;
            clk_counter <= 0;

            rx_value <= 0;

        end else begin

            prev_uart_clk <= uart_tx_clk;

            if (state == STATE_UART_TX || state == STATE_UART_RX) begin
                if (clk_counter == UART_COUNTER_BAUD_9600) begin
                    uart_tx_clk <= ~uart_tx_clk;
                    clk_counter <= 0;
                end else begin
                    clk_counter <= clk_counter + 1;
                end
            end

            case(state)
                STATE_UART_IDLE: begin
                    counter <= 0;
                    uart_tx_clk <= 0;

                   if(start_tx & ~clear_to_send) begin
                        state <= STATE_UART_TX;
                        buffer <= {1'b1, tx_value, 1'b0}; // Shifted towards bit 0
                    end else if (rx == 0 && rx_clear == 0) begin
                        // Low was detected on the rx and rx_clear bit is set to 0
                        state <= STATE_UART_RX;
                    end
                end
                STATE_UART_TX: begin
                    // Baud rate = 115200, which is about a counter value of 434 per period.

                    // Only when there is change of the uart clk state, going from low to high
                    if (prev_uart_clk == 0 && uart_tx_clk == 1) begin
                        buffer <= (buffer >> 1);
                        counter <= counter + 1;

                        if (counter == 9) begin
                            state <= STATE_UART_TX_DONE;
                        end
                    end
                end

                STATE_UART_RX: begin
                    // 1 uart period is 434 counts.
                    if ((counter == 0 && prev_uart_clk == 0 && uart_tx_clk == 1) || (counter != 0 && prev_uart_clk == 1 && uart_tx_clk == 0)) begin
                        buffer <= {rx, 9'd0} | (buffer >> 1);
                        counter <= counter + 1;

                        if (counter == 8) begin
                            state <= STATE_UART_RX_AVAILABLE;
                        end
                    end
                end

                STATE_UART_TX_DONE: begin
                    if (start_tx == 0) begin
                        state <= STATE_UART_IDLE;
                    end
                end

                STATE_UART_RX_AVAILABLE: begin
                    rx_value <= buffer[9:2];
                    if (rx_clear == 1) begin
                        state <= STATE_UART_IDLE;
                    end
                end

                default: ;
            endcase
        end
    end

    assign tx = (state == STATE_UART_TX) ? buffer[0] : 1;
    assign tx_done = (state == STATE_UART_TX_DONE);
    assign rx_available = (state == STATE_UART_RX_AVAILABLE);

    // Set req to send to high, only if in idle and there is no rx available
    assign request_to_send = (state == STATE_UART_IDLE | state == STATE_UART_RX) & ~rx_available;

endmodule
