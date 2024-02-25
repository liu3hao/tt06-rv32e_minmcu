module mem_controller #(parameter size=32) (
    input  wire miso,  // Main spi signals
    output wire sclk,
    output wire mosi,
    output wire cs,

    input  wire [23:0] target_address,
    output wire [31:0] fetched_data,

    input  wire start_fetch,
    output wire fetch_done,

    input wire clk,   // system clock
    input wire rst_n  // global reset signal reset_n - low to reset
);

    mem_read mem_read1 (
        .miso(miso),
        .sclk(sclk),
        .mosi(mosi),
        .cs  (cs),

        .target_address(target_address),
        .fetched_data  (fetched_data),

        .start_fetch(start_fetch),
        .fetch_done (fetch_done),

        .clk  (clk),
        .rst_n(rst_n)
    );

    wire icache_valid;
    wire [size-1:0] icache_data;

    wire icache_write_data;

    cache instruction_cache1 (
        .address({8'b0, target_address}),

        .write_data (icache_write_data),
        .write_value(fetched_data),

        .valid(icache_valid),
        .data (icache_data),

        .clk  (clk),
        .rst_n(rst_n)
    );

    assign icache_write_data = (rst_n == 1 && fetch_done == 1 && icache_valid ==0);

endmodule


module cache #(
    parameter size = 32
) (
    input wire [size-1:0] address,

    input wire write_data,
    input wire [size-1:0] write_value,

    output wire valid,
    output wire [size-1:0] data,

    input wire clk,   // system clock
    input wire rst_n  // global reset signal reset_n - low to reset
);

    localparam block_bits = 3;
    localparam ignored_bits = 2; // 2 LSB can be ignored because they
                                 // are within the word.

    localparam tag_size = size-block_bits-ignored_bits;

    reg [(size * 8 - 1):0] inner_data;
    reg [(tag_size * 8 - 1): 0] inner_tags;
    reg [7:0] inner_valid;

    wire [ignored_bits-1:0] block_index;
    assign block_index = address[block_bits + ignored_bits:ignored_bits]; // last 2 bits can be ignored.

    wire [tag_size-1:0] tag_compare;
    assign tag_compare = address[size-1:(block_bits + ignored_bits)];

    always @(posedge clk) begin
        if (rst_n == 0) begin
            inner_data  <= 0;
            inner_valid <= 0;
        end else begin
            if (write_data) begin

                case (block_index)
                    3'd0: inner_data[size-1:0]         <= write_value;
                    3'd1: inner_data[size*2-1: size]   <= write_value;
                    3'd2: inner_data[size*3-1: size*2] <= write_value;
                    3'd3: inner_data[size*4-1: size*3] <= write_value;
                    3'd4: inner_data[size*5-1: size*4] <= write_value;
                    3'd5: inner_data[size*6-1: size*5] <= write_value;
                    3'd6: inner_data[size*7-1: size*6] <= write_value;
                    3'd7: inner_data[size*8-1: size*7] <= write_value;
                    default: ;
                endcase;

                case (block_index)
                    3'd0: inner_tags[tag_size-1:0] <= tag_compare;
                    3'd1: inner_tags[tag_size*2-1:tag_size] <= tag_compare;
                    3'd2: inner_tags[tag_size*3-1:tag_size*2] <= tag_compare;
                    3'd3: inner_tags[tag_size*4-1:tag_size*3] <= tag_compare;
                    3'd4: inner_tags[tag_size*5-1:tag_size*4] <= tag_compare;
                    3'd5: inner_tags[tag_size*6-1:tag_size*5] <= tag_compare;
                    3'd6: inner_tags[tag_size*7-1:tag_size*6] <= tag_compare;
                    3'd7: inner_tags[tag_size*8-1:tag_size*7] <= tag_compare;
                    default: ;
                endcase;

                inner_valid[block_index] <= 1;
            end
        end
    end

    assign data = (block_index == 3'b000) ? inner_data[size-1:0]
                    : (block_index == 3'b001) ? inner_data[(size*2)-1:size]
                    : (block_index == 3'b010) ? inner_data[(size*3)-1: (size*2)]
                    : (block_index == 3'b011) ? inner_data[(size*4)-1 : (size*3)]
                    : (block_index == 3'b100) ? inner_data[(size*5)-1 : (size*4)]
                    : (block_index == 3'b101) ? inner_data[(size*6)-1 : (size*5)]
                    : (block_index == 3'b110) ? inner_data[(size*7)-1 : (size*6)]
                    : (block_index == 3'b111) ? inner_data[(size*8)-1 : (size*7)]
                    : 0;

    assign valid = inner_valid[block_index]
                    && tag_compare == (
                        (block_index == 3'd0) ? inner_tags[tag_size-1: 0]
                        : (block_index == 3'd1) ? inner_data[tag_size*2-1: tag_size]
                        : (block_index == 3'd2) ? inner_data[tag_size*3-1: tag_size*2]
                        : (block_index == 3'd3) ? inner_data[tag_size*4-1: tag_size*3]
                        : (block_index == 3'd4) ? inner_data[tag_size*5-1: tag_size*4]
                        : (block_index == 3'd5) ? inner_data[tag_size*6-1: tag_size*5]
                        : (block_index == 3'd6) ? inner_data[tag_size*7-1: tag_size*6]
                        : (block_index == 3'd7) ? inner_data[tag_size*8-1: tag_size*7]
                        : 0);

endmodule
