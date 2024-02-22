
from cocotb.triggers import FallingEdge, RisingEdge
from cocotbext.spi import SpiSlaveBase, SpiConfig

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
