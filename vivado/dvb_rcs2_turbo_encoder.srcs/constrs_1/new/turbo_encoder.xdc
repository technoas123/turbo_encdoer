# 1. Clock Definition (61.44 MHz = 16.276 ns period)
create_clock -name sys_clk -period 16.276 [get_ports aclk]

# 2. Input Delay Constraints (Exact wrapper port names)
set_input_delay -clock sys_clk -max 2.0 [get_ports {aresetn cfg_wave_id[*] s_axis_tdata[*] s_axis_tvalid s_axis_tlast m_axis_tready}]
set_input_delay -clock sys_clk -min 0.0 [get_ports {aresetn cfg_wave_id[*] s_axis_tdata[*] s_axis_tvalid s_axis_tlast m_axis_tready}]

# 3. Output Delay Constraints
set_output_delay -clock sys_clk -max 2.0  [get_ports {m_axis_tdata[*] m_axis_tvalid m_axis_tlast s_axis_tready}]
set_output_delay -clock sys_clk -min -0.5 [get_ports {m_axis_tdata[*] m_axis_tvalid m_axis_tlast s_axis_tready}]

# 4. Standalone Bitstream DRC Overrides (Bypasses unassigned pin errors)
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]