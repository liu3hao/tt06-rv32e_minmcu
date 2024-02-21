# SPDX-FileCopyrightText: © 2023 Uri Shaked <uri@tinytapeout.com>
# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge

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
        super().__init__(bus)

    async def get_content(self):
        await self.idle.wait()
        return self.content

    async def _transaction(self, frame_start, frame_end):
        await frame_start
        self.idle.clear()

        self.content = int(await self._shift(31))

        # this is needed because _shift does not work so well for CPOL=0, CPHA=0
        await FallingEdge(self._sclk)

        await self.shift2(32, 0xff1122ff)

        await frame_end

    async def shift2(self, num_bits, value):
        # immediately set miso and shift out the rest
        self._miso.value = (value >> (num_bits-1)) & 0b1
        return await self._shift(num_bits-1, value)


@cocotb.test()
async def test_counter(dut):
    dut._log.info("Start")

    spi_slave = SimpleSpiSlave(SpiBus.from_entity(dut))
  
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.rst_n.value = 0

    dut._log.info("Start clock")
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    await ClockCycles(dut.sclk, 64)
    dut._log.info("End clock")

    await ClockCycles(dut.clk, 10)

    spi_content = hex(spi_slave.content)
    dut._log.info("got spi slave content: " + spi_content)