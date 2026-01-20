#!/usr/bin/env python3
"""
Generate test programs for the Multi-Core MESI Simulator
"""

import os

OPCODES = {
    'add': 0, 'sub': 1, 'and': 2, 'or': 3, 'xor': 4, 'mul': 5,
    'sll': 6, 'sra': 7, 'srl': 8,
    'beq': 9, 'bne': 10, 'blt': 11, 'bgt': 12, 'ble': 13, 'bge': 14,
    'jal': 15, 'lw': 16, 'sw': 17,
    'halt': 21
}

def encode_instruction(opcode, rd, rs, rt, imm):
    op = OPCODES.get(opcode, opcode) if isinstance(opcode, str) else opcode
    if imm < 0:
        imm = imm & 0xFFF
    return ((op & 0xFF) << 24) | ((rd & 0xF) << 20) | ((rs & 0xF) << 16) | \
           ((rt & 0xF) << 12) | (imm & 0xFFF)

def write_imem(filename, instructions):
    with open(filename, 'w') as f:
        for inst in instructions:
            f.write(f'{inst:08X}\n')

def generate_mulserial(output_dir):
    """Simple: load two values, multiply, store result"""
    os.makedirs(output_dir, exist_ok=True)
    
    core0 = [
        encode_instruction('lw', 2, 0, 0, 0),    # R2 = MEM[0]
        encode_instruction('lw', 3, 0, 1, 4),    # R3 = MEM[4]
        encode_instruction('mul', 4, 2, 3, 0),   # R4 = R2 * R3
        encode_instruction('sw', 4, 0, 1, 8),    # MEM[8] = R4
        encode_instruction('halt', 0, 0, 0, 0),
    ]
    write_imem(os.path.join(output_dir, 'imem0.txt'), core0)
    
    halt_only = [encode_instruction('halt', 0, 0, 0, 0)]
    for i in range(1, 4):
        write_imem(os.path.join(output_dir, f'imem{i}.txt'), halt_only)
    
    with open(os.path.join(output_dir, 'memin.txt'), 'w') as f:
        f.write('00000002\n')  # MEM[0] = 2
        f.write('00000000\n')
        f.write('00000000\n')
        f.write('00000000\n')
        f.write('00000003\n')  # MEM[4] = 3
    
    print(f"Generated mulserial in {output_dir}")

if __name__ == '__main__':
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    generate_mulserial(os.path.join(base_dir, 'tests', 'mulserial'))
