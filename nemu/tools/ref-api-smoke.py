#!/usr/bin/env python3

import argparse
import ctypes
import sys

DIFFTEST_TO_DUT = 0
DIFFTEST_TO_REF = 1


class Riscv32CPUState(ctypes.Structure):
    _fields_ = [
        ("gpr", ctypes.c_uint32 * 32),
        ("pc", ctypes.c_uint32),
    ]


def require_symbol(lib, name):
    try:
        return getattr(lib, name)
    except AttributeError:
        print(f"missing exported symbol: {name}", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Smoke-test NEMU REF DiffTest APIs")
    parser.add_argument("ref_so", help="path to NEMU REF shared object")
    parser.add_argument("--reset-vector", type=lambda x: int(x, 0), default=0x80000000)
    args = parser.parse_args()

    lib = ctypes.CDLL(args.ref_so)

    difftest_init = require_symbol(lib, "difftest_init")
    difftest_memcpy = require_symbol(lib, "difftest_memcpy")
    difftest_regcpy = require_symbol(lib, "difftest_regcpy")
    difftest_exec = require_symbol(lib, "difftest_exec")
    require_symbol(lib, "difftest_raise_intr")

    difftest_init.argtypes = [ctypes.c_int]
    difftest_memcpy.argtypes = [ctypes.c_uint32, ctypes.c_void_p, ctypes.c_size_t, ctypes.c_bool]
    difftest_regcpy.argtypes = [ctypes.c_void_p, ctypes.c_bool]
    difftest_exec.argtypes = [ctypes.c_uint64]

    difftest_init(0)

    state = Riscv32CPUState()
    difftest_regcpy(ctypes.byref(state), DIFFTEST_TO_DUT)
    assert state.pc == args.reset_vector, f"unexpected reset pc: 0x{state.pc:08x}"
    assert state.gpr[0] == 0, "x0 is not zero after reset"

    payload = bytes(range(16))
    write_buf = ctypes.create_string_buffer(payload)
    read_buf = ctypes.create_string_buffer(len(payload))
    test_addr = args.reset_vector + 0x100
    difftest_memcpy(test_addr, write_buf, len(payload), DIFFTEST_TO_REF)
    difftest_memcpy(test_addr, read_buf, len(payload), DIFFTEST_TO_DUT)
    assert read_buf.raw == payload, "memory round-trip mismatch"

    difftest_exec(1)
    difftest_regcpy(ctypes.byref(state), DIFFTEST_TO_DUT)
    assert state.pc == args.reset_vector + 4, f"unexpected pc after one step: 0x{state.pc:08x}"
    assert state.gpr[0] == 0, "x0 is not zero after one step"
    assert state.gpr[5] == args.reset_vector, f"unexpected t0 after auipc: 0x{state.gpr[5]:08x}"

    print(
        "REF_API_SMOKE status=pass "
        f"pc=0x{state.pc:08x} "
        f"x0=0x{state.gpr[0]:08x} "
        f"t0=0x{state.gpr[5]:08x} "
        f"mem_addr=0x{test_addr:08x}"
    )


if __name__ == "__main__":
    main()
