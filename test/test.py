# SPDX-FileCopyrightText: © 2023 Uri Shaked <uri@tinytapeout.com>
# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge

from cocotbext.spi import SpiBus
from helpers import SimpleSpiSlave

async def run_program(dut, memory, max_reads=None, wait_cycles=100):
    dut._log.info("Start")

    spi_peri = SimpleSpiSlave(SpiBus.from_entity(dut.cpu1.mem_controller1))  
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

    def on_data_received(spi_peri_content):
        dut._log.info("Got after 32 sclk: " + hex(spi_peri_content))

        command = spi_peri_content >> 24
        if command == 0x03:
            address = spi_peri_content & 0xffffff
            dut._log.info('read data at address: '+ hex(address))
            return_value = memory[int(address/4)]
            spi_peri.return_value = return_value
            dut._log.info('return value: ' + hex(return_value))

    spi_peri.on_data_received = on_data_received 

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.rst_n.value = 0

    if (max_reads == None):
        max_reads = len(memory)

    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1
    counter = 0

    while True:
        dut._log.info("Waiting for CS falling edge")
        await FallingEdge(dut.cpu1.mem_controller1.cs)
        
        await ClockCycles(dut.cpu1.mem_controller1.sclk, 32)

        await RisingEdge(dut.cpu1.mem_controller1.cs)
        counter += 1

        # Use this as the stop signal for now
        if (counter >= max_reads):
            break

    await ClockCycles(dut.clk, wait_cycles)

# @cocotb.test()
# async def test_simple(dut):
#     dut._log.info("Start")

#     spi_peri = SimpleSpiSlave(SpiBus.from_entity(dut.cpu1.mem_read1))
#     spi_peri.return_value = 0x11223344
  
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
#     spi_peri.return_value = 0x55665566

#     await FallingEdge(dut.cpu1.mem_read1.cs)

#     dut._log.info("Fetch next 4 bytes")
#     await ClockCycles(dut.cpu1.mem_read1.sclk, 64)

#     await RisingEdge(dut.cpu1.fetch_done)
#     assert dut.cpu1.fetched_data.value == 0x55665566


# @cocotb.test()
# async def test_addi_add(dut):
#     await run_program(dut, [
#         0x3e800093,
#         0x7d008113,
#         0xc1800193,
#         0x00310233
#     ])

#     assert dut.cpu1.r1.value == 1000
#     assert dut.cpu1.r2.value == 3000
#     assert dut.cpu1.r3.value.signed_integer == -1000
#     assert dut.cpu1.r4.value == 2000

# @cocotb.test()
# async def test_slt(dut):
#     await run_program(dut, [
#         0xc1800093,
#         0xe0c00113,
#         0x0020a1b3,
#         0x00112233
#     ])

#     assert dut.cpu1.r1.value.signed_integer == -1000
#     assert dut.cpu1.r2.value.signed_integer == -500
#     assert dut.cpu1.r3.value == 1
#     assert dut.cpu1.r4.value == 0

# @cocotb.test()
# async def test_sltu(dut):
#     await run_program(dut, [
#         0x06400093,
#         0x0c800113,
#         0x0020b1b3,
#         0x00112233
#     ])

#     assert dut.cpu1.r1.value == 100
#     assert dut.cpu1.r2.value == 200
#     assert dut.cpu1.r3.value == 1
#     assert dut.cpu1.r4.value == 0

# @cocotb.test()
# async def test_xor(dut):
#     await run_program(dut, [
#         0x06400093,
#         0x0c800113,
#         0x0020c1b3,
#         0x00114233
#     ])

#     assert dut.cpu1.r1.value == 100
#     assert dut.cpu1.r2.value == 200
#     assert dut.cpu1.r3.value == 172
#     assert dut.cpu1.r4.value == 172

# @cocotb.test()
# async def test_srli_srl(dut):
#     await run_program(dut, [
#         0x06400093,
#         0x0c800113,
#         0x0020d193,
#         0x00415213,
#     ])

#     assert dut.cpu1.r1.value == 100
#     assert dut.cpu1.r2.value == 200
#     assert dut.cpu1.r3.value == 25
#     assert dut.cpu1.r4.value == 12

# @cocotb.test()
# async def test_srai_sra(dut):
#     await run_program(dut, [
#         0x06400093,
#         0xf3800113,
#         0x4020d193,
#         0x40415213,
#     ])

#     assert dut.cpu1.r1.value == 100
#     assert dut.cpu1.r2.value.signed_integer == -200
#     assert dut.cpu1.r3.value == 25
#     assert dut.cpu1.r4.value.signed_integer == -13

# @cocotb.test()
# async def test_icache(dut):
#     await run_program(dut, [
#         0x06400093,
#         0xf3800113,
#         0x4020d193,
#         0x40415213,
#     ])

#     assert dut.cpu1.mem_controller1.instruction_cache1.inner_data.value == \
#             0x06400093 |            \
#             0xf3800113 << 32 |      \
#             0x4020d193 << 64 |      \
#             0x40415213 << 96

@cocotb.test()
async def test_load(dut):
    await run_program(dut, [
        0x01002283,  # lw x5, 16(x0)
        0x01402303,  # lw x6, 20(x0)
        0,
        0,
        0x55667788,
        0x11223344,
        0,
    ], max_reads=4)

    assert dut.cpu1.r5.value == 0x55667788
    assert dut.cpu1.r6.value == 0x11223344



# TODO add more tests..