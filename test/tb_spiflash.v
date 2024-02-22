`default_nettype none `timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb_spiflash ();

    // Dump the signals to a VCD file. You can view it with gtkwave.
    initial begin
        $dumpfile("tb_spiflash.vcd");
        $dumpvars(0, tb_spiflash);
        #1;
    end

    reg clk;
    reg rst_n;

    reg miso;
    reg sclk;
    reg mosi;
    reg cs;

    reg start_fetch;
    reg [23:0] target_address;
    reg [31:0] fetched_data;

    reg fetch_done;

    mem_read mem_read1 (
        .miso(miso),
        .mosi(mosi),
        .cs  (cs),
        .sclk(sclk),

        .target_address(target_address),
        .fetched_data(fetched_data),

        .start_fetch(start_fetch),
        .fetch_done(fetch_done),

        .clk  (clk),   // clock
        .rst_n(rst_n)  // not reset
    );

endmodule
