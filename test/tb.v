`default_nettype none `timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

    // Dump the signals to a VCD file. You can view it with gtkwave.
    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
        #1;
    end

    // Wire up the inputs and outputs:
    reg  clk;
    reg  rst_n;
    reg  ena;

    reg  sclk;
    reg  miso;
    wire mosi;
    wire cs;

    // Replace tt_um_example with your module name:
    rv32e_cpu cpu1 (

        // Include power ports for the Gate Level test:
`ifdef GL_TEST
        .VPWR(1'b1),
        .VGND(1'b0),
`endif

        .miso(miso),
        .mosi(mosi),
        .cs  (cs),
        .sclk(sclk),


        //   .ui_in  (ui_in),    // Dedicated inputs
        //   .uo_out (uo_out),   // Dedicated outputs
        //   .uio_in (uio_in),   // IOs: Input path
        //   .uio_out(uio_out),  // IOs: Output path
        //   .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
        .ena  (ena),   // enable - goes high when design is selected
        .clk  (clk),   // clock
        .rst_n(rst_n)  // not reset
    );

endmodule
