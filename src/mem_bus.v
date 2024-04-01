
module mem_bus #(
        parameter address_size = 16 + 2
    )(
    input  wire miso,  // Main spi signals
    output wire sclk,
    output wire mosi,

    output wire cs1,    // CS for flash memory
    output wire cs2,    // CS for RAM

    input wire [2:0] num_bytes,

    input wire [4:0] inputs,
    output reg [3:0] outputs,

    output wire [4:0] io_direction,
    output wire [4:0] io_outputs,
    input wire [4:0] io_inputs,

    output wire uart_tx,
    input wire uart_rx,

    // Limit to 3 address bytes, and 1 extra byte for whether it is
    // flash or RAM access.
    input  wire [address_size-1:0] target_address,
    output wire [31:0] fetched_value,

    input wire is_write,
    input wire [31:0] write_value,

    input wire start_request,
    output wire request_done,

    input wire clk,
    input wire rst_n
);
    wire is_mem = ~target_address[address_size-1];

    reg io_request_done;
    reg [7:0] io_value;

    // If the MSB is 0, then select the SPI flash/ram
    wire mem_start_request = (is_spi_peripheral & spi_peripheral_start_request)
                             | (start_request & is_mem);
    wire mem_request_done;

    wire [31:0] mem_fetched_value;

    assign request_done = is_mem ? mem_request_done : io_request_done;
    assign fetched_value = is_mem ? mem_fetched_value : {24'd0, io_value};

    wire spi_in_transaction;
    reg is_spi_peripheral;
    reg spi_peripheral_start_request;
    reg [7:0] spi_peripheral_tx_bytes;
    reg [7:0] spi_peripheral_rx_bytes;
    reg [3:0] spi_cs_bits;
    reg spi_op_done;

    reg [7:0] uart_tx_byte;
    reg uart_start_tx;
    wire uart_tx_done;
    reg uart_status_bits_hold;

    reg [7:0] uart_rx_byte;
    reg uart_rx_available;
    reg uart_rx_clear;

    spi_controller #(.address_size(address_size)) spi_controller1 (
        .miso(miso),
        .sclk(sclk),
        .mosi(mosi),

        .in_transaction(spi_in_transaction),

        .num_bytes(num_bytes),

        .is_peripheral(is_spi_peripheral),
        .peripheral_tx_bytes(spi_peripheral_tx_bytes),

        .target_address(target_address),
        .fetched_value (mem_fetched_value),

        .is_write(is_write),
        .write_value(write_value),

        .start_request(mem_start_request),
        .request_done(mem_request_done),

        .clk(clk)
    );

    uart uart0 (
        .start_tx(uart_start_tx),
        .tx_value(uart_tx_byte),

        .tx_done(uart_tx_done),
        .tx(uart_tx),

        .rx_available(uart_rx_available),
        .rx_value(uart_rx_byte),
        .rx_clear(uart_rx_clear),
        .rx(uart_rx),

        .rst_n(rst_n),
        .clk(clk)
    );

    reg [3:0] outputs_bits;     // output only pins
    reg [4:0] input_bits;       // input only pins

    reg [4:0] io_direction_bits;    // io pins direction
    reg [4:0] io_inputs_bits;       // io pins input value
    reg [4:0] io_outputs_bits;      // io pins output value

    reg [2:0] state;

    localparam STATE_PARSE =    3'b001;
    localparam STATE_PENDING =  3'b010;
    localparam STATE_DONE =     3'b100;

    always @ (posedge clk) begin
        if (~rst_n) begin
            outputs_bits <= 0;
            spi_cs_bits <= 0;
            io_request_done <= 0;
            input_bits <= 0;

            io_inputs_bits <= 0;
            io_outputs_bits <= 0;
            io_direction_bits <= 0;

            is_spi_peripheral <= 0;
            spi_peripheral_tx_bytes <= 0;
            spi_peripheral_start_request <= 0;
            spi_op_done <= 0;

            uart_start_tx <= 0;
            uart_status_bits_hold <= 0;
            uart_tx_byte <= 0;

            uart_rx_clear <= 0;

            state <= STATE_PARSE;

        end else begin
            if (start_request) begin

                case(state)
                    STATE_PARSE: begin
                        if (is_write) begin
                            case (target_address[7:0])
                                8'h0: outputs_bits <= write_value[3:0];
                                8'h2: io_direction_bits <= write_value[4:0];
                                8'h4: io_outputs_bits <= io_direction_bits & write_value[4:0];
                                8'h5: begin
                                    spi_peripheral_start_request <= 0;
                                    is_spi_peripheral <= write_value[0];
                                    spi_cs_bits <= write_value[4:1];
                                    spi_op_done <= 0;
                                end
                                8'h8: spi_peripheral_tx_bytes <= write_value[7:0];
                                8'h10: begin
                                    if (uart_start_tx == 0 && write_value[0]) begin
                                        uart_start_tx <= 1;
                                        uart_status_bits_hold <= 0;
                                    end

                                    // clear rx available bit
                                    uart_rx_clear <= write_value[1];

                                end
                                8'h14: uart_tx_byte <= write_value[7:0];
                                default: ;
                            endcase
                        end else begin
                            case (target_address[7:0])
                                8'h0:  io_value <= {4'd0, outputs_bits};
                                8'h1:  io_value <= {3'd0, input_bits};
                                8'h2:  io_value <= {3'd0, io_direction_bits};
                                8'h3:  io_value <= {3'd0, io_inputs_bits};
                                8'h4:  io_value <= {3'd0, io_outputs_bits};
                                8'h6:  io_value <= {7'd0, spi_op_done};
                                8'h8:  io_value <= spi_peripheral_tx_bytes;
                                8'hC:  io_value <= spi_peripheral_rx_bytes;
                                8'h10: io_value <= {7'd0, uart_start_tx};
                                8'h11: io_value <= {6'd0, uart_rx_available, uart_status_bits_hold};
                                8'h14: io_value <= uart_tx_byte;
                                8'h15: io_value <= uart_rx_byte;
                                default: ;
                            endcase
                        end

                        if (is_write && target_address[7:0] == 5 && write_value[0]) begin
                            state <= STATE_PENDING;
                        end else begin
                            // For all other registers, the io request is done
                            // in the same cycle
                            io_request_done <= 1;
                            state <= STATE_DONE;
                        end
                    end
                    STATE_PENDING: begin
                        if (is_write && target_address[7:0] == 5 && write_value[0]) begin
                            spi_peripheral_start_request <= 1;

                            if (mem_request_done) begin
                                spi_peripheral_rx_bytes <= mem_fetched_value[7:0];
                                io_request_done <= 1;
                                is_spi_peripheral <= 0;
                                state <= STATE_DONE;
                                spi_op_done <= 1;
                            end
                        end
                    end
                    STATE_DONE:;
                    default: ;
                endcase
            end else begin
                io_request_done <= 0;
                state <= STATE_PARSE;
            end

            // always update the input bits
            input_bits <= inputs;
            io_inputs_bits <= ~io_direction_bits & io_inputs;
        end

        if (uart_start_tx == 1 && uart_tx_done) begin
            uart_status_bits_hold <= 1;
            uart_start_tx <= 0; // reset the start tx bit, to prepare for next
        end
    end

    wire peripheral_cs = ~(~is_mem & is_spi_peripheral & spi_in_transaction);

    always @ (*) begin
        case (spi_cs_bits)
            4'b0001: outputs = (outputs_bits & 4'b1110) | {3'd0, peripheral_cs};
            4'b0010: outputs = (outputs_bits & 4'b1101) | ({3'd0, peripheral_cs} << 1);
            4'b0100: outputs = (outputs_bits & 4'b1011) | ({3'd0, peripheral_cs} << 2);
            4'b1000: outputs = (outputs_bits & 4'b0111) | ({3'd0, peripheral_cs} << 3);
            default: outputs = outputs_bits;
        endcase
    end

    assign io_direction = io_direction_bits;
    assign io_outputs = io_outputs_bits;

    assign cs1 = ~(is_mem & spi_in_transaction & ~target_address[address_size-2]);
    assign cs2 = ~(is_mem & spi_in_transaction & target_address[address_size-2]);

endmodule
