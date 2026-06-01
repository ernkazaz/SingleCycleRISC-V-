# ==============================================================================
# Cocotb Testbench: Single Cycle RISC-V Processor (RV32I)
#
# Mirrors the structure of the ARM testbench from EE446.
# Contains a Python performance model that executes the same instruction stream
# as the HDL design and compares register file + PC after every clock cycle.
#
# DUT top-level expected ports:
#   clk, rst
#   PC          [31:0]  output
#
# DUT hierarchy expected (adjust paths to match your top-level module):
#   dut.my_datapath.Reg_file      — Register_file submodule inside Datapath
#
# Register file submodule expected ports (used for comparison):
#   Debug_Source_select [4:0] input  — drives which register appears on Debug_out
#   Debug_out           [31:0] output
#
# Termination condition: instruction word == 32'h00000000 (all-zero NOP / halt)
# Success condition    : x31 == 0x600D  after halt
# ==============================================================================

import logging
import cocotb
from tabulate import tabulate
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer


# ─────────────────────────────────────────────────────────────────────────────
# Tiny byte-addressable memory model (mirrors HDL Memory module)
# ─────────────────────────────────────────────────────────────────────────────
class ByteMemory:
    def __init__(self, size=1024):
        self.mem = bytearray(size)

    def write_byte(self, addr, val):
        self.mem[addr & (len(self.mem)-1)] = val & 0xFF

    def write_half(self, addr, val):
        self.write_byte(addr,   val & 0xFF)
        self.write_byte(addr+1, (val >> 8) & 0xFF)

    def write_word(self, addr, val):
        for i in range(4):
            self.write_byte(addr+i, (val >> (8*i)) & 0xFF)

    def read_byte_u(self, addr):
        return self.mem[addr & (len(self.mem)-1)]

    def read_byte_s(self, addr):
        v = self.read_byte_u(addr)
        return v if v < 0x80 else v - 0x100

    def read_half_u(self, addr):
        return self.read_byte_u(addr) | (self.read_byte_u(addr+1) << 8)

    def read_half_s(self, addr):
        v = self.read_half_u(addr)
        return v if v < 0x8000 else v - 0x10000

    def read_word(self, addr):
        return (self.read_byte_u(addr)   |
                (self.read_byte_u(addr+1) << 8)  |
                (self.read_byte_u(addr+2) << 16) |
                (self.read_byte_u(addr+3) << 24))


# ─────────────────────────────────────────────────────────────────────────────
# Helper: sign-extend a value from 'bits' wide to 32-bit Python int
# ─────────────────────────────────────────────────────────────────────────────
def sign_ext(val, bits):
    val = val & ((1 << bits) - 1)
    if val >> (bits - 1):
        val -= (1 << bits)
    return val


# ─────────────────────────────────────────────────────────────────────────────
# Helper: mask to 32-bit unsigned
# ─────────────────────────────────────────────────────────────────────────────
def u32(val):
    return val & 0xFFFF_FFFF


# ─────────────────────────────────────────────────────────────────────────────
# Read hex file: each line is 4 space-separated little-endian bytes
# Returns list of 32-bit unsigned integers (one per instruction word)
# ─────────────────────────────────────────────────────────────────────────────
def read_hex_file(path):
    words = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split()
            assert len(parts) == 4, f"Unexpected hex line format: {line!r}"
            b0, b1, b2, b3 = [int(p, 16) for p in parts]
            words.append(b0 | (b1 << 8) | (b2 << 16) | (b3 << 24))
    return words


# ─────────────────────────────────────────────────────────────────────────────
# RISC-V instruction field decoder
# ─────────────────────────────────────────────────────────────────────────────
class RV32Instr:
    def __init__(self, word):
        self.word   = word
        self.opcode = word & 0x7F
        self.rd     = (word >> 7)  & 0x1F
        self.funct3 = (word >> 12) & 0x7
        self.rs1    = (word >> 15) & 0x1F
        self.rs2    = (word >> 20) & 0x1F
        self.funct7 = (word >> 25) & 0x7F

        # I-type immediate
        self.imm_i = sign_ext(word >> 20, 12)

        # S-type immediate
        self.imm_s = sign_ext(((word >> 25) << 5) | ((word >> 7) & 0x1F), 12)

        # B-type immediate
        b_imm = (((word >> 31) & 1) << 12 |
                 ((word >>  7) & 1) << 11 |
                 ((word >> 25) & 0x3F) << 5 |
                 ((word >>  8) & 0xF)  << 1)
        self.imm_b = sign_ext(b_imm, 13)

        # U-type immediate (already shifted to upper 20 bits)
        self.imm_u = word & 0xFFFFF000

        # J-type immediate
        j_imm = (((word >> 31) & 1)    << 20 |
                 ((word >> 12) & 0xFF)  << 12 |
                 ((word >> 20) & 1)     << 11 |
                 ((word >> 21) & 0x3FF) << 1)
        self.imm_j = sign_ext(j_imm, 21)

    def log(self, logger):
        logger.debug(
            "   INSTR 0x%08X | op=0x%02X f3=%d f7=0x%02X "
            "rd=x%d rs1=x%d rs2=x%d",
            self.word, self.opcode, self.funct3, self.funct7,
            self.rd, self.rs1, self.rs2
        )


# ─────────────────────────────────────────────────────────────────────────────
# Performance model + DUT wrapper
# ─────────────────────────────────────────────────────────────────────────────
class TB:
    # Opcodes
    OP_REG   = 0b011_0011
    OP_IMM   = 0b001_0011
    OP_LOAD  = 0b000_0011
    OP_STORE = 0b010_0011
    OP_BRANCH= 0b110_0011
    OP_JAL   = 0b110_1111
    OP_JALR  = 0b110_0111
    OP_LUI   = 0b011_0111
    OP_AUIPC = 0b001_0111

    def __init__(self, instr_words, dut):
        self.dut    = dut
        self.instrs = instr_words
        self.logger = logging.getLogger("RISCV_PerfModel")
        self.logger.setLevel(logging.DEBUG)

        # Architectural state
        self.PC  = 0
        self.RF  = [0] * 32     # x0..x31; x0 always 0
        self.mem = ByteMemory(1024)

        self.cycle = 0
        self.errors = 0

    # ── Register write (enforces x0==0) ──────────────────────────────
    def write_reg(self, rd, val):
        if rd != 0:
            self.RF[rd] = u32(val)

    # ── Read DUT register via Debug port ─────────────────────────────
    async def read_dut_reg(self, reg_idx):
        self.dut.my_datapath.Reg_file.Debug_Source_select.value = reg_idx
        await Timer(1, unit='ps')   # Delta delay only: allows combinational logic to settle in 0-time
        return int(self.dut.my_datapath.Reg_file.Debug_out.value)

    # ── Compare Python model vs DUT after every clock edge ───────────
    async def compare(self):
        self.logger.debug("── Cycle %d  PC_model=0x%08X ──", self.cycle, self.PC)
        dut_pc = int(self.dut.PC.value)

        log_rows = [["PC", f"0x{self.PC:08X}", f"0x{dut_pc:08X}",
                     "✓" if self.PC == dut_pc else "✗ MISMATCH"]]

        pc_ok = (self.PC == dut_pc)
        reg_ok = True

        for i in range(32):
            exp = self.RF[i]
            got = await self.read_dut_reg(i)
            match = (exp == got)
            if not match:
                reg_ok = False
            log_rows.append([
                f"x{i}", f"0x{exp:08X}", f"0x{got:08X}",
                "✓" if match else "✗ MISMATCH"
            ])

        table = tabulate(log_rows,
                         headers=["Signal", "Expected", "DUT", "Status"],
                         tablefmt="github")
        self.logger.debug("\n%s", table)

        if not pc_ok:
            self.logger.error("CYCLE %d: PC mismatch! expected=0x%08X got=0x%08X",
                              self.cycle, self.PC, dut_pc)
            self.errors += 1
        if not reg_ok:
            self.logger.error("CYCLE %d: Register file mismatch!", self.cycle)
            self.errors += 1

        assert pc_ok,   f"PC mismatch at cycle {self.cycle}"
        assert reg_ok,  f"Register file mismatch at cycle {self.cycle}"

    # ── Execute one instruction in the Python model ───────────────────
    def step(self):
        self.cycle += 1
        idx  = self.PC >> 2
        word = self.instrs[idx]
        ins  = RV32Instr(word)
        ins.log(self.logger)

        next_pc = u32(self.PC + 4)   # default: advance normally

        op = ins.opcode

        # ── R-type ────────────────────────────────────────────────
        if op == self.OP_REG:
            a = self.RF[ins.rs1]
            b = self.RF[ins.rs2]
            sa = a if a < 0x8000_0000 else a - 0x1_0000_0000  # signed view
            sb = b if b < 0x8000_0000 else b - 0x1_0000_0000

            f3, f7 = ins.funct3, ins.funct7
            if   f3 == 0b000 and f7 == 0b000_0000: res = u32(a + b)        # ADD
            elif f3 == 0b000 and f7 == 0b010_0000: res = u32(a - b)        # SUB
            elif f3 == 0b001:                       res = u32(a << (b&31))  # SLL
            elif f3 == 0b010:                       res = 1 if sa < sb else 0  # SLT
            elif f3 == 0b011:                       res = 1 if a  < b  else 0  # SLTU
            elif f3 == 0b100:                       res = u32(a ^ b)        # XOR
            elif f3 == 0b101 and f7 == 0b000_0000: res = a >> (b&31)       # SRL
            elif f3 == 0b101 and f7 == 0b010_0000: res = u32(sa >> (b&31)) # SRA
            elif f3 == 0b110:                       res = u32(a | b)        # OR
            elif f3 == 0b111:                       res = u32(a & b)        # AND
            else:
                self.logger.error("Unknown R-type funct3=%d funct7=%d", f3, f7)
                assert False
            self.write_reg(ins.rd, res)

        # ── I-type ALU ────────────────────────────────────────────
        elif op == self.OP_IMM:
            a   = self.RF[ins.rs1]
            imm = ins.imm_i
            sa  = a if a < 0x8000_0000 else a - 0x1_0000_0000
            f3  = ins.funct3
            f7  = ins.funct7  # for SRAI vs SRLI
            shamt = ins.rs2   # bits [24:20] of instruction

            if   f3 == 0b000: res = u32(a + imm)                                  # ADDI
            elif f3 == 0b001: res = u32(a << (shamt & 31))                                # SLLI
            elif f3 == 0b010: res = 1 if sa < imm else 0                                  # SLTI
            elif f3 == 0b011: res = 1 if a < u32(imm) else 0                              # SLTIU
            elif f3 == 0b100: res = u32(a ^ imm)                                          # XORI
            elif f3 == 0b101 and f7 == 0b000_0000:
                res = a >> (shamt & 31)                                                    # SRLI
            elif f3 == 0b101 and f7 == 0b010_0000:
                res = u32(sa >> (shamt & 31))                                              # SRAI
            elif f3 == 0b110: res = u32(a | imm)                                          # ORI
            elif f3 == 0b111: res = u32(a & imm)                                          # ANDI
            else:
                self.logger.error("Unknown I-ALU funct3=%d", f3)
                assert False
            self.write_reg(ins.rd, res)

        # ── Load ──────────────────────────────────────────────────
        elif op == self.OP_LOAD:
            addr = u32(self.RF[ins.rs1] + ins.imm_i)
            f3   = ins.funct3
            if   f3 == 0b000: res = u32(self.mem.read_byte_s(addr))   # LB
            elif f3 == 0b001: res = u32(self.mem.read_half_s(addr))   # LH
            elif f3 == 0b010: res = u32(self.mem.read_word(addr))     # LW
            elif f3 == 0b100: res = self.mem.read_byte_u(addr)        # LBU
            elif f3 == 0b101: res = self.mem.read_half_u(addr)        # LHU
            else:
                self.logger.error("Unknown load funct3=%d", f3)
                assert False
            self.write_reg(ins.rd, res)

        # ── Store ─────────────────────────────────────────────────
        elif op == self.OP_STORE:
            addr = u32(self.RF[ins.rs1] + ins.imm_s)
            val  = self.RF[ins.rs2]
            f3   = ins.funct3
            if   f3 == 0b000: self.mem.write_byte(addr, val)   # SB
            elif f3 == 0b001: self.mem.write_half(addr, val)   # SH
            elif f3 == 0b010: self.mem.write_word(addr, val)   # SW
            else:
                self.logger.error("Unknown store funct3=%d", f3)
                assert False

        # ── Branch ────────────────────────────────────────────────
        elif op == self.OP_BRANCH:
            a  = self.RF[ins.rs1]; b  = self.RF[ins.rs2]
            sa = a if a < 0x8000_0000 else a - 0x1_0000_0000
            sb = b if b < 0x8000_0000 else b - 0x1_0000_0000
            f3 = ins.funct3
            taken = False
            if   f3 == 0b000: taken = (a == b)     # BEQ
            elif f3 == 0b001: taken = (a != b)     # BNE
            elif f3 == 0b100: taken = (sa < sb)    # BLT
            elif f3 == 0b101: taken = (sa >= sb)   # BGE
            elif f3 == 0b110: taken = (a < b)      # BLTU
            elif f3 == 0b111: taken = (a >= b)     # BGEU
            else:
                self.logger.error("Unknown branch funct3=%d", f3)
                assert False
            if taken:
                next_pc = u32(self.PC + ins.imm_b)

        # ── JAL ───────────────────────────────────────────────────
        elif op == self.OP_JAL:
            self.write_reg(ins.rd, next_pc)          # rd = PC+4
            next_pc = u32(self.PC + ins.imm_j)

        # ── JALR ──────────────────────────────────────────────────
        elif op == self.OP_JALR:
            ret     = next_pc                        # PC+4
            next_pc = u32((self.RF[ins.rs1] + ins.imm_i) & ~1)
            self.write_reg(ins.rd, ret)

        # ── LUI ───────────────────────────────────────────────────
        elif op == self.OP_LUI:
            self.write_reg(ins.rd, u32(ins.imm_u))

        # ── AUIPC ─────────────────────────────────────────────────
        elif op == self.OP_AUIPC:
            self.write_reg(ins.rd, u32(self.PC + ins.imm_u))

        else:
            self.logger.error("Unknown opcode 0x%02X at PC=0x%08X", op, self.PC)
            assert False, f"Unknown opcode 0x{op:02X}"

        self.PC = next_pc

    # ── Main test loop ────────────────────────────────────────────────
    async def run_test(self):
        # Execute first instruction in model, then sync with first clock edge
        self.step()
        await RisingEdge(self.dut.clk)
        await FallingEdge(self.dut.clk)
        await self.compare()

        # Run until the halt word (all-zero NOP) is the current instruction
        while self.instrs[self.PC >> 2] != 0:
            self.step()
            await RisingEdge(self.dut.clk)
            await FallingEdge(self.dut.clk)
            await self.compare()

        # ── Final check: x31 must be 0x600D (success flag) ───────────
        x31_model = self.RF[31]
        x31_dut   = await self.read_dut_reg(31)
        SUCCESS   = 0x000000CE

        self.logger.info("=" * 60)
        if x31_model == SUCCESS and x31_dut == SUCCESS:
            self.logger.info("ALL TESTS PASSED   ✓   x31=0x%08X", SUCCESS)
        else:
            self.logger.error("FINAL CHECK FAILED — x31 model=0x%08X dut=0x%08X "
                              "(expected 0x%08X)", x31_model, x31_dut, SUCCESS)
        self.logger.info("=" * 60)

        assert x31_model == SUCCESS, \
            f"Performance model did not reach SUCCESS (x31=0x{x31_model:08X})"
        assert x31_dut == SUCCESS, \
            f"DUT did not reach SUCCESS (x31=0x{x31_dut:08X})"
        assert self.errors == 0, \
            f"{self.errors} mismatch(es) detected during simulation"


# ─────────────────────────────────────────────────────────────────────────────
# Cocotb test entry point
# ─────────────────────────────────────────────────────────────────────────────
@cocotb.test()
async def riscv_single_cycle_test(dut):
    # Start 10 ns clock (100 MHz)
    Clock(dut.clk, 10, unit="ns").start()

    # Synchronous reset
    dut.rst.value = 1
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst.value = 0
    await FallingEdge(dut.clk)

    instr_words = read_hex_file("Instructions.hex")

    tb = TB(instr_words, dut)
    await tb.run_test()