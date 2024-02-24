# SPDX-FileCopyrightText: © 2023 Uri Shaked <uri@tinytapeout.com>
# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge

from cocotbext.spi import SpiBus
from helpers import SimpleSpiSlave

async def run_program(dut, program_instructions, wait_cycles=100):
    dut._log.info("Start")

    spi_peri = SimpleSpiSlave(SpiBus.from_entity(dut.cpu1.mem_read1))  
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1

    for instruction in program_instructions:
        spi_peri.return_value = instruction

        dut._log.info("Fetch 4 bytes from memory")
        await ClockCycles(dut.cpu1.mem_read1.sclk, 64)
        await RisingEdge(dut.cpu1.fetch_done)

        dut._log.info("Received bytes: " + hex(instruction))
        assert dut.cpu1.fetched_data.value == instruction

    await ClockCycles(dut.clk, wait_cycles)

@cocotb.test()
async def test_simple(dut):
    dut._log.info("Start")

    spi_peri = SimpleSpiSlave(SpiBus.from_entity(dut.cpu1.mem_read1))
    spi_peri.return_value = 0x11223344
  
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1

    dut._log.info("Fetch first 4 bytes")
    await ClockCycles(dut.cpu1.mem_read1.sclk, 64)

    await RisingEdge(dut.cpu1.fetch_done)
    assert dut.cpu1.fetched_data.value == 0x11223344
    spi_peri.return_value = 0x55665566

    await FallingEdge(dut.cpu1.mem_read1.cs)

    dut._log.info("Fetch next 4 bytes")
    await ClockCycles(dut.cpu1.mem_read1.sclk, 64)

    await RisingEdge(dut.cpu1.fetch_done)
    assert dut.cpu1.fetched_data.value == 0x55665566


@cocotb.test()
async def test_addi_add(dut):
    await run_program(dut, [
        0x3e800093,
        0x7d008113,
        0xc1800193,
        0x00310233
    ])

    assert dut.cpu1.r1.value == 1000
    assert dut.cpu1.r2.value == 3000
    assert dut.cpu1.r3.value.signed_integer == -1000
    assert dut.cpu1.r4.value == 2000

@cocotb.test()
async def test_slt(dut):
    await run_program(dut, [
        0xc1800093,
        0xe0c00113,
        0x0020a1b3,
        0x00112233
    ])

    assert dut.cpu1.r1.value.signed_integer == -1000
    assert dut.cpu1.r2.value.signed_integer == -500
    assert dut.cpu1.r3.value == 1
    assert dut.cpu1.r4.value == 0

@cocotb.test()
async def test_sltu(dut):
    await run_program(dut, [
        0x06400093,
        0x0c800113,
        0x0020b1b3,
        0x00112233
    ])

    assert dut.cpu1.r1.value == 100
    assert dut.cpu1.r2.value == 200
    assert dut.cpu1.r3.value == 1
    assert dut.cpu1.r4.value == 0

@cocotb.test()
async def test_xor(dut):
    await run_program(dut, [
        0x06400093,
        0x0c800113,
        0x0020c1b3,
        0x00114233
    ])

    assert dut.cpu1.r1.value == 100
    assert dut.cpu1.r2.value == 200
    assert dut.cpu1.r3.value == 172
    assert dut.cpu1.r4.value == 172

@cocotb.test()
async def test_srli_srl(dut):
    await run_program(dut, [
        0x06400093,
        0x0c800113,
        0x0020d193,
        0x00415213,
    ])

    assert dut.cpu1.r1.value == 100
    assert dut.cpu1.r2.value == 200
    assert dut.cpu1.r3.value == 25
    assert dut.cpu1.r4.value == 12

@cocotb.test()
async def test_srai_sra(dut):
    await run_program(dut, [
        0x06400093,
        0x0c800113,
        0x4020d193,
        0x40415213,
    ])

    assert dut.cpu1.r1.value == 100
    assert dut.cpu1.r2.value == 200
    assert dut.cpu1.r3.value == 25
    assert dut.cpu1.r4.value == 12

@cocotb.test()
async def test_srai_sra_negative(dut):
    await run_program(dut, [
        0x06400093,
        0xf3800113,
        0x4020d193,
        0x40415213,
    ])

    assert dut.cpu1.r1.value == 100
    assert dut.cpu1.r2.value.signed_integer == -200
    assert dut.cpu1.r3.value == 25
    assert dut.cpu1.r4.value.signed_integer == -13