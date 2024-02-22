# SPDX-FileCopyrightText: © 2023 Uri Shaked <uri@tinytapeout.com>
# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge

from cocotbext.spi import SpiBus
from helpers import SimpleSpiSlave

@cocotb.test()
async def test_simple(dut):
    dut._log.info("Start")

    spi_slave = SimpleSpiSlave(SpiBus.from_entity(dut))
    spi_slave.return_value = 0x11223344
  
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1

    dut._log.info("Fetch first 4 bytes")
    await ClockCycles(dut.sclk, 64)

    await RisingEdge(dut.cpu1.fetch_done)
    assert dut.cpu1.fetched_data.value == 0x11223344
    spi_slave.return_value = 0x55665566

    await FallingEdge(dut.cs)

    dut._log.info("Fetch next 4 bytes")
    await ClockCycles(dut.sclk, 64)

    await RisingEdge(dut.cpu1.fetch_done)
    assert dut.cpu1.fetched_data.value == 0x55665566