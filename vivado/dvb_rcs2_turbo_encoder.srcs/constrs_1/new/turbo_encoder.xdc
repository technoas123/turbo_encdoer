# ============================================================
# turbo_encoder.xdc
# Production timing constraints for DVB-RCS2 Turbo Encoder
# Target device: xc7a35tcsg324-1 (Artix-7 35T, CSG324, speed -1)
# Clock: 100 MHz
# I/O standard: LVCMOS33 (typical for Artix-7 development boards)
#
# NOTE: These constraints use realistic placeholder values for a board-level
# implementation. Update the input/output delay numbers once the exact source
# and load devices, trace lengths, and clocking topology are known.
# ============================================================

# ------------------------------------------------------------------
# 1. Primary clock
# ------------------------------------------------------------------
# 100 MHz clock arrives at a clock-capable pin. The waveform is 50/50 duty.
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports clk]

# ------------------------------------------------------------------
# 2. Clock uncertainty
# ------------------------------------------------------------------
# Clock uncertainty models the difference between the ideal clock used during
# synthesis and the real clock seen by the FPGA:
#   - PLL/MMCM phase error
#   - Clock distribution (BUFG) skew
#   - Period jitter and cycle-to-cycle jitter
#   - Process/voltage/temperature margin
#
# A 200 ps setup uncertainty and 100 ps hold uncertainty are conservative
# starting points for a 100 MHz design using the FPGA's internal PLL/BUFG.
set_clock_uncertainty -setup 0.200 [get_clocks sys_clk]
set_clock_uncertainty -hold  0.100 [get_clocks sys_clk]

# ------------------------------------------------------------------
# 3. Asynchronous reset
# ------------------------------------------------------------------
# rst_n is assumed to be asynchronous assert, synchronous release inside the
# RTL (the RTL synchronises it if needed). The pad-to-FF path is not timed.
set_false_path -from [get_ports rst_n]

# ------------------------------------------------------------------
# 4. Input delay constraints
# ------------------------------------------------------------------
# System-synchronous inputs: data and clock come from the same clock domain
# at the board level. The values below assume:
#   - Source clock-to-Q max = 2.0 ns
#   - Source clock-to-Q min = 0.5 ns
#   - Board trace delay max = 0.5 ns
#   - Board trace delay min = 0.2 ns
#   - Some clock skew margin absorbed into the numbers
#
# max delay = source Tcko_max + board trace_max
# min delay = source Tcko_min + board trace_min
set_input_delay -clock sys_clk -max 2.5 [get_ports {s_axis_tvalid s_axis_tdata[*] s_axis_tlast}]
set_input_delay -clock sys_clk -min 0.7 [get_ports {s_axis_tvalid s_axis_tdata[*] s_axis_tlast}]

# ------------------------------------------------------------------
# 5. Output delay constraints
# ------------------------------------------------------------------
# Downstream device requirements (system-synchronous):
#   - Downstream setup time = 1.5 ns
#   - Downstream hold time  = 0.5 ns
#   - Board trace delay max = 0.5 ns
#   - Board trace delay min = 0.2 ns
#
# max delay = downstream Tsu + board trace_max
# min delay = downstream Thd - board trace_min (can be negative)
set_output_delay -clock sys_clk -max 2.0 [get_ports {m_axis_tvalid m_axis_tdata[*] m_axis_tlast}]
set_output_delay -clock sys_clk -min -0.3 [get_ports {m_axis_tvalid m_axis_tdata[*] m_axis_tlast}]

# ------------------------------------------------------------------
# 6. I/O standard and drive properties (generic LVCMOS33)
# ------------------------------------------------------------------
set_property IOSTANDARD LVCMOS33 [get_ports {clk rst_n s_axis_tvalid s_axis_tdata s_axis_tlast m_axis_tvalid m_axis_tdata m_axis_tlast}]
set_property DRIVE 12 [get_ports {m_axis_tvalid m_axis_tdata m_axis_tlast}]

# ------------------------------------------------------------------
# 7. Pin planning (UNCOMMENT and fill in for a specific board)
# ------------------------------------------------------------------
# Example below uses Basys 3 / Nexys A7 style 100 MHz clock and reset buttons.
# Replace with your board's master XDC pin assignments.
#
# set_property PACKAGE_PIN W5  [get_ports clk]
# set_property PACKAGE_PIN U18 [get_ports rst_n]   ;# BTNC on Nexys A7
# set_property PACKAGE_PIN V17 [get_ports {s_axis_tdata[0]}]
# ... (add remaining pins) ...

# ------------------------------------------------------------------
# 8. Additional checks (optional but recommended for product quality)
# ------------------------------------------------------------------
# Report unconstrained endpoints during implementation review:
#   report_clock_interaction
#   report_timing_summary
#   check_timing
