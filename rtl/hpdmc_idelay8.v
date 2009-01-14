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

module hpdmc_idelay8(
	input [7:0] i,
	output [7:0] o,
	
	input clk,
	input rst,
	input ce,
	input inc
);

IDELAY #(
	.IOBDELAY_TYPE("VARIABLE"),
	.IOBDELAY_VALUE(0)
) d0 (
	.I(i[0]),
	.C(clk),
	.INC(inc),
	.CE(ce),
	.RST(rst),
	.O(o[0])
);
IDELAY #(
	.IOBDELAY_TYPE("VARIABLE"),
	.IOBDELAY_VALUE(0)
) d1 (
	.I(i[1]),
	.C(clk),
	.INC(inc),
	.CE(ce),
	.RST(rst),
	.O(o[1])
);
IDELAY #(
	.IOBDELAY_TYPE("VARIABLE"),
	.IOBDELAY_VALUE(0)
) d2 (
	.I(i[2]),
	.C(clk),
	.INC(inc),
	.CE(ce),
	.RST(rst),
	.O(o[2])
);
IDELAY #(
	.IOBDELAY_TYPE("VARIABLE"),
	.IOBDELAY_VALUE(0)
) d3 (
	.I(i[3]),
	.C(clk),
	.INC(inc),
	.CE(ce),
	.RST(rst),
	.O(o[3])
);
IDELAY #(
	.IOBDELAY_TYPE("VARIABLE"),
	.IOBDELAY_VALUE(0)
) d4 (
	.I(i[4]),
	.C(clk),
	.INC(inc),
	.CE(ce),
	.RST(rst),
	.O(o[4])
);
IDELAY #(
	.IOBDELAY_TYPE("VARIABLE"),
	.IOBDELAY_VALUE(0)
) d5 (
	.I(i[5]),
	.C(clk),
	.INC(inc),
	.CE(ce),
	.RST(rst),
	.O(o[5])
);
IDELAY #(
	.IOBDELAY_TYPE("VARIABLE"),
	.IOBDELAY_VALUE(0)
) d6 (
	.I(i[6]),
	.C(clk),
	.INC(inc),
	.CE(ce),
	.RST(rst),
	.O(o[6])
);
IDELAY #(
	.IOBDELAY_TYPE("VARIABLE"),
	.IOBDELAY_VALUE(0)
) d7 (
	.I(i[7]),
	.C(clk),
	.INC(inc),
	.CE(ce),
	.RST(rst),
	.O(o[7])
);

endmodule
