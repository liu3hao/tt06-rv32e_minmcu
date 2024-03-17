# SPDX-FileCopyrightText: © 2023 Uri Shaked <uri@tinytapeout.com>
# SPDX-License-Identifier: MIT

import cocotb
from helpers import get_register, load_binary, assert_registers_zero, run_program

@cocotb.test()
async def test_addi_add(dut):
    # addi x1, x1, 1000
    # addi x2, x1, 2000
    # addi x3, x3, -1000
    # add x4, x2, x3

    await run_program(dut, '''
        3e808093
        7d008113
        c1818193
        00310233
        0000006f
        ''')

    assert get_register(dut, 1).value == 1000
    assert get_register(dut, 2).value == 3000
    assert get_register(dut, 3).value.signed_integer == -1000
    assert get_register(dut, 4).value == 2000
    assert_registers_zero(dut, 5)

@cocotb.test()
async def test_slt(dut):
    # addi x1, x1, -1000
    # addi x2, x2, -500
    # slt x3, x1, x2
    # slt x4, x2, x1

    await run_program(dut, '''
        c1808093
        e0c10113
        0020a1b3
        00112233
        0000006f
    ''')

    assert get_register(dut, 1).value.signed_integer == -1000
    assert get_register(dut, 2).value.signed_integer == -500
    assert get_register(dut, 3).value == 1
    assert get_register(dut, 4).value == 0
    assert_registers_zero(dut, 5)

@cocotb.test()
async def test_sltu(dut):
    # addi x1, x1, 100
    # addi x2, x2, 200
    # sltu x3, x1, x2
    # sltu x4, x2, x1
    await run_program(dut, '''
        06408093
        0c810113
        0020b1b3
        00113233
        0000006f
    ''')

    assert get_register(dut, 1).value == 100
    assert get_register(dut, 2).value == 200
    assert get_register(dut, 3).value == 1
    assert get_register(dut, 4).value == 0
    assert_registers_zero(dut, 5)

@cocotb.test()
async def test_xor(dut):
    # addi x1, x1, 100
    # addi x2, x2, 200
    # xor x3, x1, x2
    # xor x4, x2, x1
    await run_program(dut, '''
        06408093
        0c810113
        0020c1b3
        00114233
        0000006f
    ''')

    assert get_register(dut, 1).value == 100
    assert get_register(dut, 2).value == 200
    assert get_register(dut, 3).value == 172
    assert get_register(dut, 4).value == 172
    assert_registers_zero(dut, 5)

@cocotb.test()
async def test_srli_srl(dut):
    # addi x1, x1, 100
    # addi x2, x2, 200
    # srli x3, x1, 2
    # srli x4, x2, 4
    await run_program(dut, '''
        06408093
        0c810113
        0020d193
        00415213
        0000006f
        ''')

    assert get_register(dut, 1).value == 100
    assert get_register(dut, 2).value == 200
    assert get_register(dut, 3).value == 25
    assert get_register(dut, 4).value == 12
    assert_registers_zero(dut, 5)

@cocotb.test()
async def test_srai_sra(dut):
    # addi x1, x1, 100
    # addi x2, x2, -200
    # srai x3, x1, 2
    # srai x4, x2, 4
    await run_program(dut, '''
        06408093
        f3810113
        4020d193
        40415213
        0000006f
        ''')

    assert get_register(dut, 1).value == 100
    assert get_register(dut, 2).value.signed_integer == -200
    assert get_register(dut, 3).value == 25
    assert get_register(dut, 4).value.signed_integer == -13
    assert_registers_zero(dut, 5)

@cocotb.test()
async def test_ori(dut):
    # addi x1, x1, 100
    # addi x2, x2, 7
    # ori x3, x1, 20
    # ori x4, x2, 1

    await run_program(dut, '''
        06408093
        00710113
        0140e193
        00116213
        0000006f
                      ''')

    assert get_register(dut, 1).value == 100
    assert get_register(dut, 2).value == 7
    assert get_register(dut, 3).value == 116
    assert get_register(dut, 4).value == 7
    assert_registers_zero(dut, 5)

@cocotb.test()
async def test_andi(dut):
    # addi x1, x1, 20
    # andi x2, x1, 0xf0
    # and x3, x1, x2

    await run_program(dut, '''
        01408093
        0f00f113
        0020f1b3
        0000006f
        ''')

    assert get_register(dut, 1).value == 20
    assert get_register(dut, 2).value == 16
    assert get_register(dut, 3).value == 16
    assert_registers_zero(dut, 5)

@cocotb.test()
async def test_load(dut):
    # lw x1, 32(x0)
    # lw x2, 36(x0)
    # lb x3, 33(x0)
    # lb x4, 32(x0)
    # ret
        
    await run_program(dut, '''
        02002083
        02402103
        02100183
        02000203
        0000006f
        0
        0
        0
        55779922
        11223344
        0
        ''')

    assert get_register(dut, 1).value == 0x55779922
    assert get_register(dut, 2).value == 0x11223344
    assert get_register(dut, 3).value == 0xffffff99
    assert get_register(dut, 4).value == 0x22
    assert_registers_zero(dut, 5)


@cocotb.test()
async def test_load_lb_lbu(dut):
    # lb x1, 33(x0)
    # lbu x2, 33(x0)
    await run_program(dut, '''
        02100083
        02104103
        0000006f
        0
        0
        0
        0
        0
        55779988
        11223344
    ''')

    assert get_register(dut, 1).value == 0xffffff99
    assert get_register(dut, 2).value == 0x99
    assert_registers_zero(dut, 3)

@cocotb.test()
async def test_load_lh_lhu(dut):
    # lh x1, 33(x0)
    # lhu x2, 33(x0)
    await run_program(dut, '''
        02101083
        02105103
        0000006f
        0
        0
        0
        0
        0
        55997788
        11223344
    ''')

    assert get_register(dut, 1).value == 0xffff9977
    assert get_register(dut, 2).value == 0x9977
    assert_registers_zero(dut, 3)

@cocotb.test()
async def test_load_lw(dut):
    # lw x1, 33(x0)
    # lw x2, 32(x0)
    # lw x3, 31(x0)
    await run_program(dut, '''
        02102083
        02002103
        01f02183 
        0000006f
        0
        0
        0
        0
        55997788
        11223344
    ''')

    assert get_register(dut, 1).value == 0x44559977
    assert get_register(dut, 2).value == 0x55997788
    assert get_register(dut, 3).value == 0x99778800
    assert_registers_zero(dut, 4)

@cocotb.test()
async def test_store_sw(dut):
    # lw x1, 32(x0)   
    # addi x2, x2, 1234
    # addi x8, x8, 10
    # sw x2, 0(x1)
    # sw x2, 8(x1)
    # ret
        
    ram_chip, flash = await run_program(dut, '''
        02002083
        4d210113
        00a40413
        0020a023
        0020a423
        0000006f
        0
        0
        01000000
        ''')

    assert get_register(dut, 1).value == 0x01000000
    assert get_register(dut, 2).value == 1234
    assert get_register(dut, 8).value == 10 # Make sure this is not changed
    assert ram_chip.get_value(0, 4) == 1234
    assert ram_chip.get_value(8, 4) == 1234
    assert_registers_zero(dut, 3, 7)
    assert_registers_zero(dut, 9)

@cocotb.test()
async def test_store_sb(dut):
    # lw x1, 32(x0)
    # addi x2, x2, 1234
    # sb x2, 0(x1)
    # sb x2, 8(x1)
        
    ram_chip, flash = await run_program(dut, '''
        02002083
        4d210113
        00208023
        00208423
        0000006f
        0
        0
        0
        01000000
        ''')

    assert get_register(dut, 1).value == 0x01000000
    assert get_register(dut, 2).value == 1234
    assert ram_chip.get_value(0, 1) == 0xD2
    assert ram_chip.get_value(8, 1) == 0xD2
    assert_registers_zero(dut, 3)

@cocotb.test()
async def test_store_sh(dut):
    # lw x1, 32(x0)
    # addi x2, x2, 1234
    # sh x2, 0(x1)
    # sh x2, 8(x1)
        
    ram_chip, flash = await run_program(dut, '''
        02002083
        4d210113
        00209023
        00209423
        0000006f
        0
        0
        0
        01000000
        ''')

    assert get_register(dut, 1).value == 0x01000000
    assert get_register(dut, 2).value == 1234
    assert ram_chip.get_value(0, 2) == 0x4D2
    assert ram_chip.get_value(8, 2) == 0x4D2
    assert_registers_zero(dut, 3)

@cocotb.test()
async def test_store_and_load(dut):
    # lw x1, 28(x0)
    # addi x2, x2, 1234
    # sw x2, 0(x1)
    # sw x2, 8(x1)
    # lw x3, 0(x1)
    # lb x4, 0(x1)
        
    ram_chip, flash = await run_program(dut, '''
        01c02083
        4d210113
        0020a023
        0020a423
        0000a183
        00008203
        0000006f
        01000000
        0
        0
        ''')

    assert get_register(dut, 1).value == 0x01000000
    assert get_register(dut, 2).value == 1234
    assert get_register(dut, 3).value == 1234
    assert (get_register(dut, 4).value) & 0xff == 0xd2
    assert get_register(dut, 4).value.signed_integer == -46

    assert ram_chip.get_value(0, 4) == 1234
    assert ram_chip.get_value(8, 4) == 1234

    assert_registers_zero(dut, 5)

@cocotb.test()
async def test_jal(dut):
    # addi x1, x1, 10
    # addi x2, x2, 20
    # jal x8, 24
    # addi x3, x3, 30
    # addi x4, x4, 40
    # addi x5, x5, 50
    # addi x6, x6, 60
    # addi x7, x7, 70
        
    await run_program(dut, '''
        00a08093
        01410113
        0100046f
        01e18193
        02820213
        03228293
        03c30313
        04638393
        0000006f
        ''')

    assert get_register(dut, 1).value == 10
    assert get_register(dut, 2).value == 20
    assert get_register(dut, 3).value == 0
    assert get_register(dut, 4).value == 0
    assert get_register(dut, 5).value == 0
    assert get_register(dut, 6).value == 60
    assert get_register(dut, 7).value == 70
    assert get_register(dut, 8).value == 12
    assert_registers_zero(dut, 9)

@cocotb.test()
async def test_jalr(dut):
    # addi x1, x1, 10
    # addi x2, x2, 20
    # jalr x8, 24(x0)
    # addi x3, x3, 30
    # addi x4, x4, 40
    # addi x5, x5, 50
    # addi x6, x6, 60
    # addi x7, x7, 70
        
    await run_program(dut, '''
        00a08093
        01410113
        01800467
        01e18193
        02820213
        03228293
        03c30313
        04638393
        0000006f
        ''')

    assert get_register(dut, 1).value == 10
    assert get_register(dut, 2).value == 20
    assert get_register(dut, 3).value == 0
    assert get_register(dut, 4).value == 0
    assert get_register(dut, 5).value == 0
    assert get_register(dut, 6).value == 60
    assert get_register(dut, 7).value == 70
    assert get_register(dut, 8).value == 12
    assert_registers_zero(dut, 9)

@cocotb.test()
async def test_lui_auipc(dut):
    # addi x1, x1, 10
    # lui x2, 0x12345
    # lui x3, 0x123
    # auipc x4, 8
    # auipc x5, 12
        
    await run_program(dut, '''
        00a08093
        12345137
        001231b7
        00008217
        0000c297
        0000006f
        ''')

    assert get_register(dut, 1).value == 10
    assert get_register(dut, 2).value == 0x12345000
    assert get_register(dut, 3).value == 0x123000
    assert get_register(dut, 4).value == 0x8000 + 12
    assert get_register(dut, 5).value == 0xc000 + 16
    assert_registers_zero(dut, 6)

@cocotb.test()
async def test_beq(dut):
    # addi x1, x0, 1000
    # addi x2, x2, 10
    # beq  x1, x2, 8
    # addi x3, x3, 10
    # beq  x2, x3, 12
    # addi x4, x4, 20
    # addi x5, x5, 30
    # addi x6, x6, 40

    await run_program(dut, '''
        3E800093
        00A10113
        00208463 
        00A18193
        00310663
        01420213
        01E28293
        02830313
        0000006f
        ''')

    assert get_register(dut, 1).value == 1000
    assert get_register(dut, 2).value == 10
    assert get_register(dut, 3).value == 10
    assert get_register(dut, 4).value == 0
    assert get_register(dut, 5).value == 0
    assert get_register(dut, 6).value == 40
    assert_registers_zero(dut, 7)

@cocotb.test()
async def test_bne(dut):
    # addi x1, x0, 1000
    # addi x2, x2, 10
    # bne  x1, x2, 8
    # addi x3, x3, 10
    # bne  x2, x3, 12
    # addi x4, x4, 20
    # addi x5, x5, 30
    # addi x6, x6, 40

    await run_program(dut, '''
        3E800093
        00A10113
        00209463
        00A18193
        00311663
        01420213
        01E28293
        02830313
        0000006f
        ''')

    assert get_register(dut, 1).value == 1000
    assert get_register(dut, 2).value == 10
    assert get_register(dut, 3).value == 0
    assert get_register(dut, 4).value == 0
    assert get_register(dut, 5).value == 0
    assert get_register(dut, 6).value == 40
    assert_registers_zero(dut, 7)

@cocotb.test()
async def test_bge(dut):
    # addi x1, x0, -10
    # addi x2, x2, 10
    # bge  x1, x2, 8
    # bge  x2, x1, 8
    # addi x3, x0, 10
    # addi x4, x0, 20

    await run_program(dut, '''
        FF600093
        00A10113
        0020D463
        00115463
        00A00193
        01400213	
        0000006f
        ''')

    assert get_register(dut, 1).value.signed_integer == -10
    assert get_register(dut, 2).value == 10
    assert get_register(dut, 3).value == 0
    assert get_register(dut, 4).value == 20
    assert_registers_zero(dut, 5)

@cocotb.test()
async def test_bgeu(dut):
    # addi x1, x0,  -10
    # addi x2, x2,  10
    # bgeu x1, x2,  8
    # addi x3, x0,  10
    # bgeu x2, x1,  8
    # addi x4, x0,  20
    # addi x5, x0,  30

    await run_program(dut, '''
        FF600093
        00A10113
        0020F463
        00A00193
        00117463
        01400213
        01E00293	
        0000006f
        ''')

    assert get_register(dut, 1).value.signed_integer == -10
    assert get_register(dut, 2).value == 10
    assert get_register(dut, 3).value == 0
    assert get_register(dut, 4).value == 20
    assert get_register(dut, 5).value == 30
    assert_registers_zero(dut, 6)

@cocotb.test()
async def test_blt(dut):
    # addi x1 , x0,-10
    # addi x2, x2, 10
    # blt  x1, x2,  8
    # addi x3, x0, 10
    # blt  x2, x1, 8
    # addi x4, x0, 20
    # addi x5, x0, 30

    await run_program(dut, '''
        FF600093
        00A10113
        0020C463
        00A00193
        00114463
        01400213
        01E00293	
        0000006f
        ''')

    assert get_register(dut, 1).value.signed_integer == -10
    assert get_register(dut, 2).value == 10
    assert get_register(dut, 3).value == 0
    assert get_register(dut, 4).value == 20
    assert get_register(dut, 5).value == 30
    assert_registers_zero(dut, 6)

@cocotb.test()
async def test_bltu(dut):
    # addi x1, x0, -10
    # addi x2, x2, 10
    # bltu x1, x2,  8
    # addi x3, x0, 10
    # bltu x2, x1, 8
    # addi x4, x0, 20
    # addi x5, x0, 30

    await run_program(dut, '''
        FF600093
        00A10113
        0020E463
        00A00193
        00116463
        01400213
        01E00293	
        0000006f
        ''')

    assert get_register(dut, 1).value.signed_integer == -10
    assert get_register(dut, 2).value == 10
    assert get_register(dut, 3).value == 10
    assert get_register(dut, 4).value == 0
    assert get_register(dut, 5).value == 30
    assert_registers_zero(dut, 6)

@cocotb.test()
async def test_script1(dut):

    bytes = load_binary('binaries/hello2.bin')
    ram_chip, flash_chip = await run_program(dut, memory=bytes)

    ram_chip.dump_memory2()

    # return value of the function
    assert get_register(dut, 10).value == 1024

# TODO add more tests..
    
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