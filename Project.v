
module part3
	(
		CLOCK_50,						//	On Board 50 MHz
		// Your inputs and outputs here
        KEY,
        SW,
		// The ports below are for the VGA output.  Do not change.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B   						//	VGA Blue[9:0]
	);

	input			CLOCK_50;				//	50 MHz
	input   [9:0]   SW;
	input   [3:0]   KEY;

	// Declare your inputs and outputs here
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;			//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]
	
	wire resetn;
	assign resetn = KEY[0];
	
	// Create the colour, x, y and writeEn wires that are inputs to the controller.
	wire [2:0] colour;
	wire [7:0] x;
	wire [6:0] y;
	wire writeEn;
	wire ld_x, ld_y;

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEn),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "black.mif";
			
	// Put your code here. Your code should produce signals x,y,colour and writeEn/plot
	// for the VGA controller, in addition to any other functionality your design may require.

    control c0(.clk(CLOCK_50), .resetn(resetn), .enable(SW[0]), .colour_in(SW[9:7]), .x_out(x), .y_out(y), .colour_out(colour), .plot(writeEn));
    
endmodule

module frame_counter(output out, input clk, input resetn, input enable);

	reg [19:0] q;
	

    always @(posedge clk)
	begin
		if (!resetn)
			q <= 20'd833334;
		else if (enable == 1'b1)
			begin
				if (q == 20'd0)
					q <= 20'd833334;
				else
					q <= q - 1'b1;
			end
	end
	assign out = (q == 20'd0) ? 1 : 0;
endmodule

module delay_counter(output out, input clk, input resetn, input enable);

	reg [3:0] q;
	
    always @(posedge clk)
	begin
		if (!resetn)
			q <= 4'b1111;
		else if (enable == 1'b1)
			begin
				if (q == 4'b0000)
					q <= 4'b1111;
				else
					q <= q - 1'b1;
			end
	end
	assign out = (q == 4'b0000) ? 1 : 0;
endmodule
	

module counter_x
	(
		input clk, resetn, enable,
		input direction, 
		output reg [7:0] x
	);

	always @(negedge clk)
		begin
			if (!resetn)
				x <= 8'b00000000;
			else if (enable) 
				begin
					if (direction == 1'b1)
						x <= x + 1'b1;
					else if (direction == 1'b0)
						x <= x - 1'b1;
				end
		end
endmodule

module counter_y
	(
		input clk, resetn, enable,
		input direction, 
		output reg [6:0] y
	);

	always @(negedge clk)
		begin
			if (!resetn)
				y <= 7'd60;
			else if (enable) 
				begin
					if (direction == 1'b1)
						y <= y + 1'b1;
					else if (direction == 1'b0)
						y <= y - 1'b1;
				end
		end
endmodule
					

module vertical_register
	(
		input clk, resetn, 
		input [6:0] y,
		output reg direction
	);
	
	always @(posedge clk)
		begin
			if (!resetn)
				direction <= 1'b0;
			else begin
				if (y == 7'b0000000)
					direction <= 1'b1;
				else if (y == 7'd116)
					direction <= 1'b0;
				else
					direction <= direction;
			end
		end
endmodule

module horizontal_register
	(
		input clk, resetn, 
		input [7:0] x,
		output reg direction
	);
	
	always @(posedge clk)
		begin
			if (!resetn)
				direction <= 1'b1;
			else begin
				if (x == 8'b00000000)
					direction <= 1'b1;
				else if (x == 8'd156)
					direction <= 1'b0;
				else
					direction <= direction;
			end
		end
endmodule

module datapath_part2
	(
		input clk,
		input resetn, enable,
		input [2:0] colour_in,
		input [7:0] x_in,
		input [6:0] y_in,
		output [7:0] x_coordinate,
		output [6:0] y_coordinate,
		output reg [2:0] colour_out
	);
	
	reg [5:0] counter;
	wire [1:0] count_x;
	wire [1:0] count_y;

	always @(posedge clk) begin
		if (!resetn) begin
			colour_out <= 3'b0;
			counter <= 6'b0000;
			end
		else begin 
			colour_out <= colour_in;
			if (enable)
				counter <= counter + 1'b1;
			end
	end
	
	assign count_x = counter [2:0];
	assign count_y = counter [5:3];
	
	assign x_coordinate = x_in + count_x;
	assign y_coordinate = y_in + count_y;
	
endmodule

module control
	(
		input clk, resetn, enable,
		input [2:0] colour_in,
		output [7:0] x_out,
		output [6:0] y_out,
		output [2:0] colour_out,
		output plot
	);

	wire delay_out;
	wire frame_out;
	wire x_direction, y_direction;
	wire[7:0] x_in;
	wire[6:0] y_in;
	wire[2:0] colour;

	assign colour = delay_out ? 3'b000 : colour_in;

	frame_counter c0(frame_out, clk, resetn, enable);
	delay_counter c1(delay_out, clk, resetn, frame_out);
	
	horizontal_register r0(clk ,resetn, x_in, x_direction);
	vertical_register r1(clk, resetn, y_in, y_direction);

	counter_x c2(clk, resetn, delay_out, x_direction, x_in);
	counter_y c3(clk, resetn, delay_out, y_direction, y_in);

	datapath_part2 d0(clk, resetn, enable, colour, x_in, y_in, x_out, y_out, colour_out);

	assign plot = resetn;
endmodule

module asteroid_control //Moves vertically down, does not move sideways
	(
		input clk, resetn, enable,
		input [2:0] colour_in,
		input [7:0] x_in
		output [7:0] x_out,
		output [6:0] y_out,
		output [2:0] colour_out,
		output plot
	);

	wire delay_out;
	wire frame_out;
	wire[6:0] y_in;
	wire[2:0] colour;

	assign colour = delay_out ? 3'b000 : colour_in;

	frame_counter c0(frame_out, clk, resetn, enable);
	delay_counter c1(delay_out, clk, resetn, frame_out);

	counter_y c3(clk, resetn, delay_out, 1'b1, y_in);

	datapath_part2 d0(clk, resetn, enable, colour, x_in, y_in, x_out, y_out, colour_out);

	assign plot = resetn;
endmodule


