CameraLink Frame-grabber IP
===========================

シンプルなCameraLink BASEコンフィグレーション用のフレームグラバーIPです。  
カメラ映像のワンショット取り込み、連続取り込みが可能です。  

BASEコンフィグレーションのうち下記のカラーフォーマットに対応します。
- 24bitRGBカラー
- 8bitモノクロ（1-Tap, 2-Tap, 3-Tap)  
  ※10bit,12bit,14bit,16bitモノクロフォーマットは24bitカラーで取り込み後に別途演算処理を行う事で対応が可能

また対応する画像サイズとドットクロックは以下の通りです。
- 水平：8～16384ピクセル（４ピクセル単位）
- 垂直：1～16384ライン（１ライン単位）
- ドットクロック：0～85MHz


使用環境
-------
- QuartusPrime 17.1以降のPlatform Designer用
- NiosIIおよびメモリデバイスのインスタンスが必要
- LVDS→TTL信号変換はDS90CR288Aを外付け
- CC信号はPIOコンポーネント、serTC/serTFG信号はUARTコンポーネントを別途インスタンス


ライセンス
=========
[The MIT License (MIT)](https://opensource.org/licenses/MIT)  
Copyright (c) 2018 J-7SYSTEM WORKS LIMITED.

業務使用についての相談などありましたら s.osafune@j7system.jp までご連絡ください。


使い方
=====

1. `ctfg`フォルダ以下をプロジェクトの`ip`フォルダ以下にコピーします。
2. Platform Designerで`clfg_component`を追加します。
3. コンポーネントの信号を接続します。
	- `s1`はコントロールスレーブで、NiosIIのデータマスタに接続します。
	- `m1`はキャプチャデータを転送するバスマスタで、メモリデバイスに接続します。
	- `clock_s1`,`reset_s1`はスレーブクロックソースに、`clock_m1`,`reset_m1`はマスタークロックソースに、それぞれ接続します。
	- `irq_s1`は割り込み信号です。NiosIIの割り込みに接続します。
	- `cl_input`はCameraLink信号の入力になります。Conduit信号としてコンポーネント外部へ引き出します。
4. CC信号を使用する場合はPIOを、serTC/serTFG信号を使用する場合はUARTを任意で追加してください。

NiosII ソフトウェア例
--------------------
```c
const int sizex = 640;
const int sizey = 480;
const int bpp = 3; // bytes per pixel

alt_u32 datanum = sizex * sizey * bpp / 4;
alt_u32 *pCapture = (alt_u32 *)alt_uncached_malloc(datasize);
if (pCapture != NULL) return -1;

// ペリフェラル停止を待つ 
IOWR(CLR_FG_BASE, 0, 0);
while((IORD(CLR_FG_BASE, 0) & (1<<0))) {}

// モード設定（3-Tap or 24bit-color、ワンショット)
IOWR(CLR_FG_BASE, 0, (0<<4)|(bpp<<2)|(0<<1));

// ペリフェラルをイネーブル
IOWR(CLR_FG_BASE, 0, (0<<4)|(bpp<<2)|(1<<1));
while(!(IORD(CLR_FG_BASE, 0) & (1<<0))) {}

// 取り込みレジスタ設定 
IOWR(CLR_FG_BASE, 2, datanum); // データ数
IOWR(CLR_FG_BASE, 3, (alt_u32)pCapture); // ストア先アドレス

// キャプチャ
while(!(IORD(CLR_FG_BASE, 1) & (1<<0))) {} // READYを待つ
IOWR(CLR_FG_BASE, 1, (1<<1)); // キャプチャ要求 
while(!(IORD(CLR_FG_BASE, 1) & (1<<17))) {} // キャプチャ終了を待つ 

```

