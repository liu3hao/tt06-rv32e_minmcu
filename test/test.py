# SPDX-FileCopyrightText: © 2023 Uri Shaked <uri@tinytapeout.com>
# SPDX-License-Identifier: MIT

import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, First, ClockCycles
from cocotbext.spi import SpiBus

from helpers import SpiFlashPeripheral, ValueWrapper, get_halt_signal, get_io_output_pin, get_output_pin, get_register, load_binary, assert_registers_zero, run_program, set_input_pin
from cocotbext.uart import UartSink, UartSource

test_cpu = True
test_peripherals = True

if test_cpu:
    from test_cpu import *

if test_peripherals:
    from test_peripherals import *


@cocotb.test()
async def test_debug_mode(dut):
    dut.ui_in.value = 0

    dumped_spi_contents = {"result": {}}

    async def connect_spi():

        tmp_spi = SpiFlashPeripheral(SpiBus.from_entity(dut,
                                                cs_name='out3'), {}, 
                                                dut, name='spi_debug')
        
        tmp_spi.show_debug_logs = True

        # when there is a high detected on this pin, then enable debug mode
        await RisingEdge(dut.out0)
        dut.ui_in[6].value = 1

        for i in range(0, 35):
            await RisingEdge(dut.out3)

        dumped_spi_contents["contents"] = tmp_spi.contents

        # exit debug mode, program continues normally
        dut.ui_in[6].value = 0

    ram_chip, flash = await run_program(dut, '''
 0x00000000	|	0x0200A083	|	lw x1, peripherals
 0x00000004	|	0x00100113	|	addi x2, x0, 1
 0x00000008	|	0x3E800193	|	addi x3, x0, 1000
 0x0000000C	|	0x7D000213	|	addi x4, x0, 2000
 0x00000010	|	0xC1800293	|	addi x5, x0, -1000
 0x00000014	|	0x00208023	|	sb x2, 0(x1)
 0x00000018	|	0x83000313	|	addi x6, x0, -2000
 0x0000001C	|	0x0000006F	|	jal x0, 0
-------------------------------------------------------------------------
 Data Dump
-------------------------------------------------------------------------
 0x00000024	|	0x00020000
        ''', extra_func=connect_spi)
    
    dumped_values = {}

     # read out in words
    for i in range(0, 16):
        start = i * 4
        counter = 0
        value = 0
        while counter < 4:
            value = (dumped_spi_contents["contents"][start+counter] << (counter*8)) | value
            counter += 1
        dumped_values[i] = ValueWrapper(value)

    assert dumped_values[0].value == 24
    assert dumped_values[1].value == 0x20000
    assert dumped_values[2].value == 1
    assert dumped_values[3].value == 1000
    assert dumped_values[4].value == 2000
    assert dumped_values[5].value.signed_integer == -1000

    for i in range(6, 16):
        assert dumped_values[i].value == 0