# UVM

[From here](https://verificationguide.com/uvm/uvm-testbench-architecture/)

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