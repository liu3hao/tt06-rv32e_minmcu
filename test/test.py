# SPDX-FileCopyrightText: © 2023 Uri Shaked <uri@tinytapeout.com>
# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge

from cocotbext.spi import SpiBus
from helpers import SimpleSpiSlave

# @cocotb.test()
# async def test_simple(dut):
#     dut._log.info("Start")

#     spi_slave = SimpleSpiSlave(SpiBus.from_entity(dut.cpu1.mem_read1))
#     spi_slave.return_value = 0x11223344
  
#     clock = Clock(dut.clk, 10, units="us")
#     cocotb.start_soon(clock.start())

#     # Reset
#     dut._log.info("Reset")
#     dut.ena.value = 1
#     dut.rst_n.value = 0

#     await ClockCycles(dut.clk, 20)
#     dut.rst_n.value = 1

#     dut._log.info("Fetch first 4 bytes")
#     await ClockCycles(dut.cpu1.mem_read1.sclk, 64)

#     await RisingEdge(dut.cpu1.fetch_done)
#     assert dut.cpu1.fetched_data.value == 0x11223344
#     spi_slave.return_value = 0x55665566

#     await FallingEdge(dut.cpu1.mem_read1.cs)

#     dut._log.info("Fetch next 4 bytes")
#     await ClockCycles(dut.cpu1.mem_read1.sclk, 64)

#     await RisingEdge(dut.cpu1.fetch_done)
#     assert dut.cpu1.fetched_data.value == 0x55665566


@cocotb.test()
async def test_commands(dut):
    dut._log.info("Start")

    spi_slave = SimpleSpiSlave(SpiBus.from_entity(dut.cpu1.mem_read1))

    program_instructions = [
        0x3e800093,
        0x7d008113,
        0xc1800193,
        0x00310233
    ]
  
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1

    for instruction in program_instructions:
        spi_slave.return_value = instruction

        dut._log.info("Fetch 4 bytes from memory")
        await ClockCycles(dut.cpu1.mem_read1.sclk, 64)
        await RisingEdge(dut.cpu1.fetch_done)

        dut._log.info("Received bytes: " + hex(instruction))
        assert dut.cpu1.fetched_data.value == instruction

    await ClockCycles(dut.clk, 100)

    assert dut.cpu1.r1.value == 1000
    assert dut.cpu1.r2.value == 3000
    assert dut.cpu1.r3.value.signed_integer == -1000
    assert dut.cpu1.r4.value == 2000