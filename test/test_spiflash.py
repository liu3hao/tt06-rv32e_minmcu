# SPDX-FileCopyrightText: © 2023 Uri Shaked <uri@tinytapeout.com>
# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

from cocotbext.spi import SpiBus
from helpers import SimpleSpiSlave

@cocotb.test()
async def test_spiflash(dut):
    dut._log.info("Start")

    spi_slave = SimpleSpiSlave(SpiBus.from_entity(dut))
    spi_slave.return_value = 0x99887766
  
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.rst_n.value = 0
    dut.start_fetch.value = 0
    dut.target_address.value = 0x123456

    dut._log.info("Start clock")
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    await ClockCycles(dut.clk, 20)

    # No start signal yet, so CS signal should be high still
    assert dut.cs.value == 1        

    await ClockCycles(dut.clk, 10)
    dut.start_fetch.value = 1

    await ClockCycles(dut.sclk, 1)
    assert dut.cs.value == 0
    assert dut.fetch_done.value == 0

    await ClockCycles(dut.sclk, 31)
    assert dut.fetch_done.value == 0

    await ClockCycles(dut.sclk, 32)
    dut._log.info("End clock")

    await ClockCycles(dut.clk, 100)

    dut._log.info("Check SPI peripheral content")
    assert spi_slave.content == 0x03123456

    dut._log.info("Check fetched data")
    assert dut.fetched_data.value == 0x99887766
    assert dut.fetch_done.value == 1
    assert dut.cs.value == 1

    dut._log.info("Prepare for next read")
    # Prepare for another read
    await ClockCycles(dut.clk, 200)
    dut.start_fetch.value = 0
    dut.target_address.value = 0x789abc

    spi_slave.return_value = 0x11223344

    dut._log.info("Start next read")
    await ClockCycles(dut.clk, 10)
    dut.start_fetch.value = 1

    await ClockCycles(dut.sclk, 1)
    assert dut.fetch_done.value == 0
    assert dut.fetched_data.value == 0
    assert dut.cs.value == 0

    await ClockCycles(dut.sclk, 63)

    dut._log.info("Read is done")

    await ClockCycles(dut.clk, 20)

    dut._log.info("Check fectched data")
    assert spi_slave.content == 0x03789abc
    assert dut.fetched_data.value == 0x11223344

@cocotb.test()
async def test_spiflash_interrupted(dut):
    dut._log.info("Start")

    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.rst_n.value = 0
    dut.start_fetch.value = 0
    dut.target_address.value = 0x123456
    dut.miso.value = 0

    dut._log.info("Start clock")
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    await ClockCycles(dut.clk, 20)

    # No start signal yet, so CS signal should be high still
    assert dut.cs.value == 1        

    await ClockCycles(dut.clk, 10)
    dut.start_fetch.value = 1

    await ClockCycles(dut.sclk, 1)
    assert dut.cs.value == 0
    assert dut.fetch_done.value == 0

    await ClockCycles(dut.sclk, 10)
    dut.start_fetch.value = 0

    await ClockCycles(dut.clk, 20)
    assert dut.cs.value == 1
    assert dut.sclk.value == 0
