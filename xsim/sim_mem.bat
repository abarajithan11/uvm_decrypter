SETLOCAL EnableDelayedExpansion

call F:/Xilinx/Vivado/2022.1/bin/xvlog -sv ../tb/mem_test.sv  -L uvm                                                    || exit /b !ERRORLEVEL!
call F:/Xilinx/Vivado/2022.1/bin/xelab tbench_top --snapshot tbench_top -log elaborate.log --debug typical           || exit /b !ERRORLEVEL!
call F:/Xilinx/Vivado/2022.1/bin/xsim tbench_top --tclbatch xsim_cfg.tcl                                             || exit /b !ERRORLEVEL!