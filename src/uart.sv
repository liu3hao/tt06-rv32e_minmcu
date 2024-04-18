
module uart (
    input wire start_tx,
    input [7:0] tx_value,
    output wire tx_done,
    output wire tx,

    output wire rx_available,
    input wire rx,
    output wire [7:0] rx_value,
    input wire rx_clear,

    input wire [11:0] uart_baud_counter,

    input wire clear_to_send,
    output wire request_to_send,

    // output wire tmp_rx_uart_clk,
    // output wire tmp_tx_uart_clk,

    input wire rst_n,
    input wire clk
);
    localparam STATE_IDLE =     3'b001;
    localparam STATE_ACTIVE =   3'b010;
    localparam STATE_DONE =     3'b100;

    reg [2:0] rx_state;
    reg [2:0] tx_state;

    reg [9:0] tx_buffer;
    reg [8:0] rx_buffer;

    reg [3:0] tx_bit_counter;
    reg [3:0] rx_bit_counter;

    reg tx_uart_clk;
    reg rx_uart_clk;

    reg [11:0] tx_clk_counter;
    reg [11:0] rx_clk_counter;

    reg tx_prev_uart_clk;
    reg rx_prev_uart_clk;

    // assign tmp_tx_uart_clk = tx_uart_clk;
    // assign tmp_rx_uart_clk = rx_uart_clk;

    always @ (posedge clk) begin
        if (rst_n == 0) begin
            tx_state <= STATE_IDLE;
            rx_state <= STATE_IDLE;

            tx_bit_counter <= 0;
            rx_bit_counter <= 0;

            tx_prev_uart_clk <= 0;
            rx_prev_uart_clk <= 0;

            tx_uart_clk <= 0;
            rx_uart_clk <= 0;

            tx_clk_counter <= 0;
            rx_clk_counter <= 0;

            tx_buffer <= 0;
            rx_buffer <= 0;
            
        end else begin
            case (tx_state)
                STATE_IDLE: begin
                    if (start_tx && ~clear_to_send) begin
                        tx_state <= STATE_ACTIVE;
                        tx_buffer <= {1'b1, tx_value, 1'b0}; // Shifted towards bit 0
                        tx_bit_counter <= 0;
                        tx_uart_clk <= 0;
                        tx_prev_uart_clk <= 0;
                    end
                end
                STATE_ACTIVE: begin
                    tx_prev_uart_clk <= tx_uart_clk;

                    if (tx_clk_counter == uart_baud_counter) begin
                        tx_uart_clk <= ~tx_uart_clk;
                        tx_clk_counter <= 0;
                    end else begin
                        tx_clk_counter <= tx_clk_counter + 1;
                    end

                    // Only when there is change of the uart clk state, going from low to high
                    if (tx_prev_uart_clk == 1 && tx_uart_clk == 0) begin
                        tx_buffer <= (tx_buffer >> 1);
                        tx_bit_counter <= tx_bit_counter + 1;

                        if (tx_bit_counter == 9) begin
                            tx_state <= STATE_DONE;
                        end
                    end
                end
                STATE_DONE: begin
                    if (start_tx == 0) begin
                        tx_state <= STATE_IDLE;
                    end
                end
                default:;
            endcase

            case (rx_state)
                STATE_IDLE: begin
                    if (rx == 0 && rx_clear == 0) begin
                        rx_state <= STATE_ACTIVE;
                        rx_bit_counter <= 0;
                        rx_uart_clk <= 0;
                        rx_prev_uart_clk <= 0;
                    end
                end
                STATE_ACTIVE : begin
                    rx_prev_uart_clk <= rx_uart_clk;

                    if (rx_clk_counter == uart_baud_counter) begin
                        rx_uart_clk <= ~rx_uart_clk;
                        rx_clk_counter <= 0;
                    end else begin
                        rx_clk_counter <= rx_clk_counter + 1;
                    end

                    if (rx_prev_uart_clk == 0 && rx_uart_clk == 1) begin
                        rx_buffer <= {rx, 8'd0} | (rx_buffer >> 1);
                        rx_bit_counter <= rx_bit_counter + 1;

                        if (rx_bit_counter == 9) begin
                            rx_state <= STATE_DONE;
                        end
                    end
                end
                STATE_DONE: begin
                    if (rx_clear == 1) begin
                        rx_state <= STATE_IDLE;
                    end
                end
                default: ;
            endcase
        end
    end

    assign tx =             (tx_state == STATE_ACTIVE) ? tx_buffer[0] : 1;
    assign tx_done =        (tx_state == STATE_DONE);

    assign rx_value =       rx_buffer[7:0];
    assign rx_available =   (rx_state == STATE_DONE);

    // Set req to send to high, only if in idle and there is no rx available
    assign request_to_send = rx_available;

endmodule
