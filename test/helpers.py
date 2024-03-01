import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge

from cocotbext.spi import SpiBus
from cocotb.triggers import FallingEdge, RisingEdge, First
from cocotbext.spi import SpiSlaveBase, SpiConfig

class SpiFlashPeripheral(SpiSlaveBase):
    def __init__(self, bus, contents, name):
        self._config = SpiConfig(
            data_output_idle=0,
            word_width=8,
            msb_first=True,
            cpol=0,
            cpha=0,
        )

        # Memory contents
        self.contents = contents
        self.name = name

        super().__init__(bus)

    
    def get_value(self, address, num_bytes):
        value = 0
        for i in range(0, num_bytes):
            value = (value << 8) | self.contents[address + i]
        return value
    
    def dump_memory(self):
        print(self.contents)

    async def _transaction(self, frame_start, frame_end):
        await frame_start

        self.idle.clear()

        # wait for first byte
        first_byte = await self.read_in(8)

        if first_byte == 0x03:
            # print('starting read operation', self.name)
            
            # Read address, next 3 bytes are read address
            address = await self.read_in(24)

            while True:
                if (await First(RisingEdge(self._sclk), frame_end)) != frame_end:
                    # if not a stop frame, then transmit the next byte
                    memory_value = self.contents[address]
                    await self.shift2(8, memory_value)
                    address += 1
                else:
                    break

        elif first_byte == 0x02:
            # print('starting write operation', self.name)

            # Write operation, next 3 bytes are starting address
            address = await self.read_in(24)

            while True:
                if (await First(RisingEdge(self._sclk), frame_end)) != frame_end:

                    result = int(self._mosi.value)

                    for i in range(0, 7):
                        # expect 7 more bytes
                        await FallingEdge(self._sclk)
                        await RisingEdge(self._sclk)
                        result = (result << 1) | int(self._mosi.value)

                    await FallingEdge(self._sclk)
                    self.contents[address] = result
                    address += 1
                    
                else:
                    break
        else:
            await frame_end

    async def read_in(self, length):
        result = await self._shift(length-1)
        await RisingEdge(self._sclk)
        result = (result << 1) | int(self._mosi.value)
        await FallingEdge(self._sclk)
        return result

    async def shift2(self, num_bits, value):
        # immediately set miso and shift out the rest
        self._miso.value = (value >> (num_bits-1)) & 0b1
        return await self._shift(num_bits-1, value)



def prepare_bytes(memory_array):
    # organize the memory array into bytes
    bytes_array = []

    for item in memory_array:
        tmp = item
        bits = [0] * 32
        index = 0

        while tmp > 0:
            bits[index] = tmp % 2
            tmp = tmp >> 1
            index += 1

        bits.reverse()
        
        for i in range(0, 4):
            tmp_bits = bits[i*8:(i+1)*8]

            value = 0
            for index, val in enumerate(tmp_bits):
                value = value | (val << (7-index))
            # print(tmp_bits, value, hex(value))
            bytes_array.append(value)

    # for value in bytes_array:
    #     print("%02x" % value)

    return bytes_array

async def run_program(dut, raw='', memory=None, max_reads=None, wait_cycles=100):
    dut._log.info("Run program")

    if raw != '':
        memory = []
        lines = raw.splitlines()
        lines = [line.strip() for line in lines]
        for line in lines:
            if line != '':
                memory.append(int(line, 16))

    bytes_array = prepare_bytes(memory)
    ram_bytes = [0] * 128

    # Flash memory
    flash_chip = SpiFlashPeripheral(SpiBus.from_entity(dut.cpu1.mem_controller1, 
                                                 cs_name='cs1'), bytes_array, 
                                                 name='flash')  
    
    # PSRAM
    ram_chip = SpiFlashPeripheral(SpiBus.from_entity(dut.cpu1.mem_controller1, 
                                                 cs_name='cs2'), ram_bytes, 
                                                 name='ram')
    
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())

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
        await FallingEdge(dut.cpu1.mem_controller1.cs1)
        await RisingEdge(dut.cpu1.mem_controller1.cs1)
        
        counter += 1

        # Use this as the stop signal for now
        if (counter >= max_reads):
            break

    await ClockCycles(dut.clk, wait_cycles)

    return ram_chip, flash_chip