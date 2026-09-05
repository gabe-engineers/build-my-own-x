# Specs

Supports 9 bits for addressing memory. Word addressable only (not byte addressable), word size is 16 bits.
 
Number of registers: 8 16-bit registers

# Instruction Set Architecture

- LDI rd immediate
- LOAD rd addr
- STORE rs addr
- ADD rd r1 r2
- SUB rd r1 r2
- SHL rd r1 r2
- SHR rd r1 r2
- MUL rd r1 r2
- AND rd r1 r2
- OR rd r1 r2
- XOR rd r1 r2
- CMP r1 r2
- MOV rd r1
- JMP addr
- JZ addr
- HALT


## Instruction Format

Every instruction is 16-bits wide. The first 4 bits are always the Opcode, the rest of the bits are interpreted based on the Opcode and can be of 5 different types.

### 1 Register and 1 Memory Address

LOAD and STORE instructions have this type. The format is `OP r addr` standing for the register destination/start and the memory address for the operation.


| Bits           | 15:12  | 11:9     | 8:0            |
| -------------- | ------ | -------- | -------------- |
| Interpretation | Opcode | Register | Memory address |


### 3 Register Operations

Instructions like ADD, SUB, SHL, SHR, MUL, AND, OR and XOR us this instruction format.


| Bits           | 15:12  | 11:9     | 8:6            | 5:3 | 2:0 |
| -------------- | ------ | -------- | -------------- | ---- | ----|
| Interpretation | Opcode | Destination Register | Operand register 1 | Operand register 2 | Unused |


### 2 Register Operations

Instructions like CMP and MOV use two registers as input.

| Bits           | 15:12  | 11:9     | 8:6            | 5: 0 |
| -------------- | ------ | -------- | -------------- | ---- |
| Interpretation | Opcode | Operand register 1 | Operand register 2 | Unused |


### 1 Memory Address

Instructions like JMP and JZ use only 1 memory address as input.

| Bits           | 15:12  | 11:0 |
| -------------- | ------ | -------- |
| Interpretation | Opcode | Memory Address |

### 1 Register and 1 immediate

LDI uses the 1 register and 1 immediate format.


| Bits           | 15:12  | 11:9                 | 8:0       |
| -------------- | ------ | -------------------- | --------- |
| Interpretation | Opcode | Destination register | Immediate |

