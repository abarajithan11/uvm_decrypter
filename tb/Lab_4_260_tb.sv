// `include "uvm_macros.svh"
// import uvm_pkg::*;

// typedef logic [63:0][7:0] logic [63:0][7:0];

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

    // select LFSR tap pattern
    // ***** choose any value < 6 *****
    
    if(pat_sel > 5) begin 
      $display("illegal pattern select chosen, overriding with 3");
      pat_sel = 3;                         // overrides illegal selections
    end  
    else
      $display("tap pattern %d selected",pat_sel);

    // set starting LFSR state for program -- 
    // ***** choose any 6-bit nonzero value *****
    if(!LFSR_init) begin
      $display("illegal zero LFSR start pattern chosen, overriding with 6'h01");
      LFSR_init = 6'h01;                   // override 0 with a legal (nonzero) value
    end
    else
      $display("LFSR starting pattern = %b",LFSR_init);

    // precompute encrypted message
	  lfsr_ptrn = LFSR_ptrn[pat_sel];        // select one of the 6 permitted tap ptrns

	  lfsr2[0]     = LFSR_init;              // any nonzero value (zero may be helpful for debug)
    $display();
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
    $display("here is the original message with _ preamble padding");

    for(int jj=0; jj<64; jj++)
      $write("%s",msg_padded2[jj]);
    $display("\n");
    $display("here is the padded and encrypted pattern in ASCII");

    for(int jj=0; jj<64; jj++)
        $write("%s",str_enc2[jj]);
    $display("\n");
    $display("here is the padded pattern in hex"); 

	  for(int jj=0; jj<64; jj++)
      $write(" %h",msg_padded2[jj]);
	  $display("\n");

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
  
  clocking driver_cb @(posedge clk);
    default input #1 output #1;
    output init;
    output wr_en;
    output raddr; 
    output waddr;
    output data_in;
    input  data_out;
    input  done;
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
  endclocking
  
  modport DRIVER  (clocking driver_cb,  input clk);
  modport MONITOR (clocking monitor_cb, input clk);

endinterface

class rand_data;

  rand bit unsigned [7:0] pre_length;
  constraint pre_length_c { pre_length  >=7 && pre_length <= 63; } // values 7 to 63 recommended

  rand int unsigned pat_sel;
  constraint pat_sel_size { pat_sel < 6; }

  rand bit unsigned [5:0] LFSR_init;
  constraint LFSR_init_non_zero { LFSR_init !=0; }
 
  rand byte unsigned temp[];
  constraint str_len { temp.size() < 50; } // Length of the string
  constraint str_ascii { foreach(temp[i]) temp[i] inside {[65:90], [97:122]}; } //To restrict between 'A-Z' and 'a-z'
  constraint padded_len { pre_length + temp.size() <= 50; }
 
  function string get_str();
      string str;
      foreach(temp[i]) str = {str, string'(temp[i])};
      return str;
      // return "Mr_Watson_come_here_I_want_to_see_you";
  endfunction

  function new();
    pre_length = 10;    // values 7 to 63 recommclearended
    pat_sel =  2;
    LFSR_init = 6'h01;  // for program 2 run
  endfunction

endclass

module Lab_4_260_tb;


  logic clk = 0;
  initial forever #5ns clk <= !clk;

  logic       init              ;          // init (reset, start) command to DUT
  logic       wr_en             ;          // DUT memory core write enable
  logic [7:0] raddr             ,
              waddr             ,
              data_in           ;
  wire  [7:0] data_out          ;
  wire        done              ;          // done flag returned by DUT
  top_level_4_260 dut(.*)       ;          // your top level design goes here 



  rand_data obj;
  string      str2, str_dec2    ;          // decrypted string will go here
  logic [63:0][7:0] msg_crypto2   ,          // encrypted message according to the DUT
                    msg_decryp2   ,          // recovered decrypted message from DUT
                    msg_padded2   ;

  bit reading = 0;
  bit [7:0] raddr_mon = 0;


  initial begin	 :driver

    obj = new();

    repeat (1000) begin

      obj.randomize();
      str2 = obj.get_str();
      
      msg_padded2 = pad(.str2(str2), .pre_length(obj.pre_length));
      msg_crypto2 = encrypt(.msg_padded2(msg_padded2), .pat_sel(obj.pat_sel), .LFSR_init(obj.LFSR_init));

      init  = 'b1;
      wr_en = 'b0;

      repeat(5) @(posedge clk);

      for(int qp=0; qp<64; qp++) begin
        @(posedge clk);
        wr_en   <= 'b1;                   // turn on memory write enable
        waddr   <= qp+64;                 // write encrypted message to mem [64:127]
        data_in <= msg_crypto2[qp];
      end

      @(posedge clk) wr_en <= 'b0;                   // turn off mem write for rest of simulation
      @(posedge clk) init  <= 0 ;

      repeat(6) @(posedge clk);              // wait for 6 clock cycles of nominal 10ns each
      wait(done);                            // wait for DUT's done flag to go high
      
      #10ns $display("done at time %t",$time);

      reading = 1;
      for(int n=0; n<str2.len+1; n++)
        @(posedge clk) raddr <= n;

      @(posedge clk) reading = 0;
      @(posedge clk);
    end

    #20ns $stop;
  end  :driver


  initial forever begin: monitor_scoreboard

    wait(reading);
    while (reading) begin
      @(posedge clk)
      msg_decryp2[raddr] = data_out;
      $display ("monitor reading %d %d", raddr_mon, data_out); //msg_decryp2[raddr-1] <= data_out;
    end

    str_dec2 = "";
    for(int rr=0; rr<str2.len; rr++)
      str_dec2 = {str_dec2, string'(msg_decryp2[rr])};

    $display ("Decoded message: %s ", str_dec2);
    assert (str_dec2 == str2) 
      $display ("\n - DECRYPTION SUCCESSFUL\n");
    else
      $fatal ("\n - DECRYPTION FAILED. Sent: %s, Got: %s \n", str2, str_dec2);

  end: monitor_scoreboard


endmodule