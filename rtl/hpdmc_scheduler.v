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

module hpdmc_scheduler #(
	parameter sdram_depth = 26,
	parameter sdram_columndepth = 8
) (
	input sys_clk,
	input sdram_rst,
	
	input [31:0] wb_adr_i,
	input [2:0] wb_cti_i,
	input [7:0] wb_sel_i,
	input wb_cyc_i,
	input wb_stb_i,
	input wb_we_i,
	output reg wb_ack_o,
	
	input wb_nextadr_valid,
	input [31:0] wb_nextadr,
	
	/* Clocks we must wait following a PRECHARGE command (usually tRP). */
	input [2:0] tim_rp,
	/* Clocks we must wait following an ACTIVATE command (usually tRCD). */
	input [2:0] tim_rcd,
	/* CAS latency, 0 = 2 or 2.5 (autodetected), 1 = 3 */
	input tim_cas,
	/* Auto-refresh period (usually tREFI). */
	input [10:0] tim_refi,
	/* Clocks we must wait following an AUTO REFRESH command (usually tRFC). */
	input [3:0] tim_rfc,
	
	output sdram_cs_n,
	output sdram_we_n,
	output sdram_cas_n,
	output sdram_ras_n,
	output [12:0] sdram_adr,
	output [1:0] sdram_ba,
	
	output op_write,
	output op_read,
	
	output reg buffer_w_next,
	output reg buffer_w_nextburst,
	output [7:0] buffer_w_mask,
	output [63:0] buffer_w_dat,
	
	output reg buffer_r_next,
	output reg buffer_r_nextburst,
	input [63:0] buffer_r_dat
);

/* Fetch queue */

reg wishbone_req;
reg wishbone_we;
reg [sdram_depth-3-1:0] wishbone_adr;
reg prefetch_req;
reg [sdram_depth-3-1:0] prefetch_adr;

always @(posedge sdram_rst, posedge sys_clk) begin
	if(sdram_rst) begin
		wishbone_req <= 1'b0;
		prefetch_req <= 1'b0;
	end else begin
		wishbone_req <= wb_cyc_i & wb_stb_i & ~wb_ack_o;
		wishbone_we <= wb_we_i;
		wishbone_adr <= wb_adr_i[sdram_depth-1:3];
		prefetch_req <= wb_nextadr_valid;
		prefetch_adr <= wb_nextadr[sdram_depth-1:3];
	end
end

reg next_address_valid;
reg next_address_we;
reg [sdram_depth-3-1:0] next_address;
reg address_valid;
/* if the address_we bit is set to 1, this means that the WB is waiting on write ;
 * it is safe to send the Write command immediately as the bus will be
 * able to supply the data.
 */
reg address_we;
reg [sdram_depth-3-1:0] address;
reg fetched_address_valid;
reg write_valid;
reg [sdram_depth-3-1:0] fetched_address;

wire wishbone_req_valid = wishbone_req
	& ((wishbone_adr != next_address)    | (wishbone_we != next_address_we) | ~next_address_valid)
	& ((wishbone_adr != address)         | (wishbone_we != address_we)      | ~address_valid)
	& ((wishbone_adr != fetched_address) | (wishbone_we != write_valid)     | ~(fetched_address_valid|write_valid));

wire prefetch_req_valid = prefetch_req
	& ((prefetch_adr != next_address)    | ~next_address_valid)
	& ((prefetch_adr != address)         | ~address_valid)
	& ((prefetch_adr != fetched_address) | ~fetched_address_valid);

reg fq_clearfetch;
reg fq_next;

always @(posedge sdram_rst, posedge sys_clk) begin
	if(sdram_rst) begin
		next_address_valid <= 1'b0;
		address_valid <= 1'b0;
		fetched_address_valid <= 1'b0;
		write_valid <= 1'b0;
	end else begin
		if(fq_next) begin
			fetched_address_valid <= address_valid & ~address_we;
			write_valid <= address_valid & address_we;
			fetched_address <= address;
		end else if(fq_clearfetch) begin
			fetched_address_valid <= 1'b0;
			write_valid <= 1'b0;
		end
		if(fq_next) begin
			next_address_valid <= 1'b0;
			next_address_we <= 1'b0;
			address_valid <= next_address_valid;
			address_we <= next_address_we;
			address <= next_address;
		end else begin
			case({next_address_valid, address_valid, wishbone_req_valid, prefetch_req_valid})
				4'b0001: begin
					address_valid <= 1'b1;
					address_we <= 1'b0;
					address <= prefetch_adr;
				end
				4'b0010: begin
					address_valid <= 1'b1;
					address_we <= wishbone_we;
					address <= wishbone_adr;
				end
				4'b0011: begin
					next_address_valid <= 1'b1;
					next_address_we <= 1'b0;
					next_address <= prefetch_adr;
					address_valid <= 1'b1;
					address_we <= wishbone_we;
					address <= wishbone_adr;
				end
				4'b0101: begin
					next_address_valid <= 1'b1;
					next_address_we <= 1'b0;
					next_address <= prefetch_adr;
				end
				4'b0110: begin
					next_address_valid <= 1'b1;
					next_address_we <= wishbone_we;
					next_address <= wishbone_adr;
				end
				4'b0111: begin
					next_address_valid <= 1'b1;
					next_address_we <= wishbone_we;
					next_address <= wishbone_adr;
				end
			endcase
		end
	end
end

/*
 * Address Mapping :
 * |    ROW ADDRESS   |    BANK NUMBER    |  COL ADDRESS  | for 32-bit words
 * |depth-1 coldepth+2|coldepth+1 coldepth|coldepth-1    0|
 * (depth for 32-bit words, which is sdram_depth-2)
 */

parameter rowdepth = sdram_depth-2-1-(sdram_columndepth+2)+1;

wire [sdram_depth-1-2:0] address32 = {address, 1'b0};

wire [sdram_columndepth-1:0] col_address = address32[sdram_columndepth-1:0];
wire [1:0] bank_address = address32[sdram_columndepth+1:sdram_columndepth];
wire [rowdepth-1:0] row_address = address32[sdram_depth-2-1:sdram_columndepth+2];

/* Track open rows */
reg [3:0] has_openrow;
reg [rowdepth-1:0] openrows[0:3];
reg [3:0] track_close;
reg [3:0] track_open;

always @(posedge sdram_rst, posedge sys_clk) begin
	if(sdram_rst) begin
		has_openrow = 4'h0;
	end else begin
		has_openrow = (has_openrow | track_open) & ~track_close;
		
		if(track_open[0]) openrows[0] <= row_address;
		if(track_open[1]) openrows[1] <= row_address;
		if(track_open[2]) openrows[2] <= row_address;
 		if(track_open[3]) openrows[3] <= row_address;
	end
end

/* Check for page hits */
wire bank_open = has_openrow[bank_address]; 
wire page_hit = bank_open & (openrows[bank_address] == row_address);

/* Address drivers */

reg sdram_adr_loadrow;
reg sdram_adr_loadcol;
reg sdram_adr_loadA10;
assign sdram_adr =
	 ({13{sdram_adr_loadrow}}	& row_address)
	|({13{sdram_adr_loadcol}}	& col_address)
	|({13{sdram_adr_loadA10}}	& 13'd1024);

assign sdram_ba = bank_address;

/* Command drivers */

reg sdram_cs;
reg sdram_we;
reg sdram_cas;
reg sdram_ras;
assign sdram_cs_n = ~sdram_cs;
assign sdram_we_n = ~sdram_we;
assign sdram_cas_n = ~sdram_cas;
assign sdram_ras_n = ~sdram_ras;

/* Timing counters */

/* The number of clocks we must wait following a PRECHARGE command (usually tRP). */
reg [2:0] precharge_counter;
reg reload_precharge_counter;
wire precharge_done = (precharge_counter == 3'd0);
always @(posedge sys_clk) begin
	if(reload_precharge_counter)
		precharge_counter <= tim_rp;
	else if(~precharge_done)
		precharge_counter <= precharge_counter - 3'd1;
end

/* The number of clocks we must wait following an ACTIVATE command (usually tRCD). */
reg [2:0] activate_counter;
reg reload_activate_counter;
wire activate_done = (activate_counter == 3'd0);
always @(posedge sys_clk) begin
	if(reload_activate_counter)
		activate_counter <= tim_rcd;
	else if(~activate_done)
		activate_counter <= activate_counter - 3'd1;
end

/* The number of clocks we must wait before the first data is sent after a READ (CAS latency). */
reg [1:0] cas_counter;
reg reload_cas_counter;
wire cas_done = (cas_counter == 2'd0);
always @(posedge sys_clk) begin
	if(reload_cas_counter)
		cas_counter <= {1'b1, tim_cas};
	else if(~cas_done)
		cas_counter <= cas_counter - 2'd1;
end

/* The number of clocks we have left before we must refresh one row in the SDRAM array. */
reg [10:0] refresh_counter;
reg reload_refresh_counter;
wire must_refresh = refresh_counter == 11'd0;
always @(posedge sdram_rst, posedge sys_clk) begin
	if(sdram_rst)
		refresh_counter <= 11'd0;
	else begin
		if(reload_refresh_counter)
			refresh_counter <= tim_refi;
		else if(~must_refresh)
			refresh_counter <= refresh_counter - 11'd1;
	end
end

/* The number of clocks we must wait following an AUTO REFRESH command (usually tRFC). */
reg [3:0] autorefresh_counter;
reg reload_autorefresh_counter;
wire autorefresh_done = (autorefresh_counter == 4'd0);
always @(posedge sys_clk) begin
	if(reload_autorefresh_counter)
		autorefresh_counter <= tim_rfc;
	else if(~autorefresh_done)
		autorefresh_counter <= autorefresh_counter - 4'd1;
end

/* Control the DDRIO block */

wire start_ddrio_read = (cas_counter == 2'd1);
reg [1:0] readburst_counter;
wire readburst_done = (readburst_counter == 2'd0);
always @(posedge sdram_rst, posedge sys_clk) begin
	if(sdram_rst)
		readburst_counter <= 2'd0;
	else begin
		if(start_ddrio_read)
			readburst_counter <= 2'd3;
		else if(~readburst_done)
			readburst_counter <= readburst_counter - 2'd1;
	end
end
assign op_read = ~readburst_done;

reg start_ddrio_write;
reg [2:0] writeburst_counter;
wire writeburst_done = (writeburst_counter == 3'd0);
always @(posedge sdram_rst, posedge sys_clk) begin
	if(sdram_rst)
		writeburst_counter <= 3'd0;
	else begin
		if(start_ddrio_write)
			writeburst_counter <= 3'd4;
		else if(~writeburst_done)
			writeburst_counter <= writeburst_counter - 3'd1;
	end
end
assign op_write = ~writeburst_done;


/* FSM that pushes commands into the SDRAM */

reg [3:0] state;
reg [3:0] next_state;

parameter IDLE			= 4'd0;
parameter ACTIVATE		= 4'd1;
parameter READ			= 4'd2;
parameter WRITE			= 4'd3;
parameter PRECHARGEALL		= 4'd4;
parameter AUTOREFRESH		= 4'd5;
parameter AUTOREFRESH_WAIT	= 4'd6;

always @(posedge sdram_rst, posedge sys_clk) begin
	if(sdram_rst)
		state <= IDLE;
	else begin
		//$display("state: %d -> %d", state, next_state);
		state <= next_state;
	end
end

always @(*) begin
	next_state = state;
	
	reload_precharge_counter = 1'b0;
	reload_activate_counter = 1'b0;
	reload_cas_counter = 1'b0;
	reload_refresh_counter = 1'b0;
	reload_autorefresh_counter = 1'b0;
	
	sdram_cs = 1'b0;
	sdram_we = 1'b0;
	sdram_cas = 1'b0;
	sdram_ras = 1'b0;
	
	sdram_adr_loadrow = 1'b0;
	sdram_adr_loadcol = 1'b0;
	sdram_adr_loadA10 = 1'b0;
	
	fq_next = 1'b0;
	
	track_close = 4'b0000;
	track_open = 4'b0000;
	
	start_ddrio_write = 1'b0;

	case(state)
		IDLE: begin
			if(must_refresh)
				next_state = PRECHARGEALL;
			else begin
				if(address_valid) begin
					if(page_hit) begin
						if(address_we) begin
							if(readburst_done & (~write_valid | fq_clearfetch)) begin
								/* Write */
								sdram_cs = 1'b1;
								sdram_ras = 1'b0;
								sdram_cas = 1'b1;
								sdram_we = 1'b1;
								sdram_adr_loadcol = 1'b1;
								
								start_ddrio_write = 1'b1;
								
								fq_next = 1'b1;
							end
						end else begin
							if(writeburst_done & (~fetched_address_valid | fq_clearfetch)) begin
								/* Read */
								sdram_cs = 1'b1;
								sdram_ras = 1'b0;
								sdram_cas = 1'b1;
								sdram_we = 1'b0;
								sdram_adr_loadcol = 1'b1;
								
								reload_cas_counter = 1'b1;
								
								fq_next = 1'b1;
							end
						end
					end else begin
						if(bank_open) begin
							/* Precharge Bank */
							sdram_cs = 1'b1;
							sdram_ras = 1'b1;
							sdram_cas = 1'b0;
							sdram_we = 1'b1;
							
							track_close[bank_address] = 1'b1;
							reload_precharge_counter = 1'b1;
							next_state = ACTIVATE;
						end else begin
							/* Activate */
							sdram_cs = 1'b1;
							sdram_ras = 1'b1;
							sdram_cas = 1'b0;
							sdram_we = 1'b0;
							sdram_adr_loadrow = 1'b1;
				
							track_open[bank_address] = 1'b1;
							reload_activate_counter = 1'b1;
							if(address_we)
								next_state = WRITE;
							else
								next_state = READ;
						end
					end
				end
			end
		end
		
		ACTIVATE: begin
			if(precharge_done) begin
				sdram_cs = 1'b1;
				sdram_ras = 1'b1;
				sdram_cas = 1'b0;
				sdram_we = 1'b0;
				sdram_adr_loadrow = 1'b1;
				
				track_open[bank_address] = 1'b1;
				reload_activate_counter = 1'b1;
				if(address_we)
					next_state = WRITE;
				else
					next_state = READ;
			end
		end
		READ: begin
			if(activate_done) begin
				if(must_refresh)
					next_state = PRECHARGEALL;					
				else if(writeburst_done & (~fetched_address_valid | fq_clearfetch)) begin
					sdram_cs = 1'b1;
					sdram_ras = 1'b0;
					sdram_cas = 1'b1;
					sdram_we = 1'b0;
					sdram_adr_loadcol = 1'b1;
					
					reload_cas_counter = 1'b1;
					
					fq_next = 1'b1;
					next_state = IDLE;
				end
			end
		end
		WRITE: begin
			if(activate_done) begin
				if(must_refresh)
					next_state = PRECHARGEALL;
				else if(readburst_done & (~write_valid | fq_clearfetch)) begin
					sdram_cs = 1'b1;
					sdram_ras = 1'b0;
					sdram_cas = 1'b1;
					sdram_we = 1'b1;
					sdram_adr_loadcol = 1'b1;
					
					start_ddrio_write = 1'b1;
					
					fq_next = 1'b1;
					next_state = IDLE;
				end
			end
		end
		
		PRECHARGEALL: begin
			sdram_cs = 1'b1;
			sdram_ras = 1'b1;
			sdram_cas = 1'b0;
			sdram_we = 1'b1;
			sdram_adr_loadA10 = 1'b1;
					
			reload_precharge_counter = 1'b1;
			next_state = AUTOREFRESH;
		end
		AUTOREFRESH: begin
			track_close = 4'b1111;
			if(precharge_done) begin
				sdram_cs = 1'b1;
				sdram_ras = 1'b1;
				sdram_cas = 1'b1;
				sdram_we = 1'b0;
				reload_refresh_counter = 1'b1;
				reload_autorefresh_counter = 1'b1;
				next_state = AUTOREFRESH_WAIT;
			end
		end
		AUTOREFRESH_WAIT: begin
			if(autorefresh_done)
				next_state = IDLE;
		end
		
	endcase
end

/* Service WISHBONE requests */

reg [3:0] wstate;
reg [3:0] next_wstate;

parameter WIDLE 		= 4'd0;
parameter WPROCESS_READ		= 4'd1;
parameter WBURST_READ		= 4'd2;
parameter WPROCESS_WRITE	= 4'd3;
parameter WBURST_WRITE		= 4'd4;

always @(posedge sdram_rst, posedge sys_clk) begin
	if(sdram_rst)
		wstate <= WIDLE;
	else begin
		if((wstate != next_wstate) | (wstate != WIDLE)) $display("wstate: %d->%d", wstate, next_wstate);
		wstate <= next_wstate;
	end
end

reg [2:0] fetchavail_counter;
wire fetched_address_available = (fetchavail_counter == 3'd0);
always @(posedge sys_clk) begin
	if(~fetched_address_valid)
		fetchavail_counter <= {2'b10, tim_cas};
	else if(~fetched_address_available)
		fetchavail_counter <= fetchavail_counter - 3'd1;
end

wire prefetch_hit = (wishbone_adr == fetched_address);

wire burst_on = (wb_cti_i == 3'b010) & wb_cyc_i & wb_stb_i;

reg [1:0] maxburst_counter;
reg reload_maxburst_counter;
wire maxburst_done = (maxburst_counter == 2'd0);
always @(posedge sys_clk) begin
	if(reload_maxburst_counter)
		maxburst_counter <= 2'd3;
	else
		maxburst_counter <= maxburst_counter - 2'd1;
end

always @(*) begin
	next_wstate = wstate;

	wb_ack_o = 1'b0;
	
	reload_maxburst_counter = 1'b0;
	fq_clearfetch = 1'b0;
	buffer_r_next = 1'b0;
	buffer_r_nextburst = 1'b0;
	buffer_w_next = 1'b0;
	buffer_w_nextburst = 1'b0;
	
	case(wstate)
		WIDLE: begin
			buffer_r_nextburst = 1'b1;
			if(wb_cyc_i & wb_stb_i) begin
				if(wb_we_i) begin
					next_wstate = WPROCESS_WRITE;
				end else
					next_wstate = WPROCESS_READ;
			end
		end
		
		WPROCESS_READ: begin
			if(fetched_address_available) begin
				fq_clearfetch = 1'b1;
				if(prefetch_hit) begin
					wb_ack_o = 1'b1;
					buffer_r_next = 1'b1;
					reload_maxburst_counter = 1'b1;
					if(burst_on)
						next_wstate = WBURST_READ;
					else
						next_wstate = WIDLE;
				end
			end
		end
		
		WBURST_READ: begin
			wb_ack_o = 1'b1;
			buffer_r_next = 1'b1;
			if(~burst_on | maxburst_done)
				next_wstate = WIDLE;
		end
		
		WPROCESS_WRITE: begin
			if(write_valid) begin
				fq_clearfetch = 1'b1;
				wb_ack_o = 1'b1;
				buffer_w_next = 1'b1;
				reload_maxburst_counter = 1'b1;
				if(burst_on)
					next_wstate = WBURST_WRITE;
				else
					next_wstate = WIDLE;
			end else
				buffer_w_nextburst = 1'b1;
		end
		WBURST_WRITE: begin
			wb_ack_o = 1'b1;
			buffer_w_next = 1'b1;
			if(~burst_on | maxburst_done)
				next_wstate = WIDLE;
		end
	endcase
end

endmodule
