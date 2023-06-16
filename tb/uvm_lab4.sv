`include "uvm_macros.svh"
import uvm_pkg::*;


function logic [63:0][7:0] pad (
  input string str2,
  input logic [7:0] pre_length
  );

    int lk, ct;

    // set preamble lengths for the program runs (always > 6)
    // ***** choose any value > 6 *****
    
    if(pre_length < 7) begin
      $display("illegal preamble length chosen, overriding with 8");
      pre_length =  8;                     // override < 6 with a legal value
    end else
      $display("preamble length = %d",pre_length);

    if(str2.len>50) 
      $display("illegally long string of length %d, truncating to 50 chars.",str2.len);

    $display("original message string length = %d",str2.len);

    for(lk = 0; lk<str2.len; lk++)
      if(str2[lk]==8'h5f) continue;	       // count leading _ chars in string
	  else break;                          // we shall add these to preamble pad length
	  $display("embedded leading underscore count = %d",lk);

    for(int nn=0; nn<64; nn++)			   // count leading underscores
      if(str2[nn]==8'h5f) ct++; 
	  else break;
	  $display("ct = %d",ct);

    $display("run encryption of this original message: ");
    $display("%s",str2);             // print original message in transcript window

    for(int j=0; j<64; j++) 			   // pre-fill message_padded with ASCII _ characters
      pad[j] = 8'h5f;         
    for(int l=0; l<str2.len; l++)  	 // overwrite up to 60 of these spaces w/ message itself
      pad[pre_length+l] = byte'(str2[l]); 

endfunction

function logic [63:0][7:0] encrypt (
    input logic [63:0][7:0] msg_padded2,
    input int pat_sel,
    input logic [5:0] LFSR_init  // for program 2 run
  );

    string      str_enc2[64];          // decryption program input
    logic [5:0] LFSR_ptrn[6];		       // 6 possible maximal-length 6-bit LFSR tap ptrns
    logic [63:0][7:0] msg_crypto2;
    logic [5:0] lfsr_ptrn,
                lfsr2[64];

    // the 6 possible (constant) maximal-length feedback tap patterns from which to choose
    LFSR_ptrn[0] = 6'h21;
    LFSR_ptrn[1] = 6'h2D;
    LFSR_ptrn[2] = 6'h30;
    LFSR_ptrn[3] = 6'h33;
    LFSR_ptrn[4] = 6'h36;
    LFSR_ptrn[5] = 6'h39;

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

    return msg_crypto2;

endfunction

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
    output init;
    output wr_en;
    output raddr; 
    output waddr;
    output data_in;
    input  data_out;
    input  done;
    output reading;
  endclocking
  
  clocking monitor_cb @(posedge clk);
    default input #1 output #1;
    input init;
    input wr_en;
    input raddr; 
    input waddr;
    input data_in;
    input data_out;
    input done;
    input reading;
  endclocking
  
  modport DRIVER  (clocking driver_cb,  input clk);
  modport MONITOR (clocking monitor_cb, input clk);

endinterface

//-------------------------------------------------------------------------
//            Sequence Item
//-------------------------------------------------------------------------

class dec_seq_item extends uvm_sequence_item;

  rand bit  unsigned [7:0] pre_length;
  rand int  unsigned pat_sel;
  rand bit  unsigned [5:0] LFSR_init;
  rand byte unsigned temp[];

  logic [63:0][7:0] msg_crypto2   ,          // encrypted message according to the DUT
                    msg_decryp2   ,          // recovered decrypted message from DUT
                    msg_padded2   ;
  
  //Utility and Field macros
  `uvm_object_utils_begin(dec_seq_item)
    `uvm_field_int(pre_length,UVM_ALL_ON)
    `uvm_field_int(pat_sel,UVM_ALL_ON)
    `uvm_field_int(LFSR_init,UVM_ALL_ON)
    // `uvm_field_int(temp,UVM_ALL_ON)
    `uvm_field_int(msg_crypto2,UVM_ALL_ON)
    `uvm_field_int(msg_decryp2,UVM_ALL_ON)
    `uvm_field_int(msg_padded2,UVM_ALL_ON)
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
  constraint str_ascii { foreach(temp[i]) temp[i] inside {[65:90], [97:122]}; } //To restrict between 'A-Z' and 'a-z'
  constraint padded_len { pre_length + temp.size() <= 50; }

  function string get_str();
      string str;
      foreach(temp[i]) str = {str, string'(temp[i])};
      return str;
      // return "Mr_Watson_come_here_I_want_to_see_you";
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
   repeat(10) begin
    req = dec_seq_item::type_id::create("req");
    wait_for_grant();
    req.randomize();
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

  string      str2 = "abc"   ;          // decrypted string will go here
  logic [63:0][7:0] msg_crypto2   ,          // encrypted message according to the DUT
                    msg_decryp2   ,          // recovered decrypted message from DUT
                    msg_padded2   ;

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

      str2 = req.get_str();
      // uvm_config_db#(string)::set(this, "uvm_test_top", "str2", str2);
      uvm_config_db#(string)::set(uvm_root::get(),"*","str2",str2);
      
      msg_padded2 = pad(.str2(str2), .pre_length(req.pre_length));
      msg_crypto2 = encrypt(.msg_padded2(msg_padded2), .pat_sel(req.pat_sel), .LFSR_init(req.LFSR_init));

      `DRIV_IF.init  <= 'b1;
      `DRIV_IF.wr_en <= 'b0;

      repeat(5) @(posedge vif.DRIVER.clk);

      for(int qp=0; qp<64; qp++) begin
        @(posedge vif.DRIVER.clk);
        `DRIV_IF.wr_en   <= 'b1;                   // turn on memory write enable
        `DRIV_IF.waddr   <= qp+64;                 // write encrypted message to mem [64:127]
        `DRIV_IF.data_in <= msg_crypto2[qp];
      end

      @(posedge vif.DRIVER.clk) `DRIV_IF.wr_en <= 'b0;                   // turn off mem write for rest of simulation
      @(posedge vif.DRIVER.clk) `DRIV_IF.init  <= 0 ;

      repeat(6) @(posedge vif.DRIVER.clk);              // wait for 6 clock cycles of nominal 10ns each
      wait(`DRIV_IF.done);                            // wait for DUT's done flag to go high
      
      #10ns $display("done at time %t",$time);

      `DRIV_IF.reading <= 1;
      for(int n=0; n<str2.len+1; n++)
        @(posedge vif.DRIVER.clk) `DRIV_IF.raddr <= n;

      @(posedge vif.DRIVER.clk) `DRIV_IF.reading <= 0;
      repeat(100) @(posedge vif.DRIVER.clk);

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

      wait(vif.monitor_cb.reading);
      while (vif.monitor_cb.reading) begin
        @(posedge vif.MONITOR.clk)
        trans_collected.msg_decryp2[vif.monitor_cb.raddr] = vif.monitor_cb.data_out;
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
    
    forever begin
      wait(pkt_qu.size() > 0);
      dec_pkt = pkt_qu.pop_front();

     if(!uvm_config_db#(string)::get(this, "", "str2", str2))
       `uvm_fatal("NO_STR",{"no str found"});

      str_dec2 = "";
      for(int rr=0; rr<str2.len; rr++)
        str_dec2 = {str_dec2, string'(dec_pkt.msg_decryp2[rr])};

      $display ("Original message: %s, Decoded message: %s , len %d", str2, str_dec2, str2.len);
      assert (str_dec2 == str2) 
        $display ("\n - DECRYPTION SUCCESSFUL\n");
      else begin
        `uvm_error("ERROR", "failed");
        $display ("\n - DECRYPTION FAILED. Sent: %s, Got: %s \n", str2, str_dec2);
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
  dec_sequence seq;

  // constructor
  function new(string name = "dec_wr_rd_test",uvm_component parent=null);
    super.new(name,parent);
  endfunction : new

  // build_phase
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Create the sequence
    seq = dec_sequence::type_id::create("seq");
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


module uvm_test_top;

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
    run_test("dec_wr_rd_test");
  end
endmodule