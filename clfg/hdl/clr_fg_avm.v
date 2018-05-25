// ===================================================================
// TITLE : CameraLink Framegrabber / AVM burst master(32bit×32burst)
//
//   DEGISN : S.OSAFUNE (J-7SYSTEM WORKS LIMITED)
//   DATE   : 2018/05/17 -> 2018/05/24
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

module clr_fg_avm (
	// Interface: clk
	input wire			csi_reset,
	input wire			avm_clk,

	// Interface: Avalon-MM master
	output wire [31:0]	avm_address,
	output wire [5:0]	avm_burstcount,			// バースト長 1～32 
	output wire			avm_write,
	output wire [31:0]	avm_writedata,
	output wire [3:0]	avm_byteenable,
	input wire			avm_waitrequest,

	// External Interface
	input wire			enable,					// データ転送イネーブル（'0'でトランザクション中止） 
	input wire			start,					// 転送開始要求 (readyとハンドシェーク) 
	output wire			ready,
	input wire  [31:0]	address_top,			// ストア先頭アドレス(下位2bit無効) 
	input wire  [25:0]	transdata_num,			// 転送データワード数 

	input wire  [31:0]	writedata,
	output wire			writedata_rdack,
	input wire  [10:0]	writedata_usedw			// データFIFOにキューされている数 
);


/* ===== 外部変更可能パラメータ ========== */



/* ----- 内部パラメータ ------------------ */

	localparam	STATE_IDLE			= 5'd0,
				STATE_SETUP			= 5'd1,
				STATE_BURSTWRITE	= 5'd2,
				STATE_LOOP			= 5'd3,
				STATE_DONE			= 5'd31;


/* ※以降のパラメータ宣言は禁止※ */

/* ===== ノード宣言 ====================== */
	/* 内部は全て正論理リセットとする。ここで定義していないノードの使用は禁止 */
	wire			reset_sig = csi_reset;		// モジュール内部駆動非同期リセット 

	/* 内部は全て正エッジ駆動とする。ここで定義していないクロックノードの使用は禁止 */
	wire			clock_sig = avm_clk;		// Avalonバス駆動クロック 

	/* SDC制約付きレジスタの宣言 */
	(* altera_attribute = {"-name SDC_STATEMENT \"set_false_path -to [get_registers *clr_fg_avm:*\|enable_in_reg\[0\]]\""} *)
	reg  [1:0]		enable_in_reg;
	(* altera_attribute = {"-name SDC_STATEMENT \"set_false_path -to [get_registers *clr_fg_avm:*\|start_in_reg\[0\]]\""} *)
	reg  [1:0]		start_in_reg;
	(* altera_attribute = {"-name SDC_STATEMENT \"set_false_path -to [get_registers *clr_fg_avm:*\|address_in_reg\[*\]]\""} *)
	reg  [31:2]		address_in_reg;
	(* altera_attribute = {"-name SDC_STATEMENT \"set_false_path -to [get_registers *clr_fg_avm:*\|transnum_in_reg\[*\]]\""} *)
	reg  [25:0]		transnum_in_reg;

	wire			enable_sig, start_sig;

	reg  [4:0]		avmstate_reg;
	reg				ready_reg;
	reg				write_reg;
	reg  [5:0]		burstcount_reg, chunkcount_reg;
	reg  [25:0]		datacount_reg;
	reg  [31:0]		address_reg;


/* ※以降のwire、reg宣言は禁止※ */

/* ===== テスト記述 ============== */



/* ===== モジュール構造記述 ============== */

	///// 信号の同期化 /////

	always @(posedge clock_sig) begin
		enable_in_reg <= {enable_in_reg[0], enable};
		start_in_reg <= {start_in_reg[0], start};
		address_in_reg <= address_top[31:2];
		transnum_in_reg <= transdata_num;
	end

	assign enable_sig = enable_in_reg[1];
	assign start_sig = start_in_reg[1];


	///// AvalonMMトランザクション処理 /////

	assign writedata_rdack = (write_reg && !avm_waitrequest)? 1'b1 : 1'b0;	// データ要求 

	always @(posedge clock_sig or posedge reset_sig) begin
		if (reset_sig) begin
			avmstate_reg <= STATE_DONE;
			ready_reg <= 1'b0;
			datacount_reg <= 1'd0;
			chunkcount_reg <= 1'd0;
			burstcount_reg <= 1'd0;
			write_reg <= 1'b0;
		end
		else begin

			case (avmstate_reg)
				STATE_IDLE : begin					// IDLE 
					if (enable_sig) begin
						if (start_sig) begin
							avmstate_reg <= STATE_SETUP;
							ready_reg <= 1'b0;
							datacount_reg <= transnum_in_reg;
							address_reg <= {address_in_reg, 2'b00};
						end
					end
					else begin
						avmstate_reg <= STATE_DONE;
						ready_reg <= 1'b0;
					end
				end

				STATE_SETUP : begin					// バーストセットアップ 
					if (enable_sig) begin
						if (datacount_reg < 32) begin
							if (writedata_usedw >= datacount_reg[4:0]) begin
								avmstate_reg <= STATE_BURSTWRITE;
								chunkcount_reg <= datacount_reg[5:0];
								burstcount_reg <= datacount_reg[5:0];
								write_reg <= 1'b1;
							end
						end
						else begin
							if (writedata_usedw >= 32) begin
								avmstate_reg <= STATE_BURSTWRITE;
								chunkcount_reg <= 6'd32;
								burstcount_reg <= 6'd32;
								write_reg <= 1'b1;
							end
						end
					end
					else begin
						avmstate_reg <= STATE_DONE;		// トランザクション中止 
					end
				end

				STATE_BURSTWRITE : begin			// データバーストライト 
					if (!avm_waitrequest) begin
						if (chunkcount_reg == 1) begin
							avmstate_reg <= STATE_LOOP;
							write_reg <= 1'b0;
						end

						chunkcount_reg <= chunkcount_reg - 1'd1;
						datacount_reg <= datacount_reg - 1'd1;
					end
				end

				STATE_LOOP : begin					// ループカウント 
					if (datacount_reg == 0 || !enable_sig) begin
						avmstate_reg <= STATE_DONE;
					end
					else begin
						avmstate_reg <= STATE_SETUP;
						address_reg <= address_reg + 32'd128;
					end
				end

				STATE_DONE : begin					// イネーブル待ち 
					if (enable_sig) begin
						avmstate_reg <= STATE_IDLE;
						ready_reg <= 1'b1;
					end
				end

			endcase
		end
	end

	assign avm_address = {address_reg[31:2], 2'b0};
	assign avm_burstcount = burstcount_reg;
	assign avm_write = write_reg;
	assign avm_writedata = writedata;
	assign avm_byteenable = 4'b1111;				// 4バイトライト固定 

	assign ready = ready_reg;


endmodule
