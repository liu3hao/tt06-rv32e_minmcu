
module registers #(
    parameter size = 32
) (
    input wire [3:0] write_register,
    input wire [1:0] write_value,

    // up to 16 registers
    input wire [3:0] r_sel1,
    output wire [1:0] r_value1,

    input wire [3:0] r_sel2,
    output wire [1:0] r_value2,

    input wire wr_en,
    input wire shift,

    input wire clk,
    input wire rst_n
);
    reg [size-1:0] registers[16];  // Array of 16 32-bit registers

    // Reading data from registers
    assign r_value1 = registers[r_sel1][1:0];
    assign r_value2 = registers[r_sel2][1:0];

    always @(posedge clk) begin
        if (rst_n == 0) begin
            for (int i = 0; i < 16; i = i + 1) begin
                registers[i] <= 0;
            end
        end else begin

            if (shift) begin
                for (int i = 1; i < 16; i = i + 1) begin
                    registers[i] <= (registers[i] >> 2) | ((registers[i] & 32'h3) << 30);
                end
            end

            if (wr_en && write_register != 0) begin
                registers[write_register][31:30] <= write_value;
            end
        end
    end

endmodule
