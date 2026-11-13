"""lldb side of the sideload JIT on iOS 26 TXM devices (docs/04 section 8.1). DevJIT builds only.

Same protocol as StikDebug's universal.js: the core runs `mov x16, #1; brk #0xf00d` with x0 = 0 and x1 = size
(Cores/shared/Jit26.c). This stop hook asks debugserver for an RX region (`_M<size>,rx`), rewrites one byte per
16 KiB page through debugserver so the page may run, returns the address in x0, steps over the brk and continues.

Xcode: add `command script import <repo>/scripts/jit26_lldb.py` to ~/.lldbinit-Xcode, then Run the DevJIT scheme.
Command line: `command script import scripts/jit26_lldb.py` before attaching (the hook sits on the dummy target).
"""
import lldb

PAGE = 0x4000
BRK_F00D = 0xD4200000 | (0xF00D << 5)


def _packet(debugger, text):
    result = lldb.SBCommandReturnObject()
    debugger.GetCommandInterpreter().HandleCommand("process plugin packet send '%s'" % text, result)
    for line in (result.GetOutput() or "").splitlines():
        line = line.strip()
        if line.startswith("response:"):
            return line[len("response:"):].strip()
    return ""


def prepare_region(debugger, addr, size):
    """A fresh RX region when addr is 0, then each page touched through debugserver. Returns its address or 0."""
    if addr == 0:
        reply = _packet(debugger, "_M%x,rx" % size)
        try:
            addr = int(reply, 16) if reply and not reply.startswith("E") else 0
        except ValueError:
            addr = 0
    if addr:
        for offset in range(0, size, PAGE):
            byte = _packet(debugger, "m%x,1" % (addr + offset))
            if len(byte) != 2 or _packet(debugger, "M%x,1:%s" % (addr + offset, byte)) != "OK":
                return 0
    return addr


class Jit26StopHook:
    def __init__(self, target, extra_args, internal_dict):
        pass

    def handle_stop(self, exe_ctx, stream):
        process, frame = exe_ctx.GetProcess(), exe_ctx.GetThread().GetFrameAtIndex(0)
        error = lldb.SBError()
        pc = frame.GetPC()
        if process.ReadUnsignedFromMemory(pc, 4, error) != BRK_F00D or error.Fail():
            return True  # Not ours: stop as usual.
        reg = lambda name: frame.FindRegister(name).GetValueAsUnsigned()
        command, addr, size = reg("x16"), reg("x0"), reg("x1")
        if command == 1 and size:
            addr = prepare_region(exe_ctx.GetTarget().GetDebugger(), addr, size)
            frame.FindRegister("x0").SetValueFromCString("0x%x" % addr, error)
            stream.Print("jit26: region 0x%x size 0x%x\n" % (addr, size))
        frame.SetPC(pc + 4)  # 0 (detach) and unknown commands: step over and stay attached.
        return False


def __lldb_init_module(debugger, internal_dict):
    debugger.HandleCommand("target stop-hook add -P %s.Jit26StopHook" % __name__)
