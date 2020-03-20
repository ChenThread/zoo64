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

unit Keys;

interface
	var
		KeysRightShiftHeld: Boolean;
		KeysLeftShiftHeld: Boolean;
		KeysShiftHeld: Boolean;
		KeysCtrlHeld: Boolean;
		KeysAltHeld: Boolean;
		KeysNumLockHeld: Boolean;
	procedure KeysUpdateModifiers;

implementation
uses Dos;

procedure KeysUpdateModifiers;
	begin
		{
			TODO: INT 16h/AH=02h - Get shift flags 
			Bit(s)	Description	(RBIL Table 00582)
			 7	Insert active
			 6	CapsLock active
			 5	NumLock active
			 4	ScrollLock active
			 3	Alt key pressed (either Alt on 101/102-key keyboards)
			 2	Ctrl key pressed (either Ctrl on 101/102-key keyboards)
			 1	left shift key pressed
			 0	right shift key pressed
		}

		{
			KeysRightShiftHeld := (regs.AL mod 2) = 1;
			KeysLeftShiftHeld := ((regs.AL div 2) mod 2) = 1;
			KeysCtrlHeld := ((regs.AL div 4) mod 2) = 1;
			KeysAltHeld := ((regs.AL div 8) mod 2) = 1;
			KeysNumLockHeld := ((regs.AL div 32) mod 2) = 1;
		}
		KeysRightShiftHeld := false;
		KeysLeftShiftHeld := false;
		KeysCtrlHeld := false;
		KeysAltHeld := false;
		KeysNumLockHeld := false;

		KeysShiftHeld := KeysRightShiftHeld or KeysLeftShiftHeld;
	end;

begin
end.
