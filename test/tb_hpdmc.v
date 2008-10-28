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

module tb_hpdmc();

reg clk_p;
initial clk_p = 1'b0;
always #5 clk_p = ~clk;
reg clk;
initial clk = 1'b0;
always @(clk_p) #0.5 clk <= clk_p;

reg clk2x;
initial clk2x = 1'b1;
always #2.5 clk2x = ~clk2x;

wire sdram_cke;
wire sdram_cs_n;
wire sdram_we_n;
wire sdram_cas_n;
wire sdram_ras_n;
wire [3:0] sdram_dqm;
wire [12:0] sdram_adr;
wire [1:0] sdram_ba;
wire [31:0] sdram_dq;
wire [3:0] sdram_dqs;

ddr sdram1(
	.Addr(sdram_adr),
	.Ba(sdram_ba),
	.Clk(clk),
	.Clk_n(~clk),
	.Cke(sdram_cke),
	.Cs_n(sdram_cs_n),
	.Ras_n(sdram_ras_n),
	.Cas_n(sdram_cas_n),
	.We_n(sdram_we_n),
	
	.Dm(sdram_dqm[3:2]),
	.Dqs(sdram_dqs[3:2]),
	.Dq(sdram_dq[31:16])
);

ddr sdram0(
	.Addr(sdram_adr),
	.Ba(sdram_ba),
	.Clk(clk),
	.Clk_n(~clk),
	.Cke(sdram_cke),
	.Cs_n(sdram_cs_n),
	.Ras_n(sdram_ras_n),
	.Cas_n(sdram_cas_n),
	.We_n(sdram_we_n),
	
	.Dm(sdram_dqm[1:0]),
	.Dqs(sdram_dqs[1:0]),
	.Dq(sdram_dq[15:0])
);

reg rst;

reg [31:0] wbc_adr_i;
reg [31:0] wbc_dat_i;
wire [31:0] wbc_dat_o;
reg wbc_cyc_i;
reg wbc_stb_i;
reg wbc_we_i;
wire wbc_ack_o;

reg [31:0] wb_adr_i;
reg [2:0] wb_cti_i;
reg [63:0] wb_dat_i;
wire [63:0] wb_dat_o;
reg [7:0] wb_sel_i;
reg wb_cyc_i;
reg wb_stb_i;
reg wb_we_i;
wire wb_ack_o;

reg wb_nextadr_valid;
reg [31:0] wb_nextadr;

hpdmc dut(
	.sys_clk(clk),
	.sys_clk2x(clk2x),
	.sys_rst(rst),

	.wbc_adr_i(wbc_adr_i),
	.wbc_dat_i(wbc_dat_i),
	.wbc_dat_o(wbc_dat_o),
	.wbc_sel_i(4'hf),
	.wbc_cyc_i(wbc_stb_i),
	.wbc_stb_i(wbc_stb_i),
	.wbc_we_i(wbc_we_i),
	.wbc_ack_o(wbc_ack_o),
	
	.wb_adr_i(wb_adr_i),
	.wb_cti_i(wb_cti_i),
	.wb_dat_i(wb_dat_i),
	.wb_dat_o(wb_dat_o),
	.wb_sel_i(wb_sel_i),
	.wb_cyc_i(wb_cyc_i),
	.wb_stb_i(wb_stb_i),
	.wb_we_i(wb_we_i),
	.wb_ack_o(wb_ack_o),
	
	/* Address prediction (used for reads only) */
	.wb_nextadr_valid(wb_nextadr_valid),
	.wb_nextadr(wb_nextadr),

	.sdram_cke(sdram_cke),
	.sdram_cs_n(sdram_cs_n),
	.sdram_we_n(sdram_we_n),
	.sdram_cas_n(sdram_cas_n),
	.sdram_ras_n(sdram_ras_n),
	.sdram_dqm(sdram_dqm),
	.sdram_adr(sdram_adr),
	.sdram_ba(sdram_ba),
	.sdram_dq(sdram_dq),
	.sdram_dqs(sdram_dqs)
);

/*
initial begin
	#205820 $dumpfile("ddrsignals.vcd");
	$dumpvars(0, sdram);
end
*/

task waitclock;
begin
	wait(clk == 1'b0);
	wait(clk == 1'b1);
	#1;
end
endtask

task waitnclock;
input [15:0] n;
integer i;
begin
	for(i=0;i<n;i=i+1)
		waitclock;
end
endtask

task wbcwrite;
input [31:0] address;
input [31:0] data;
integer i;
begin
	wbc_adr_i = address;
	wbc_dat_i = data;
	wbc_cyc_i = 1'b1;
	wbc_stb_i = 1'b1;
	wbc_we_i = 1'b1;
	i = 0;
	#1;
	while(~wbc_ack_o) begin
		i = i+1;
		waitclock;
	end
	wbc_cyc_i = 1'b0;
	wbc_stb_i = 1'b0;
	wbc_we_i = 1'b0;
	waitclock;
	$display("Configuration Write: %x=%x acked in %d clocks", address, data, i);
end
endtask

task wbcread;
input [31:0] address;
integer i;
begin
	wbc_adr_i = address;
	wbc_cyc_i = 1'b1;
	wbc_stb_i = 1'b1;
	wbc_we_i = 1'b0;
	i = 0;
	#1;
	while(~wbc_ack_o) begin
		i = i+1;
		waitclock;
	end
	wbc_cyc_i = 1'b0;
	wbc_stb_i = 1'b0;
	wbc_we_i = 1'b0;
	$display("Configuration Read : %x=%x acked in %d clocks", address, wbc_dat_o, i);
	waitclock;
end
endtask

task wbread;
input [31:0] address;
integer i;
begin
	wb_adr_i = address;
	wb_cyc_i = 1'b1;
	wb_stb_i = 1'b1;
	wb_we_i = 1'b0;
	wb_cti_i = 3'b000;
	i = 0;
	#1;
	while(~wb_ack_o) begin
		i = i+1;
		waitclock;
	end
	wb_cyc_i = 1'b0;
	wb_stb_i = 1'b0;
	wb_we_i = 1'b0;
	$display("Memory Read : %x=%x acked in %d clocks", address, wb_dat_o, i);
	waitclock;
end
endtask

task wbreadburst;
input [31:0] address;
integer i;
begin
	wb_adr_i = address;
	wb_cyc_i = 1'b1;
	wb_stb_i = 1'b1;
	wb_we_i = 1'b0;
	wb_cti_i = 3'b010;
	i = 0;
	#1;
	while(~wb_ack_o) begin
		i = i+1;
		waitclock;
	end
	$display("Memory Read : %x=%x acked in %d clocks", address, wb_dat_o, i);
	for(i=0;i<3;i=i+1) begin
		waitclock;
		$display("(burst continuing)     %x", wb_dat_o);
	end
	
	wb_cti_i = 3'b000;
	wb_cyc_i = 1'b0;
	wb_stb_i = 1'b0;
	wb_we_i = 1'b0;
	waitclock;
end
endtask

task wbwrite;
input [31:0] address;
input [63:0] data;
integer i;
begin
	wb_adr_i = address;
	wb_dat_i = data;
	wb_cyc_i = 1'b1;
	wb_stb_i = 1'b1;
	wb_sel_i = 8'hff;
	wb_we_i = 1'b1;
	wb_cti_i = 3'b000;
	i = 0;
	#1;
	while(~wb_ack_o) begin
		i = i+1;
		waitclock;
	end
	wb_cyc_i = 1'b0;
	wb_stb_i = 1'b0;
	wb_we_i = 1'b0;
	$display("Memory Write : %x=%x acked in %d clocks", address, data, i);
	waitclock;
end
endtask

task wbwriteburst;
input [31:0] address;
integer i;
begin
	wb_adr_i = address;
	wb_cyc_i = 1'b1;
	wb_stb_i = 1'b1;
	wb_we_i = 1'b1;
	wb_sel_i = 8'hff;
	wb_dat_i = {$random, $random};
	wb_cti_i = 3'b010;
	i = 0;
	#1;
	while(~wb_ack_o) begin
		i = i+1;
		waitclock;
	end
	$display("Memory Write : %x=%x acked in %d clocks", address, wb_dat_i, i);
	for(i=0;i<3;i=i+1) begin
		wb_dat_i = {$random, $random};
		waitclock;
		$display("(burst continuing)     %x", wb_dat_i);
	end
	
	wb_cti_i = 3'b000;
	wb_cyc_i = 1'b0;
	wb_stb_i = 1'b0;
	wb_we_i = 1'b0;
	waitclock;
end
endtask

always begin
	$dumpfile("hpdmc.vcd");

	/* Reset / Initialize our logic */
	rst = 1'b1;
	
	wbc_adr_i = 32'd0;
	wbc_dat_i = 32'd0;
	wbc_cyc_i = 1'b0;
	wbc_stb_i = 1'b0;
	wbc_we_i = 1'b0;
	
	wb_adr_i = 32'd0;
	wb_cti_i = 3'd0;
	wb_dat_i = 64'd0;
	wb_sel_i = 8'd0;
	wb_cyc_i = 1'b0;
	wb_stb_i = 1'b0;
	wb_we_i = 1'b0;
	
	wb_nextadr_valid = 1'b0;
	wb_nextadr = 32'd0;
	
	waitclock;
	
	rst = 1'b0;
	
	waitclock;
	
	/* SDRAM initialization sequence. */
	/* The controller already comes up in Bypass mode with CKE disabled. */
	
	/* Wait 200us */
	#200000;
	
	/* Bring CKE high */
	wbcwrite(32'h00, 32'h07);
	/* Precharge All:
	 * CS=1
	 * WE=1
	 * CAS=0
	 * RAS=1
	 * A=A10
	 * BA=Don't Care
	 */
	wbcwrite(32'h04, 32'b00_0010000000000_1011);
	waitnclock(2);
	
	/* Load Extended Mode Register:
	 * CS=1
	 * WE=1
	 * CAS=1
	 * RAS=1
	 * A=Value
	 * BA=01
	 *
	 * Extended mode register encoding :
	 * A12-A2 reserved, must be 0
	 * A1 weak drive strength
	 * A0 DLL disable
	 */
	wbcwrite(32'h04, 32'b01_0000000000000_1111);
	waitnclock(2);
	
	/* Load Mode Register, DLL in Reset:
	 * CS=1
	 * WE=1
	 * CAS=1
	 * RAS=1
	 * A=Value
	 * BA=00
	 *
	 * Mode register encoding :
	 * A12-A7 = 000000 Normal operation w/o DLL reset
	 *          000010 Normal operation in DLL reset
	 * A6-A4  = 010    CL2
	 * A3     = 0      Sequential burst
	 * A2-A0  = 011    Burst length = 8
	 */
	wbcwrite(32'h04, 32'b00__000010_010_0_011__1111);
	waitnclock(200);
	
	/* Precharge All */
	wbcwrite(32'h04, 32'b00_0010000000000_1011);
	waitnclock(2);
	
	/* Auto Refresh
	 * CS=1
	 * WE=0
	 * CAS=1
	 * RAS=1
	 * A=Don't Care
	 * BA=Don't Care
	 */
	wbcwrite(32'h04, 32'b00_0000000000000_1101);
	waitnclock(8);
	
	/* Auto Refresh */
	wbcwrite(32'h04, 32'b00_0000000000000_1101);
	waitnclock(8);
	
	/* Load Mode Register, DLL enabled */
	wbcwrite(32'h04, 32'b00__000000_010_0_011__1111);
	waitnclock(200);
	
	/* SDRAM initialization complete.
	 * Now, disable Bypass mode and bring up the hardware controller.
	 */
	
	/* We want to know what it sends to the SDRAM chips */
	$dumpvars(0, dut);
	
	wbcwrite(32'h00, 32'h04);
	waitnclock(30);
	
	/*
	 * Try some transfers.
	 */
	/*
	wb_nextadr = 32'h00000020;
	wb_nextadr_valid = 1'b1;
	wbreadburst(32'h00);
	wb_nextadr = 32'h00000040;
	wbreadburst(32'h20);
	wb_nextadr = 32'h00000060;
	wbreadburst(32'h40);
	wb_nextadr_valid = 1'b0;
	wbreadburst(32'h60);*/
	
	//wbwrite(32'h00000000, 64'h1111222233334444);
	
	wbwriteburst(32'h00);
	wbwriteburst(32'h20);
 	wbwriteburst(32'h40);
 	wbwriteburst(32'h12340);
 	wbwriteburst(32'h12360);
	waitnclock(10);
	wbreadburst(32'h00);
	//wbreadburst(32'h00);
	//waitnclock(10);
	
	$finish;
end

endmodule

