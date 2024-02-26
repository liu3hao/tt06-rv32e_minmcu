
from cocotb.triggers import FallingEdge, RisingEdge, Edge, First
from cocotbext.spi import SpiSlaveBase, SpiConfig

class SimpleSpiSlave(SpiSlaveBase):
    def __init__(self, bus, contents):
        self._config = SpiConfig(
            data_output_idle=0,
            word_width=8,
            msb_first=True,
            cpol=0,
            cpha=0,
        )

        # Memory contents
        self.contents = contents
        
        self.content = 0
        self.return_value = 0

        super().__init__(bus)

    async def get_content(self):
        await self.idle.wait()
        return self.content

    async def _transaction(self, frame_start, frame_end):
        await frame_start

        self.idle.clear()

        # wait for first byte
        first_byte = await self.read_in(8)

        if first_byte == 0x03:
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
