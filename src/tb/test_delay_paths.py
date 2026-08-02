import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge


async def reset_dut(dut, cycles=3):
    dut.iRST.value = 0
    await Timer(15, unit="ns")
    dut.iRST.value = 1
    for _ in range(cycles):
        await RisingEdge(dut.iCLK)


@cocotb.test()
async def test_nominal_no_glitch(dut):
    """At nominal 100 MHz, no TRC channel should report an error."""
    clock = Clock(dut.iCLK, 10, unit="ns")   # 10 ns = 100 MHz
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    for _ in range(20):
        await RisingEdge(dut.iCLK)

    dut._log.info(f"oTRC_ERR (nominal) = {dut.oTRC_ERR.value}")
    assert dut.oTRC_ERR.value == 0, (
        f"Expected no glitch at nominal clock, got oTRC_ERR={dut.oTRC_ERR.value}. "
        "If this fails, the delay chain lengths (192/144/96/48 inverters) "
        "need to be re-tuned against your target clock period -- this is "
        "exactly the 'vGlitch' calibration step described in the Black Hat "
        "TRC reference."
    )


@cocotb.test()
async def test_glitch_injection(dut):
    """Speeding the clock up drastically should trip at least one TRC channel."""
    clock = Clock(dut.iCLK, 10, unit="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)
    for _ in range(10):
        await RisingEdge(dut.iCLK)

    fast_clock = Clock(dut.iCLK, 1, unit="ns")   # 1 ns = 1 GHz (way too fast)
    cocotb.start_soon(fast_clock.start())

    for _ in range(30):
        await RisingEdge(dut.iCLK)

    dut._log.info(f"oTRC_ERR (during glitch) = {dut.oTRC_ERR.value}")
    assert dut.oTRC_ERR.value != 0, (
        "Expected at least one TRC channel to trip under a severe "
        "overclocking glitch, but oTRC_ERR stayed 0000."
    )
