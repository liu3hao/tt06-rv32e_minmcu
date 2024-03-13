
module registers (
    input wire [3:0] write_register,
    input wire [31:0] write_value,

    // up to 16 registers
    input wire [3:0] r_sel1,
    output wire [31:0] r_value1,

    input wire [3:0] r_sel2,
    output wire [31:0] r_value2,

    input wire clk,
    input wire rst_n
);
    reg [31:0] registers [16];   // Array of 16 32-bit registers

    // Reading data from registers
    assign r_value1 = registers[r_sel1];
    assign r_value2 = registers[r_sel2];

    // Writing data into registers
    always @(posedge clk) begin
        if (rst_n == 0) begin
            registers[0]  <= 0;
            registers[1]  <= 0;
            registers[2]  <= 0;
            registers[3]  <= 0;
            registers[4]  <= 0;
            registers[5]  <= 0;
            registers[6]  <= 0;
            registers[7]  <= 0;
            registers[8]  <= 0;
            registers[9]  <= 0;
            registers[10] <= 0;
            registers[11] <= 0;
            registers[12] <= 0;
            registers[13] <= 0;
            registers[14] <= 0;
            registers[15] <= 0;

        end else if (write_register != 0) begin
            // Do not allow reg 0 to be changed.
            registers[write_register] <= write_value;
        end
    end

endmodule
