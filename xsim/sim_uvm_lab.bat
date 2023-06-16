SETLOCAL EnableDelayedExpansion

call F:/Xilinx/Vivado/2022.1/bin/xvlog -sv ../rtl/dat_mem.sv ../rtl/top_level_4_260.sv ../tb/uvm_lab4.sv  -L uvm    || exit /b !ERRORLEVEL!
call F:/Xilinx/Vivado/2022.1/bin/xelab tb_top --snapshot tb_top -log elaborate.log --debug typical                  || exit /b !ERRORLEVEL!
call F:/Xilinx/Vivado/2022.1/bin/xsim tb_top --tclbatch xsim_cfg.tcl                                                || exit /b !ERRORLEVEL!