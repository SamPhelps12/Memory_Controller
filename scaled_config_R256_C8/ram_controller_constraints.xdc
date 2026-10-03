## Minimal constraints for ram_controller (top module), targeting xc7a100tcsg324-1
## No physical board attached -- only a clock constraint is defined so Vivado
## can perform meaningful timing analysis against the intended 100 MHz target.
## All other ports (reset, ce, req, rw, addr, Qi, ready, Qa_out) are left
## unconstrained -- Vivado will report them as such; this is expected and
## harmless without a physical board to pin them to.

create_clock -name clk -period 10.000 [get_ports clk]
