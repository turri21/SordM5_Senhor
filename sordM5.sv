//============================================================================
//  Computer: Sord M5
//
//  Copyright (C) 2018 Sorgelig
//  Copyright (C) 2021 molekula
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

    //if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
    output [12:0] VIDEO_ARX,
    output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,
	output        HDMI_BLACKOUT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
 
assign VGA_F1 = 0;
assign VGA_SCALER = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;

assign AUDIO_S = 0;
assign AUDIO_MIX = 0;

assign LED_USER = ioctl_download;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[13:12];

assign VIDEO_ARX = (!ar) ? 12'd4 : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? 12'd3 : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"Sord M5;;",
	"-;",
  "O02,Memory extension,None,EM-5,EM-64,64KBF,64KRX,BrnoMod;",
  "h0O34,Cartrige,None,BASIC-I,BASIC-G,BASIC-F;",
  "h1O5,EM64 mode,64KB,32KB;",
  "h1O6,EM64 mon. deactivate,Dis.,En.;",
  "h1O7,EM64 wp low 32KB,Dis.,En.;",
  "h1O8,EM64 boot on,ROM,RAM;",  
  "h2F1,binROM,Load to ROM;",
  "-;",
  "OI,Tape Input,File,ADC;",
  "H3F2,CAS,Load Tape;",
  "H3O9,Fast Tape Load,On,Off;",
  "H3OA,Tape Sound,On,Off;",
	"-;",
	"-;",
  "OCD,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
  "OEF,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
  "OG,Border,No,Yes;",
  "-;",
	"TH,Reset;",
	"RH,Reset and close OSD;",
	"V,v",`BUILD_DATE 
};

wire  [1:0] buttons;
wire [31:0] status;
wire [10:0] ps2_key;
wire [5:0]  joy0;
wire [5:0]  joy1;

wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        forced_scandoubler;
wire [21:0] gamma_bus;
wire        cart_enable = status[2:1] ==  2'b00 | status[2:0] == 3'b010;
wire        binary_load_enable = cart_enable & status[4:3] == 2'b00;
wire        kb64_enable = status[2:0] == 3'b010;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	// .EXT_BUS(),
	.gamma_bus(gamma_bus),

	.forced_scandoubler(forced_scandoubler),

	//.buttons(buttons),
	.status(status),
   .status_menumask({status[18],binary_load_enable,kb64_enable, cart_enable}),
	.ps2_key(ps2_key),
	.joystick_0(joy0),
	.joystick_1(joy1),
	
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index)
);

///////////////////////   CLOCKS   ///////////////////////////////

wire clk_sys;
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys)
);

reg ce_10m7 = 0;
reg ce_5m3 = 0;
always @(posedge clk_sys) begin
	reg [2:0] div;
	
	div <= div+1'd1;
	ce_10m7 <= !div[1:0];
	ce_5m3  <= !div[2:0];
end

/////////////////  RESET  /////////////////////////
reg [4:0] old_ram_mode = 5'd0;
always @(posedge clk_sys) begin
	old_ram_mode <= status[4:0];
end

wire ram_mode_changed = old_ram_mode == status[4:0] ? 1'b0 : 1'b1 ;
wire reset = RESET | ram_mode_changed | buttons[1] | status[17] | (ioctl_index == 8'd1 & ioctl_download);


////////////////  Console  ////////////////////////

wire [10:0] audio;
assign AUDIO_L = {audio,5'd0};
assign AUDIO_R = {audio,5'd0};

wire [7:0] R,G,B;
wire hblank, vblank;
wire hsync, vsync;

assign CLK_VIDEO = clk_sys;


sordM5 SordM5
(
	.clk_i(clk_sys),
	.clk_en_10m7_i(ce_10m7),
	.reset_n_i(~reset),
	.por_n_o(),
	.border_i(status[16]),
	.rgb_r_o(R),
	.rgb_g_o(G),
	.rgb_b_o(B),
	.hsync_n_o(hsync),
	.vsync_n_o(vsync),
	.hblank_o(hblank),
	.vblank_o(vblank),
	.audio_o(audio), 
  .ps2_key_i(ps2_key),
  .joy0_i(joy0),
  .joy1_i(joy1),
  .ioctl_addr (ioctl_addr),
  .ioctl_dout (ioctl_dout),
  .ioctl_index (ioctl_index),
  .ioctl_wr (ioctl_wr),  
  .ioctl_download (ioctl_download),
  .DDRAM_BUSY ( DDRAM_BUSY),
  .DDRAM_BURSTCNT ( DDRAM_BURSTCNT),
  .DDRAM_ADDR ( DDRAM_ADDR),
  .DDRAM_DOUT ( DDRAM_DOUT),
  .DDRAM_DOUT_READY ( DDRAM_DOUT_READY),
  .DDRAM_RD ( DDRAM_RD),
  .DDRAM_DIN ( DDRAM_DIN),
  .DDRAM_BE ( DDRAM_BE),
  .DDRAM_WE ( DDRAM_WE),
  .DDRAM_CLK ( DDRAM_CLK),
  .casSpeed (status[9]),
  .tape_sound_i (status[10]),
  .tape_data_i (tape_in),
  .tape_adc_i (status[18]),
  .ramMode_i (status[8:0])
);

assign VGA_SL = sl[1:0];

wire [2:0] scale = status[15:14];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;

reg hs_o, vs_o;
always @(posedge CLK_VIDEO) begin
	hs_o <= ~hsync;
	if(~hs_o & ~hsync) vs_o <= ~vsync;
end

wire  freeze_sync;
video_mixer #(.LINE_LENGTH(290), .GAMMA(1)) video_mixer
(
	.*,
	.ce_pix(ce_5m3),
	.scandoubler(scale || forced_scandoubler),
	.hq2x(scale==1),

	// Positive pulses.
	.HSync(hs_o),
	.VSync(vs_o),
	.HBlank(hblank),
	.VBlank(vblank)
);

/////////////////  Tape In   /////////////////
wire tape_adc, tape_adc_act, tape_in;

assign tape_in = tape_adc_act & tape_adc;

ltc2308_tape #(.ADC_RATE(120000), .CLK_RATE(42666666)) tape
(
   .clk(clk_sys),
   .ADC_BUS(ADC_BUS),
   .dout(tape_adc),
   .active(tape_adc_act)
);

endmodule
