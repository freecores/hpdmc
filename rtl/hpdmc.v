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

/*
 * This core targets 32-bit wide DDR SDRAM chips.
 *
 * Static parameters are capacity and column count,
 * the rest is configured at runtime.
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
	/* Clock and Reset signals are shared between all interfaces */
	input sys_clk,
	input sys_clk2x,
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
	
	/* Memory WISHBONE interface */
	/* Only classic and incrementing burst transfers are supported.
	 * NB. Bursts of more than 4 words will be interrupted.
	 */
	input [31:0] wb_adr_i,
	input [2:0] wb_cti_i,
	input [63:0] wb_dat_i,
	output [63:0] wb_dat_o,
	input [7:0] wb_sel_i,
	input wb_cyc_i,
	input wb_stb_i,
	input wb_we_i,
	output wb_ack_o,
	
	/* Address prediction (used for reads only) */
	input wb_nextadr_valid,
	input [31:0] wb_nextadr,

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

/* Register all control signals */
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
 * CKE is always in bypass mode.
 */
wire bypass;

wire sdram_cs_n_bypass;
wire sdram_we_n_bypass;
wire sdram_cas_n_bypass;
wire sdram_ras_n_bypass;
wire [12:0] sdram_adr_bypass;
wire [1:0] sdram_ba_bypass;

wire sdram_cs_n_sched;
wire sdram_we_n_sched;
wire sdram_cas_n_sched;
wire sdram_ras_n_sched;
wire [12:0] sdram_adr_sched;
wire [1:0] sdram_ba_sched;

assign sdram_cs_n_r = bypass ? sdram_cs_n_bypass : sdram_cs_n_sched;
assign sdram_we_n_r = bypass ? sdram_we_n_bypass : sdram_we_n_sched;
assign sdram_cas_n_r = bypass ? sdram_cas_n_bypass : sdram_cas_n_sched;
assign sdram_ras_n_r = bypass ? sdram_ras_n_bypass : sdram_ras_n_sched;
assign sdram_adr_r = bypass ? sdram_adr_bypass : sdram_adr_sched;
assign sdram_ba_r = bypass ? sdram_ba_bypass : sdram_ba_sched;

/* Configuration registers and Bypass mode */
wire sdram_rst;

wire [2:0] tim_rp;
wire [2:0] tim_rcd;
wire tim_cas;
wire [10:0] tim_refi;
wire [3:0] tim_rfc;

hpdmc_conf conf(
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
	.tim_rfc(tim_rfc)
);

/* Data path */

wire op_write;
wire op_read;
wire buffer_w_load;
wire buffer_r_next;
wire buffer_r_nextburst;

hpdmc_ddrio ddrio(
	.clk(sys_clk),
	.clk2x(sys_clk2x),
	.rst(sdram_rst),
	
	.op_write(op_write),
	.op_read(op_read),
	
	.buffer_w_load(buffer_w_load),
	.buffer_w_mask(~wb_sel_i),
	.buffer_w_dat(wb_dat_i),
	
	.buffer_r_next(buffer_r_next),
	.buffer_r_nextburst(buffer_r_nextburst),
	.buffer_r_dat(wb_dat_o),
	
	.sdram_dqm(sdram_dqm),
	.sdram_dq(sdram_dq),
	.sdram_dqs(sdram_dqs)
);

/* Scheduler */

hpdmc_scheduler #(
	.sdram_depth(sdram_depth),
	.sdram_columndepth(sdram_columndepth)
) scheduler (
	.sys_clk(sys_clk),
	.sdram_rst(sdram_rst),
	
	.wb_adr_i(wb_adr_i),
	.wb_cti_i(wb_cti_i),
	.wb_sel_i(wb_sel_i),
	.wb_cyc_i(wb_cyc_i),
	.wb_stb_i(wb_stb_i),
	.wb_we_i(wb_we_i),
	.wb_ack_o(wb_ack_o),
	
	.wb_nextadr_valid(wb_nextadr_valid),
	.wb_nextadr(wb_nextadr),
	
	.tim_rp(tim_rp),
	.tim_rcd(tim_rcd),
	.tim_cas(tim_cas),
	.tim_refi(tim_refi),
	.tim_rfc(tim_rfc),
	
	.sdram_cs_n(sdram_cs_n_sched),
	.sdram_we_n(sdram_we_n_sched),
	.sdram_cas_n(sdram_cas_n_sched),
	.sdram_ras_n(sdram_ras_n_sched),
	.sdram_adr(sdram_adr_sched),
	.sdram_ba(sdram_ba_sched),
	
	.op_write(op_write),
	.op_read(op_read),
	
	.buffer_w_load(buffer_w_load),
	.buffer_w_mask(buffer_w_mask),
	.buffer_w_dat(buffer_w_dat),
	
	.buffer_r_next(buffer_r_next),
	.buffer_r_nextburst(buffer_r_nextburst),
	.buffer_r_dat(buffer_r_dat)
);

endmodule
