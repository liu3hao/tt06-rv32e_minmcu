
module uart_tx (
    input wire start_tx,
    input [7:0] tx_value,

    output wire tx_done,
    output wire tx,

    input wire rst_n,
    input wire clk
);

    localparam STATE_UART_IDLE =    3'b001;
    localparam STATE_UART_TX =      3'b010;
    localparam STATE_UART_TX_DONE = 3'b100;

    reg [2:0] state;
    reg [10:0] output_buffer;
    reg inner_tx_done;
    reg [7:0] counter;

    reg uart_clk;
    reg [31:0] clk_counter;

    reg prev_uart_clk;

    always@ (posedge clk) begin
        if (rst_n == 0) begin
            uart_clk <= 1;
            clk_counter <= 0;
        end else begin
            if (state == STATE_UART_TX) begin
                clk_counter <= clk_counter + 1;
                if (clk_counter == 2604) begin
                    uart_clk <= ~uart_clk;
                    clk_counter <= 0;
                end
            end
        end
    end

    always @ (posedge clk) begin
        if (rst_n == 0) begin
            state <= STATE_UART_IDLE;
            output_buffer <= 0;
            inner_tx_done <= 0;
            counter <= 0;

            prev_uart_clk <= 0;

        end else begin

            prev_uart_clk <= uart_clk;

            if (state == STATE_UART_IDLE && start_tx == 1) begin
                state <= STATE_UART_TX;
                counter <= 0;
                output_buffer <= {1'b1, tx_value, 2'b01};

            end else if (state == STATE_UART_TX) begin
                if (start_tx == 1 && inner_tx_done == 0 && (prev_uart_clk == 0 && uart_clk == 1)) begin
                    output_buffer <= (output_buffer >> 1);
                    counter <= counter + 1;

                    if (counter >= 10) begin
                        state <= STATE_UART_TX_DONE;
                        inner_tx_done <= 1;
                    end
                end
            end else if (state == STATE_UART_TX_DONE) begin
                if (start_tx == 0) begin
                    state <= STATE_UART_IDLE;
                    inner_tx_done <= 0;
                end
            end
        end
    end

    assign tx = (state == STATE_UART_IDLE || state == STATE_UART_TX_DONE) ? 1 : output_buffer[0];
    assign tx_done = inner_tx_done;

endmodule
