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

module hpdmc_datactl(
	input sys_clk,
	input sdram_rst,
	
	input read,
	input write,
	input [3:0] concerned_bank,
	output reg read_safe,
	output reg write_safe,
	output [3:0] precharge_safe,
	
	output reg ack,
	output reg direction,
	
	input tim_cas,
	input [1:0] tim_wr
);

/*
 * read_safe: whether it is safe to register a Read command
 * into the SDRAM at the next cycle.
 */

reg [2:0] read_safe_counter;
always @(posedge sys_clk) begin
	if(sdram_rst) begin
		read_safe_counter <= 3'd0;
		read_safe <= 1'b1;
	end else begin
		if(read) begin
			read_safe_counter <= 3'd4;
			read_safe <= 1'b0;
		end else if(write) begin
			/* after a write, read is unsafe for 5-CL cycles, therefore we load :
			 * 3 at CAS Latency 2 (tim_cas = 0)
			 * 2 at CAS Latency 3 (tim_cas = 1)
			 */
			read_safe_counter <= {2'b01, ~tim_cas};
			read_safe <= 1'b0;
		end else begin
			if(read_safe_counter == 3'd1)
				read_safe <= 1'b1;
			if(~read_safe)
				read_safe_counter <= read_safe_counter - 3'd1;
		end
	end
end

/*
 * write_safe: whether it is safe to register a Write command
 * into the SDRAM at the next cycle.
 */

reg [2:0] write_safe_counter;
always @(posedge sys_clk) begin
	if(sdram_rst) begin
		write_safe_counter <= 3'd0;
		write_safe <= 1'b1;
	end else begin
		if(read) begin
			write_safe_counter <= {2'b11, tim_cas};
			write_safe <= 1'b0;
		end else if(write) begin
			write_safe_counter <= 3'd4;
			write_safe <= 1'b0;
		end else begin
			if(write_safe_counter == 3'd1)
				write_safe <= 1'b1;
			if(~write_safe)
				write_safe_counter <= write_safe_counter - 3'd1;
		end
	end
end

/* Generate ack signal.
 * After write is asserted, it should pulse after 2 cycles.
 * After read is asserted, it should pulse after CL+3 cycles, that is
 * 5 cycles when tim_cas = 0
 * 6 cycles when tim_cas = 1
 */

reg ack_read3;
reg ack_read2;
reg ack_read1;
reg ack_read0;

always @(posedge sys_clk) begin
	if(sdram_rst) begin
		ack_read3 <= 1'b0;
		ack_read2 <= 1'b0;
		ack_read1 <= 1'b0;
		ack_read0 <= 1'b0;
	end else begin
		if(tim_cas) begin
			ack_read3 <= read;
			ack_read2 <= ack_read3;
			ack_read1 <= ack_read2;
			ack_read0 <= ack_read1;
		end else begin
			ack_read2 <= read;
			ack_read1 <= ack_read2;
			ack_read0 <= ack_read1;
		end
	end
end

reg ack0;
always @(posedge sys_clk) begin
	if(sdram_rst) begin
		ack0 <= 1'b0;
		ack <= 1'b0;
	end else begin
		ack0 <= ack_read0|write;
		ack <= ack0;
	end
end

/* during a 4-word write, we drive the pins for 5 cycles 
 * and 1 cycle in advance (first word is invalid)
 * so that we remove glitches on DQS without resorting
 * to asynchronous logic.
 */

/* direction must be glitch-free, as it directly drives the
 * tri-state enable for DQ and DQS.
 */
reg write_d;
reg [2:0] counter_writedirection;
always @(posedge sys_clk) begin
	if(sdram_rst) begin
		counter_writedirection <= 3'd0;
		direction <= 1'b0;
	end else begin
		if(write_d) begin
			counter_writedirection <= 3'b101;
			direction <= 1'b1;
		end else begin
			if(counter_writedirection == 3'b001)
				direction <= 1'b0;
			if(direction)
				counter_writedirection <= counter_writedirection - 3'd1;
		end
	end
end

always @(posedge sys_clk) begin
	if(sdram_rst)
		write_d <= 1'b0;
	else
		write_d <= write;
end

/* Counters that prevent a busy bank from being precharged */
hpdmc_banktimer banktimer0(
	.sys_clk(sys_clk),
	.sdram_rst(sdram_rst),
	
	.tim_cas(tim_cas),
	.tim_wr(tim_wr),
	
	.read(read & concerned_bank[0]),
	.write(write & concerned_bank[0]),
	.precharge_safe(precharge_safe[0])
);
hpdmc_banktimer banktimer1(
	.sys_clk(sys_clk),
	.sdram_rst(sdram_rst),
	
	.tim_cas(tim_cas),
	.tim_wr(tim_wr),
	
	.read(read & concerned_bank[1]),
	.write(write & concerned_bank[1]),
	.precharge_safe(precharge_safe[1])
);
hpdmc_banktimer banktimer2(
	.sys_clk(sys_clk),
	.sdram_rst(sdram_rst),
	
	.tim_cas(tim_cas),
	.tim_wr(tim_wr),
	
	.read(read & concerned_bank[2]),
	.write(write & concerned_bank[2]),
	.precharge_safe(precharge_safe[2])
);
hpdmc_banktimer banktimer3(
	.sys_clk(sys_clk),
	.sdram_rst(sdram_rst),
	
	.tim_cas(tim_cas),
	.tim_wr(tim_wr),
	
	.read(read & concerned_bank[3]),
	.write(write & concerned_bank[3]),
	.precharge_safe(precharge_safe[3])
);

endmodule
