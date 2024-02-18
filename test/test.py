# SPDX-FileCopyrightText: © 2023 Uri Shaked <uri@tinytapeout.com>
# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

@cocotb.test()
async def test_counter(dut):
  dut._log.info("Start")
  
  # Our example module doesn't use clock and reset, but we show how to use them here anyway.
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
  await ClockCycles(dut.clk, 1)

  # wait 100 cycles, output value should be 100
  await ClockCycles(dut.clk, 100)
  assert dut.uo_out.value == 100

  # reset signal again
  dut.rst_n.value = 0
  await ClockCycles(dut.clk, 1)

  # wait 10 clock cycles, expect output value to be 0
  await ClockCycles(dut.clk, 10)
  assert dut.uo_out.value == 0

  # remove reset
  await ClockCycles(dut.clk, 1)
  dut.rst_n.value = 1

  await ClockCycles(dut.clk, 1)

  # wait 10 clock cycles, expect output value to be 10
  await ClockCycles(dut.clk, 10)
  assert dut.uo_out.value == 10