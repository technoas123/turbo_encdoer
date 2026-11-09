# AD9361-compatible clock (max sample clock)
create_clock -period 16.276 -name sys_clk [get_ports clk]

# ---------------------------------------------------------------------------
# IOB packing (keep - still helps pad timing)
# ---------------------------------------------------------------------------
set_property IOB TRUE [get_ports m_axis_tdata[*]]
set_property IOB TRUE [get_ports m_axis_tvalid]
set_property IOB TRUE [get_ports m_axis_tlast]
set_property IOB TRUE [get_ports s_axis_tready]

# ---------------------------------------------------------------------------
# Board-level I/O delays @ 61.44 MHz
# (relaxed vs 100 MHz; adjust if you have a real timing budget to AD9361/FPGA)
# ---------------------------------------------------------------------------
# Outputs: encoder → next stage / DMA
set_output_delay -clock sys_clk -max 2.0 [get_ports m_axis_tdata[*]]
set_output_delay -clock sys_clk -max 2.0 [get_ports m_axis_tvalid]
set_output_delay -clock sys_clk -max 2.0 [get_ports m_axis_tlast]
set_output_delay -clock sys_clk -max 2.0 [get_ports s_axis_tready]

set_output_delay -clock sys_clk -min -0.5 [get_ports m_axis_tdata[*]]
set_output_delay -clock sys_clk -min -0.5 [get_ports m_axis_tvalid]
set_output_delay -clock sys_clk -min -0.5 [get_ports m_axis_tlast]
set_output_delay -clock sys_clk -min -0.5 [get_ports s_axis_tready]

# Inputs: upstream → encoder
set_input_delay  -clock sys_clk -max 2.0 [get_ports s_axis_tdata[*]]
set_input_delay  -clock sys_clk -max 2.0 [get_ports s_axis_tvalid]
set_input_delay  -clock sys_clk -max 2.0 [get_ports s_axis_tlast]
set_input_delay  -clock sys_clk -max 2.0 [get_ports m_axis_tready]

set_input_delay  -clock sys_clk -min 0.0 [get_ports s_axis_tdata[*]]
set_input_delay  -clock sys_clk -min 0.0 [get_ports s_axis_tvalid]
set_input_delay  -clock sys_clk -min 0.0 [get_ports s_axis_tlast]
set_input_delay  -clock sys_clk -min 0.0 [get_ports m_axis_tready]