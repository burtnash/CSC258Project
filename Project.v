`include "vga_adapter/vga_adapter.v"
`include "vga_adapter/vga_address_translator.v"
`include "vga_adapter/vga_controller.v"
`include "vga_adapter/vga_pll.v"

module project
	(
		CLOCK_50,						//	On Board 50 MHz
		// Your inputs and outputs here
        KEY,
        SW,
				HEX0,
				HEX1,
				HEX2,
				HEX3,
				HEX4,
				HEX5,
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
	output [6:0] HEX0;
	output [6:0] HEX1;
	output [6:0] HEX2;
	output [6:0] HEX3;
	output [6:0] HEX4;
	output [6:0] HEX5;

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
	wire left, right;
	assign left = ~KEY[2];
	assign right = ~KEY[1];
	
	// Create the colour, x, and y wires that are inputs to the controller.
	wire [2:0] colour;
	wire [4:0] x;
	wire [5:0] y;
	wire [23:0] score;

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
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "black.mif";
			
	datapath d0(resetn, CLOCK_50, enable, left, right, x, y, colour, score);
	seven_segment ss0(score[3:0], HEX0[6:0]);
	seven_segment ss1(score[7:4], HEX1[6:0]);
	seven_segment ss2(score[11:8], HEX2[6:0]);
	seven_segment ss3(score[15:12], HEX3[6:0]);
	seven_segment ss4(score[19:16], HEX4[6:0]);
	seven_segment ss5(score[23:20], HEX5[6:0]);
    
endmodule

module datapath(resetin, clock, enable, left, right, x, y, colour, score);
	input resetin;
	input clock;
	input enable;
	input left, right;
	output [4:0] x;
	output [5:0] y;
	output reg [2:0] colour;
	output [23:0] score;
	
	reg counter_x_enable;
	wire [3:0] player_location;
	wire frame_out;
	wire delay_out;
	wire [767:0] display_and_buffer;
	wire [511:0] w_display;
	wire [511:0] player_display;
	wire [255:0] w_spawner;
	wire w_set_buffer;
	wire [2047:0] display;
	wire resetn;
	wire collision;

	always @(posedge clock)
	begin
		counter_x_enable <= (y == 6'b111111) ? 1'b1 : 1'b0;
		colour <= (display[64 * x + y] == 1'b1) ? 3'b111 : 3'b001;
	end

	frame_counter c0(frame_out, clock, resetn, enable);
	delay_counter c1(delay_out, clock, resetn, frame_out);

	counter_y cy(clock, resetn, enable, y);
	counter_x cx(clock, resetn, counter_x_enable, x);
	
	convert512to2048 converter(player_display, display);

	module movement_control(delay_out, resetn, enable, left, right, player_location);
	module display_movement(clock, resetn, w_display, player_location, player_display, collision);

	// collision_detect cd(clock, w_display, player_location, collision);
	score_tracker st(clock, resetn, delay_out, score);

	spawner sp(delay_out, enable, resetn, w_spawner, w_set_buffer);
	game_state gs(w_display, display_and_buffer, w_spawner, delay_out, resetn, enable, w_set_buffer); 

	assign resetn = collision ? 1'b0 : resetin;

endmodule

module convert512to2048(input [511:0] in, output reg [2047:0] out);
	integer x, y;
	always @(*) begin
		for (x=0; x<16; x=x+1) begin
			for (y=0; y<32; y=y+1) begin
				out[2*(64*x+y)] <= in[32*x+y];
				out[2*(64*x+y)+1] <= in[32*x+y];
				out[2*(64*x+y)+64] <= in[32*x+y];
				out[2*(64*x+y)+65] <= in[32*x+y];
			end
		end
	end
endmodule

/* Translates left and right into register storing position 1-14 */
module movement_control (input clock, input resetn, input enable, input left, input right, output reg [3:0] position);
	always @(posedge clk)
	begin
		if (!resetn)
			position <= 4'b0100;
		else if (enable)
			begin
				if (left && position > 4'b0001)
					position <= position - 1'b1;
				else if (right && position < 4'b1110)
					position <= position + 1'b1;
				else
					position <= position;
			end
	end
endmodule

/* Displays player on output screen based on input screen*/
module display_movement (input clock, input resetn, input [511:0] in, input [3:0] player, output reg [511:0] out, output reg collision);
	always @(posedge clock) begin
		out <= in;
		//Draws Ship
		out[32*player+31] <= 1'b1; //Center of ship
		out[32*player-1] <= 1'b1;
		out[32*player+30] <= 1'b1;
		out[32*player+63] <= 1'b1;

		if (!resetn)
			collision <= 1'b0;
		if (collision == 1'b0)
		begin
			if (out[32*player+31] == 1'b1)
				collision <= 1'b1;
			if (out[32*player-1] == 1'b1)
				collision <= 1'b1;
			if (out[32*player+30] == 1'b1)
				collision <= 1'b1;
			if (out[32*player+63] == 1'b1)
				collision <= 1'b1;
		end
		//Draws whitespace around ship
		/*
		out[32*player-2] <= 1'b0;
		out[32*player+62] <= 1'b0;
		if (player > 4'b0001)
			out[32*player-33] <= 1'b0;
		if (player < 4'b1110)
			out[32*player+95] <= 1'b0;
			*/

	end
endmodule
/*
module collision_detect (input clock, input [511:0] in, input [3:0] player, output reg collision);
	always @(posedge clock) begin 
		if (!resetn)
			collision <= 1'b0;
		if (collision == 1'b0)
		begin
			if (out[32*player+31] == 1'b1)
				collision <= 1'b1;
			if (out[32*player-1] == 1'b1)
				collision <= 1'b1;
			if (out[32*player+30] == 1'b1)
				collision <= 1'b1;
			if (out[32*player+63] == 1'b1)
				collision <= 1'b1;
		end
	end
endmodule */

module score_tracker(input clock, input resetn, input enable, output reg [23:0] score);
	always @(posedge clock) begin
		if (!resetn)
			score <= 24'h0;
		else if (enable)
			score <= score + 1'b1;
	end
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
		output reg [4:0] x
	);

	always @(posedge clock)
		begin
			if (!resetn)
				x <= 5'b00000;
			else if (enable) 
				x <= x + 1'b1;
		end
endmodule

module counter_y
	(
		input clock, resetn, enable,
		output reg [5:0] y
	);

	always @(posedge clock)
		begin
			if (!resetn)
				y <= 6'b000000;
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
				bit <= ((out_value >> 0) ^ (out_value >> 2) ^ (out_value >> 3));
				out_value <= (out_value >> 1) | (bit << 4);
			end
			counter <= counter + 8'b00000001;
		end
	end

endmodule

module rand(clock, resetn, enable, seed, out);
	input clock, resetn, enable;
	input [31:0] seed;
	output out;
	reg [31:0] mReg;
	always @(posedge clock) begin
		if(~resetn) begin
			mReg <= seed;
		end
		else if(enable) begin
			mReg <= {mReg[0], mReg[31:1]};
		end
	end
	assign out = mReg[0];
	
endmodule

module rand4(clock, resetn, enable, seed, out);
	input clock, resetn, enable;
	input [31:0] seed;
	output [3:0] out;
	
	rand r0(clock, resetn, enable, seed + 32'hABCDEF12,out[0]);
	rand r1(clock, resetn, enable, seed + 32'h00F8BA30,out[1]);
	rand r2(clock, resetn, enable, seed + 32'h3743D849 ,out[2]);
	rand r3(clock, resetn, enable, seed + 32'h21F99CEE ,out[3]);
	
	/*rand r0(clock, resetn, enable, 32'hABCDEF12 ,out[0]);
	rand r1(clock, resetn, enable, 32'hF8B323AF ,out[1]);
	rand r2(clock, resetn, enable, 32'hC0900ADE ,out[2]);
	rand r3(clock, resetn, enable, 32'h0B313800 ,out[3]);*/
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
   
	wire [3:0] w_rand_x;
	wire [3:0] w_rand_w;
	wire [3:0] w_rand_h;
	
	/*
	lfsr4 l0(clock, resetn, enable, 16'b0010001111110101, w_rand_x);
	lfsr4 lw(clock, resetn, enable, 16'b0010000001110101, w_rand_w);
	lfsr4 lh(clock, resetn, enable, 16'b0011100000010101, w_rand_h);*/
	rand4 r0(clock, resetn, enable, 32'hABCDEF12, w_rand_x);
	rand4 r1(clock, resetn, enable, 32'h00F8BA30, w_rand_w);
	rand4 r2(clock, resetn, enable, 32'h3743D849 ,w_rand_h);
	
	wire [255:0] w_rectangle;
	get_rectangle gr(clock, w_rand_x, 4'b0000, w_rand_w, w_rand_h, w_rectangle);
	
	wire [255:0] w_circle;
	get_circle gc(clock,  w_rand_x, 4'b0100, {1'b0, w_rand_w[2:0]}, w_circle);
	
	wire w_choose_shape;
	//lfsr choose(clock, resetn, enable, 16'b0011100000010101, w_choose_shape);
	rand r3(clock, resetn, enable, 32'hABCDEF12, w_choose_shape);
	
	always @ (posedge clock) begin
		if(~resetn) begin 
			counter <= 8'b00000000;
			out_buffer <= 256'h00;
			set_buffer <= 1'b0;
		end
		else if(enable) begin
			counter <= counter + 8'b00000001;
			/*if(w_choose_shape)begin
				w_out_buffer <= w_rectangle;
			end
			else begin 
				w_out_buffer <= w_circle;
			end*/
			if(counter >= 8'b00010000)begin
				counter <= 8'b00000000;
				//out_buffer <= w_out_buffer;
				if(w_choose_shape)begin
					out_buffer <= w_rectangle;
				end
				else begin 
					out_buffer <= w_circle;
				end
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

module seven_segment(in, out);
    input [3:0] in;
    output [6:0] out;

    assign out[0] = ~in[3] & ~in[2] & ~in[1] & in[0] | ~in[3] & in[2] & ~in[1] & ~in[0] | in[3] & in[2] & ~in[1] & in[0] | in[3] & ~in[2] & in[1] & in[0];
	assign out[1] = ~in[3] & in[2] & ~in[1] & in[0] | in[3] & in[1] & in[0] | in[3] & in[2] & ~in[0] | in[2] & in[1] & ~in[0];
	assign out[2] = ~in[3] & ~in[2] & in[1] & ~in[0] | in[3] & in[2] & in[1] | in[3] & in[2] & ~in[0];
	assign out[3] = ~in[3] & ~in[2] & ~in[1] & in[0] | ~in[3] & in[2] & ~in[1] & ~in[0] | in[2] & in[1] & in[0] | in[3] & ~in[2] & ~in[1] & in[0] | in[3] & ~in[2] & in[1] & ~in[0];
	assign out[4] = ~in[3] & in[0] | ~in[3] & in[2] & ~in[1] | ~in[2] & ~in[1] & in[0];
	assign out[5] = ~in[3] & ~in[2] & in[1] | ~in[3] & ~in[2] & in[0] | ~in[3] & in[1] & in[0] | in[3] & in[2] & ~in[1] & in[0];
	assign out[6] = ~in[3] & ~in[2] & ~in[1] | ~in[3] & in[2] & in[1] & in[0] | in[3] & in[2] & ~in[1] & ~in[0];
	 
endmodule

