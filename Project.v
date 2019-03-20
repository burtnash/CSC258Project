`include "vga_adapter/vga_adapter.v"
`include "vga_adapter/vga_address_translator.v"
`include "vga_adapter/vga_controller.v"
`include "vga_adapter/vga_pll.v"

module phase1
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
	wire enable;
	assign enable = SW[0];
	
	// Create the colour, x, and y wires that are inputs to the controller.
	wire [2:0] colour;
	wire [3:0] x;
	wire [4:0] y;

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.
	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(enable),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "16x32";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "black.mif";
			
	datapath d0(resetn, CLOCK_50, enable, x, y, colour);
    
endmodule

module datapath(resetn, clock, enable, x, y, colour);
	input resetn;
	input clock;
	input enable;
	output [3:0] x;
	output [4:0] y;
	output reg [2:0] colour;
	
	reg counter_x_enable;
	wire frame_out;
	wire delay_out;
	wire [767:0] display_and_buffer;
	wire [511:0] w_display;
	wire [255:0] w_spawner;
	wire w_set_buffer;

	always @(posedge clock)
	begin
		assign counter_x_enable = (y == 5'b11111) ? 1 : 0;
		assign colour = (w_display[32*x+y] == 1'b1) ? 3'b111 : 3'b000;
	end

	frame_counter c0(frame_out, clock, resetn, enable);
	delay_counter c1(delay_out, clock, resetn, frame_out);

	counter_y cy(clock, resetn, enable, y);
	counter_x cx(clock, resetn, counter_x_enable, x);

	spawner sp(CLOCK_50, delay_out, resetn, w_spawner, w_set_buffer); //Set enable == delay_out?
	game_state gs(w_display, display_and_buffer, w_spanner, clock, resetn, delay_out, w_set_buffer); //Set enable = delay_out?

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
		input clock, resetn, enable,
		output reg [3:0] x
	);

	always @(posedge clock)
		begin
			if (!resetn)
				x <= 4'b0000;
			else if (enable) 
				x <= x + 1'b1;
		end
endmodule

module counter_y
	(
		input clock, resetn, enable,
		output reg [4:0] y
	);

	always @(posedge clock)
		begin
			if (!resetn)
				y <= 5'b00000;
			else if (enable) 
				y <= y + 1'b1;
		end
endmodule


module main(display, display_and_buffer, CLOCK_50, resetn, enable, set_buffer,c0, c1, c2, c3, c4, c5, c6, c7);
	input CLOCK_50, resetn, enable, set_buffer;
	output  [511:0]display;
	output [767:0] display_and_buffer;
	
	output [18:0] c0, c1, c2, c3, c4, c5, c6, c7;
	
	
	
	// output of rectangle
	//wire [255:0] w_rectangle;
	//get_rectangle rect(CLOCK_50, 4'b0001, 4'b0110, 4'b0011, 4'b0110, w_rectangle);
	wire [255:0] w_spawner;
	wire w_set_buffer;
	spawner sp(CLOCK_50, 1, resetn, w_spawner, w_set_buffer);
	
	// add_buffer= w_rectangle
	game_state gs(w_display,display_and_buffer, w_spawner, CLOCK_50, resetn, enable, w_set_buffer);
	assign display = w_display;
	
	// for displaying top 8 pixels of screen in model sim
	///*
	//assign c0 = w_display[32*0+:18];
	//assign c1 = w_display[32*1+:18];
	//assign c2 = w_display[32*2+:18];
	//assign c3 = w_display[32*3+:18];
	//assign c4 = w_display[32*4+:18];
	//assign c5 = w_display[32*5+:18];
	//assign c6 = w_display[32*6+:18];
	//assign c7 = w_display[32*7+:18];
	//*/
	
	wire[4:0] w_rand;
	random rand(CLOCK_50, resetn, enable, w_rand);
	
	// for displaying rectangle in model sim
	/*
	assign c0 = w_rectangle[16*0+:16];
	assign c1 = w_rectangle[16*1+:16];
	assign c2 = w_rectangle[16*2+:16];
	assign c3 = w_rectangle[16*3+:16];
	assign c4 = w_rectangle[16*4+:16];
	assign c5 = w_rectangle[16*5+:16];*/
	
endmodule

module random(clock, resetn, enable, out_value);
	input clock, resetn, enable;
	
	
	reg [7:0] counter;
	
	reg [4:0] bit;
	output reg [4:0] out_value;
	
	integer i;
	always @(posedge clock) begin
		if(~resetn) begin
			counter <= 8'b00000000;
			bit <= 5'b00000;
			out_value <= 5'b00101; // arbitrarily picked
		end
		else if(enable) begin
			bit <= counter[6:2];
			for(i = 0; i < 16; i= i+1) begin
				bit = ((out_value >> 0) ^ (out_value >> 2) ^ (out_value >> 3));
				out_value = (out_value >> 1) | (bit << 4);
			end
			counter <= counter + 8'b00000001;
		end
	end

endmodule

/* Output a rectangle into 16x6 out_buffer*/
module get_rectangle(clock, x, y, w, h, out_buffer);
	input clock;
	input [3:0] x, y, w, h;
	output reg [255:0] out_buffer; // 16x16 output
	
	integer ix, iy;
	always @ (posedge clock) begin
		for (ix=0; ix<16; ix=ix+1) begin
			for(iy = 0; iy < 16; iy = iy +1) begin
				if(ix >= x && ix < x + w && iy >= y && iy < y + h) begin
					out_buffer[ix*16 + iy] <= 1;
				end
				
				else begin
					out_buffer[ix*16 + iy] <= 0;
				end
			end
		end
	end
endmodule

/* Output a circle into 16x6 out_buffer*/
module get_circle(clock, x, y, r, out_buffer);
	input clock;
	input [3:0] x, y, r;
	output reg [255:0] out_buffer; // 16x16 output
	
	integer ix, iy;
	always @ (posedge clock) begin
		for (ix=0; ix<16; ix=ix+1) begin
			for(iy = 0; iy < 16; iy = iy +1) begin
				if((ix-x)*(ix-x) + (iy-y)*(iy-y) <= r*r) begin
					out_buffer[ix*16 + iy] <= 1;
				end
				else begin
					out_buffer[ix*16 + iy] <= 0;
				end
			end
		end
	end
	
endmodule


/* If enabled, will regularly output a rectangle into out_buffer, and set set_buffer to 1 for 1 clock cycle*/
module spawner(clock, enable, resetn, /*delay,*/ out_buffer, set_buffer);
	input clock, enable, resetn;
	//input [7:0] delay;
	output reg [255:0] out_buffer; 
	output reg set_buffer; 
	
	reg [7:0] counter;
	
	wire [255:0] w_out_buffer;
   //get_rectangle gs(clock, 4'b0001, 4'b0110, 4'b0011, 4'b0110, w_out_buffer);
	
	wire [4:0] w_random;
	random rand(clock, resetn, enable, w_random);
	
	//get_circle gs(clock, 4'b0100, 4'b0110, 4'b0011, w_out_buffer);
	get_circle gs(clock, w_random[3:0], 4'b0110, 4'b0011, w_out_buffer);
	
	always @ (posedge clock) begin
		if(~resetn) begin 
			counter <= 8'b00000000;
			out_buffer <= 256'h00;
			set_buffer <= 1'b0;
		end
		else if(enable) begin
			counter <= counter + 8'b00000001;
			if(counter >= 8'b00010000)begin
				counter <= 8'b00000000;
				out_buffer <= w_out_buffer;
				set_buffer <= 1'b1;
			end
			else begin
				set_buffer <= 1'b0;
				out_buffer <= 256'h00;
			end
			
		end
	end
	
endmodule



module game_state(display, display_and_buffer, add_buffer, clock, resetn, enable, set_buffer);
	
	input resetn, clock, enable, set_buffer;
	input [255:0] add_buffer;
	
	output reg [511:0] display; // 16 x 32 display
	output reg [767:0] display_and_buffer; // 16x48: 16 x 32 display + 16 x 16 buffer on top
	
	integer ix;
	integer iy;
	always @ (posedge clock) begin
        if (~resetn) begin
				// Reset the display_and_buffer. For now, puts a line of 1's at the top
				for (ix=0; ix<16; ix=ix+1) begin
					display_and_buffer[ix*48] <= 1'b1;
					display_and_buffer[ix * 48 + 1 +: 47] <= 47'h00000000;
				end
        end
		  else if(set_buffer) begin
				// set the 16x16 buffer on the top
				for(ix = 0; ix < 16; ix = ix+1) begin
					display_and_buffer[ix*48 +: 16] <= add_buffer[ix*16 +: 16];
				end
		  end
		  
		  // shift display down 1 row
        else if(enable) begin
				for (ix=0; ix<16; ix=ix+1) begin
					display_and_buffer[ix * 48 +: 48] <= {display_and_buffer[ix*48 +:47], 1'b0};
				end
        end
		  
		  // set the output for just the displayed part of the display_and_buffer
		  for (ix=0; ix<16; ix=ix+1) begin
			 display[ix*32 +:32] <= display_and_buffer[ix * 48 + 16 +: 32];
		  end
		  
    end
	 
endmodule



