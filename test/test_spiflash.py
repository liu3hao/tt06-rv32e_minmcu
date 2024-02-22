# SPDX-FileCopyrightText: © 2023 Uri Shaked <uri@tinytapeout.com>
# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge

from cocotbext.spi import SpiSlaveBase, SpiBus, SpiConfig

class SimpleSpiSlave(SpiSlaveBase):

    def __init__(self, bus):
        self._config = SpiConfig(
            data_output_idle=0,
            word_width=8,
            msb_first=True,
            cpol=0,
            cpha=0,
        )
        self.content = 0
        self.return_value = 0

        super().__init__(bus)

    async def get_content(self):
        await self.idle.wait()
        return self.content

    async def _transaction(self, frame_start, frame_end):
        await frame_start
        self.idle.clear()

        self.content = int(await self._shift(31))

        await RisingEdge(self._sclk)
        self.content = (self.content << 1) | int(self._mosi.value)
        

        # this is needed because _shift does not work so well for CPOL=0, CPHA=0
        await FallingEdge(self._sclk)

        await self.shift2(32, self.return_value)

        await frame_end

    async def shift2(self, num_bits, value):
        # immediately set miso and shift out the rest
        self._miso.value = (value >> (num_bits-1)) & 0b1
        return await self._shift(num_bits-1, value)


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