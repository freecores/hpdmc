/*
 * High Performance Dynamic Memory Controller
 * Copyright (C) 2008, 2009 Sebastien Bourdeauducq - http://lekernel.net
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

module hpdmc #(
	/*
	 * The depth of the SDRAM array, in bytes.
	 * Capacity (in bytes) is 2^sdram_depth.
	 */
	parameter sdram_depth = 26,
	
	/*
	 * The number of column address bits of the SDRAM.
	 */
	parameter sdram_columndepth = 8
) (
	input sys_clk,
	/*
	 * Clock used to generate DQS.
	 * Typically sys_clk phased out by 90 degrees,
	 * as data is sent synchronously to sys_clk.
	 */
	input dqs_clk,
	
	input sys_rst,
	
	/* Configuration WISHBONE interface */
	input [31:0] wbc_adr_i,
	input [31:0] wbc_dat_i,
	output [31:0] wbc_dat_o,
	input [3:0] wbc_sel_i,
	input wbc_cyc_i,
	input wbc_stb_i,
	input wbc_we_i,
	output wbc_ack_o,
	
	/* Simple FML 4x64 interface to the memory contents */
	input [sdram_depth-1:0] fml_adr,
	input fml_stb,
	input fml_we,
	output fml_ack,
	input [7:0] fml_sel,
	input [63:0] fml_di,
	output [63:0] fml_do,
	
	/* SDRAM interface.
	 * The SDRAM clock should be driven synchronously to the system clock.
	 * It is not generated inside this core so you can take advantage of
	 * architecture-dependent clocking resources to generate a clean
	 * differential clock.
	 */
	output reg sdram_cke,
	output reg sdram_cs_n,
	output reg sdram_we_n,
	output reg sdram_cas_n,
	output reg sdram_ras_n,
	output reg [12:0] sdram_adr,
	output reg [1:0] sdram_ba,
	
	output [3:0] sdram_dqm,
	inout [31:0] sdram_dq,
	inout [3:0] sdram_dqs
);

/* Register all control signals, leaving the possibility to use IOB registers */
wire sdram_cke_r;
wire sdram_cs_n_r;
wire sdram_we_n_r;
wire sdram_cas_n_r;
wire sdram_ras_n_r;
wire [12:0] sdram_adr_r;
wire [1:0] sdram_ba_r;

always @(posedge sys_clk) begin
	sdram_cke <= sdram_cke_r;
	sdram_cs_n <= sdram_cs_n_r;
	sdram_we_n <= sdram_we_n_r;
	sdram_cas_n <= sdram_cas_n_r;
	sdram_ras_n <= sdram_ras_n_r;
	sdram_ba <= sdram_ba_r;
	sdram_adr <= sdram_adr_r;
end

/* Mux the control signals according to the "bypass" selection.
 * CKE always comes from the control interface.
 */
wire bypass;

wire sdram_cs_n_bypass;
wire sdram_we_n_bypass;
wire sdram_cas_n_bypass;
wire sdram_ras_n_bypass;
wire [12:0] sdram_adr_bypass;
wire [1:0] sdram_ba_bypass;

wire sdram_cs_n_mgmt;
wire sdram_we_n_mgmt;
wire sdram_cas_n_mgmt;
wire sdram_ras_n_mgmt;
wire [12:0] sdram_adr_mgmt;
wire [1:0] sdram_ba_mgmt;

assign sdram_cs_n_r = bypass ? sdram_cs_n_bypass : sdram_cs_n_mgmt;
assign sdram_we_n_r = bypass ? sdram_we_n_bypass : sdram_we_n_mgmt;
assign sdram_cas_n_r = bypass ? sdram_cas_n_bypass : sdram_cas_n_mgmt;
assign sdram_ras_n_r = bypass ? sdram_ras_n_bypass : sdram_ras_n_mgmt;
assign sdram_adr_r = bypass ? sdram_adr_bypass : sdram_adr_mgmt;
assign sdram_ba_r = bypass ? sdram_ba_bypass : sdram_ba_mgmt;

/* Control interface */
wire sdram_rst;

wire [2:0] tim_rp;
wire [2:0] tim_rcd;
wire tim_cas;
wire [10:0] tim_refi;
wire [3:0] tim_rfc;
wire [1:0] tim_wr;

wire idelay_rst;
wire idelay_ce;
wire idelay_inc;

hpdmc_ctlif ctlif(
	.sys_clk(sys_clk),
	.sys_rst(sys_rst),
	
	.wbc_adr_i(wbc_adr_i),
	.wbc_dat_i(wbc_dat_i),
	.wbc_dat_o(wbc_dat_o),
	.wbc_sel_i(wbc_sel_i),
	.wbc_cyc_i(wbc_cyc_i),
	.wbc_stb_i(wbc_stb_i),
	.wbc_we_i(wbc_we_i),
	.wbc_ack_o(wbc_ack_o),
	
	.bypass(bypass),
	.sdram_rst(sdram_rst),
	
	.sdram_cke(sdram_cke_r),
	.sdram_cs_n(sdram_cs_n_bypass),
	.sdram_we_n(sdram_we_n_bypass),
	.sdram_cas_n(sdram_cas_n_bypass),
	.sdram_ras_n(sdram_ras_n_bypass),
	.sdram_adr(sdram_adr_bypass),
	.sdram_ba(sdram_ba_bypass),
	
	.tim_rp(tim_rp),
	.tim_rcd(tim_rcd),
	.tim_cas(tim_cas),
	.tim_refi(tim_refi),
	.tim_rfc(tim_rfc),
	.tim_wr(tim_wr),
	
	.idelay_rst(idelay_rst),
	.idelay_ce(idelay_ce),
	.idelay_inc(idelay_inc)
);

/* SDRAM management unit */
wire mgmt_stb;
wire mgmt_we;
wire [sdram_depth-3-1:0] mgmt_address;
wire mgmt_ack;

wire read;
wire write;
wire [3:0] concerned_bank;
wire read_safe;
wire write_safe;
wire [3:0] precharge_safe;

hpdmc_mgmt #(
	.sdram_depth(sdram_depth),
	.sdram_columndepth(sdram_columndepth)
) mgmt (
	.sys_clk(sys_clk),
	.sdram_rst(sdram_rst),
	
	.tim_rp(tim_rp),
	.tim_rcd(tim_rcd),
	.tim_refi(tim_refi),
	.tim_rfc(tim_rfc),
	
	.stb(mgmt_stb),
	.we(mgmt_we),
	.address(mgmt_address),
	.ack(mgmt_ack),
	
	.read(read),
	.write(write),
	.concerned_bank(concerned_bank),
	.read_safe(read_safe),
	.write_safe(write_safe),
	.precharge_safe(precharge_safe),
	
	.sdram_cs_n(sdram_cs_n_mgmt),
	.sdram_we_n(sdram_we_n_mgmt),
	.sdram_cas_n(sdram_cas_n_mgmt),
	.sdram_ras_n(sdram_ras_n_mgmt),
	.sdram_adr(sdram_adr_mgmt),
	.sdram_ba(sdram_ba_mgmt)
);

/* Bus interface */
wire data_ack;

hpdmc_busif #(
	.sdram_depth(sdram_depth)
) busif (
	.sys_clk(sys_clk),
	.sdram_rst(sdram_rst),
	
	.fml_adr(fml_adr),
	.fml_stb(fml_stb),
	.fml_we(fml_we),
	.fml_ack(fml_ack),
	
	.mgmt_stb(mgmt_stb),
	.mgmt_we(mgmt_we),
	.mgmt_address(mgmt_address),
	.mgmt_ack(mgmt_ack),
	
	.data_ack(data_ack)
);

/* Data path controller */
wire direction;

hpdmc_datactl datactl(
	.sys_clk(sys_clk),
	.sdram_rst(sdram_rst),
	
	.read(read),
	.write(write),
	.concerned_bank(concerned_bank),
	.read_safe(read_safe),
	.write_safe(write_safe),
	.precharge_safe(precharge_safe),
	
	.ack(data_ack),
	.direction(direction),
	
	.tim_cas(tim_cas),
	.tim_wr(tim_wr)
);

/* Data path */
hpdmc_ddrio ddrio(
	.sys_clk(sys_clk),
	.dqs_clk(dqs_clk),
	
	.direction(direction),
	/* Bit meaning is the opposite between
	 * the FML selection signal and SDRAM DQM pins.
	 */
	.mo(~fml_sel),
	.do(fml_di),
	.di(fml_do),
	
	.sdram_dqm(sdram_dqm),
	.sdram_dq(sdram_dq),
	.sdram_dqs(sdram_dqs),
	
	.idelay_rst(idelay_rst),
	.idelay_ce(idelay_ce),
	.idelay_inc(idelay_inc)
);

endmodule
