# UVM

To run on Windows Powershell using Xilinx Vivado:
```
cd xsim
./xsim_uvm_lab4.bat
```
For other shells, modify commands in batch file

## Result:

```
----------------------------------------------------------------
Name                         Type                    Size  Value
----------------------------------------------------------------
uvm_test_top                 all_test                -     @341
  env                        dec_model_env           -     @354
    dec_agnt                 dec_agent               -     @375
      driver                 dec_driver              -     @417
        rsp_port             uvm_analysis_port       -     @436
        seq_item_port        uvm_seq_item_pull_port  -     @426
      monitor                dec_monitor             -     @394
        item_collected_port  uvm_analysis_port       -     @407
      sequencer              dec_sequencer           -     @446
        rsp_export           uvm_analysis_export     -     @455
        seq_item_export      uvm_seq_item_pull_imp   -     @573
        arbitration_queue    array                   0     -
        lock_queue           array                   0     -
        num_last_reqs        integral                32    'd1
        num_last_rsps        integral                32    'd1
    dec_scb                  dec_scoreboard          -     @384
      item_collected_export  uvm_analysis_imp        -     @590
----------------------------------------------------------------

 - MEM DATA MATCHES, CHECKSUM MATCHES:  44 

 - MEM DATA MATCHES, CHECKSUM MATCHES: 116 

 - MEM DATA MATCHES, CHECKSUM MATCHES:  19

Encoding step: orginal message: uGD`+l7, len:           7, lk:           0, ct:           0
LFSR_ptrn = 39, LFSR_init = 3d 3d
done at time            522995000
Original message: uGD`+l7, Decoded message: uGD`+l7 , len           7

 - DECRYPTION SUCCESSFUL

Encoding step: orginal message: qo06Q, len:           5, lk:           0, ct:           0
LFSR_ptrn = 21, LFSR_init = 03 03
done at time            524985000
Original message: qo06Q, Decoded message: qo06Q , len           5

 - DECRYPTION SUCCESSFUL

Encoding step: orginal message: M~, len:           2, lk:           0, ct:           0
LFSR_ptrn = 33, LFSR_init = 0b 0b
done at time            526975000
Original message: M~, Decoded message: M~ , len           2

 - DECRYPTION SUCCESSFUL


UVM_INFO D:/courses/ece260c/project/tb/uvm_lab4.sv(567) @ 720485000: uvm_test_top [all_test] ---------------------------------------
UVM_INFO D:/courses/ece260c/project/tb/uvm_lab4.sv(568) @ 720485000: uvm_test_top [all_test] ----           TEST PASS           ----
UVM_INFO D:/courses/ece260c/project/tb/uvm_lab4.sv(569) @ 720485000: uvm_test_top [all_test] ---------------------------------------


[UVM/RELNOTES]     1
[UVM/COMP/NAMECHECK]     1
[TEST_DONE]     1
[RNTST]     1

** Report counts by id
UVM_FATAL :    0
UVM_ERROR :    0
UVM_WARNING :    0
UVM_INFO :    7
** Report counts by severity

--- UVM Report Summary ---
```

# UVM Structure

[Step by step guide](https://verificationguide.com/uvm/uvm-testbench-architecture/)

## 1. seq_item

Has attributes needed for a randomized stimulus

- rand addr, w_en, r_en, w_data, r_data
- constraint: r_en != w_en

## 2. sequence #(seq_item)


- body()
  - req = seq_item('req')
  - wait_for_grant()
  - req.randomize()
  - send_request()
  - wait_for_done()


### 2.1. write_sequence #(seq_item)

- uvm_do_with(req, req.w_en == 1)

### 2.2. read_sequence #(seq_item)

- uvm_do_with(req, req.r_en == 1)

### 2.3. write_read_sequence #(seq_item)

- wr_seq
- rd_seq
- body()
  - `uvm_do(wr_seq)
  - `uvm_do(rd_seq)


## 3. sequencer #(seq_item)

## 4. driver #(seq_item)

- interface
- run_phase()
  - seq_item_port.get_next_item(req);
  - drive();                           // custom task
  - seq_item_port.item_done();
- drive()                              // drive inputs of dut
  - if.addr <= addr
  - if (w_en) if.w_en <= w_en; if.w_data <= w_data 
  - if (r_en) if.r_en <= r_en;
  - @(posedge vif.MONITOR.clk);


## 5. monitor

- interface
- uvm_analysis_port #(seq_item) item_collected_port; // decalre analysis port
- seq_item trans_collected;
- run_phase() // sampling logic
  - forever 
    - @(posedge vif.MONITOR.clk); 
    - wait(signals) 
    - do_something...

After sampling, end the sampled transaction packet to the scoreboard using the write method
- item_collected_port.write(trans_collected); 

## 6. agent

- Decalre driver, sequencer, monitor
- build_phase()
  - monitor
  - if (is_active)
    - driver
    - sequencer
- connect_phase()
  - if (is_active)
    - driver.seq_item_port.connect(sequencer.seq_item_export); // connect driver and sequencer

## 7. scoreboard

- build_phase()
  - declare & create analysis port to receive transaction from monitor (item_collected_export)
- write(seq_item pkt)
  - pkt.print();
- run_phase()
  - comparison logic ...

## 8. env

- agent
- scoreboard
- connect_phase()
  - mem_agnt.monitor.item_collected_port.connect(mem_scb.item_collected_export); // Connecti monitor port to scoreboard port

## 9. test

- env
- sequence
- run_phase()
  - seq.start(env.mem_agnt.sequencer);

## 9.1 write_read_test

- build_phase()
  - seq = wr_rd_sequence::type_id::create("seq");
- run_phase()
  - seq.start(env.mem_agnt.sequencer);

## 10. tb_top

- clock_gen
- interface
- dut
- uvm_config_db#(virtual mem_if)::set(uvm_root::get(),"*","vif",intf);
- initial run_test('test_1')