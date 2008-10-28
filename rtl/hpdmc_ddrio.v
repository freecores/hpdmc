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

//`default_nettype none

module hpdmc_ddrio(
	input clk,
	input clk2x,
	input rst,
	
	/* First data is sent one cycle after op_write is asserted.
	 * It should be asserted for n*4 cycles (n=number of bursts).
	 */
	input op_write,
	input op_read,
	
	input buffer_w_next,
	input buffer_w_nextburst,
	input [7:0] buffer_w_mask,
	input [63:0] buffer_w_dat,
	
	input buffer_r_next,
	input buffer_r_nextburst,
	output [63:0] buffer_r_dat,
	
	output [3:0] sdram_dqm,
	inout [31:0] sdram_dq,
	inout [3:0] sdram_dqs
);

/*
 * Write FIFO, 8-word deep. MSB is the mask.
 */

reg wfifo_enable;
always @(posedge clk) wfifo_enable = op_write;

reg [3:0] wfifomask1[0:3];
reg [3:0] wfifomask0[0:3];
reg [31:0] wfifo1[0:3];
reg [31:0] wfifo0[0:3];
reg [1:0] wfifo_produce;
reg [1:0] wfifo_consume;

/* Writes to the Write FIFO */
always @(posedge clk) begin
	if(buffer_w_nextburst) begin
		wfifomask1[0] <= buffer_w_mask[7:4];
		wfifomask1[1] <= 4'b1111;
		wfifomask1[2] <= 4'b1111;
		wfifomask1[3] <= 4'b1111;
		wfifomask0[0] <= buffer_w_mask[3:0];
		wfifomask0[1] <= 4'b1111;
		wfifomask0[2] <= 4'b1111;
		wfifomask0[3] <= 4'b1111;
		wfifo1[0] <= buffer_w_dat[63:32];
		wfifo0[0] <= buffer_w_dat[31:0];
		wfifo_produce <= 2'b01;
	end else if(buffer_w_next) begin
		wfifo_produce <= wfifo_produce + 1;
		wfifomask1[wfifo_produce] <= buffer_w_mask[7:4];
		wfifomask0[wfifo_produce] <= buffer_w_mask[3:0];
		wfifo1[wfifo_produce] <= buffer_w_dat[63:32];
		wfifo0[wfifo_produce] <= buffer_w_dat[31:0];
	end
end

/* Reads from the Write FIFO */
reg [3:0] wfifo_outmask;
reg [31:0] wfifo_out;
always @(posedge rst, negedge clk2x) begin
	if(rst)
		wfifo_consume <= 2'b11;
	else begin
		if(clk) begin
			if(wfifo_enable)
				wfifo_consume <= wfifo_consume + 1;
			wfifo_outmask <= wfifomask0[wfifo_consume];
			wfifo_out <= wfifo0[wfifo_consume];
			if(wfifo_enable)
				$display("Read from LOW Write FIFO(%d) Mask %h", wfifo_consume, wfifomask0[wfifo_consume]);
		end else begin
			wfifo_outmask <= wfifomask1[wfifo_consume];
			wfifo_out <= wfifo1[wfifo_consume];
		end
	end
end

/* Generate DQ/DQM/DQS */
reg wfifo_enable_r;
always @(posedge clk) wfifo_enable_r <= wfifo_enable;
reg dq_drive;
always @(posedge rst, posedge clk2x) begin
	if(rst)
		dq_drive <= 1'b0;
	else begin
		if(~clk) begin
			if(~wfifo_enable_r) dq_drive <= 1'b0;
		end else begin
			if(wfifo_enable) dq_drive <= 1'b1;
		end
	end
end

assign sdram_dq = dq_drive ? wfifo_out : 32'hzzzzzzzz;
assign sdram_dqm = wfifo_outmask;
assign sdram_dqs = dq_drive ? {4{clk}} : 4'hz;


/*
 * Read FIFO, 8-word deep
 */

reg read_enable;
reg op_read_r;
always @(posedge clk) op_read_r <= op_read;
always @(negedge clk) read_enable <= op_read | op_read_r;

reg [7:0] rfifo7[0:3];
reg [7:0] rfifo6[0:3];
reg [7:0] rfifo5[0:3];
reg [7:0] rfifo4[0:3];
reg [7:0] rfifo3[0:3];
reg [7:0] rfifo2[0:3];
reg [7:0] rfifo1[0:3];
reg [7:0] rfifo0[0:3];
reg [1:0] rfifo_produce0;
reg [1:0] rfifo_produce1;
reg [1:0] rfifo_produce2;
reg [1:0] rfifo_produce3;
reg [1:0] rfifo_consume;

/* Writes to the Read FIFO */

/* DQS0 */
always @(posedge sdram_dqs[0]) begin
	if(read_enable)
		rfifo4[rfifo_produce0] <= sdram_dq[7:0];
end
always @(posedge rst, negedge sdram_dqs[0]) begin
	if(rst)
		rfifo_produce0 <= 2'b00;
	else begin
		if(read_enable) begin
			rfifo_produce0 <= rfifo_produce0 + 1;
			rfifo0[rfifo_produce0] <= sdram_dq[7:0];
		end
	end
end

/* DQS1 */
always @(posedge sdram_dqs[1]) begin
	if(read_enable)
		rfifo5[rfifo_produce1] <= sdram_dq[15:8];
end
always @(posedge rst or negedge sdram_dqs[1]) begin
	if(rst)
		rfifo_produce1 <= 2'b00;
	else begin
		if(read_enable) begin
			rfifo_produce1 <= rfifo_produce1 + 1;
			rfifo1[rfifo_produce1] <= sdram_dq[15:8];
		end
	end
end

/* DQS2 */
always @(posedge sdram_dqs[2]) begin
	if(read_enable)
		rfifo6[rfifo_produce2] <= sdram_dq[23:16];
end
always @(posedge rst or negedge sdram_dqs[2]) begin
	if(rst)
		rfifo_produce2 <= 2'b00;
	else begin
		if(read_enable) begin
			rfifo_produce2 <= rfifo_produce2 + 1;
			rfifo2[rfifo_produce2] <= sdram_dq[23:16];
		end
	end
end

/* DQS3 */
always @(posedge sdram_dqs[3]) begin
	if(read_enable)
		rfifo7[rfifo_produce3] <= sdram_dq[31:24];
end
always @(posedge rst, negedge sdram_dqs[3]) begin
	if(rst)
		rfifo_produce3 <= 2'b00;
	else begin
		if(read_enable) begin
			rfifo_produce3 <= rfifo_produce3 + 1;
			rfifo3[rfifo_produce3] <= sdram_dq[31:24];
		end
	end
end

/* Reads from the Read FIFO */
always @(posedge rst, posedge clk) begin
	if(rst)
		rfifo_consume <= 2'b00;
	else begin
		if(buffer_r_nextburst)
			rfifo_consume <= 2'b00;
		else if(buffer_r_next)
			rfifo_consume <= rfifo_consume + 1;
	end
end

assign buffer_r_dat = {rfifo7[rfifo_consume],
			rfifo6[rfifo_consume],
			rfifo5[rfifo_consume],
			rfifo4[rfifo_consume],
			rfifo3[rfifo_consume],
			rfifo2[rfifo_consume],
			rfifo1[rfifo_consume],
			rfifo0[rfifo_consume]};

endmodule
