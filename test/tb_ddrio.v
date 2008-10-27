/*
 * High Performance Dynamic Memory Controller
 * Copyright (C) 2008 Sebastien Bourdeauducq - http://lekernel.net
 * This file is part of HPDMC.
 *
 * HPDMC is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Library General Public License as published
 * by the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301,
 * USA.
 */

`timescale 1ns / 1ps

`define SINGLEWBURST
`define MULTIWBURST
`define SINGLERBURST
`define MULTIRBURST

module tb_ddrio();

/* clk should have a small delay relative to clk2x
 * to meet the setup/hold time requirement of registers
 * synchronous to clk2x whose input depend on clk.
 */
reg clk_p;
initial clk_p = 1'b0;
always #5 clk_p = ~clk;
reg clk;
initial clk = 1'b0;
always @(clk_p) #0.5 clk <= clk_p;

reg clk2x;
initial clk2x = 1'b1;
always #2.5 clk2x = ~clk2x;

reg rst;

reg op_write;
reg op_read;

reg buffer_w_load;
reg [7:0] buffer_w_mask;
reg [63:0] buffer_w_dat;

reg buffer_r_next;
reg buffer_r_nextburst;
wire [63:0] buffer_r_dat;

wire [31:0] sdram_dq;
wire [3:0] sdram_dqs;
hpdmc_ddrio ddrio(
	.clk(clk),
	.clk2x(clk2x),
	.rst(rst),
	
	.op_write(op_write),
	.op_read(op_read),
	
	.buffer_w_load(buffer_w_load),
	.buffer_w_mask(buffer_w_mask),
	.buffer_w_dat(buffer_w_dat),
	
	.buffer_r_next(buffer_r_next),
	.buffer_r_nextburst(buffer_r_nextburst),
	.buffer_r_dat(buffer_r_dat),
	
	.sdram_dqm(),
	.sdram_dq(sdram_dq),
	.sdram_dqs(sdram_dqs)
);

task waitclock;
begin
	wait(clk == 1'b0);
	wait(clk == 1'b1);
	#1;
end
endtask

task pushdata;
input [63:0] data;
begin
	$display("Pushing %x into the Write FIFO", data);
	buffer_w_mask = 8'hff;
	buffer_w_dat = data;
	buffer_w_load = 1'b1;
	waitclock;
	buffer_w_load = 1'b0;
end
endtask

task pulldata;
begin
	$display("Pulling %x from the Read FIFO", buffer_r_dat);
	waitclock;
end
endtask

reg [31:0] sentdata;
initial sentdata = 32'hzzzzzzzz;
reg [3:0] sentstrobe;
initial sentstrobe = 4'hz;

reg sendburst8;
always @(posedge sendburst8) begin
	#5  sentdata = 32'h11111111;
	#5  sentdata = 32'h22222222;
	#5  sentdata = 32'h33333333;
	#5  sentdata = 32'h44444444;
	#5  sentdata = 32'h55555555;
	#5  sentdata = 32'h66666666;
	#5  sentdata = 32'h77777777;
	#5  sentdata = 32'h88888888;
	#5  sentdata = 32'hzzzzzzzz;
end

always @(posedge sendburst8) begin
	#2.5  sentstrobe = 4'h0;
	#5    sentstrobe = 4'hf;
	#5    sentstrobe = 4'h0;
	#5    sentstrobe = 4'hf;
	#5    sentstrobe = 4'h0;
	#5    sentstrobe = 4'hf;
	#5    sentstrobe = 4'h0;
	#5    sentstrobe = 4'hf;
	#5    sentstrobe = 4'h0;
	#5    sentstrobe = 4'hz;
end

reg sendburst16;
always @(posedge sendburst16) begin
	#5  sentdata = 32'h11111111;
	#5  sentdata = 32'h22222222;
	#5  sentdata = 32'h33333333;
	#5  sentdata = 32'h44444444;
	#5  sentdata = 32'h55555555;
	#5  sentdata = 32'h66666666;
	#5  sentdata = 32'h77777777;
	#5  sentdata = 32'h88888888;
	#5  sentdata = 32'h99999999;
	#5  sentdata = 32'haaaaaaaa;
	#5  sentdata = 32'hbbbbbbbb;
	#5  sentdata = 32'hcccccccc;
	#5  sentdata = 32'hdddddddd;
	#5  sentdata = 32'heeeeeeee;
	#5  sentdata = 32'hffffffff;
	#5  sentdata = 32'h00000000;
	#5  sentdata = 32'hzzzzzzzz;
end

always @(posedge sendburst16) begin
	#2.5  sentstrobe = 4'h0;
	#5    sentstrobe = 4'hf;
	#5    sentstrobe = 4'h0;
	#5    sentstrobe = 4'hf;
	#5    sentstrobe = 4'h0;
	#5    sentstrobe = 4'hf;
	#5    sentstrobe = 4'h0;
	#5    sentstrobe = 4'hf;
	#5    sentstrobe = 4'h0;
	#5    sentstrobe = 4'hf;
	#5    sentstrobe = 4'h0;
	#5    sentstrobe = 4'hf;
	#5    sentstrobe = 4'h0;
	#5    sentstrobe = 4'hf;
	#5    sentstrobe = 4'h0;
	#5    sentstrobe = 4'hf;
	#5    sentstrobe = 4'h0;
	#5    sentstrobe = 4'hz;
end

assign sdram_dq = sentdata;
assign sdram_dqs = sentstrobe;

initial begin
	$dumpfile("ddrio.vcd");
	$dumpvars(0, ddrio);
	
	sendburst8 = 1'b0;
	sendburst16 = 1'b0;
	
	op_write = 1'b0;
	op_read = 1'b0;
	
	buffer_w_load = 1'b0;
	buffer_w_mask = 1'b0;
	
	buffer_r_next = 1'b0;
	buffer_r_nextburst = 1'b0;
	
	rst = 1'b1;
	#9 rst = 1'b0;
	
	#5;
	
`ifdef SINGLEWBURST
	$display("");
	$display("***********************************************");
	$display("* Testing single write burst (check VCD file) *");
	$display("***********************************************");
	op_write = 1'b1;
	pushdata(64'h1111111122222222);
	pushdata(64'h3333333344444444);
	pushdata(64'h5555555566666666);
	pushdata(64'h7777777788888888);
	op_write = 1'b0;
	waitclock;
`endif
	
`ifdef MULTIWBURST
	$display("");
	$display("**************************************************");
	$display("* Testing multiple write bursts (check VCD file) *");
	$display("**************************************************");
	op_write = 1'b1;
	pushdata(64'h1111111122222222);
	pushdata(64'h3333333344444444);
	pushdata(64'h5555555566666666);
	pushdata(64'h7777777788888888);
	pushdata(64'h99999999aaaaaaaa);
	pushdata(64'hbbbbbbbbcccccccc);
	pushdata(64'hddddddddeeeeeeee);
	pushdata(64'hffffffff00000000);
	op_write = 1'b0;
	waitclock;
`endif

	#10; /* write turnaround */

`ifdef SINGLERBURST
	$display("");
	$display("*****************************");
	$display("* Testing single read burst *");
	$display("*****************************");
	sendburst8 = 1'b1;
	op_read = 1'b1;
	waitclock;
	waitclock;
	buffer_r_next = 1'b1;
	pulldata;
	op_read = 1'b0;
	pulldata;
	pulldata;
	pulldata;
	buffer_r_next = 1'b0;
	sendburst8 = 1'b0;
`endif

`ifdef MULTIRBURST
	$display("");
	$display("********************************");
	$display("* Testing multiple read bursts *");
	$display("********************************");
	sendburst16 = 1'b1;
	op_read = 1'b1;
	waitclock;
	waitclock;
	buffer_r_next = 1'b1;
	pulldata;
	pulldata;
	pulldata;
	pulldata;
	pulldata;
	op_read = 1'b0;
	pulldata;
	pulldata;
	pulldata;
	buffer_r_next = 1'b0;
	sendburst8 = 1'b0;
`endif

	waitclock;
	waitclock;
	
	$finish;
end

endmodule
