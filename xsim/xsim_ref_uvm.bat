SETLOCAL EnableDelayedExpansion

call F:/Xilinx/Vivado/2022.1/bin/xvlog -sv ../tb/ref_uvm_design.sv  -L uvm                                           || exit /b !ERRORLEVEL!
call F:/Xilinx/Vivado/2022.1/bin/xelab ref_uvm_tb --snapshot ref_uvm_tb -log elaborate.log --debug typical           || exit /b !ERRORLEVEL!
call F:/Xilinx/Vivado/2022.1/bin/xsim ref_uvm_tb --tclbatch xsim_cfg.tcl                                             || exit /b !ERRORLEVEL!