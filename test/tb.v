`default_nettype none `timescale 1ns / 100ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

    integer i;

    // Dump the signals to a VCD file. You can view it with gtkwave.
    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);

        // for (i = 0; i < 16; i = i + 1) begin
        //     $dumpvars(0, cpu1.reg1.registers[i]);
        // end
        #1;
    end

    // Wire up the inputs and outputs:
    reg clk;
    reg rst_n;
    reg ena;

    reg [7:0] ui_in;
    reg [7:0] uio_in;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    wire sclk = uo_out[5];
    wire mosi = uo_out[3];
    wire cs1 =  uo_out[4];
    wire cs2 =  uio_out[0];

    wire out0 = uo_out[1];
    wire out1 = uo_out[2];
    wire out2 = uo_out[6];
    wire out3 = uo_out[7];

    wire uart_tx = uo_out[0]; // uart output
    reg uart_rx;

    wire io_out0 = uio_out[3];
    wire io_out1 = uio_out[4];
    wire io_out2 = uio_out[5];
    wire io_out3 = uio_out[6];
    wire io_out4 = uio_out[7];

    reg miso;
    always_comb begin
        ui_in[2] = miso;
        ui_in[7] = uart_rx;
    end

    initial begin
        uart_rx = 1;

        // Set debug mode to low, so NOT in debug mode
        ui_in = 8'b10111111;
    end

    // Replace tt_um_example with your module name:
    tt_um_rv32e_cpu cpu1 (

        // Include power ports for the Gate Level test:
`ifdef GL_TEST
        .VPWR(1'b1),
        .VGND(1'b0),
`endif
        .ui_in(ui_in),      // Dedicated inputs
        .uo_out(uo_out),    // Dedicated outputs
        .uio_in(uio_in),    // IOs: Input path
        .uio_out(uio_out),  // IOs: Output path
        .uio_oe(uio_oe),    // IOs: Enable path (active high: 0=input, 1=output)
        .ena(ena),          // enable - goes high when design is selected
        .clk(clk),          // clock
        .rst_n(rst_n)       // not reset
    );

endmodule
