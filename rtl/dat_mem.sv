// Create Date:    2019.07.25
// Module Name:    dat_mem 
//
// dual-port reg file (simultaneous read and write
//   with separate address pointers)

// data memory (reg file) for CSE140L labs 4 and 5
// suggest using this one pretty much as-is, change
//   if you really need/desire to
// parameter defaults could be almost anyting,
//  because we are overriding them from top_level
//  when we instantiate this submodule
module dat_mem #(parameter W=8,               // data width 
                           byte_count=256)(	  // content size
  input           clk,
                  write_en,	               // write (store) enable
  input  [$clog2(byte_count)-1:0] raddr,   // read pointer
                  waddr,	               // write (store) pointer
  input  [ W-1:0] data_in,				   // data to write
  output [ W-1:0] data_out				   // read data out
    );

// W bits wide [W-1:0] and byte_count registers deep 	 
// this reg file is an 8x256 (default sizes) 2-dimensional array
// address pointer works down the long dimension
// data path connects across the short dimension
logic [W-1:0] core[byte_count];	 

// combinational reads w/ blanking of address 0
assign      data_out = core[raddr] ;	 

// sequential (clocked) writes	
always_ff @ (posedge clk)
  if (write_en)
    core[waddr] <= data_in;

endmodule
