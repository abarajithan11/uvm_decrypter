// Lab5b_tb	  
// testbench for programmable message encryption
// CSE140L  Spring 2020   
// Pick a starting sequence;  
// Run lab 4 equivalent to encrypt
`include "uvm_macros.svh"
import uvm_pkg::*;

module Lab_4_260_tb             ;
  logic       clk               ;		       // advances simulation step-by-step
  logic       init              ;          // init (reset, start) command to DUT
  logic       wr_en             ;          // DUT memory core write enable
  logic [7:0] raddr             ,
              waddr             ,
              data_in           ;
  wire  [7:0] data_out          ;
  wire        done              ;          // done flag returned by DUT
  logic [7:0] pre_length        ,          // bytes before first character in message
              msg_padded2[64]   ,		       // original message, plus pre- and post-padding
              msg_crypto2[64]   ,          // encrypted message according to the DUT
              msg_decryp2[64]   ;          // recovered decrypted message from DUT
  logic [5:0] LFSR_ptrn[6]      ,		       // 6 possible maximal-length 6-bit LFSR tap ptrns
			        LFSR_init         ,		       // NONZERO starting state for LFSR		   
              lfsr_ptrn         ,          // one of 6 maximal length 6-tap shift reg. ptrns
			        lfsr2[64]         ;          // states of program 2 decrypting LFSR         

// our original American Standard Code for Information Interchange message follows
// note in practice your design should be able to handle ANY ASCII string
  string     str2;
//    = "Mr_Watson_come here_I_want_to_see_you_my_aide";	// 1st program 1 input
//  string     str2  = "Knowledge comes, but wisdom lingers.     ";	// program 2 output
//  string     str2  = "                                         ";	// program 2 output
//  string     str2  = "  01234546789abcdefghijklmnopqrstuvwxyz. ";	// 2nd program 1 input
//  string     str2  = "            A joke is a very serious thing.";	// program 3 output
  int str_len                   ;		   // length of string (character count)

// displayed encrypted string will go here:
  string     str_enc2[64]       ;          // decryption program input
  string     str_dec2[64]       ;          // decrypted string will go here
  int ct                        ;
  int lk                        ;		   // counts leading spaces for program 3
  int pat_sel                   ;          // LFSR pattern select

  top_level_4_260 dut(.*)       ;          // your top level design goes here 



  initial begin	 :initial_loop
    clk   = 'b0;
    init  = 'b1;
    wr_en = 'b0;
//    static integer fi = $fopen("original_msg.txt","r");
//    $fgets(str2, fi);
    str2 = "Mr_Watson_come_here_I_want_to_see_you";//_my_aide";
    str_len = str2.len     ;
    if(str_len>50) 
      $display("illegally long string of length %d, truncating to 50 chars.",str_len);
//    for(int ml=50; ml<64; ml++)
//      str2[ml] = 8'h5f;
// the 6 possible (constant) maximal-length feedback tap patterns from which to choose
    LFSR_ptrn[0] = 6'h21;
    LFSR_ptrn[1] = 6'h2D;
    LFSR_ptrn[2] = 6'h30;
    LFSR_ptrn[3] = 6'h33;
    LFSR_ptrn[4] = 6'h36;
    LFSR_ptrn[5] = 6'h39;
// set preamble lengths for the program runs (always > 6)
// ***** choose any value > 6 *****
    pre_length                    = 10;    // values 7 to 63 recommended

    if(pre_length < 7) begin
      $display("illegal preamble length chosen, overriding with 8");
      pre_length =  8;                     // override < 6 with a legal value
    end  
    else
      $display("preamble length = %d",pre_length);

// select LFSR tap pattern
// ***** choose any value < 6 *****
    pat_sel                       =  2;
    if(pat_sel > 5) begin 
      $display("illegal pattern select chosen, overriding with 3");
      pat_sel = 3;                         // overrides illegal selections
    end  
    else
      $display("tap pattern %d selected",pat_sel);

// set starting LFSR state for program -- 
// ***** choose any 6-bit nonzero value *****
    LFSR_init = 6'h01;                     // for program 2 run
    if(!LFSR_init) begin
      $display("illegal zero LFSR start pattern chosen, overriding with 6'h01");
      LFSR_init = 6'h01;                   // override 0 with a legal (nonzero) value
    end
    else
      $display("LFSR starting pattern = %b",LFSR_init);
    $display("original message string length = %d",str_len);
    for(lk = 0; lk<str_len; lk++)
      if(str2[lk]==8'h5f) continue;	       // count leading _ chars in string
	  else break;                          // we shall add these to preamble pad length
    
	$display("embedded leading underscore count = %d",lk);
// precompute encrypted message
	lfsr_ptrn = LFSR_ptrn[pat_sel];        // select one of the 6 permitted tap ptrns
// write the three control settings into data_memory of DUT

/*  This block of code is for encoder testing only, not decoder
    @(posedge clk);
    @(posedge clk) begin
      wr_en   <= 'b1;    
      waddr   <= 'd61;                     
      data_in <= pre_length;
    end  
    @(posedge clk) begin
      waddr   <= 'd62;
      data_in <= lfsr_ptrn;
    end
    @(posedge clk) begin
      waddr   <= 'd63;
      data_in <= {2'b0,LFSR_init};
    end
// write the original message to data_memory
    for (int pq = 0; pq<61; pq++) begin
      @(posedge clk)
      waddr   <= pq;      
      data_in <= str2[pq];    
    end
    @(posedge clk) wr_en <= 'b0;           // turn off memory write enable for remainder of test
// end encoder-specific block    
*/


	  lfsr2[0]     = LFSR_init;              // any nonzero value (zero may be helpful for debug)
    $display("run encryption of this original message: ");
    $display("%s",str2);                   // print original message in transcript window
    $display();
    $display("LFSR_ptrn = %h, LFSR_init = %h %h",lfsr_ptrn,LFSR_init,lfsr2[0]);
    for(int j=0; j<64; j++) 			   // pre-fill message_padded with ASCII _ characters
      msg_padded2[j] = 8'h5f;         
    for(int l=0; l<str_len; l++)  		   // overwrite up to 60 of these spaces w/ message itself
	  msg_padded2[pre_length+l] = byte'(str2[l]); 

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


// run decryption program 
    repeat(5) @(posedge clk);

    for(int qp=0; qp<64; qp++) begin
      @(posedge clk);
      wr_en   <= 'b1;                   // turn on memory write enable
      waddr   <= qp+64;                 // write encrypted message to mem [64:127]
      data_in <= msg_crypto2[qp];
    end

    @(posedge clk)
      wr_en   <= 'b0;                   // turn off mem write for rest of simulation
//    for(int n=64; n<128; n++)
//	  dut.dm1.core[n] = msg_crypto2[n-64]; //{^msg_crypto2[n-64][6:0],msg_crypto2[n-64][6:0]};

    @(posedge clk) 
      init    <= 0 ;

    repeat(6) @(posedge clk);              // wait for 6 clock cycles of nominal 10ns each
    wait(done);                            // wait for DUT's done flag to go high
    
    #10ns $display("done at time %t",$time);
    $display("run decryption:");

    for(int nn=0; nn<64; nn++)			   // count leading underscores
      if(str2[nn]==8'h5f) ct++; 
	  else break;
	  $display("ct = %d",ct);

    for(int n=0; n<str_len+1; n++) begin
      @(posedge clk);
      raddr          <= n;
      @(posedge clk);
      msg_decryp2[n] <= data_out;
    end

    for(int rr=0; rr<str_len+1; rr++)
      str_dec2[rr] = string'(msg_decryp2[rr]);

    @(posedge clk)
    for(int qq=0; qq<str_len+1; qq++)
      $writeh(msg_decryp2[qq]);
    $display();

    for(int ss=0; ss<str_len+1; ss++)
      $write("%s",str_dec2[ss]);
    $display();  

//    $display("%d bench msg: %h dut msg: %h    %s",
//          n, str2[n+ct], dut.dm1.core[n], dut.dm1.core[n]);   
//    $fclose(fi);      

    #20ns $stop;
  end  :initial_loop

always begin							 // continuous loop
  #5ns clk = 1;							 // clock tick
  #5ns clk = 0;							 // clock tock
end										 // continue

endmodule