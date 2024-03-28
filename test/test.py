# SPDX-FileCopyrightText: © 2023 Uri Shaked <uri@tinytapeout.com>
# SPDX-License-Identifier: MIT

import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, First, ClockCycles
from cocotbext.spi import SpiBus

from helpers import SpiFlashPeripheral, get_halt_signal, get_io_output_pin, get_output_pin, get_register, load_binary, assert_registers_zero, run_program, set_input_pin
from cocotbext.uart import UartSink, UartSource

test_cpu = True
test_peripherals = True

if test_cpu:
    from test_cpu import *

if test_peripherals:
    from test_peripherals import *