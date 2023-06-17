SETLOCAL EnableDelayedExpansion

call F:/Xilinx/Vivado/2022.1/bin/xvlog -sv ../rtl/dat_mem.sv ../rtl/top_level_4_260.sv ../tb/uvm_lab4.sv  -L uvm          || exit /b !ERRORLEVEL!
call F:/Xilinx/Vivado/2022.1/bin/xelab uvm_top_tb --snapshot uvm_top_tb -log elaborate.log --debug typical                || exit /b !ERRORLEVEL!
call F:/Xilinx/Vivado/2022.1/bin/xsim uvm_top_tb --tclbatch xsim_cfg.tcl                                                  || exit /b !ERRORLEVEL!