
module registers #(
    parameter size = 32
) (
    input wire [3:0] write_register,
    input wire [size-1:0] write_value,

    // up to 16 registers
    input wire [3:0] r_sel1,
    output wire [size-1:0] r_value1,

    input wire [3:0] r_sel2,
    output wire [size-1:0] r_value2,

    input wire wr_en,
    input wire rst_n
);
    reg [size-1:0] registers[16];  // Array of 16 32-bit registers

    // Reading data from registers
    assign r_value1 = registers[r_sel1];
    assign r_value2 = registers[r_sel2];

    always @(rst_n, wr_en) begin
        if (rst_n == 0) begin
            for (int i = 0; i < 16; i = i + 1) begin
                registers[i] <= 0;
            end

        end else begin
            if (wr_en) begin
                // Writing data into registers
                for (int i = 1; i < 16; i = i + 1) begin
                    if (write_register == i[3:0]) begin
                        registers[i] <= write_value;
                    end
                end
            end
        end
    end

endmodule
