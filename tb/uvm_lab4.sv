// Code your testbench here
// or browse Examples
`include "uvm_macros.svh"
import uvm_pkg::*;

interface dec_if (input logic clk);

  logic       init;
  logic       wr_en;
  logic[7:0]  raddr, 
              waddr,
              data_in;
  logic[7:0]  data_out;
  logic       done;
  bit         reading;
  
  clocking driver_cb @(posedge clk);
    default input #1 output #1;
    output init, wr_en, raddr, waddr, data_in, reading;
    input  data_out, done;
  endclocking
  
  clocking monitor_cb @(posedge clk);
    default input #1 output #1;
    input init, wr_en, raddr, waddr, data_in, data_out, done, reading;
  endclocking
  
  modport DRIVER  (clocking driver_cb,  input clk);
  modport MONITOR (clocking monitor_cb, input clk);

endinterface

//-------------------------------------------------------------------------
//            Sequence Item
//-------------------------------------------------------------------------

class dec_seq_item extends uvm_sequence_item;

  rand int  unsigned pat_sel;
  rand bit  unsigned [7:0] pre_length;
  rand bit  unsigned [5:0] LFSR_init;
  rand byte unsigned str2_ascii[];

  
  //Utility and Field macros
  `uvm_object_utils_begin(dec_seq_item)
    `uvm_field_int(pre_length,UVM_ALL_ON)
    `uvm_field_int(pat_sel,UVM_ALL_ON)
    `uvm_field_int(LFSR_init,UVM_ALL_ON)
  `uvm_object_utils_end
  
  //Constructor
  function new(string name = "dec_seq_item");
    super.new(name);
    pre_length = 10;    // values 7 to 63 recommclearended
    pat_sel =  2;
    LFSR_init = 6'h01;  // for program 2 run
  endfunction
  
  //constaint, to generate any one among write and read
  constraint pre_length_c { pre_length  >=7 && pre_length <= 12; } // values 7 to 63 recommended
  constraint pat_sel_size { pat_sel < 6; }
  constraint LFSR_init_non_zero { LFSR_init !=0; }
  constraint str_ascii { foreach(str2_ascii[i]) str2_ascii[i] inside {[32:127]} && str2_ascii[i] != 95; } // All printable ASCII except _
  constraint padded_len { pre_length + str2_ascii.size() <= 50; }


  logic [255:0][7:0] msg_padded2, msg_crypto2, mem_data_monitored;
  string      str_enc2[64];          // decryption program input
  logic [5:0] LFSR_ptrn[6] = '{6'h21, 6'h2D, 6'h30, 6'h33, 6'h36, 6'h39};;		       // 6 possible maximal-length 6-bit LFSR tap ptrns
  logic [5:0] lfsr_ptrn, lfsr2[64];
  int lk, ct;
  string str2;

  function encrypt ();
    // make string 
    foreach(str2_ascii[i]) str2 = {str2, string'(str2_ascii[i])};

    for(lk = 0; lk<str2.len; lk++)
      if(str2[lk]==8'h5f) continue;	       // count leading _ chars in string
	    else break;                          // we shall add these to preamble pad length

    for(int nn=0; nn<64; nn++)			   // count leading underscores
      if(str2[nn]==8'h5f) ct++; 
	    else break;

    $display("Encoding step: orginal message: %s, len: %d, lk: %d, ct: %d", str2, str2.len, lk, ct);

    for(int j=0; j<64; j++) 			   // pre-fill message_padded with ASCII _ characters
      msg_padded2[j] = 8'h5f;         
    for(int l=0; l<str2.len; l++)  	 // overwrite up to 60 of these spaces w/ message itself
      msg_padded2[pre_length+l] = byte'(str2[l]); 

    // precompute encrypted message
	  lfsr_ptrn = LFSR_ptrn[pat_sel];        // select one of the 6 permitted tap ptrns

	  lfsr2[0]     = LFSR_init;              // any nonzero value (zero may be helpful for debug)
    $display("LFSR_ptrn = %h, LFSR_init = %h %h",lfsr_ptrn,LFSR_init,lfsr2[0]);

    // compute the LFSR sequence
    for (int ii=0;ii<63;ii++) begin :lfsr_loop
      lfsr2[ii+1] = (lfsr2[ii]<<1)+(^(lfsr2[ii]&lfsr_ptrn));//{LFSR[6:0],(^LFSR[5:3]^LFSR[7])};		   // roll the rolling code
    //      $display("lfsr_ptrn %d = %h",ii,lfsr2[ii]);
    end	  :lfsr_loop

    // encrypt the message
    for (int i=0; i<64; i++) begin		   // testbench will change on falling clocks
      msg_crypto2[i]        = msg_padded2[i] ^ lfsr2[i];  //{1'b0,LFSR[6:0]};	   // encrypt 7 LSBs
      str_enc2[i]           = string'(msg_crypto2[i]);
    end
    // $display("here is the original message with _ preamble padding");

    // for(int jj=0; jj<64; jj++)
    //   $write("%s",msg_padded2[jj]);
    // $display("\n");
    // $display("here is the padded and encrypted pattern in ASCII");

    // for(int jj=0; jj<64; jj++)
    //     $write("%s",str_enc2[jj]);
    // $display("\n");
    // $display("here is the padded pattern in hex"); 

	  // for(int jj=0; jj<64; jj++)
    //   $write(" %h",msg_padded2[jj]);
	  // $display("\n");

  endfunction


  rand bit [255:0][7:0] mem_data;

  function bit [7:0] checksum();
    for (int i=0; i<256; i++)
      checksum ^= mem_data[i];
  endfunction

  
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
//            Sequence: Decryption
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
   repeat(10) begin
    wait_for_grant();

    req = dec_seq_item::type_id::create("req");
    req.randomize();
    req.encrypt();
     
    uvm_config_db#(string)::set(uvm_root::get(),"*","str2",req.str2);
    uvm_config_db#(int  unsigned)::set(uvm_root::get(),"*","ptrn_sel",req.pat_sel);
     uvm_config_db#(bit  unsigned [7:0])::set(uvm_root::get(),"*","preamble_len",req.pre_length);
     uvm_config_db#(bit  unsigned [5:0])::set(uvm_root::get(),"*","LFSR_init",req.LFSR_init);
    uvm_config_db#(bit)::set(uvm_root::get(),"*","is_mem_rw_test",1'b0);

    send_request(req);
    wait_for_item_done();
   end 
  endtask
endclass


//-------------------------------------------------------------------------
//            Sequence: Memory Readback
//-------------------------------------------------------------------------

class mem_rw_sequence extends uvm_sequence#(dec_seq_item);
  
  `uvm_object_utils(mem_rw_sequence)
  
  //Constructor
  function new(string name = "mem_rw_sequence");
    super.new(name);
  endfunction
  
  `uvm_declare_p_sequencer(dec_sequencer)
  
  // create, randomize and send the item to driver
  virtual task body();
   repeat(10) begin
      wait_for_grant();

      req = dec_seq_item::type_id::create("req");
      req.randomize();
      uvm_config_db#(bit [7:0])::set(uvm_root::get(),"*","checksum",req.checksum);
      uvm_config_db#(bit [255:0][7:0])::set(uvm_root::get(),"*","mem_data",req.mem_data);
      uvm_config_db#(bit)::set(uvm_root::get(),"*","is_mem_rw_test",1'b1);

      send_request(req);
      wait_for_item_done();
   end 
  endtask
endclass

//-------------------------------------------------------------------------
//            Driver
//-------------------------------------------------------------------------

`define DRIV_IF vif.driver_cb

class dec_driver extends uvm_driver #(dec_seq_item);

  bit is_mem_rw_test;

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
       `uvm_error("NO_VIF",{"virtual interface must be set for: ",get_full_name(),".vif"});
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

    if(!uvm_config_db#(bit)::get(this, "", "is_mem_rw_test", is_mem_rw_test))
        `uvm_error("NO_MEMDATA",{"no is_mem_rw_test found"});

    if (is_mem_rw_test) begin
      `DRIV_IF.init  <= 'b1;

      for(int qp=0; qp<256; qp++) begin
        @(posedge vif.DRIVER.clk);
        `DRIV_IF.wr_en   <= 'b1; 
        `DRIV_IF.waddr   <= qp;
        `DRIV_IF.data_in <= req.mem_data[qp];
      end

      repeat(6) @(posedge vif.DRIVER.clk); 

      `DRIV_IF.reading <= 1;
      for(int n=0; n<256; n++)
        @(posedge vif.DRIVER.clk) `DRIV_IF.raddr <= n;

      @(posedge vif.DRIVER.clk) `DRIV_IF.reading <= 0;
      repeat(2) @(posedge vif.DRIVER.clk);

    end else begin

      `DRIV_IF.init  <= 'b1;
      `DRIV_IF.wr_en <= 'b0;

      repeat(5) @(posedge vif.DRIVER.clk);

      for(int qp=0; qp<64; qp++) begin
        @(posedge vif.DRIVER.clk);
        `DRIV_IF.wr_en   <= 'b1;                   // turn on memory write enable
        `DRIV_IF.waddr   <= qp+64;                 // write encrypted message to mem [64:127]
        `DRIV_IF.data_in <= req.msg_crypto2[qp];
      end

      @(posedge vif.DRIVER.clk) `DRIV_IF.wr_en <= 'b0;                   // turn off mem write for rest of simulation
      @(posedge vif.DRIVER.clk) `DRIV_IF.init  <= 0 ;

      repeat(6) @(posedge vif.DRIVER.clk);              // wait for 6 clock cycles of nominal 10ns each
      wait(`DRIV_IF.done);                            // wait for DUT's done flag to go high
      
      #10ns $display("done at time %t",$time);

      `DRIV_IF.reading <= 1;
      for(int n=0; n<req.str2.len+1; n++)
        @(posedge vif.DRIVER.clk) `DRIV_IF.raddr <= n;

      @(posedge vif.DRIVER.clk) `DRIV_IF.reading <= 0;
      repeat(2) @(posedge vif.DRIVER.clk);

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
       `uvm_error("NOVIF",{"virtual interface must be set for: ",get_full_name(),".vif"});
  endfunction: build_phase
  
  // run_phase - convert the signal level activity to transaction level.
  // i.e, sample the values on interface signal ans assigns to transaction class fields
  virtual task run_phase(uvm_phase phase);
    forever begin
		
      wait(vif.monitor_cb.reading);
      while (vif.monitor_cb.reading) begin
        @(posedge vif.MONITOR.clk)
        trans_collected.mem_data_monitored[vif.monitor_cb.raddr] = vif.monitor_cb.data_out;
        //$display("%d, %d, %h, %d, %h", ptrn_sel, preamble_len, seed, ip_str_len, mem_data);
        //$display("%d, %d, %h, %d, %h", trans_collected.pat_sel, trans_collected.pre_length, trans_collected.LFSR_init, trans_collected.str2.len, trans_collected.mem_data);
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
    string str_dec2;
    string str2;
    bit is_mem_rw_test;
    bit [255:0][7:0] mem_data;
    bit [7:0] checksum, checksum_out;
    
    forever begin
      wait(pkt_qu.size() > 0);
      dec_pkt = pkt_qu.pop_front();

      if(!uvm_config_db#(bit)::get(this, "", "is_mem_rw_test", is_mem_rw_test))
        `uvm_error("NO_MRW",{"no is_mem_rw_test found"});

      if (is_mem_rw_test) begin

        if(!uvm_config_db#(bit [255:0][7:0])::get(this, "", "mem_data", mem_data))
          `uvm_error("NO_MEMDATA",{"no mem data found"});

        if(!uvm_config_db#(bit [7:0])::get(this, "", "checksum", checksum))
          `uvm_error("NO_MEMDATA",{"no mem data found"});

        checksum_out = 0;
        for (int i=0; i<256; i++)
          checksum_out ^= dec_pkt.mem_data_monitored[i];

        assert (checksum_out == checksum && dec_pkt.mem_data_monitored == mem_data) 
          $display (" - MEM DATA MATCHES, CHECKSUM MATCHES: %d \n", checksum);
        else begin
          `uvm_error("ERROR", "Mem data failed, Checksum failed");
          $display ("\n - MEM DATA FAILED. Sent: %d, Got: %d;  CHECKSUM FAILED. Sent: %d, Got: %d \n", mem_data, dec_pkt.mem_data_monitored, checksum, checksum_out);
        end

      end else begin

        if(!uvm_config_db#(string)::get(this, "", "str2", str2))
          `uvm_error("NO_STR",{"no str found"});

        str_dec2 = "";
        for(int rr=0; rr<str2.len; rr++)
          str_dec2 = {str_dec2, string'(dec_pkt.mem_data_monitored[rr])};

        $display ("Original message: %s, Decoded message: %s , len %d", str2, str_dec2, str2.len);
        assert (str_dec2 == str2) 
          $display ("\n - DECRYPTION SUCCESSFUL\n");
        else begin
          `uvm_error("ERROR", "Decryption failed");
          $display ("\n - DECRYPTION FAILED. Sent: %s, Got: %s \n", str2, str_dec2);
        end
      end
    end
  endtask : run_phase
endclass : dec_scoreboard

//-------------------------------------------------------------------------
//            Coverage
//------------------------------------------------------------------------- 
class coverage extends uvm_subscriber #(dec_seq_item);
    `uvm_component_utils(coverage)

    int unsigned  ptrn_sel;
    int unsigned  preamble_len;
    logic [5 : 0] seed;
    int unsigned  ip_str_len;
    logic [7 : 0] addr;
    logic [7 : 0] mem_data;
	
  	bit is_mem_rw_test;	
  
  	string str2;
    real mem_coverage;
    real polyn_coverage;
    real preamble_coverage;
    real seed_coverage;
    real str_len_coverage;
    //  Covergroup: cg_ptrn_sel
    //
    covergroup cg_polyn_coverage;
        coverpoint ptrn_sel {
            bins ptrn_sel_bins[] = {[0 : 5]};
        }
    endgroup

    covergroup cg_preamble_cov;
        coverpoint preamble_len {
            bins preamble_len_bins[] = {[7 : 12]};
        }
    endgroup
	
    covergroup cg_seed_cov;
        coverpoint seed {
            bins seed_bins[] = {[1 : $]}; 
        }
    endgroup
    
    covergroup cg_str_len_cov;
        coverpoint ip_str_len {
            bins ip_str_len_bins[] = {[0 : 57]};
        }
    endgroup
	
    covergroup cg_mem_test ;
        
        coverpoint mem_data {
            bins data_bins[] = {[0 : $]};
        }
    endgroup: cg_mem_test
	
    function new(string name = "coverage", uvm_component parent);
        super.new(name, parent);
        cg_polyn_coverage = new();
        cg_preamble_cov   = new();
        cg_seed_cov       = new();
        cg_str_len_cov    = new();
        cg_mem_test       = new();
    endfunction

  function void write(dec_seq_item t);
    $display("WRITE COVERAGE");
      	if(!uvm_config_db#(bit)::get(this, "", "is_mem_rw_test", is_mem_rw_test))
        `uvm_error("NO_MRW",{"no is_mem_rw_test found"});
        
        mem_data         = t.mem_data;
        
        if (is_mem_rw_test) begin
          $display("MEM COVERAGE");
            cg_mem_test.sample();
            //$display("COVERAGE: addr = %8h, data = %8h", addr, data);
        end
        else begin
          $display("DEC COVERAGE");
          if(!uvm_config_db#(int  unsigned)::get(this, "", "ptrn_sel", ptrn_sel))
          `uvm_error("NO_MRW",{"no pat_sel found"});
          if(!uvm_config_db#(bit  unsigned [7:0])::get(this, "", "preamble_len", preamble_len))
          `uvm_error("NO_MRW",{"no pre_length found"});
           if(!uvm_config_db#(bit  unsigned [5:0])::get(this, "", "LFSR_init", seed))
          `uvm_error("NO_MRW",{"no LFSR_init found"});
          if(!uvm_config_db#(string)::get(this, "", "str2", str2))
          `uvm_error("NO_MRW",{"no str2 found"});
          ip_str_len   = str2.len;
          $display("%d, %d, %h, %d, %h", ptrn_sel, preamble_len, seed, ip_str_len, mem_data);
          //s$display("%d, %d, %h, %d, %h", t.pat_sel, t.pre_length, t.LFSR_init, t.str2.len, t.mem_data);
            cg_polyn_coverage.sample();  
            cg_preamble_cov.sample();  
            cg_seed_cov.sample();      
            cg_str_len_cov.sample();     
        end
    endfunction

    function void extract_phase(uvm_phase phase);
        super.extract_phase(phase);
        polyn_coverage = cg_polyn_coverage.get_coverage();
        preamble_coverage = cg_preamble_cov.get_coverage();
        seed_coverage = cg_seed_cov.get_coverage();
        str_len_coverage = cg_str_len_cov.get_coverage();
        mem_coverage = cg_mem_test.get_coverage();
    endfunction: extract_phase

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info(get_name(), $sformatf("\nPolynomial Coverage = %f\nPreamble Coverage = %f\nSeed Coverage = %f\nString Length Coverage = %f\nMemory Functional Coverage = %f", polyn_coverage, preamble_coverage, seed_coverage, str_len_coverage, mem_coverage), UVM_NONE)
    endfunction: report_phase
endclass

    
    
    
    
    
//-------------------------------------------------------------------------
//            Environment
//-------------------------------------------------------------------------

class dec_model_env extends uvm_env;
  
  // agent and scoreboard instance
  dec_agent      dec_agnt;
  dec_scoreboard dec_scb;
  coverage cov;
  `uvm_component_utils(dec_model_env)
  
  // constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  // build_phase - crate the components
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    dec_agnt = dec_agent::type_id::create("dec_agnt", this);
    cov    = coverage::type_id::create ("cov",this);
    dec_scb  = dec_scoreboard::type_id::create("dec_scb", this);
  endfunction : build_phase
  
  // connect_phase - connecting monitor and scoreboard port
  function void connect_phase(uvm_phase phase);
    dec_agnt.monitor.item_collected_port.connect(dec_scb.item_collected_export);
    dec_agnt.monitor.item_collected_port.connect(cov.analysis_export);
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
//            All tests
//-------------------------------------------------------------------------

class all_test extends dec_model_base_test;

  `uvm_component_utils(all_test)
  
  // sequence instance 
  mem_rw_sequence rw_seq;
  dec_sequence dec_seq;

  // constructor
  function new(string name = "all_test",uvm_component parent=null);
    super.new(name,parent);
  endfunction : new

  // build_phase
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create the sequence
    rw_seq = mem_rw_sequence::type_id::create("rw_seq");
    dec_seq = dec_sequence::type_id::create("dec_seq");
  endfunction : build_phase
  
  // run_phase - starting the test
  task run_phase(uvm_phase phase);
    
    phase.raise_objection(this);
      rw_seq.start(env.dec_agnt.sequencer);
      dec_seq.start(env.dec_agnt.sequencer);
    phase.drop_objection(this);
    
    //set a drain-time for the environment if desired
    phase.phase_done.set_drain_time(this, 50);
  endtask : run_phase
  
endclass : all_test


module uvm_top_tb;

  bit clk = 0;
  always #5 clk = ~clk;

  dec_if intf(clk);

  top_level_4_260 DUT (
    .clk      (intf.clk     ),
    .init     (intf.init    ),
    .wr_en    (intf.wr_en   ),
    .raddr    (intf.raddr   ),
    .waddr    (intf.waddr   ),
    .data_in  (intf.data_in ),
    .data_out (intf.data_out),
    .done     (intf.done    )
   );
  
  initial begin 
    uvm_config_db#(virtual dec_if)::set(uvm_root::get(),"*","vif",intf);
    $dumpfile("dump.vcd"); 
    $dumpvars;
  end
  
  initial begin 
    run_test("all_test");
  end
endmodule
