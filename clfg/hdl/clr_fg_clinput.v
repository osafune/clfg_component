// ===================================================================
// TITLE : CameraLink Framegrabber / Input front-end
//
//   DEGISN : S.OSAFUNE (J-7SYSTEM WORKS LIMITED)
//   DATE   : 2018/05/17 -> 2018/05/20
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

// 4データ/サイクルで処理するため、入力数は4の倍数であること 

// cap_mode=0 : ワンショットモード、１フレームを取り込む 
// cap_mode=1 : 連続モード、startがアサートされている間、フレームを取り込む 
// cap_modeはstartの立ち上がりでロードされる 

// tap_mode=00 : スルーモード、port_a,port_b,port_cをパッキングせずに出力 
// tap_mode=01 : 1-TAPモード、port_aを32bitにパッキング 
// tap_mode=10 : 2-TAPモード、port_a,port_bを32bitにパッキング 
// tap_mode=11 : 3-TAPモード、port_a,port_b,port_cを32bitにパッキング 
// tap_modeはenableが'0'の時にロードされる 

`default_nettype none

module clr_fg_clinput #(
	parameter DEVICE_FAMILY	= "Cyclone III"
) (
	output wire			test_trigger,
	output wire			test_frame_end,
	output wire			test_pvalid,
	output wire [31:0]	test_fifo_wrdata,
	output wire			test_fifo_wen,

	input wire			clk,

	input wire			enable,			// 非同期入力 
	input wire			start,			// 非同期入力 
	input wire  [1:0]	tap_mode,		// 非同期入力 
	input wire			cap_mode,		// 非同期入力 
	output wire			active,
	output wire			capture,
	output wire			overflow,

	input wire			fval,			// CameraLink Base configuration
	input wire			lval,
	input wire			dval,
	input wire  [7:0]	port_a,
	input wire  [7:0]	port_b,
	input wire  [7:0]	port_c,

	input wire			fifo_rdclk,
	output wire [31:0]	fifo_rddata,
	input wire			fifo_rdack,
	output wire [10:0]	fifo_usedw
);


/* ===== 外部変更可能パラメータ ========== */


/* ----- 内部パラメータ ------------------ */


/* ※以降のパラメータ宣言は禁止※ */

/* ===== ノード宣言 ====================== */
				/* 内部は全て正論理リセットとする。ここで定義していないノードの使用は禁止 */
//	wire			reset_sig = ;			// モジュール内部駆動非同期リセット 

				/* 内部は全て正エッジ駆動とする。ここで定義していないクロックノードの使用は禁止 */
	wire			clock_sig = clk;		// モジュール内部駆動クロック 

	/* SDC制約付きレジスタの宣言 */
	(* altera_attribute = {"-name SDC_STATEMENT \"set_false_path -to [get_registers *clr_fg_clinput:*\|enable_in_reg\[0\]]\""} *)
	reg [1:0]		enable_in_reg;
	(* altera_attribute = {"-name SDC_STATEMENT \"set_false_path -to [get_registers *clr_fg_clinput:*\|start_in_reg\[0\]]\""} *)
	reg [2:0]		start_in_reg;
	(* altera_attribute = {"-name SDC_STATEMENT \"set_false_path -to [get_registers *clr_fg_clinput:*\|tapmode_in_reg\[*\]]\""} *)
	reg [1:0]		tapmode_in_reg;
	(* altera_attribute = {"-name SDC_STATEMENT \"set_false_path -to [get_registers *clr_fg_clinput:*\|capmode_in_reg]\""} *)
	reg				capmode_in_reg;

	wire			enable_sig, start_sig, trigger_sig;

	reg  [1:0]		fval_in_reg;
	reg				lval_in_reg, dval_in_reg;
	reg  [7:0]		port_a_in_reg, port_b_in_reg, port_c_in_reg;
	wire			pvalid_sig;
	wire			frame_end_sig;

	reg				starthold_reg;
	reg				capture_reg;
	reg				continuous_reg;
	reg				ovf_reg;

	wire [31:0]		fifo_wrdata_sig;
	wire			fifo_wen_sig;
	wire			fifo_wrfull_sig;


/* ※以降のwire、reg宣言は禁止※ */

/* ===== テスト記述 ============== */

	assign test_trigger = trigger_sig;
	assign test_frame_end = frame_end_sig;
	assign test_pvalid = pvalid_sig;
	assign test_fifo_wrdata = fifo_wrdata_sig;
	assign test_fifo_wen = fifo_wen_sig;


/* ===== モジュール構造記述 ============== */

	// 非同期信号の同期化 

	always @(posedge clock_sig) begin
		enable_in_reg <= {enable_in_reg[0], enable};
		start_in_reg <= {start_in_reg[1:0], start};
		tapmode_in_reg <= tap_mode;
		capmode_in_reg <= cap_mode;
	end

	assign enable_sig = enable_in_reg[1];
	assign start_sig = start_in_reg[1];
	assign trigger_sig = (!start_in_reg[2] && start_in_reg[1]);

	assign active = enable_sig;


	// CameraLink入力ラッチ 

	always @(posedge clock_sig) begin
		fval_in_reg <= {fval_in_reg[0], fval};
		lval_in_reg <= lval;
		dval_in_reg <= dval;
		port_a_in_reg <= port_a;
		port_b_in_reg <= port_b;
		port_c_in_reg <= port_c;
	end

	assign frame_end_sig = (fval_in_reg[1] && !fval_in_reg[0]);


	// 制御信号生成 

	always @(posedge clock_sig) begin
		if (enable_sig) begin
			if (!capture_reg) begin
				if (starthold_reg && !fval_in_reg[0]) begin
					starthold_reg <= 1'b0;
					capture_reg <= 1'b1;
				end
				else if (trigger_sig) begin
					starthold_reg <= 1'b1;
					continuous_reg <= capmode_in_reg;
				end
			end
			else begin
				if (frame_end_sig && !(continuous_reg && start_sig)) begin
					capture_reg <= 1'b0;
				end
			end

			if (fifo_wen_sig && fifo_wrfull_sig) begin
				ovf_reg <= 1'b1;
			end
		end
		else begin
			starthold_reg <= 1'b0;
			capture_reg <= 1'b0;
			continuous_reg <= 1'b0;
			ovf_reg <= 1'b0;
		end
	end

	assign capture = capture_reg;
	assign overflow = ovf_reg;


	// TAPスイッチ 

	assign pvalid_sig = fval_in_reg[0] & lval_in_reg & dval_in_reg & capture_reg;

	clr_fg_tap
	u0 (
		.clk		(clock_sig),
		.enable		(enable_sig),
		.tap_mode	(tapmode_in_reg),
		.pvalid		(pvalid_sig),
		.port_a		(port_a_in_reg),
		.port_b		(port_b_in_reg),
		.port_c		(port_c_in_reg),

		.data		(fifo_wrdata_sig),
		.datavalid	(fifo_wen_sig)
	);


	// データ転送FIFO 

	(* altera_attribute = {"-name SDC_STATEMENT \"set_false_path -from [get_registers *clr_fg_clinput:*\|enable_in_reg\[1\]] -to [get_registers *clr_fg_clinput:*\|dcfifo:u1\|*]\""} *)
	dcfifo #(
		.lpm_type			("dcfifo"),
		.lpm_numwords		(1024),
		.lpm_width			(32),
		.lpm_widthu			(11),
		.lpm_showahead		("ON"),
		.add_usedw_msb_bit	("ON"),
		.intended_device_family	(DEVICE_FAMILY),
		.use_eab			("ON"),
		.overflow_checking	("ON"),
		.underflow_checking	("ON"),
		.read_aclr_synch	("ON"),
		.rdsync_delaypipe	(4),
		.write_aclr_synch	("ON"),
		.wrsync_delaypipe	(4)
	)
	u1 (
		.aclr		(~enable_sig),

		.wrclk		(clock_sig),
		.data		(fifo_wrdata_sig),
		.wrreq		(fifo_wen_sig),
		.wrfull		(fifo_wrfull_sig),

		.rdclk		(fifo_rdclk),
		.q			(fifo_rddata),
		.rdreq		(fifo_rdack),
		.rdusedw	(fifo_usedw)
	);



endmodule
