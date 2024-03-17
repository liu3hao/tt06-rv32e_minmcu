import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge

from cocotbext.spi import SpiBus
from cocotb.triggers import FallingEdge, RisingEdge, First
from cocotbext.spi import SpiSlaveBase, SpiConfig

class SpiFlashPeripheral(SpiSlaveBase):
    def __init__(self, bus, contents, dut, name):
        self._config = SpiConfig(
            data_output_idle=0,
            sclk_freq=50e6,
            word_width=8,
            msb_first=True,
            cpol=0,
            cpha=0,
        )

        # Memory contents
        self.contents = contents
        self.name = name
        self.dut = dut

        super().__init__(bus)

    def get_value(self, address, num_bytes):
        # return in little-endian, so earlier mem addresses are the lsb
        value = 0
        for i in range(0, num_bytes):
            value = (self.contents[address + i] << (i*8)) | value
        return value
    
    def dump_memory(self):
        print(self.contents)
    
    def dump_memory2(self):
        keys = sorted(list(self.contents.keys()))

        for addr in keys:
            print(hex(addr), self.contents[addr])

    async def _transaction(self, frame_start, frame_end):
        await frame_start
        self.idle.clear()

        # self.debugLog('start transaction')

        # wait for first byte
        first_byte = await self.shift2(8)
        # self.debugLog("got %d" % first_byte)

        if first_byte == 0x03:
            # self.debugLog('starting read operation: %s' % self.name)
            
            # Read address, next 3 bytes are read address
            address = await self.shift2(24)
            # self.debugLog('read address %d' % address)

            while True:
                try:
                    memory_value = self.contents[address]
                except:
                    memory_value = 0xff

                try:
                    await self.shift2(8, memory_value)
                    # self.debugLog("shifted out value: %d %s" % (memory_value, bin(memory_value)))
                    address += 1
                except Exception as e:
                    # self.debugLog("nothing to shift: %s" % e)
                    break

        elif first_byte == 0x02:
            # self.debugLog('starting write operation: %s' % self.name)

            # Write operation, next 3 bytes are starting address
            address = await self.shift2(24)

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

    async def shift2(self, num_bits, value=0):
        # immediately set miso and shift out the rest
        self._miso.value = (value >> (num_bits-1)) & 0b1
        result = await self._shift(num_bits-1, value)
        await RisingEdge(self._sclk)
        result = (result << 1) | int(self._mosi.value)
        await FallingEdge(self._sclk)
        return result


    def debugLog(self, message):
        self.dut._log.info(message)


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
        
        tmp_bytes = []
        for i in range(0, 4):
            tmp_bits = bits[i*8:(i+1)*8]

            value = 0
            for index, val in enumerate(tmp_bits):
                value = value | (val << (7-index))
            # print(tmp_bits, value, hex(value))
            tmp_bytes.append(value)
        
        # Convert to little endian
        tmp_bytes.reverse()
        bytes_array += tmp_bytes

    # for value in bytes_array:
    #     print("%02x" % value)

    return bytes_array

def load_binary(path):
    tmp_bytes = []
    output = []
    with open(path, 'rb') as input_file:
        tmp_bytes = input_file.read()
    for b in tmp_bytes:
        output.append(b)
    return output

async def run_program(dut, raw='', memory=None, wait_cycles=100):
    dut._log.info("Run program")

    if raw != '':
        memory = []
        lines = raw.splitlines()
        lines = [line.strip() for line in lines]
        for line in lines:
            if line != '':
                memory.append(int(line, 16))

        bytes_array = prepare_bytes(memory)
    elif memory is not None:
        bytes_array = memory

    ram_bytes = {}

    mem_external = dut.cpu1.mem_external1

    flash_chip = SpiFlashPeripheral(SpiBus.from_entity(mem_external, 
    # Flash memory
                                                 cs_name='cs1'), bytes_array, 
                                                 dut, name='flash')  
    
    # PSRAM
    ram_chip = SpiFlashPeripheral(SpiBus.from_entity(mem_external, 
                                                 cs_name='cs2'), ram_bytes, 
                                                 dut, name='ram')
    
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1

    await RisingEdge(dut.cpu1.halted)
    dut._log.info('CPU halted')

    await ClockCycles(dut.clk, wait_cycles)

    return ram_chip, flash_chip

def get_register(dut, index):
    if False:
        return dut.cpu1.reg1._id('r%d' % index, extended=False)
    else:
        return dut.cpu1.reg1._id('registers[%d]' % index, extended=False)
    
def assert_registers_zero(dut, start_from, until=15):
    for i in range(start_from, until+1):
        assert get_register(dut, i).value == 0

    return True