# ============================================================
# turbo_encoder.xdc
# Timing constraints for DVB-RCS2 Turbo Encoder
# Target device: xc7a35tcsg324-1 (Artix-7 35T, CSG324, speed -1)
# ============================================================

# --- Primary clock: 100 MHz (10 ns period) ---
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports clk]

# --- Reset: asynchronous release; SDC can't time it, so exclude ---
set_false_path -from [get_ports rst_n]

# --- Input delays (placeholder - replace with board/device numbers later) ---
set_input_delay -clock sys_clk -max 2.0 [get_ports {in_valid in_couple[*] blk_size_N[*] arp_p[*] arp_Q0[*] arp_Q1[*] arp_Q2[*] arp_Q3[*]}]
set_input_delay -clock sys_clk -min 0.5 [get_ports {in_valid in_couple[*] blk_size_N[*] arp_p[*] arp_Q0[*] arp_Q1[*] arp_Q2[*] arp_Q3[*]}]

# --- Output delays ---
set_output_delay -clock sys_clk -max 0.5 [get_ports {out_valid out_symbol[*] out_done in_ready}]
set_output_delay -clock sys_clk -min 0.0 [get_ports {out_valid out_symbol[*] out_done in_ready}]

# ============================================================
# PIN PLANNING (uncomment ONLY if you have a physical board
# and know its master XDC pin list - otherwise leave commented)
# ============================================================
# set_property PACKAGE_PIN W5   [get_ports clk]
# set_property IOSTANDARD LVCMOS33 [get_ports clk]
# set_property PACKAGE_PIN U18  [get_ports rst_n]
# set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
# ...(add the rest from your board's master XDC)...