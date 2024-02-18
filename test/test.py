# SPDX-FileCopyrightText: © 2023 Uri Shaked <uri@tinytapeout.com>
# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

def get_value1(val1, val2):
    return val1 + (((val2 >> 6) & 0b11) << 6)

def get_value2(opcode, val1, val2):
    return (opcode << 4) + (val2 & 0b1111)

@cocotb.test()
async def test_counter(dut):
    dut._log.info("Start")
  
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Test")
    await ClockCycles(dut.clk, 2)

    val1 = 12
    val2 = 10

    dut.ui_in.value = get_value1(val1, val2)
    dut.uio_in.value = get_value2(0b00, val1, val2)

    await ClockCycles(dut.clk, 1)
    assert dut.uo_out.value == 22

    val1 = 5
    val2 = 10
    dut.ui_in.value = get_value1(val1, val2)
    dut.uio_in.value = get_value2(0b00, val1, val2)
    await ClockCycles(dut.clk, 1)
    assert dut.uo_out.value == 15

    val1 = 20
    val2 = 2
    dut.ui_in.value = get_value1(val1, val2)
    dut.uio_in.value = get_value2(0b01, val1, val2)
    await ClockCycles(dut.clk, 1)
    assert dut.uo_out.value == 18