// ===================================================================
// TITLE : CameraLink Framegrabber / Tap switch
//
//   DEGISN : S.OSAFUNE (J-7SYSTEM WORKS LIMITED)
//   DATE   : 2018/05/16 -> 2018/05/16
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

// tap_mode=00 : スルーモード、port_a,port_b,port_cをパッキングせずに出力 
// tap_mode=01 : 1-TAPモード、port_aを32bitにパッキング 
// tap_mode=10 : 2-TAPモード、port_a,port_bを32bitにパッキング 
// tap_mode=11 : 3-TAPモード、port_a,port_b,port_cを32bitにパッキング 
//
// tap_modeはenableが'0'の時にロードされる 

`default_nettype none

module clr_fg_tap(
	input wire			clk,
	input wire			enable,
	input wire  [1:0]	tap_mode,

	input wire			pvalid,
	input wire  [7:0]	port_a,
	input wire  [7:0]	port_b,
	input wire  [7:0]	port_c,

	output wire [31:0]	data,
	output wire			datavalid
);


/* ===== 外部変更可能パラメータ ========== */


/* ----- 内部パラメータ ------------------ */


/* ※以降のパラメータ宣言は禁止※ */

/* ===== ノード宣言 ====================== */
				/* 内部は全て正論理リセットとする。ここで定義していないノードの使用は禁止 */
//	wire			reset_sig = ;			// モジュール内部駆動非同期リセット 

				/* 内部は全て正エッジ駆動とする。ここで定義していないクロックノードの使用は禁止 */
	wire			clock_sig = clk;		// モジュール内部駆動クロック 

	reg  [1:0]		pcount_reg;
	reg  [7:0]		din0_reg, din1_reg, din2_reg, din3_reg, din4_reg, din5_reg, din6_reg, din7_reg;
	reg				pvalid_reg;
	reg  [1:0]		mode_reg;

	reg  [31:0]		dout_node;
	reg				valid_node;


/* ※以降のwire、reg宣言は禁止※ */

/* ===== テスト記述 ============== */



/* ===== モジュール構造記述 ============== */

	// 入力ラッチ 

	always @(posedge clock_sig) begin
		if (enable) begin
			if (pvalid) begin
				pcount_reg <= pcount_reg + 1'd1;
			end

			pvalid_reg <= pvalid;
		end
		else begin
			pcount_reg <= 2'd3;
			pvalid_reg <= 1'b0;
			mode_reg <= tap_mode;
		end

		if (pvalid) begin
			din0_reg <= port_a;
			din1_reg <= port_b;
			din2_reg <= port_c;
			din3_reg <= din0_reg;
			din4_reg <= din1_reg;
			din5_reg <= din2_reg;
			din6_reg <= din3_reg;
			din7_reg <= din6_reg;
		end
	end


	// データ並べ替え 

	assign data =
			(mode_reg == 2'h0)? {8'h0, din2_reg, din1_reg, din0_reg} :
			(mode_reg == 2'h1)? {din0_reg, din3_reg, din6_reg, din7_reg} :
			(mode_reg == 2'h2)? {din1_reg, din0_reg, din4_reg, din3_reg} :
			(mode_reg == 2'h3 && pcount_reg == 2'd1)? {din0_reg, din5_reg, din4_reg, din3_reg} :
			(mode_reg == 2'h3 && pcount_reg == 2'd2)? {din1_reg, din0_reg, din5_reg, din4_reg} :
			(mode_reg == 2'h3 && pcount_reg == 2'd3)? {din2_reg, din1_reg, din0_reg, din5_reg} :
			{32{1'bx}};

	assign datavalid =
			(mode_reg == 2'h0)? pvalid_reg :
			(mode_reg == 2'h1 && pcount_reg == 2'd3)? pvalid_reg :
			(mode_reg == 2'h2 &&(pcount_reg == 2'd1 || pcount_reg == 2'd3))? pvalid_reg :
			(mode_reg == 2'h3 && pcount_reg != 2'd0)? pvalid_reg :
			1'b0;


endmodule
