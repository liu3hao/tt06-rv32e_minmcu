# SPDX-FileCopyrightText: © 2023 Uri Shaked <uri@tinytapeout.com>
# SPDX-License-Identifier: MIT

import cocotb
from helpers import run_program

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
        ''')

    assert dut.cpu1.reg1.r1.value == 1000
    assert dut.cpu1.reg1.r2.value == 3000
    assert dut.cpu1.reg1.r3.value.signed_integer == -1000
    assert dut.cpu1.reg1.r4.value == 2000

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
    ''')

    assert dut.cpu1.reg1.r1.value.signed_integer == -1000
    assert dut.cpu1.reg1.r2.value.signed_integer == -500
    assert dut.cpu1.reg1.r3.value == 1
    assert dut.cpu1.reg1.r4.value == 0

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
    ''')

    assert dut.cpu1.reg1.r1.value == 100
    assert dut.cpu1.reg1.r2.value == 200
    assert dut.cpu1.reg1.r3.value == 1
    assert dut.cpu1.reg1.r4.value == 0

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
    ''')

    assert dut.cpu1.reg1.r1.value == 100
    assert dut.cpu1.reg1.r2.value == 200
    assert dut.cpu1.reg1.r3.value == 172
    assert dut.cpu1.reg1.r4.value == 172

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
        ''')

    assert dut.cpu1.reg1.r1.value == 100
    assert dut.cpu1.reg1.r2.value == 200
    assert dut.cpu1.reg1.r3.value == 25
    assert dut.cpu1.reg1.r4.value == 12

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
        ''')

    assert dut.cpu1.reg1.r1.value == 100
    assert dut.cpu1.reg1.r2.value.signed_integer == -200
    assert dut.cpu1.reg1.r3.value == 25
    assert dut.cpu1.reg1.r4.value.signed_integer == -13

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
                      ''')

    assert dut.cpu1.reg1.r1.value == 100
    assert dut.cpu1.reg1.r2.value == 7
    assert dut.cpu1.reg1.r3.value == 116
    assert dut.cpu1.reg1.r4.value == 7

@cocotb.test()
async def test_andi(dut):
    # addi x1, x1, 20
    # andi x2, x1, 0xf0
    # and x3, x1, x2

    await run_program(dut, '''
        01408093
        0f00f113
        0020f1b3
        ''')

    assert dut.cpu1.reg1.r1.value == 20
    assert dut.cpu1.reg1.r2.value == 16
    assert dut.cpu1.reg1.r3.value == 16

@cocotb.test()
async def test_load(dut):
    # lw x1, 16(x0)
    # lw x2, 20(x0)
    # lb x3, 17(x0)
    # lb x4, 16(x0)
        
    await run_program(dut, '''
        01002083
        01402103
        01100183
        01000203 
        55997788
        11223344
        0
        ''', max_reads=8)

    assert dut.cpu1.reg1.r1.value == 0x55997788
    assert dut.cpu1.reg1.r2.value == 0x11223344
    assert dut.cpu1.reg1.r3.value == 0xffffff99
    assert dut.cpu1.reg1.r4.value == 0x55


@cocotb.test()
async def test_load_lb_lbu(dut):
    # lb x1, 33(x0)
    # lbu x2, 33(x0)
    await run_program(dut, '''
        02100083
        02104103
        0
        0
        0
        0
        0
        0
        55997788
        11223344
    ''', max_reads=5)

    assert dut.cpu1.reg1.r1.value == 0xffffff99
    assert dut.cpu1.reg1.r2.value == 0x99

@cocotb.test()
async def test_load_lh_lhu(dut):
    # lh x1, 33(x0)
    # lhu x2, 33(x0)
    await run_program(dut, '''
        02101083
        02105103
        0
        0
        0
        0
        0
        0
        55997788
        11223344
    ''', max_reads=5)

    assert dut.cpu1.reg1.r1.value == 0xffff9977
    assert dut.cpu1.reg1.r2.value == 0x9977

@cocotb.test()
async def test_load_lw(dut):
    # lw x1, 33(x0)
    # lw x2, 32(x0)
    # lw x3, 31(x0)
    await run_program(dut, '''
        02102083
        02002103
        01f02183 
        0
        0
        0
        0
        0
        55997788
        11223344
    ''', max_reads=7)

    assert dut.cpu1.reg1.r1.value == 0x99778811
    assert dut.cpu1.reg1.r2.value == 0x55997788
    assert dut.cpu1.reg1.r3.value == 0x00559977

@cocotb.test()
async def test_store_sw(dut):
    # lw x1, 16(x0)
    # addi x2, x2, 1234
    # sw x2, 0(x1)
    # sw x2, 8(x1)
        
    ram_chip, flash = await run_program(dut, '''
        01002083
        4d210113
        0020a023
        0020a423
        01000000
        0
        0
        ''', max_reads=6)

    assert dut.cpu1.reg1.r1.value == 0x01000000
    assert dut.cpu1.reg1.r2.value == 1234
    assert ram_chip.get_value(0, 4) == 1234
    assert ram_chip.get_value(8, 4) == 1234

@cocotb.test()
async def test_store_sb(dut):
    # lw x1, 16(x0)
    # addi x2, x2, 1234
    # sb x2, 0(x1)
    # sb x2, 8(x1)
        
    ram_chip, flash = await run_program(dut, '''
        01002083
        4d210113
        00208023
        00208423
        01000000
        0
        0
        ''', max_reads=6)

    assert dut.cpu1.reg1.r1.value == 0x01000000
    assert dut.cpu1.reg1.r2.value == 1234
    assert ram_chip.get_value(0, 1) == 0xD2
    assert ram_chip.get_value(8, 1) == 0xD2

@cocotb.test()
async def test_store_sh(dut):
    # lw x1, 16(x0)
    # addi x2, x2, 1234
    # sh x2, 0(x1)
    # sh x2, 8(x1)
        
    ram_chip, flash = await run_program(dut, '''
        01002083
        4d210113
        00209023
        00209423
        01000000
        0
        0
        ''', max_reads=6)

    assert dut.cpu1.reg1.r1.value == 0x01000000
    assert dut.cpu1.reg1.r2.value == 1234
    assert ram_chip.get_value(0, 2) == 0x4D2
    assert ram_chip.get_value(8, 2) == 0x4D2

@cocotb.test()
async def test_store_and_load(dut):
    # lw x1, 28(x0)
    # addi x2, x2, 1234
    # sw x2, 0(x1)
    # sw x2, 8(x1)
    # lw x3, 0(x1)
    # lb x4, 3(x1)
        
    ram_chip, flash = await run_program(dut, '''
        01c02083
        4d210113
        0020a023
        0020a423
        0000a183
        00308203
        0
        01000000
        0
        0
        ''', max_reads=10)

    assert dut.cpu1.reg1.r1.value == 0x01000000
    assert dut.cpu1.reg1.r2.value == 1234
    assert dut.cpu1.reg1.r3.value == 1234
    assert (dut.cpu1.reg1.r4.value) & 0xff == 0xd2
    assert dut.cpu1.reg1.r4.value.signed_integer == -46

    assert ram_chip.get_value(0, 4) == 1234
    assert ram_chip.get_value(8, 4) == 1234

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
        ''', max_reads=5)

    assert dut.cpu1.reg1.r1.value == 10
    assert dut.cpu1.reg1.r2.value == 20
    assert dut.cpu1.reg1.r3.value == 0
    assert dut.cpu1.reg1.r4.value == 0
    assert dut.cpu1.reg1.r5.value == 0
    assert dut.cpu1.reg1.r6.value == 60
    assert dut.cpu1.reg1.r7.value == 70
    assert dut.cpu1.reg1.r8.value == 12

@cocotb.test()
async def test_jalr(dut):
    # addi x1, x1, 10
    # addi x2, x2, 20
    # jalr x8, 24(x1)
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
        ''', max_reads=5)

    assert dut.cpu1.reg1.r1.value == 10
    assert dut.cpu1.reg1.r2.value == 20
    assert dut.cpu1.reg1.r3.value == 0
    assert dut.cpu1.reg1.r4.value == 0
    assert dut.cpu1.reg1.r5.value == 0
    assert dut.cpu1.reg1.r6.value == 60
    assert dut.cpu1.reg1.r7.value == 70
    assert dut.cpu1.reg1.r8.value == 12

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