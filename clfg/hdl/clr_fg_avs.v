// ===================================================================
// TITLE : CameraLink Framegrabber / AVS register
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

// レジスタマップ 
// reg00 : bit0:active, bit1:enable, bit2-3:tapmode, bit4:capmode, bit16:start_irqena, bit17:done_irqena, bit18:abort_irqena
// reg01 : bit0:ready, bit1:start, bit16:start_irq, bit17:done_irq, bit18:abort_irq
// reg02 : bit25-0:transdata_num
// reg03 : bit31-2:address_top, bit1-0: reserved


`default_nettype none

module clr_fg_avs (
	output wire			test_ovf_riseedge,
	output wire			test_ready_riseedge,
	output wire			test_ready_falledge,
	output wire			test_start_riseedge,
	output wire			test_avs_ready,
	output wire			test_avs_active,

	// Interface: clk
	input wire			csi_reset,
	input wire			avs_clk,

	// Interface: Avalon-MM Slave
	input wire  [1:0]	avs_address,
	input wire			avs_write,
	input wire  [31:0]	avs_writedata,
	input wire			avs_read,
	output wire [31:0]	avs_readdata,
	output wire			avs_irq,

	// External Interface
	output wire			clr_enable,
	output wire			clr_start,
	output wire [1:0]	clr_tapmode,
	output wire			clr_capmode,
	input wire			clr_active,				// 非同期入力 
	input wire			clr_capture,			// 非同期入力 
	input wire			clr_overflow,			// 非同期入力 

	output wire			avm_enable,
	output wire			avm_start,
	input wire			avm_ready,				// 非同期入力 
	output wire [31:2]	avm_addresstop,
	output wire [25:0]	avm_transdatanum
);


/* ===== 外部変更可能パラメータ ========== */



/* ----- 内部パラメータ ------------------ */



/* ※以降のパラメータ宣言は禁止※ */

/* ===== ノード宣言 ====================== */
	/* 内部は全て正論理リセットとする。ここで定義していないノードの使用は禁止 */
	wire			reset_sig = csi_reset;		// モジュール内部駆動非同期リセット 

	/* 内部は全て正エッジ駆動とする。ここで定義していないクロックノードの使用は禁止 */
	wire			clock_sig = avs_clk;		// モジュール内部駆動クロック 

	/* SDC制約付きレジスタの宣言 */
	(* altera_attribute = {"-name SDC_STATEMENT \"set_false_path -to [get_registers *clr_fg_avs:*\|active_in_reg\[0\]]\""} *)
	reg  [1:0]		active_in_reg;
	(* altera_attribute = {"-name SDC_STATEMENT \"set_false_path -to [get_registers *clr_fg_avs:*\|capture_in_reg\[0\]]\""} *)
	reg  [1:0]		capture_in_reg;
	(* altera_attribute = {"-name SDC_STATEMENT \"set_false_path -to [get_registers *clr_fg_avs:*\|ovf_in_reg\[0\]]\""} *)
	reg  [2:0]		ovf_in_reg;
	(* altera_attribute = {"-name SDC_STATEMENT \"set_false_path -to [get_registers *clr_fg_avs:*\|ready_in_reg\[0\]]\""} *)
	reg  [2:0]		ready_in_reg;

	wire			active_sig, capture_sig, ovf_riseedge_sig, ready_riseedge_sig, ready_falledge_sig;

	reg				start_reg, start_old_reg;
	wire			ready_sig;
	reg				avmstart_reg;
	reg				avmexec_reg;
	reg				start_irq_reg;
	reg				done_irq_reg;
	reg				abort_irq_reg;

	reg				enable_reg;
	reg  [1:0]		tapmode_reg;
	reg				capmode_reg;
	reg				start_irqena_reg;
	reg				done_irqena_reg;
	reg				abort_irqena_reg;
	reg  [25:0]		transdatanum_reg;
	reg  [31:2]		addresstop_reg;


/* ※以降のwire、reg宣言は禁止※ */

/* ===== テスト記述 ============== */

	assign test_ovf_riseedge = ovf_riseedge_sig;
	assign test_ready_riseedge = ready_riseedge_sig;
	assign test_ready_falledge = ready_falledge_sig;
	assign test_start_riseedge = (start_reg && !start_old_reg);
	assign test_avs_ready = ready_sig;
	assign test_avs_active = active_sig;


/* ===== モジュール構造記述 ============== */

	///// 信号の同期化 /////

	always @(posedge clock_sig) begin
		active_in_reg <= {active_in_reg[0], clr_active};
		capture_in_reg <= {capture_in_reg[0], clr_capture};
		ovf_in_reg <= {ovf_in_reg[1:0], clr_overflow};
		ready_in_reg <= {ready_in_reg[1:0], avm_ready};
	end

	assign active_sig = (active_in_reg[1] || ready_in_reg[1]);		// clinputとavmが両方disableになるとネゲート 
	assign capture_sig = capture_in_reg[1];
	assign ovf_riseedge_sig = (ovf_in_reg[1] && !ovf_in_reg[2]);
	assign ready_riseedge_sig = (ready_in_reg[1] && !ready_in_reg[2]);
	assign ready_falledge_sig = (!ready_in_reg[1] && ready_in_reg[2]);


	///// Avalon-MMインターフェース /////

	assign ready_sig = (!start_reg && !capture_sig && ready_in_reg[1]);

	assign avs_readdata =
			(avs_address == 2'h0)? {13'b0, abort_irqena_reg, done_irqena_reg, start_irqena_reg, 11'b0, capmode_reg, tapmode_reg, enable_reg, active_sig} :
			(avs_address == 2'h1)? {13'b0, abort_irq_reg, done_irq_reg, start_irq_reg, 14'b0, start_reg, ready_sig} :
			(avs_address == 2'h2)? {6'b0, transdatanum_reg} :
			(avs_address == 2'h3)? {addresstop_reg, 2'b0} :
			{32{1'bx}};

	assign avs_irq = (abort_irqena_reg & abort_irq_reg) | (done_irqena_reg & done_irq_reg) | (start_irqena_reg & start_irq_reg);


	always @(posedge clock_sig or posedge reset_sig) begin
		if (reset_sig) begin
			start_reg <= 1'b0;
			start_old_reg <= 1'b0;
			avmstart_reg <= 1'b0;
			avmexec_reg <= 1'b0;
			start_irq_reg <= 1'b0;
			done_irq_reg <= 1'b0;
			abort_irq_reg <= 1'b0;

			enable_reg <= 1'b0;
			capmode_reg <= 1'b0;
			start_irqena_reg <= 1'b0;
			done_irqena_reg <= 1'b0;
			abort_irqena_reg <= 1'b0;
		end
		else begin
			start_old_reg <= start_reg;

			// キャプチャ開始信号の処理 
			if (enable_reg) begin
				if (start_reg) begin
					if (capmode_reg) begin
						if (avs_write && avs_address == 2'h1 && avs_writedata[1] == 1'b0) begin
							start_reg <= 1'b0;
						end
					end
					else begin
						if (ready_riseedge_sig) begin
							start_reg <= 1'b0;
						end
					end
				end
				else if (avs_write && avs_address == 2'h1 && avs_writedata[1] == 1'b1 && ready_sig) begin
					start_reg <= 1'b1;
				end
			end
			else begin
				start_reg <= 1'b0;
			end

			// AVM転送信号の処理 
			if (enable_reg) begin
				if (start_reg && !start_old_reg) begin
					avmstart_reg <= 1'b1;
				end
				else if (ready_falledge_sig) begin
					avmstart_reg <= 1'b0;
				end
				else if (ready_riseedge_sig) begin
					if (capmode_reg && capture_sig) begin
						avmstart_reg <= 1'b1;
					end
				end
			end
			else begin
				avmstart_reg <= 1'b0;
			end

			// 割り込み要因フラグの処理 
			if (enable_reg) begin
				if (ready_falledge_sig) begin
					avmexec_reg <= avmstart_reg;
				end
				else if (ready_riseedge_sig) begin
					avmexec_reg <= 1'b0;
				end
			end
			else begin
				avmexec_reg <= 1'b0;
			end

			if (ready_falledge_sig) begin
				start_irq_reg <= avmstart_reg;
			end
			else if (avs_write && avs_address == 2'h1 && avs_writedata[16] == 1'b0) begin
				start_irq_reg <= 1'b0;
			end

			if (ready_riseedge_sig) begin
				done_irq_reg <= avmexec_reg;
			end
			else if (avs_write && avs_address == 2'h1 && avs_writedata[17] == 1'b0) begin
				done_irq_reg <= 1'b0;
			end

			if (ovf_riseedge_sig) begin
				abort_irq_reg <= 1'b1;
			end
			else if (avs_write && avs_address == 2'h1 && avs_writedata[18] == 1'b0) begin
				abort_irq_reg <= 1'b0;
			end


			// その他のレジスタの処理 
			if (avs_write) begin
				case (avs_address)
					2'h0 : begin
						enable_reg <= avs_writedata[1];

						if (!active_sig && avs_writedata[1] == 1'b0) begin	// ペリフェラルがdisableの時のみ書き込み可 
							tapmode_reg <= avs_writedata[3:2];
							capmode_reg <= avs_writedata[4];
						end

						start_irqena_reg <= avs_writedata[16];
						done_irqena_reg <= avs_writedata[17];
						abort_irqena_reg <= avs_writedata[18];
					end
					2'h2 : begin
						transdatanum_reg <= avs_writedata[25:0];
					end
					2'h3 : begin
						addresstop_reg <= avs_writedata[31:2];
					end
				endcase
			end

		end
	end

	assign clr_enable = enable_reg;
	assign clr_start = start_reg;
	assign clr_tapmode = tapmode_reg;
	assign clr_capmode = capmode_reg;

	assign avm_enable = (enable_reg && !ovf_in_reg[1])? 1'b1 : 1'b0;
	assign avm_start = avmstart_reg;
	assign avm_addresstop = addresstop_reg;
	assign avm_transdatanum = transdatanum_reg;



endmodule
