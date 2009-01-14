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

module hpdmc_ctlif(
	input sys_clk,
	input sys_rst,
	
	input [31:0] wbc_adr_i,
	input [31:0] wbc_dat_i,
	output reg [31:0] wbc_dat_o,
	input [3:0] wbc_sel_i,
	input wbc_cyc_i,
	input wbc_stb_i,
	input wbc_we_i,
	output reg wbc_ack_o,
	
	output reg bypass,
	output reg sdram_rst,
	
	output reg sdram_cke,
	output reg sdram_cs_n,
	output reg sdram_we_n,
	output reg sdram_cas_n,
	output reg sdram_ras_n,
	output reg [12:0] sdram_adr,
	output reg [1:0] sdram_ba,
	
	/* Clocks we must wait following a PRECHARGE command (usually tRP). */
	output reg [2:0] tim_rp,
	/* Clocks we must wait following an ACTIVATE command (usually tRCD). */
	output reg [2:0] tim_rcd,
	/* CAS latency, 0 = 2 */
	output reg tim_cas,
	/* Auto-refresh period (usually tREFI). */
	output reg [10:0] tim_refi,
	/* Clocks we must wait following an AUTO REFRESH command (usually tRFC). */
	output reg [3:0] tim_rfc,
	/* Clocks we must wait following the last word written to the SDRAM (usually tWR). */
	output reg [1:0] tim_wr,
	
	output reg idelay_rst,
	output reg idelay_ce,
	output reg idelay_inc
);

always @(posedge sys_clk) begin
	if(sys_rst) begin
		wbc_ack_o <= 1'b0;
	
		bypass <= 1'b1;
		sdram_rst <= 1'b1;
		
		sdram_cke <= 1'b0;
		sdram_adr <= 13'd0;
		sdram_ba <= 2'd0;
		
		tim_rp <= 3'd2;
		tim_rcd <= 3'd2;
		tim_cas <= 1'b0;
		tim_refi <= 11'd740;
		tim_rfc <= 4'd8;
		tim_wr <= 2'd2;
	end else begin
		if(~wbc_ack_o) begin
			if(wbc_cyc_i & wbc_stb_i) begin
				if(wbc_we_i) begin
					case(wbc_adr_i[3:2])
						2'b00: begin
							bypass <= wbc_dat_i[0];
							sdram_rst <= wbc_dat_i[1];
							sdram_cke <= wbc_dat_i[2];
						end
						2'b01: begin
							sdram_cs_n <= ~wbc_dat_i[0];
							sdram_we_n <= ~wbc_dat_i[1];
							sdram_cas_n <= ~wbc_dat_i[2];
							sdram_ras_n <= ~wbc_dat_i[3];
							sdram_adr <= wbc_dat_i[16:4];
							sdram_ba <= wbc_dat_i[18:17];
						end
						2'b10: begin
							tim_rp <= wbc_dat_i[2:0];
							tim_rcd <= wbc_dat_i[5:3];
							tim_cas <= wbc_dat_i[6];
							tim_refi <= wbc_dat_i[17:7];
							tim_rfc <= wbc_dat_i[21:18];
							tim_wr <= wbc_dat_i[23:22];
						end
						2'b11: begin
							idelay_rst <= wbc_dat_i[0];
							idelay_ce <= wbc_dat_i[1];
							idelay_inc <= wbc_dat_i[2];
						end
					endcase
				end
				wbc_ack_o <= 1'b1;
			end
		end else begin
			sdram_cs_n <= 1'b1;
			sdram_we_n <= 1'b1;
			sdram_cas_n <= 1'b1;
			sdram_ras_n <= 1'b1;
			
			idelay_rst <= 1'b0;
			idelay_ce <= 1'b0;
			idelay_inc <= 1'b0;
			
			wbc_ack_o <= 1'b0;
		end
	end
end

always @(posedge sys_clk) begin
	case(wbc_adr_i[3:2])
		2'b00: wbc_dat_o <= {sdram_cke, sdram_rst, bypass};
		2'b01: wbc_dat_o <= {sdram_ba, sdram_adr, 4'h0};
		2'b10: wbc_dat_o <= {tim_wr, tim_rfc, tim_refi, tim_cas, tim_rcd, tim_rp};
		2'b11: wbc_dat_o <= 32'd0;
	endcase
end

endmodule
