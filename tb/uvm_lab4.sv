`include "uvm_macros.svh"
import uvm_pkg::*;

module decory
  #( parameter ADDR_WIDTH = 2,
     parameter DATA_WIDTH = 8 ) (
    input  logic clk,
    input  logic reset,
    input  logic [ADDR_WIDTH-1:0]  addr,
    input  logic                  wr_en,
    input  logic                  rd_en,
    input  logic [DATA_WIDTH-1:0] wdata,
    output logic [DATA_WIDTH-1:0] rdata
  ); 
  // reg [DATA_WIDTH-1:0] rdata;
  logic [DATA_WIDTH-1:0] dec [2**ADDR_WIDTH];

  always @(posedge reset) 
    for(int i=0;i<2**ADDR_WIDTH;i++) dec[i]=8'hFF;
  always @(posedge clk) 
    if (wr_en)    dec[addr] <= wdata;
  always @(posedge clk)
    if (rd_en) rdata <= dec[addr];

endmodule

//-------------------------------------------------------------------------
//            Interface
//-------------------------------------------------------------------------

interface dec_if(input logic clk,reset);
  
  logic [1:0] addr;
  logic wr_en;
  logic rd_en;
  logic [7:0] wdata;
  logic [7:0] rdata;
  
  clocking driver_cb @(posedge clk);
    default input #1 output #1;
    output addr;
    output wr_en;
    output rd_en;
    output wdata;
    input  rdata;  
  endclocking
  
  clocking monitor_cb @(posedge clk);
    default input #1 output #1;
    input addr;
    input wr_en;
    input rd_en;
    input wdata;
    input rdata;  
  endclocking
  
  modport DRIVER  (clocking driver_cb,input clk,reset);
  modport MONITOR (clocking monitor_cb,input clk,reset);

endinterface

//-------------------------------------------------------------------------
//            Sequence Item
//-------------------------------------------------------------------------

class dec_seq_item extends uvm_sequence_item;
  //data and control fields
  rand bit [1:0] addr;
  rand bit       wr_en;
  rand bit       rd_en;
  rand bit [7:0] wdata;
       bit [7:0] rdata;
  
  //Utility and Field macros
  `uvm_object_utils_begin(dec_seq_item)
    `uvm_field_int(addr,UVM_ALL_ON)
    `uvm_field_int(wr_en,UVM_ALL_ON)
    `uvm_field_int(rd_en,UVM_ALL_ON)
    `uvm_field_int(wdata,UVM_ALL_ON)
  `uvm_object_utils_end
  
  //Constructor
  function new(string name = "dec_seq_item");
    super.new(name);
  endfunction
  
  //constaint, to generate any one among write and read
  constraint wr_rd_c { wr_en != rd_en; }; 
  
endclass

//-------------------------------------------------------------------------
//            Sequencer
//-------------------------------------------------------------------------

class dec_sequencer extends uvm_sequencer#(dec_seq_item);

  `uvm_component_utils(dec_sequencer) 

  //constructor
  function new(string name, uvm_component parent);
    super.new(name,parent);
  endfunction
  
endclass

//-------------------------------------------------------------------------
//            Sequence
//-------------------------------------------------------------------------

class dec_sequence extends uvm_sequence#(dec_seq_item);
  
  `uvm_object_utils(dec_sequence)
  
  //Constructor
  function new(string name = "dec_sequence");
    super.new(name);
  endfunction
  
  `uvm_declare_p_sequencer(dec_sequencer)
  
  // create, randomize and send the item to driver
  virtual task body();
   repeat(2) begin
    req = dec_seq_item::type_id::create("req");
    wait_for_grant();
    req.randomize();
    send_request(req);
    wait_for_item_done();
   end 
  endtask
endclass

// write_sequence - "write" type
class write_sequence extends uvm_sequence#(dec_seq_item);
  
  `uvm_object_utils(write_sequence)
   
  //Constructor
  function new(string name = "write_sequence");
    super.new(name);
  endfunction
  
  virtual task body();
    `uvm_do_with(req,{req.wr_en==1;})
  endtask
endclass

// read_sequence - "read" type
class read_sequence extends uvm_sequence#(dec_seq_item);
  
  `uvm_object_utils(read_sequence)
   
  //Constructor
  function new(string name = "read_sequence");
    super.new(name);
  endfunction
  
  virtual task body();
    `uvm_do_with(req,{req.rd_en==1;})
  endtask
endclass

// write_read_sequence - "write" followed by "read" 
class write_read_sequence extends uvm_sequence#(dec_seq_item);
  
  `uvm_object_utils(write_read_sequence)
   
  //Constructor
  function new(string name = "write_read_sequence");
    super.new(name);
  endfunction
  
  virtual task body();
    `uvm_do_with(req,{req.wr_en==1;})
    `uvm_do_with(req,{req.rd_en==1;})
  endtask
endclass

// wr_rd_sequence - "write" followed by "read" (sequence's inside sequences)
class wr_rd_sequence extends uvm_sequence#(dec_seq_item);
  
  //Declaring sequences
  write_sequence wr_seq;
  read_sequence  rd_seq;
  
  `uvm_object_utils(wr_rd_sequence)
   
  //Constructor
  function new(string name = "wr_rd_sequence");
    super.new(name);
  endfunction
  
  virtual task body();
    `uvm_do(wr_seq)
    `uvm_do(rd_seq)
  endtask
endclass


//-------------------------------------------------------------------------
//            Driver
//-------------------------------------------------------------------------

`define DRIV_IF vif.DRIVER.driver_cb

class dec_driver extends uvm_driver #(dec_seq_item);

  // Virtual Interface
  virtual dec_if vif;
  `uvm_component_utils(dec_driver)
    
  // Constructor
  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  // build phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
     if(!uvm_config_db#(virtual dec_if)::get(this, "", "vif", vif))
       `uvm_fatal("NO_VIF",{"virtual interface must be set for: ",get_full_name(),".vif"});
  endfunction: build_phase

  // run phase
  virtual task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(req);
      drive();
      seq_item_port.item_done();
    end
  endtask : run_phase
  
  // drive - transaction level to signal level
  // drives the value's from seq_item to interface signals
  virtual task drive();
    `DRIV_IF.wr_en <= 0;
    `DRIV_IF.rd_en <= 0;
    @(posedge vif.DRIVER.clk);
    
    `DRIV_IF.addr <= req.addr;
    
    if(req.wr_en) begin // write operation
      `DRIV_IF.wr_en <= req.wr_en;
      `DRIV_IF.wdata <= req.wdata;
      @(posedge vif.DRIVER.clk);
    end
    else if(req.rd_en) begin //read operation
      `DRIV_IF.rd_en <= req.rd_en;
      @(posedge vif.DRIVER.clk);
      `DRIV_IF.rd_en <= 0;
      @(posedge vif.DRIVER.clk);
      req.rdata = `DRIV_IF.rdata;
    end
    
  endtask : drive
endclass : dec_driver


//-------------------------------------------------------------------------
//            Monitor
//-------------------------------------------------------------------------

class dec_monitor extends uvm_monitor;

  // Virtual Interface
  virtual dec_if vif;

  // analysis port, to send the transaction to scoreboard
  uvm_analysis_port #(dec_seq_item) item_collected_port;
  
  // The following property holds the transaction information currently
  // begin captured (by the collect_address_phase and data_phase methods).
  dec_seq_item trans_collected;

  `uvm_component_utils(dec_monitor)

  // new - constructor
  function new (string name, uvm_component parent);
    super.new(name, parent);
    trans_collected = new();
    item_collected_port = new("item_collected_port", this);
  endfunction : new

  // build_phase - getting the interface handle
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual dec_if)::get(this, "", "vif", vif))
       `uvm_fatal("NOVIF",{"virtual interface must be set for: ",get_full_name(),".vif"});
  endfunction: build_phase
  
  // run_phase - convert the signal level activity to transaction level.
  // i.e, sample the values on interface signal ans assigns to transaction class fields
  virtual task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.MONITOR.clk);
      wait(vif.monitor_cb.wr_en || vif.monitor_cb.rd_en);
        trans_collected.addr = vif.monitor_cb.addr;
      if(vif.monitor_cb.wr_en) begin
        trans_collected.wr_en = vif.monitor_cb.wr_en;
        trans_collected.wdata = vif.monitor_cb.wdata;
        trans_collected.rd_en = 0;
        @(posedge vif.MONITOR.clk);
      end
      if(vif.monitor_cb.rd_en) begin
        trans_collected.rd_en = vif.monitor_cb.rd_en;
        trans_collected.wr_en = 0;
        @(posedge vif.MONITOR.clk);
        @(posedge vif.MONITOR.clk);
        trans_collected.rdata = vif.monitor_cb.rdata;
      end
    item_collected_port.write(trans_collected);
      end 
  endtask : run_phase

endclass : dec_monitor


//-------------------------------------------------------------------------
//            Agent
//-------------------------------------------------------------------------

class dec_agent extends uvm_agent;

  // component instances
  dec_driver    driver;
  dec_sequencer sequencer;
  dec_monitor   monitor;

  `uvm_component_utils(dec_agent)
  
  // constructor
  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  // build_phase
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    monitor = dec_monitor::type_id::create("monitor", this);

    //creating driver and sequencer only for ACTIVE agent
    if(get_is_active() == UVM_ACTIVE) begin
      driver    = dec_driver::type_id::create("driver", this);
      sequencer = dec_sequencer::type_id::create("sequencer", this);
    end
  endfunction : build_phase
  
  // connect_phase - connecting the driver and sequencer port
  function void connect_phase(uvm_phase phase);
    if(get_is_active() == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction : connect_phase
  
endclass : dec_agent


//-------------------------------------------------------------------------
//            Scoreboard
//-------------------------------------------------------------------------

class dec_scoreboard extends uvm_scoreboard;
  
  // declaring pkt_qu to store the pkt's recived from monitor
  dec_seq_item pkt_qu[$];
  
  // sc_dec 
  bit [7:0] sc_dec [4];

  //port to recive packets from monitor
  uvm_analysis_imp#(dec_seq_item, dec_scoreboard) item_collected_export;
  `uvm_component_utils(dec_scoreboard)

  // new - constructor
  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new
  // build_phase - create port and initialize local decory
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
      item_collected_export = new("item_collected_export", this);
      foreach(sc_dec[i]) sc_dec[i] = 8'hFF;
  endfunction: build_phase
  
  // write task - recives the pkt from monitor and pushes into queue
  virtual function void write(dec_seq_item pkt);
    //pkt.print();
    pkt_qu.push_back(pkt);
  endfunction : write

  // run_phase - compare's the read data with the expected data(stored in local decory)
  // local decory will be updated on the write operation.
  virtual task run_phase(uvm_phase phase);
    dec_seq_item dec_pkt;
    
    forever begin
      wait(pkt_qu.size() > 0);
      dec_pkt = pkt_qu.pop_front();
      
      if(dec_pkt.wr_en) begin
        sc_dec[dec_pkt.addr] = dec_pkt.wdata;
        `uvm_info(get_type_name(),$sformatf("------ :: WRITE DATA       :: ------"),UVM_LOW)
        `uvm_info(get_type_name(),$sformatf("Addr: %0h",dec_pkt.addr),UVM_LOW)
        `uvm_info(get_type_name(),$sformatf("Data: %0h",dec_pkt.wdata),UVM_LOW)
        `uvm_info(get_type_name(),"------------------------------------",UVM_LOW)        
      end
      else if(dec_pkt.rd_en) begin
        if(sc_dec[dec_pkt.addr] == dec_pkt.rdata) begin
          `uvm_info(get_type_name(),$sformatf("------ :: READ DATA Match :: ------"),UVM_LOW)
          `uvm_info(get_type_name(),$sformatf("Addr: %0h",dec_pkt.addr),UVM_LOW)
          `uvm_info(get_type_name(),$sformatf("Expected Data: %0h Actual Data: %0h",sc_dec[dec_pkt.addr],dec_pkt.rdata),UVM_LOW)
          `uvm_info(get_type_name(),"------------------------------------",UVM_LOW)
        end
        else begin
          `uvm_error(get_type_name(),"------ :: READ DATA MisMatch :: ------")
          `uvm_info(get_type_name(),$sformatf("Addr: %0h",dec_pkt.addr),UVM_LOW)
          `uvm_info(get_type_name(),$sformatf("Expected Data: %0h Actual Data: %0h",sc_dec[dec_pkt.addr],dec_pkt.rdata),UVM_LOW)
          `uvm_info(get_type_name(),"------------------------------------",UVM_LOW)
        end
      end
    end
  endtask : run_phase
endclass : dec_scoreboard


//-------------------------------------------------------------------------
//            Environment
//-------------------------------------------------------------------------

class dec_model_env extends uvm_env;
  
  // agent and scoreboard instance
  dec_agent      dec_agnt;
  dec_scoreboard dec_scb;
  
  `uvm_component_utils(dec_model_env)
  
  // constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  // build_phase - crate the components
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    dec_agnt = dec_agent::type_id::create("dec_agnt", this);
    dec_scb  = dec_scoreboard::type_id::create("dec_scb", this);
  endfunction : build_phase
  
  // connect_phase - connecting monitor and scoreboard port
  function void connect_phase(uvm_phase phase);
    dec_agnt.monitor.item_collected_port.connect(dec_scb.item_collected_export);
  endfunction : connect_phase

endclass : dec_model_env

//-------------------------------------------------------------------------
//            Base test
//-------------------------------------------------------------------------

class dec_model_base_test extends uvm_test;

  `uvm_component_utils(dec_model_base_test)
  
  // env instance 
  dec_model_env env;

  // constructor
  function new(string name = "dec_model_base_test",uvm_component parent=null);
    super.new(name,parent);
  endfunction : new

  // build_phase
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create the env
    env = dec_model_env::type_id::create("env", this);
  endfunction : build_phase
  
  // end_of_elobaration phase
  virtual function void end_of_elaboration();
    //print's the topology
    print();
  endfunction

  // end_of_elobaration phase
 function void report_phase(uvm_phase phase);
   uvm_report_server svr;
   super.report_phase(phase);
   
   svr = uvm_report_server::get_server();
   if(svr.get_severity_count(UVM_FATAL)+svr.get_severity_count(UVM_ERROR)>0) begin
     `uvm_info(get_type_name(), "---------------------------------------", UVM_NONE)
     `uvm_info(get_type_name(), "----            TEST FAIL          ----", UVM_NONE)
     `uvm_info(get_type_name(), "---------------------------------------", UVM_NONE)
    end
    else begin
     `uvm_info(get_type_name(), "---------------------------------------", UVM_NONE)
     `uvm_info(get_type_name(), "----           TEST PASS           ----", UVM_NONE)
     `uvm_info(get_type_name(), "---------------------------------------", UVM_NONE)
    end
  endfunction 

endclass : dec_model_base_test


//-------------------------------------------------------------------------
//            Write Read test
//-------------------------------------------------------------------------

class dec_wr_rd_test extends dec_model_base_test;

  `uvm_component_utils(dec_wr_rd_test)
  
  // sequence instance 
  wr_rd_sequence seq;

  // constructor
  function new(string name = "dec_wr_rd_test",uvm_component parent=null);
    super.new(name,parent);
  endfunction : new

  // build_phase
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create the sequence
    seq = wr_rd_sequence::type_id::create("seq");
  endfunction : build_phase
  
  // run_phase - starting the test
  task run_phase(uvm_phase phase);
    
    phase.raise_objection(this);
      seq.start(env.dec_agnt.sequencer);
    phase.drop_objection(this);
    
    //set a drain-time for the environment if desired
    phase.phase_done.set_drain_time(this, 50);
  endtask : run_phase
  
endclass : dec_wr_rd_test


module tb_top;

  bit clk, reset;

  always #5 clk = ~clk;
  
  initial begin
    reset = 1;
    #5 reset =0;
  end
  
  dec_if intf(clk,reset);

  decory DUT (
    .clk(intf.clk),
    .reset(intf.reset),
    .addr(intf.addr),
    .wr_en(intf.wr_en),
    .rd_en(intf.rd_en),
    .wdata(intf.wdata),
    .rdata(intf.rdata)
   );
  
  initial begin 
    uvm_config_db#(virtual dec_if)::set(uvm_root::get(),"*","vif",intf);
    $dumpfile("dump.vcd"); 
    $dumpvars;
  end
  
  initial begin 
    run_test("dec_wr_rd_test");
  end
endmodule