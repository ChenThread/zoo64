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

procedure VideoWriteTextCO80(x, y, color: byte; text: TVideoLine);
	begin
		GotoXY(x, y);
		TextColor(color);
		Write(text);
	end;

procedure VideoWriteTextCO40(x, y, color: byte; text: TVideoLine);
	begin
		GotoXY(x, y);
		TextColor(color);
		Write(text);
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
		Write(text);
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
		Write(text);
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
			Write('  Video mode:  C)olor,  M)onochrome?  ');
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
		if toVideo then
			Move(data^, Ptr(VideoTextSegment, offset)^, chars * 2)
		else
			Move(Ptr(VideoTextSegment, offset)^, data^, chars * 2);
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
