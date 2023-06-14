SETLOCAL EnableDelayedExpansion

call F:/Xilinx/Vivado/2022.1/bin/xvlog -sv ../rtl/dat_mem.sv ../rtl/top_level_4_260.sv ../tb/Lab_4_260_tb.sv  -L uvm   || exit /b !ERRORLEVEL!
call F:/Xilinx/Vivado/2022.1/bin/xelab Lab_4_260_tb --snapshot Lab_4_260_tb -log elaborate.log --debug typical         || exit /b !ERRORLEVEL!
call F:/Xilinx/Vivado/2022.1/bin/xsim Lab_4_260_tb --tclbatch xsim_cfg.tcl                                             || exit /b !ERRORLEVEL!