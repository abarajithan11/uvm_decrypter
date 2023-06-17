SETLOCAL EnableDelayedExpansion

call F:/Xilinx/Vivado/2022.1/bin/xvlog -sv ../rtl/dat_mem.sv ../rtl/top_level_4_260.sv ../tb/basic_tb.sv  -L uvm   || exit /b !ERRORLEVEL!
call F:/Xilinx/Vivado/2022.1/bin/xelab basic_tb --snapshot basic_tb -log elaborate.log --debug typical      || exit /b !ERRORLEVEL!
call F:/Xilinx/Vivado/2022.1/bin/xsim basic_tb --tclbatch xsim_cfg.tcl                                      || exit /b !ERRORLEVEL!