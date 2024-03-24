
module mem_bus #(
        parameter address_size = 16 + 2
    )(
    input  wire miso,  // Main spi signals
    output wire sclk,
    output wire mosi,

    output wire cs1,
    output wire cs2,

    input wire [2:0] num_bytes,

    input wire [5:0] inputs,
    output wire [3:0] outputs,

    output wire [4:0] io_direction,
    output wire [4:0] io_outputs,
    input wire [4:0] io_inputs,

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
    wire mem_start_request = start_request & is_mem;
    wire mem_request_done;

    wire [31:0] mem_fetched_value;

    assign request_done = is_mem ? mem_request_done : io_request_done;
    assign fetched_value = is_mem ? mem_fetched_value : {24'd0, io_value};

    mem_external #(.address_size(address_size)) mem1(
        .miso(miso),
        .sclk(sclk),
        .mosi(mosi),

        .cs1(cs1),
        .cs2(cs2),

        .num_bytes(num_bytes),
        .target_address(target_address),
        .fetched_value (mem_fetched_value),

        .is_write(is_write),
        .write_value(write_value),

        .start_request(mem_start_request),
        .request_done(mem_request_done),

        .clk(clk)
    );

    reg [3:0] outputs_bits;     // output only pins
    reg [5:0] input_bits;       // input only pins

    reg [4:0] io_direction_bits;    // io pins direction
    reg [4:0] io_inputs_bits;       // io pins input value
    reg [4:0] io_outputs_bits;      // io pins output value

    always @ (posedge clk) begin
        if (~rst_n) begin
            outputs_bits <= 0;
            io_request_done <= 0;
            input_bits <= 0;

            io_inputs_bits <= 0;
            io_outputs_bits <= 0;
            io_direction_bits <= 0;

        end else begin
            if (start_request) begin
                if (~io_request_done) begin

                    if (is_write) begin
                        case (target_address[7:0])
                            0: outputs_bits <= write_value[3:0];
                            2: io_direction_bits <= write_value[4:0];
                            4: io_outputs_bits <= write_value[4:0];
                            default: ;
                        endcase
                    end else begin
                        case (target_address[7:0])
                            0: io_value <= {4'd0, outputs_bits};
                            1: io_value <= {2'd0, input_bits};
                            2: io_value <= {3'd0, io_direction_bits};
                            3: io_value <= {3'd0, io_inputs_bits};
                            4: io_value <= {3'd0, io_outputs_bits};
                            default: ;
                        endcase
                    end
                    io_request_done <= 1;
                end
            end else begin
                io_request_done <= 0;
            end

            // always update the input bits
            input_bits <= inputs;
            io_inputs_bits <= ~io_direction_bits & io_inputs;
        end
    end

    assign outputs = outputs_bits;
    assign io_direction = io_direction_bits;
    assign io_outputs = io_outputs_bits;

endmodule
