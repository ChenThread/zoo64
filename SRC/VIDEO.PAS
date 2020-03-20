{
	Copyright (c) 2020 Adrian Siekierka

	Based on a reconstruction of code from ZZT,
	Copyright 1991 Epic MegaGames, used with permission.

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
}

{$I-}
unit Video;

interface
	type
		TVideoLine = string[80];
		TVideoWriteTextProc = procedure(x, y, color: byte; text: TVideoLine);
	const
		PORT_CGA_PALETTE = $03D9;
	var
		VideoWriteText: TVideoWriteTextProc;
		VideoMonochrome: boolean;
		CP437ToUnicode: array[0 .. 255] of smallint = (
			$0020, $263A, $263B, $2665, $2666, $2663, $2660, $2022,
			$25D8, $25CB, $25D9, $2642, $2640, $266A, $266B, $263C,
			$25BA, $25C4, $2195, $203C, $00B6, $00A7, $25AC, $21A8,
			$2191, $2193, $2192, $2190, $221F, $2194, $25B2, $25BC,

			$0020, $0021, $0022, $0023, $0024, $0025, $0026, $0027,
			$0028, $0029, $002A, $002B, $002C, $002D, $002E, $002F,
			$0030, $0031, $0032, $0033, $0034, $0035, $0036, $0037,
			$0038, $0039, $003A, $003B, $003C, $003D, $003E, $003F,
			$0040, $0041, $0042, $0043, $0044, $0045, $0046, $0047,
			$0048, $0049, $004A, $004B, $004C, $004D, $004E, $004F,
			$0050, $0051, $0052, $0053, $0054, $0055, $0056, $0057,
			$0058, $0059, $005A, $005B, $005C, $005D, $005E, $005F,
			$0060, $0061, $0062, $0063, $0064, $0065, $0066, $0067,
			$0068, $0069, $006A, $006B, $006C, $006D, $006E, $006F,
			$0070, $0071, $0072, $0073, $0074, $0075, $0076, $0077,
			$0078, $0079, $007A, $007B, $007C, $007D, $007E, $2302,

			$00C7, $00FC, $00E9, $00E2, $00E4, $00E0, $00E5, $00E7,
			$00EA, $00EB, $00E8, $00EF, $00EE, $00EC, $00C4, $00C5,
			$00C9, $00E6, $00C6, $00F4, $00F6, $00F2, $00FB, $00F9,
			$00FF, $00D6, $00DC, $00A2, $00A3, $00A5, $20A7, $0192,
			$00E1, $00ED, $00F3, $00FA, $00F1, $00D1, $00AA, $00BA,
			$00BF, $2310, $00AC, $00BD, $00BC, $00A1, $00AB, $00BB,
			$2591, $2592, $2593, $2502, $2524, $2561, $2562, $2556,
			$2555, $2563, $2551, $2557, $255D, $255C, $255B, $2510,
			$2514, $2534, $252C, $251C, $2500, $253C, $255E, $255F,
			$255A, $2554, $2569, $2566, $2560, $2550, $256C, $2567,
			$2568, $2564, $2565, $2559, $2558, $2552, $2553, $256B,
			$256A, $2518, $250C, $2588, $2584, $258C, $2590, $2580,
			$03B1, $00DF, $0393, $03C0, $03A3, $03C3, $00B5, $03C4,
			$03A6, $0398, $03A9, $03B4, $221E, $03C6, $03B5, $2229,
			$2261, $00B1, $2265, $2264, $2320, $2321, $00F7, $2248,
			$00B0, $2219, $00B7, $221A, $207F, $00B2, $25A0, $0020);
	procedure WriteCP437(text: TVideoLine);
	function VideoConfigure: boolean;
	procedure VideoWriteTextCO80(x, y, color: byte; text: TVideoLine);
	procedure VideoWriteTextCO40(x, y, color: byte; text: TVideoLine);
	procedure VideoWriteTextBW80(x, y, color: byte; text: TVideoLine);
	procedure VideoWriteTextBW40(x, y, color: byte; text: TVideoLine);
	procedure VideoInstall(columns, borderColor: integer);
	procedure VideoUninstall;
	procedure VideoShowCursor;
	procedure VideoHideCursor;
	procedure VideoSetBorderColor(value: integer);
	procedure VideoMove(x, y, chars: integer; data: pointer; toVideo: boolean);

implementation
uses Crt, Dos;
var
	VideoColumns: integer;
	VideoBorderColor: integer;
	VideoTextSegment: word;
	VideoTextPointer: pointer;
	VideoCursorVisible: boolean;

procedure WriteCP437(text: TVideoLine);
	var
		textRaw: RawByteString;
		x, y, i: integer;
		ch: integer;
	begin
		{
			Apparently Free Pascal's Crt unit doesn't actually support UTF-8.
			So we force it to accept what we tell it to.
			Yep, one character at a time. --GM
		}
		x := WhereX;
		y := WhereY;
		for i := 1 to Length(text) do begin
			ch := CP437ToUnicode[Ord(text[i])];
			if ch < $80 then
				textRaw := Chr(ch)
			else if ch < $0800 then
				textRaw := (''
					+ Chr(((ch shr  6) and $1F) or $C0)
					+ Chr(((ch shr  0) and $3F) or $80)
					)
			else { ch < $10000 }
				textRaw := (''
					+ Chr(((ch shr 12) and $0F) or $E0)
					+ Chr(((ch shr  6) and $3F) or $80)
					+ Chr(((ch shr  0) and $3F) or $80)
					);
			Write(textRaw);
			GotoXY(x+(i-1)+1, y);
		end;
	end;

procedure VideoWriteTextCO80(x, y, color: byte; text: TVideoLine);
	begin
		GotoXY(x, y);
		TextColor(color);
		WriteCP437(text);
	end;

procedure VideoWriteTextCO40(x, y, color: byte; text: TVideoLine);
	begin
		GotoXY(x, y);
		TextColor(color);
		WriteCP437(text);
	end;

procedure VideoWriteTextBW80(x, y, color: byte; text: TVideoLine);
	begin
		if (color and $08) = $08 then begin
			if (color and $F0) = 0 then
				color := $0F
			else
				color := $7F;
		end else begin
			if (color and $07) <> 0 then
				color := $07
			else
				color := $70;
		end;
		GotoXY(x, y);
		TextColor(color);
		WriteCP437(text);
	end;

procedure VideoWriteTextBW40(x, y, color: byte; text: TVideoLine);
	begin
		if (color and $08) = $08 then begin
			if (color and $F0) = 0 then
				color := $0F
			else
				color := $7F;
		end else begin
			if (color and $07) <> 0 then
				color := $07
			else
				color := $70;
		end;
		GotoXY(x, y);
		TextColor(color);
		WriteCP437(text);
	end;

function VideoConfigure: boolean;
	var
		charTyped: Char;
	begin
		charTyped := ' ';
		if LastMode = 7 then begin
			VideoWriteText := @VideoWriteTextBW80;
			VideoMonochrome := true;
		end else begin
			Writeln;
			WriteCP437('  Video mode:  C)olor,  M)onochrome?  ');
			repeat
				repeat until KeyPressed;
				charTyped := UpCase(ReadKey);
			until charTyped in [#27, 'C', 'M'];
			case charTyped of
				'C': VideoMonochrome := false;
				'M': VideoMonochrome := true;
				#27: VideoMonochrome := (LastMode = 7);
			end;
		end;
		VideoConfigure := charTyped <> #27;
	end;

procedure VideoInstall(columns, borderColor: integer);
	begin
		{ TODO: INT 10h/AH=12h/BL=30h AL=01h: Set vertical resolution to 350 lines }

		if not VideoMonochrome then
			TextBackground(borderColor);

		VideoColumns := columns;
		if VideoMonochrome then begin
			if LastMode in [0, 1, 2, 3] then begin
				if columns = 80 then begin
					TextMode(BW80);
					VideoWriteText := @VideoWriteTextBW80;
				end else begin
					TextMode(BW40);
					VideoWriteText := @VideoWriteTextBW40;
				end;
			end else begin
				VideoWriteText := @VideoWriteTextBW80;
				TextMode(7);
				VideoColumns := 80;
			end;
		end else begin
			if VideoColumns = 80 then begin
				TextMode(CO80);
				VideoWriteText := @VideoWriteTextCO80;
			end else begin
				TextMode(CO40);
				VideoWriteText := @VideoWriteTextCO40;
			end;
			if not VideoMonochrome then
				TextBackground(borderColor);
			ClrScr;
		end;
		if not VideoCursorVisible then
			VideoHideCursor;
		VideoSetBorderColor(borderColor);
	end;

procedure VideoUninstall;
	begin
		{ TODO: INT 10h/AH=12h/BL=30h AL=01h: Set vertical resolution to 350 lines }
		TextBackground(0);
		VideoColumns := 80;
		if VideoMonochrome then
			TextMode(BW80)
		else
			TextMode(CO80);
		VideoSetBorderColor(0);
		ClrScr;
	end;

procedure VideoSetCursorShape(value: integer);
	begin
		{
			TODO: INT 10h/AH=01h: Set cursor shape
			CH = cursor start and options (see RBIL #00013)
			CL = bottom scan line containing cursor (bits 0-4)
			CX is set to value
		}
	end;

procedure VideoShowCursor;
	begin
		VideoSetCursorShape($0607);
		VideoCursorVisible := true;
	end;

procedure VideoHideCursor;
	begin
		VideoSetCursorShape($2000);
		VideoCursorVisible := false;
	end;

procedure VideoSetBorderColor(value: integer);
	begin
		{
			TODO: Set border colour to colour index in value
			(This normally sets IO byte 0x3D9 to value)
		}

		VideoBorderColor := value;
	end;

procedure VideoMove(x, y, chars: integer; data: pointer; toVideo: boolean);
	var
		offset: integer;
	begin
		offset := (y * VideoColumns + x) * 2;
		VideoWriteTextCO80(0, 0, 0, '');
		{ TODO: Set up a buffer to put text onto }
		{
			if toVideo then
				Move(data^, Ptr(VideoTextSegment, offset)^, chars * 2)
			else
				Move(Ptr(VideoTextSegment, offset)^, data^, chars * 2);
		}
	end;


begin
	VideoBorderColor := 0;
	VideoColumns := 80;
	VideoWriteText := @VideoWriteTextBW80;
	if LastMode = 7 then begin
		VideoTextSegment := $B000;
		VideoMonochrome := true;
	end else begin
		VideoTextSegment := $B800;
		VideoMonochrome := false;
	end;
	VideoTextPointer := Ptr(VideoTextSegment, $0000);
	VideoCursorVisible := true;
end.
