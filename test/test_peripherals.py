import cocotb
from cocotb.triggers import RisingEdge, FallingEdge, First, ClockCycles
from cocotbext.spi import SpiBus

from helpers import SpiFlashPeripheral, get_halt_signal, get_io_output_pin, get_output_pin, get_register, load_binary, assert_registers_zero, run_program, set_input_pin
from cocotbext.uart import UartSink, UartSource

baudrate = 9600

@cocotb.test()
async def test_output_write_read_single(dut):
    # lw x1, 32(x0)
    # addi x2, x2, 5
    # sb x2, 0(x1)
    # lb x3, 0(x1)
        
    ram_chip, flash = await run_program(dut, '''
        02002083
        00510113
        00208023
        00008183
        0000006f
        0
        0
        0
        00020000
        ''')

    assert get_register(dut, 1).value == 0x20000
    assert get_register(dut, 2).value == 5
    assert get_register(dut, 3).value == 5
    assert_registers_zero(dut, 4)

    assert get_output_pin(dut, 0).value == 1
    assert get_output_pin(dut, 1).value == 0
    assert get_output_pin(dut, 2).value == 1
    assert get_output_pin(dut, 3).value == 0

@cocotb.test()
async def test_output_write_over(dut):
    # lw x1, 32(x0)
    # addi x2, x2, 10
    # sb x2, 0(x1)
    # lb x4, 0(x1)
    # addi x3, x3, 9
    # sb x3, 0(x1)
        
    ram_chip, flash = await run_program(dut, '''
        02002083
        00A10113
        00208023
        00008203
        00918193
        00308023
        0000006f
        0
        00020000
        ''')

    assert get_register(dut, 1).value == 0x20000
    assert get_register(dut, 2).value == 10
    assert get_register(dut, 3).value == 9
    assert get_register(dut, 4).value == 10
    assert_registers_zero(dut, 5)

    assert get_output_pin(dut, 0).value == 1
    assert get_output_pin(dut, 1).value == 0
    assert get_output_pin(dut, 2).value == 0
    assert get_output_pin(dut, 3).value == 1

@cocotb.test()
async def test_read_input_pins(dut):
    dut.ui_in.value = 0

    async def connect_pins():
        # when there is a high detected on this pin, then set input pins
        await RisingEdge(dut.out0)
        dut.ui_in[0].value = 1
        dut.ui_in[5].value = 1

    ram_chip, flash = await run_program(dut, '''
 0x00000000	|	0x0180A083	|	lw x1, peripherals
 0x00000004	|	0x00108103	|	lb x2, 1(x1)
 0x00000008	|	0x00100193	|	addi x3, x0, 1
 0x0000000C	|	0x00308023	|	sb x3, 0(x1)
 0x00000010	|	0x00108203	|	lb x4, 1(x1)
 0x00000014	|	0x0000006F	|	jal x0, 0
-------------------------------------------------------------------------
 Data Dump
-------------------------------------------------------------------------
 0x0000001C	|	0x00020000	
        ''', extra_func=connect_pins)
    
    assert get_register(dut, 1).value == 0x20000
    assert get_register(dut, 2).value == 0
    assert get_register(dut, 3).value == 1
    assert get_register(dut, 4).value == 17
    assert_registers_zero(dut, 5)

@cocotb.test()
async def test_io_pins(dut):
    # lw x1, 32(x0)
    # addi x2, x2, 24
    # lb x3, 3(x1)
    # sb x2, 2(x1)
    # addi x2, x0, 18
    # sb x2, 4(x1)
    # sb x4, 3(x1)

    dut.uio_in[3].value = 1
    dut.uio_in[4].value = 0
    dut.uio_in[5].value = 0
    dut.uio_in[6].value = 1
    dut.uio_in[7].value = 1

    async def connect_pins():
        # when there is a high detected on this pin, then set input pins
        await RisingEdge(dut.io_out4)

        # set the inputs, however, since the io bits are still outputs
        # so there should be no change
        dut.uio_in[3].value = 0
        dut.uio_in[4].value = 1
        dut.uio_in[6].value = 0
        pass

    ram_chip, flash = await run_program(dut, '''
0x00000000	|	0x02002083	|	lw x1, 32(x0)
0x00000004	|	0x01800113	|	addi x2, x0, 24
0x00000008	|	0x00308183	|	lb x3, 3(x1)
0x0000000C	|	0x00208123	|	sb x2, 2(x1)
0x00000010	|	0x01200113	|	addi x2, x0, 18
0x00000014	|	0x00208223	|	sb x2, 4(x1)
0x00000018	|	0x00308203	|	lb x4, 3(x1)
        0000006f
        00020000
        ''', extra_func=connect_pins)
    
    assert get_register(dut, 1).value == 0x20000
    assert get_register(dut, 2).value == 18
    assert get_register(dut, 3).value == 0x19
    assert get_register(dut, 4).value == 2
    assert assert_registers_zero(dut, 5)

    assert get_io_output_pin(dut, 0) == 0
    assert get_io_output_pin(dut, 1) == 0
    assert get_io_output_pin(dut, 2) == 0
    assert get_io_output_pin(dut, 3) == 0
    assert get_io_output_pin(dut, 4) == 1

@cocotb.test()
async def test_spi_peripherals(dut):

    async def add_spi_device():
        tmp_spi = SpiFlashPeripheral(SpiBus.from_entity(dut,
                                                cs_name='out0'), {}, 
                                                dut, name='tmp_spi1')

        async def tmp(first_byte):
            # return the byte + 1
            await tmp_spi.shift2(8, first_byte + 1)

        tmp_spi.custom_func = tmp

    ram_chip, flash = await run_program(dut, '''
 0x00000000	|	0x0280A083	|	lw x1, peripherals
 0x00000004	|	0x01500113	|	addi x2, x0, 21
 0x00000008	|	0x00300193	|	addi x3, x0, 3
 0x0000000C	|	0x00208423	|	sb x2, 8(x1)
 0x00000010	|	0x000082A3	|	sb x0, 5(x1)
 0x00000014	|	0x003082A3	|	sb x3, 5(x1)
 0x00000018	|	0x00608283	|	lb x5, 6(x1)
 0x0000001C	|	0x00C08203	|	lb x4, 12(x1)
 0x00000020	|	0x000082A3	|	sb x0, 5(x1)
 0x00000024	|	0x0000006F	|	jal x0, 0
-------------------------------------------------------------------------
 Data Dump
-------------------------------------------------------------------------
 0x0000002C	|	0x00020000	
        ''', extra_func=add_spi_device)
    
    assert get_register(dut, 1).value == 0x20000
    assert get_register(dut, 2).value == 21
    assert get_register(dut, 3).value == 3
    assert get_register(dut, 4).value == 22
    assert get_register(dut, 5).value == 1
    assert assert_registers_zero(dut, 6)

@cocotb.test()
async def test_spi_program(dut):

    async def add_spi_device():
        tmp_spi = SpiFlashPeripheral(SpiBus.from_entity(dut,
                                                cs_name='out0'), {}, 
                                                dut, name='tmp_spi1')

        async def tmp(first_byte):
            # return the byte + 1
            await tmp_spi.shift2(8, first_byte + 1)

        tmp_spi.custom_func = tmp

    bytes = load_binary('binaries/test_spi.bin')
    ram_chip, flash_chip = await run_program(dut, memory=bytes, 
                                             extra_func=add_spi_device)

    # ram_chip.dump_memory2()

    # return value of the function
    assert get_register(dut, 10).value == 0xab + 1

@cocotb.test()
async def test_program1(dut):

    bytes = load_binary('binaries/test_program.bin')
    ram_chip, flash_chip = await run_program(dut, memory=bytes)

    # ram_chip.dump_memory2()

    # return value of the function
    assert get_register(dut, 10).value == 1024

@cocotb.test()
async def test_program3(dut):
    # program sets output pins and reads input pins

    bytes = load_binary('binaries/test_input_output_pins.bin')
    dut.ui_in.value = 0     # initialize inputs to some value, otherwise tests fails

    async def detect_edges():
        halted_signal = RisingEdge(get_halt_signal(dut))
        out0 = get_output_pin(dut, 0)

        out0_rising = RisingEdge(out0)
        out0_falling = FallingEdge(out0)

        rising_edges = 0
        falling_edges = 0
        
        while True:
            tmp_sig = await First(halted_signal, out0_rising, out0_falling)
            if tmp_sig == out0_rising:
                rising_edges += 1

                # set some input values
                set_input_pin(dut, 0, 1)
                set_input_pin(dut, 1, 0)
                set_input_pin(dut, 2, 1)

            elif tmp_sig == out0_falling:
                falling_edges += 1
            else:
                break

        print(rising_edges, falling_edges)

        assert rising_edges == 5
        assert falling_edges == 5

    ram_chip, flash_chip = await run_program(dut, memory=bytes, 
                                            extra_func=detect_edges)

    # ram_chip.dump_memory2()

    # return value is the result of the input pins register
    assert get_register(dut, 10).value == 5

    assert get_output_pin(dut, 0).value == 0
    assert get_output_pin(dut, 1).value == 0
    assert get_output_pin(dut, 2).value == 0
    assert get_output_pin(dut, 3).value == 1

@cocotb.test()
async def test_program4(dut):
    # program sets output pins and reads input pins

    bytes = load_binary('binaries/test_io_pins.bin')
    dut.ui_in.value = 0     # initialize inputs to some value, other tests fails
    dut.uio_in.value = 0

    async def detect_edges():
        halted_signal = RisingEdge(get_halt_signal(dut))
        out0 = get_io_output_pin(dut, 0)

        out0_rising = RisingEdge(out0)
        out0_falling = FallingEdge(out0)

        tmp_sig = await First(halted_signal, out0_rising, out0_falling)
        assert tmp_sig == out0_rising

        await ClockCycles(dut.clk, 1)

        assert get_io_output_pin(dut, 0).value == 1
        assert get_io_output_pin(dut, 1).value == 1
        assert get_io_output_pin(dut, 2).value == 0
        assert get_io_output_pin(dut, 3).value == 0
        assert get_io_output_pin(dut, 4).value == 1

        dut.uio_in.value = 0b10101000

        tmp_sig = await First(halted_signal, out0_rising, out0_falling)
        assert tmp_sig == out0_falling

    ram_chip, flash_chip = await run_program(dut, memory=bytes, 
                                            extra_func=detect_edges)

    # ram_chip.dump_memory2()

    # return value is the result of the input pins register
    assert get_register(dut, 10).value == 4

    assert get_io_output_pin(dut, 0).value == 0
    assert get_io_output_pin(dut, 1).value == 0
    assert get_io_output_pin(dut, 2).value == 0
    assert get_io_output_pin(dut, 3).value == 0
    assert get_io_output_pin(dut, 3).value == 0

@cocotb.test()
async def test_uart_tx_single(dut):

    async def add_uart_device():
        uart_sink = UartSink(dut.uart_tx, baud=baudrate, bits=8)
        await FallingEdge(dut.uart_tx)
        result = await uart_sink.read(1)
        result = [int(val) for val in result][0]

        assert result == 202

    await run_program(dut, '''
0x00000000	|	0x0200A083	|	lw x1, peripherals
0x00000004	|	0x0CA00113	|	addi x2, x0, 202
0x00000008	|	0x00100193	|	addi x3, x0, 1
0x0000000C	|	0x00208A23	|	sb x2, 20(x1)
0x00000010	|	0x00308823	|	sb x3, 16(x1)
-------------------------------------------------------------------------
here:
0x00000014	|	0x01108203	|	lb x4, 17(x1)
0x00000018	|	0xFE321EE3	|	bne x4, x3, here
0x0000001C	|	0x0000006F	|	jal x0, 0
-------------------------------------------------------------------------
Data Dump
-------------------------------------------------------------------------
0x00000024	|	0x00020000	
        ''', extra_func=add_uart_device, timeout_us=2000)

    assert get_register(dut, 1).value == 0x20000
    assert get_register(dut, 2).value == 202
    assert get_register(dut, 3).value == 1
    assert get_register(dut, 4).value == 1
    assert_registers_zero(dut, 5)

@cocotb.test()
async def test_uart_tx_single_flow_control(dut):

    # set as high, so do not expect data to be sent
    dut.ui_in[0].value = 1

    async def add_uart_device():
        uart_sink = UartSink(dut.uart_tx, baud=baudrate, bits=8)

        await RisingEdge(dut.out1)  # wait for signal from program

        # set as low, so send the data
        dut.ui_in[0].value = 0

        result = await uart_sink.read(1)
        result = [int(val) for val in result][0]

        assert result == 202
        print('reached here')

    await run_program(dut, '''
 0x00000000	|	0x03C0A083	|	lw x1, peripherals
 0x00000004	|	0x0CA00113	|	addi x2, x0, 202
 0x00000008	|	0x00500193	|	addi x3, x0, 5
 0x0000000C	|	0x00A00313	|	addi x6, x0, 10
 0x00000010	|	0x00200393	|	addi x7, x0, 2
 0x00000014	|	0x00100413	|	addi x8, x0, 1
 0x00000018	|	0x00208A23	|	sb x2, 20(x1)
 0x0000001C	|	0x00308823	|	sb x3, 16(x1)
-------------------------------------------------------------------------
 	here:
 0x00000020	|	0x01108203	|	lb x4, 17(x1)
 0x00000024	|	0x00629663	|	bne x5, x6, here2
 0x00000028	|	0xFE821CE3	|	bne x4, x8, here
 0x0000002C	|	0x0000006F	|	jal x0, 0
-------------------------------------------------------------------------
 	here2:
 0x00000030	|	0x00128293	|	addi x5, x5, 1
 0x00000034	|	0x00708023	|	sb x7, 0(x1)
 0x00000038	|	0xFE9FF06F	|	jal x0, here
-------------------------------------------------------------------------
 Data Dump
-------------------------------------------------------------------------
 0x00000040	|	0x00020000	
        ''', extra_func=add_uart_device, timeout_us=2000)

    assert get_register(dut, 1).value == 0x20000
    assert get_register(dut, 2).value == 202
    assert get_register(dut, 3).value == 5
    assert get_register(dut, 4).value == 1
    assert get_register(dut, 5).value == 10
    assert get_register(dut, 6).value == 10
    assert get_register(dut, 7).value == 2
    assert get_register(dut, 8).value == 1
    assert_registers_zero(dut, 9)

@cocotb.test()
async def test_uart_tx_multiple(dut):

    async def add_uart_device():
        uart_sink = UartSink(dut.uart_tx, baud=baudrate, bits=8)
        
        all_bytes = []
        
        while len(all_bytes) < 2:
            await FallingEdge(dut.uart_tx)
            result = await uart_sink.read(1)
            result = [int(val) for val in result][0]
            all_bytes.append(result)

        assert all_bytes == [12, 45]

    await run_program(dut, '''
0x00000000	|	0x0340A083	|	lw x1, peripherals
0x00000004	|	0x00C00113	|	addi x2, x0, 12
0x00000008	|	0x00100193	|	addi x3, x0, 1
0x0000000C	|	0x00208A23	|	sb x2, 20(x1)
0x00000010	|	0x00308823	|	sb x3, 16(x1)
-------------------------------------------------------------------------
    here:
0x00000014	|	0x01108203	|	lb x4, 17(x1)
0x00000018	|	0xFE321EE3	|	bne x4, x3, here
0x0000001C	|	0x02D00113	|	addi x2, x0, 45
0x00000020	|	0x00208A23	|	sb x2, 20(x1)
0x00000024	|	0x00308823	|	sb x3, 16(x1)
-------------------------------------------------------------------------
    here2:
0x00000028	|	0x01108203	|	lb x4, 17(x1)
0x0000002C	|	0xFE321EE3	|	bne x4, x3, here2
0x00000030	|	0x0000006F	|	jal x0, 0
-------------------------------------------------------------------------
Data Dump
-------------------------------------------------------------------------
0x00000038	|	0x00020000	|	..
        ''', extra_func=add_uart_device, timeout_us=3000)

    assert get_register(dut, 1).value == 0x20000
    assert get_register(dut, 2).value != 0
    assert get_register(dut, 3).value == 1
    assert get_register(dut, 4).value == 1
    assert_registers_zero(dut, 5)

@cocotb.test()
async def test_program5_uart_tx(dut):
    # program sets output pins and reads input pins

    bytes = load_binary('binaries/test_uart.bin')
    dut.ui_in.value = 0     # initialize inputs to some value, other tests fails
    dut.uio_in.value = 0
    dut.ui_in[7].value = 1  # must set to high initially, otherwise this would trigger uart rx

    async def add_uart_device():
        uart_sink = UartSink(dut.uart_tx, baud=baudrate, bits=8)
        
        all_bytes = []
        
        while len(all_bytes) < 5:
            await FallingEdge(dut.uart_tx)
            result = await uart_sink.read(1)
            result = [int(val) for val in result][0]
            all_bytes.append(result)

        byte_array = bytearray(all_bytes)
        result_string = byte_array.decode('utf-8')
        assert result_string == 'hello'

    ram_chip, flash_chip = await run_program(dut, memory=bytes, 
                                            extra_func=add_uart_device)


@cocotb.test()
async def test_uart_rx_single (dut):

    async def add_uart_device():

        uart_sink = UartSource(dut.uart_rx, baud=baudrate, bits=8)
        await RisingEdge(dut.out0)  # wait to go high first before starting to send

        await uart_sink.write([0b10101010])
        
    await run_program(dut, '''
 0x00000000	|	0x0200A083	|	lw x1, peripherals
 0x00000004	|	0x00200113	|	addi x2, x0, 2
 0x00000008	|	0x00100193	|	addi x3, x0, 1
 0x0000000C	|	0x00308023	|	sb x3, 0(x1)
-------------------------------------------------------------------------
 	wait_for_rx:
 0x00000010	|	0x01108183	|	lb x3, 17(x1)
 0x00000014	|	0xFE219EE3	|	bne x3, x2, wait_for_rx
 0x00000018	|	0x0150C203	|	lbu x4, 21(x1)
 0x0000001C	|	0x0000006F	|	jal x0, 0
-------------------------------------------------------------------------
 Data Dump
-------------------------------------------------------------------------
 0x00000024	|	0x00020000	|	..
        ''', extra_func=add_uart_device, timeout_us=3000)

    assert get_register(dut, 1).value == 0x20000
    assert get_register(dut, 2).value == 2
    assert get_register(dut, 3).value == 2
    assert get_register(dut, 4).value == 0xaa
    assert_registers_zero(dut, 5)
    

@cocotb.test()
async def test_uart_rx_multiple(dut):

    async def add_uart_device():

        uart_sink = UartSource(dut.uart_rx, baud=baudrate, bits=8)
        await RisingEdge(dut.out0)  # wait to go high first before starting to send

        await uart_sink.write([0b10101010])

        await FallingEdge(dut.out0)

        await RisingEdge(dut.out0)

        await uart_sink.write([0b01100110])

        
    await run_program(dut, '''
 0x00000000	|	0x0440A083	|	lw x1, peripherals
 0x00000004	|	0x00200113	|	addi x2, x0, 2
 0x00000008	|	0x00100193	|	addi x3, x0, 1
 0x0000000C	|	0x00308023	|	sb x3, 0(x1)
-------------------------------------------------------------------------
 	wait_for_rx:
 0x00000010	|	0x01108203	|	lb x4, 17(x1)
 0x00000014	|	0xFE221EE3	|	bne x4, x2, wait_for_rx
 0x00000018	|	0x00008023	|	sb x0, 0(x1)
 0x0000001C	|	0x0150C283	|	lbu x5, 21(x1)
 0x00000020	|	0x00008023	|	sb x0, 0(x1)
 0x00000024	|	0x00208823	|	sb x2, 16(x1)
 0x00000028	|	0x00008823	|	sb x0, 16(x1)
 0x0000002C	|	0x00308023	|	sb x3, 0(x1)
-------------------------------------------------------------------------
 	wait_for_rx_2:
 0x00000030	|	0x01108203	|	lb x4, 17(x1)
 0x00000034	|	0xFE221EE3	|	bne x4, x2, wait_for_rx_2
 0x00000038	|	0x00008023	|	sb x0, 0(x1)
 0x0000003C	|	0x0150C303	|	lbu x6, 21(x1)
 0x00000040	|	0x0000006F	|	jal x0, 0
-------------------------------------------------------------------------
 Data Dump
-------------------------------------------------------------------------
 0x00000048	|	0x00020000	|	..
        ''', extra_func=add_uart_device, timeout_us=3000)

    assert get_register(dut, 1).value == 0x20000
    assert get_register(dut, 2).value == 2
    assert get_register(dut, 3).value == 1
    assert get_register(dut, 4).value == 2
    assert get_register(dut, 5).value == 0xaa
    assert get_register(dut, 6).value == 0x66
    assert_registers_zero(dut, 7)


@cocotb.test()
async def test_uart_rx_flow_control (dut):

    dut.ui_in[0].value = 0

    async def add_uart_device():

        uart_sink = UartSource(dut.uart_rx, baud=baudrate, bits=8)
        await RisingEdge(dut.out0)  # wait to go high first before starting to send

        await uart_sink.write([0b10101010])
        assert dut.out0.value == 1
        await FallingEdge(dut.out0)

        await RisingEdge(dut.out0)  # wait to go high again
        await uart_sink.write([0b11110011])

        await FallingEdge(dut.out0)
        
    await run_program(dut, '''
 0x00000000	|	0x0480A083	|	lw x1, peripherals
 0x00000004	|	0x00200113	|	addi x2, x0, 2
 0x00000008	|	0x00100193	|	addi x3, x0, 1
 0x0000000C	|	0x00400313	|	addi x6, x0, 4
 0x00000010	|	0x00308023	|	sb x3, 0(x1)
 0x00000014	|	0x00608823	|	sb x6, 16(x1)
-------------------------------------------------------------------------
 	wait_for_rx:
 0x00000018	|	0x01108183	|	lb x3, 17(x1)
 0x0000001C	|	0xFE219EE3	|	bne x3, x2, wait_for_rx
 0x00000020	|	0x0150C203	|	lbu x4, 21(x1)
 0x00000024	|	0x00000193	|	addi x3, x0, 0
 0x00000028	|	0x00600313	|	addi x6, x0, 6
 0x0000002C	|	0x00608823	|	sb x6, 16(x1)
 0x00000030	|	0x00400313	|	addi x6, x0, 4
 0x00000034	|	0x00608823	|	sb x6, 16(x1)
-------------------------------------------------------------------------
 	wait_for_rx2:
 0x00000038	|	0x01108183	|	lb x3, 17(x1)
 0x0000003C	|	0xFE219EE3	|	bne x3, x2, wait_for_rx2
 0x00000040	|	0x0150C283	|	lbu x5, 21(x1)
 0x00000044	|	0x0000006F	|	jal x0, 0
-------------------------------------------------------------------------
 Data Dump
-------------------------------------------------------------------------
 0x0000004C	|	0x00020000
        ''', extra_func=add_uart_device, timeout_us=3000)

    assert get_register(dut, 1).value == 0x20000
    assert get_register(dut, 2).value == 2
    assert get_register(dut, 3).value == 2
    assert get_register(dut, 4).value == 0xaa
    assert get_register(dut, 6).value == 4
    assert_registers_zero(dut, 7)
    

@cocotb.test()
async def test_blinky(dut):
    # program sets output pins and reads input pins

    bytes = load_binary('binaries/test_blinky.bin')
    ram_chip, flash_chip = await run_program(dut, memory=bytes)
    
    assert dut.out0.value == 1
    assert dut.out3.value == 1