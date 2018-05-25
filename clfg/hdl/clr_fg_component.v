// ===================================================================
// TITLE : CameraLink Framegrabber (clr_fg_component)
//
//   DEGISN : S.OSAFUNE (J-7SYSTEM WORKS LIMITED)
//   DATE   : 2018/05/19 -> 2018/05/20
//   UPDATE : 
//
// ===================================================================

/*******************************************************************************
 The MIT License (MIT)
 Copyright (c) 2018 J-7SYSTEM WORKS LIMITED.

 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
 of the Software, and to permit persons to whom the Software is furnished to do
 so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
*******************************************************************************/

`default_nettype none

module clr_fg_component #(
	parameter DEVICE_FAMILY	= "Cyclone III"
) (
	// Interface: s1_clk
	input wire			rsi_s1_reset,
	input wire			csi_s1_clk,

	// Interface: Avalon-MM slave
	input wire  [1:0]	avs_s1_address,
	input wire			avs_s1_write,
	input wire  [31:0]	avs_s1_writedata,
	input wire			avs_s1_read,
	output wire [31:0]	avs_s1_readdata,
	output wire			avs_s1_irq,

	// Interface: m1_clk
	input wire			rsi_m1_reset,
	input wire			csi_m1_clk,

	// Interface: Avalon-MM write master
	output wire [31:0]	avm_m1_address,
	output wire [5:0]	avm_m1_burstcount,
	output wire			avm_m1_write,
	output wire [31:0]	avm_m1_writedata,
	output wire [3:0]	avm_m1_byteenable,
	input wire			avm_m1_waitrequest,

	// Interface: Conduit end
	input wire			coe_clr_clk,
	input wire			coe_clr_fval,			// CameraLink Base configuration
	input wire			coe_clr_lval,
	input wire			coe_clr_dval,
	input wire  [7:0]	coe_clr_port_a,
	input wire  [7:0]	coe_clr_port_b,
	input wire  [7:0]	coe_clr_port_c
);


/* ===== 外部変更可能パラメータ ========== */



/* ----- 内部パラメータ ------------------ */



/* ※以降のパラメータ宣言は禁止※ */

/* ===== ノード宣言 ====================== */
//				/* 内部は全て正論理リセットとする。ここで定義していないノードの使用は禁止 */
//	wire			reset_sig = ;			// モジュール内部駆動非同期リセット 

				/* 内部は全て正エッジ駆動とする。ここで定義していないクロックノードの使用は禁止 */
//	wire			clock_sig = ;			// モジュール内部駆動クロック 

	wire			clr_enable_sig;
	wire			clr_start_sig;
	wire [1:0]		clr_tapmode_sig;
	wire			clr_capmode_sig;
	wire			clr_active_sig;
	wire			clr_capture_sig;
	wire			clr_overflow_sig;
	wire			avm_enable_sig;
	wire			avm_start_sig;
	wire			avm_ready_sig;
	wire [31:2]		avm_addresstop_sig;
	wire [25:0]		avm_transdatanum_sig;

	wire [31:0]		fifo_rddata_sig;
	wire			fifo_rdack_sig;
	wire [10:0]		fifo_usedw_sig;


/* ※以降のwire、reg宣言は禁止※ */

/* ===== テスト記述 ============== */



/* ===== モジュール構造記述 ============== */

	// Avalon-MM slaveモジュールインスタンス 

	clr_fg_avs
	u0 (
		.csi_reset			(rsi_s1_reset),
		.avs_clk			(csi_s1_clk),
		.avs_address		(avs_s1_address),
		.avs_write			(avs_s1_write),
		.avs_writedata		(avs_s1_writedata),
		.avs_read			(avs_s1_read),
		.avs_readdata		(avs_s1_readdata),
		.avs_irq			(avs_s1_irq),

		.clr_enable			(clr_enable_sig),
		.clr_start			(clr_start_sig),
		.clr_tapmode		(clr_tapmode_sig),
		.clr_capmode		(clr_capmode_sig),
		.clr_active			(clr_active_sig),
		.clr_capture		(clr_capture_sig),
		.clr_overflow		(clr_overflow_sig),

		.avm_enable			(avm_enable_sig),
		.avm_start			(avm_start_sig),
		.avm_ready			(avm_ready_sig),
		.avm_addresstop		(avm_addresstop_sig),
		.avm_transdatanum	(avm_transdatanum_sig)
	);


	// CameraLink 入力モジュールインスタンス 

	clr_fg_clinput #(
		.DEVICE_FAMILY	(DEVICE_FAMILY)
	)
	u1 (
		.clk			(coe_clr_clk),

		.enable			(clr_enable_sig),
		.start			(clr_start_sig),
		.tap_mode		(clr_tapmode_sig),
		.cap_mode		(clr_capmode_sig),
		.active			(clr_active_sig),
		.capture		(clr_capture_sig),
		.overflow		(clr_overflow_sig),

		.fval			(coe_clr_fval),
		.lval			(coe_clr_lval),
		.dval			(coe_clr_dval),
		.port_a			(coe_clr_port_a),
		.port_b			(coe_clr_port_b),
		.port_c			(coe_clr_port_c),

		.fifo_rdclk		(csi_m1_clk),
		.fifo_rddata	(fifo_rddata_sig),
		.fifo_rdack		(fifo_rdack_sig),
		.fifo_usedw		(fifo_usedw_sig)
	);


	// Avalon-MM write masterモジュールインスタンス 

	clr_fg_avm
	u2 (
		.csi_reset			(rsi_m1_reset),
		.avm_clk			(csi_m1_clk),
		.avm_address		(avm_m1_address),
		.avm_burstcount		(avm_m1_burstcount),
		.avm_write			(avm_m1_write),
		.avm_writedata		(avm_m1_writedata),
		.avm_byteenable		(avm_m1_byteenable),
		.avm_waitrequest	(avm_m1_waitrequest),

		.enable				(avm_enable_sig),
		.start				(avm_start_sig),
		.ready				(avm_ready_sig),
		.address_top		({avm_addresstop_sig, 2'b0}),
		.transdata_num		(avm_transdatanum_sig),

		.writedata			(fifo_rddata_sig),
		.writedata_rdack	(fifo_rdack_sig),
		.writedata_usedw	(fifo_usedw_sig)
	);



endmodule
