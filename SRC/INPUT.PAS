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

{$PACKRECORDS 1}
unit Input;

interface
	const
		KEY_BACKSPACE = #8;
		KEY_TAB = #9;
		KEY_ENTER = #13;
		KEY_CTRL_Y = #25;
		KEY_ESCAPE = #27;
		KEY_ALT_P = #153;
		KEY_F1 = #187;
		KEY_F2 = #188;
		KEY_F3 = #189;
		KEY_F4 = #190;
		KEY_F5 = #191;
		KEY_F6 = #192;
		KEY_F7 = #193;
		KEY_F8 = #194;
		KEY_F9 = #195;
		KEY_F10 = #196;
		KEY_UP = #200;
		KEY_PAGE_UP = #201;
		KEY_LEFT = #203;
		KEY_RIGHT = #205;
		KEY_DOWN = #208;
		KEY_PAGE_DOWN = #209;
		KEY_INSERT = #210;
		KEY_DELETE = #211;
		KEY_HOME = #212;
		KEY_END = #213;
	var
		InputDeltaX, InputDeltaY: integer;
		InputShiftPressed: boolean;
		InputShiftAccepted: boolean;
		InputJoystickEnabled: boolean;
		InputMouseEnabled: boolean;
		InputKeyPressed: char;
		InputMouseX, InputMouseY: integer;
		InputMouseActivationX, InputMouseActivationY: integer;
		InputMouseButtonX, InputMouseButtonY: integer;
		InputJoystickMoved: boolean;
	procedure InputUpdate;
	procedure InputInitDevices;
	procedure InputReadWaitKey;
	function InputConfigure: boolean;

implementation
uses Dos, Crt, Keys, Sounds, Video;

const
	PORT_JOYSTICK = $0201;
var
	JoystickXInitial, JoystickYInitial: integer;
	InputLastDeltaX, InputLastDeltaY: integer;
	JoystickXMin, JoystickXCenter, JoystickXMax: integer;
	JoystickYMin, JoystickYCenter, JoystickYMax: integer;
	InputKeyBuffer: string;

function InputIsJoystickButtonPressed: boolean;
	begin
		{ TODO: Get buttons }
		{InputIsJoystickButtonPressed := (Port[PORT_JOYSTICK] and $30) <> $30;}
		InputIsJoystickButtonPressed := false;
	end;

procedure InputJoystickGetCoords(var x, y: integer);
	{var
		startTicks: word;}
	begin
		x := 0;
		y := 0;
		{ TODO: Get coords }
		{
		startTicks := TimerTicks;
		Port[PORT_JOYSTICK] := 0;
		repeat
			x := x + (Port[PORT_JOYSTICK] and 1);
			y := y + (Port[PORT_JOYSTICK] and 2);
		until ((Port[PORT_JOYSTICK] and 3) = 0) or ((TimerTicks - startTicks) > 3);
		y := y div 2;
		if (TimerTicks - startTicks) > 3 then begin
			x := -1;
			y := -1;
		end;
		}
	end;

function InputCalibrateJoystickPosition(msg: String; var x, y: integer): boolean;
	var
		charTyped: char;
	begin
		charTyped := #0;
		WriteCP437(msg);
		repeat
			InputJoystickGetCoords(x, y);
			if KeyPressed then
				charTyped := ReadKey;
		until (charTyped = #27) or (InputIsJoystickButtonPressed);
		Delay(25);

		if charTyped <> #27 then begin
			InputCalibrateJoystickPosition := true;
			repeat
				if KeyPressed then charTyped := ReadKey;
			until (not InputIsJoystickButtonPressed) or (charTyped = #27);
		end;
		Delay(25);

		if charTyped = #27 then
			InputCalibrateJoystickPosition := false;
		WriteLn;
		WriteLn;
	end;

function InputInitJoystick: boolean;
	var
		joyX, joyY: integer;
	begin
		InputJoystickGetCoords(joyX, joyY);
		if (joyX > 0) and (joyY > 0) then  begin
			JoystickXInitial := joyX;
			JoystickYInitial := joyY;
			InputInitJoystick := true;
		end else begin
			InputInitJoystick := false;
		end;
	end;

procedure InputCalibrateJoystick;
	var
		charTyped: char;
	label CalibrationStart;
	begin
	CalibrationStart:
		InputJoystickEnabled := false;
		WriteLn;
		WriteCP437('  Joystick calibration:  Press ESCAPE to abort.');
		WriteLn;
		WriteLn;

		if not InputCalibrateJoystickPosition(
			'  Center joystick and press button: ',
			JoystickXCenter, JoystickYCenter
		) then exit;
		if not InputCalibrateJoystickPosition(
			'  Move joystick to UPPER LEFT corner and press button: ',
			JoystickXMin, JoystickYMin
		) then exit;
		if not InputCalibrateJoystickPosition(
			'  Move joystick to LOWER RIGHT corner and press button: ',
			JoystickXMax, JoystickYMax
		) then exit;

		JoystickXMin := JoystickXMin - JoystickXCenter;
		JoystickXMax := JoystickXMax - JoystickXCenter;
		JoystickYMin := JoystickYMin - JoystickYCenter;
		JoystickYMax := JoystickYMax - JoystickYCenter;

		{ if calibration valid range -> successful }
		if (JoystickXMin < 1) and (JoystickXMax > 1)
			and (JoystickYMin < 1) and (JoystickYMax > 1) then
		begin
			InputJoystickEnabled := true;
		end else begin
			WriteCP437('  Calibration failed - try again (y/N)? ');
			repeat until KeyPressed;
			charTyped := ReadKey;
			WriteLn;
			if UpCase(charTyped) = 'Y' then
				goto CalibrationStart;
		end;
	end;

procedure InputUpdate;
	var
		joyXraw, joyYraw: integer;
		joyX, joyY: integer;
		mouseButtons: integer;
	begin
		InputDeltaX := 0;
		InputDeltaY := 0;
		InputShiftPressed := false;
		InputJoystickMoved := false;
		while KeyPressed do begin
			InputKeyPressed := ReadKey;
			if (InputKeyPressed = #0) or (InputKeyPressed = #1) or (InputKeyPressed = #2) then
				InputKeyBuffer := InputKeyBuffer + Chr(Ord(ReadKey) or $80)
			else
				InputKeyBuffer := InputKeyBuffer + InputKeyPressed;
		end;
		if Length(InputKeyBuffer) <> 0 then begin
			InputKeyPressed := InputKeyBuffer[1];
			if Length(InputKeyBuffer) = 1 then
				InputKeyBuffer := ''
			else
				InputKeyBuffer := Copy(InputKeyBuffer, Length(InputKeyBuffer) - 1, 1);

			case InputKeyPressed of
				KEY_UP, '8': begin
					InputDeltaX := 0;
					InputDeltaY := -1;
				end;
				KEY_LEFT, '4': begin
					InputDeltaX := -1;
					InputDeltaY := 0;
				end;
				KEY_RIGHT, '6': begin
					InputDeltaX := 1;
					InputDeltaY := 0;
				end;
				KEY_DOWN, '2': begin
					InputDeltaX := 0;
					InputDeltaY := 1;
				end;
			end;
		end else begin
			InputKeyPressed := #0;
		end;

		if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
			{ keyboard movement }
			KeysUpdateModifiers;
			InputShiftPressed := KeysShiftHeld;
		end else if InputJoystickEnabled then begin
			InputJoystickGetCoords(joyXraw, joyYraw);

			joyX := joyXraw - JoystickXCenter;
			joyY := joyYraw - JoystickYCenter;

			if Abs(joyX) > Abs(joyY) then begin
				if joyX < (JoystickXMin div 2) then begin
					InputDeltaX := -1;
					InputJoystickMoved := true;
				end else if joyX > (JoystickXMax div 2) then begin
					InputDeltaX := 1;
					InputJoystickMoved := true;
				end;
			end else begin
				if joyY < (JoystickYMin div 2) then begin
					InputDeltaY := -1;
					InputJoystickMoved := true;
				end else if joyY > (JoystickYMax div 2) then begin
					InputDeltaY := 1;
					InputJoystickMoved := true;
				end;
			end;

			if InputIsJoystickButtonPressed then begin
				if not InputShiftAccepted then
					InputShiftPressed := true;
			end else begin
				InputShiftAccepted := false;
			end;
		end else if InputMouseEnabled then begin
			{
				TODO: INT 33h/AX=000Bh: Read Motion Counters

				Output:
				CX = number of mickeys mouse moved horizontally since last call
				DX = number of mickeys mouse moved vertically

				These get added like so:
			}
			{
				InputMouseX := InputMouseX + Integer(regs.CX);
				InputMouseY := InputMouseY + Integer(regs.DX);
			}

			if Abs(InputMouseX) > Abs(InputMouseY) then begin
				if Abs(InputMouseX) > InputMouseActivationX then begin
					if InputMouseX > 0 then
						InputDeltaX := 1
					else
						InputDeltaX := -1;
					InputMouseX := 0;
				end;
			end else if Abs(InputMouseY) > Abs(InputMouseX) then begin
				if Abs(InputMouseY) > InputMouseActivationY then begin
					if InputMouseY > 0 then
						InputDeltaY := 1
					else
						InputDeltaY := -1;
					InputMouseY := 0;
				end;
			end;

			{
				TODO: INT 33h/AX=0003h: Return Position and Button Status

				Output:
				BX = button status (see RBIL #03168)
				CX = column
				DX = row

				We only care about BX here.

				Bit(s)	Description	(RBIL Table 03168)
				 0	left button pressed if 1
				 1	right button pressed if 1
				 2	middle button pressed if 1 (Mouse Systems/Logitech/Genius)
			}

			mouseButtons := 0;

			{ left mouse button }
			if (mouseButtons and 1) <> 0 then begin
				if not InputShiftAccepted then
					InputShiftPressed := true;
			end else begin
				InputShiftAccepted := false;
			end;

			{ right/middle mouse button }
			if (mouseButtons and 6) <> 0 then begin
				if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
					InputMouseButtonX := InputDeltaX;
					InputMouseButtonY := InputDeltaY;
				end else begin
					InputDeltaX := InputMouseButtonX;
					InputDeltaY := InputMouseButtonY;
				end;
			end else begin
				InputMouseButtonX := 0;
				InputMouseButtonY := 0;
			end;
		end;

		if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
			InputLastDeltaX := InputDeltaX;
			InputLastDeltaY := InputDeltaY;
		end;
	end;

function InputInitMouse: boolean;
	begin
		{
			TODO: Any mouse initialisation needed here.

			Also, for some reason,
			the original code sets InputInitMouse by some conditional,
			but then immediately sets it to true afterwards.
		}
		InputInitMouse := true;
	end;

procedure InputInitDevices;
	begin
		InputJoystickEnabled := InputInitJoystick;
		InputMouseEnabled := InputInitMouse;
	end;

function InputConfigure: boolean;
	var
		charTyped: char;
	begin
		charTyped := ' ';
		if InputJoystickEnabled or InputMouseEnabled then begin
			Writeln;
			WriteCP437('  Game controller:  K)eyboard');
			if InputJoystickEnabled then
				WriteCP437(',  J)oystick');
			if InputMouseEnabled then
				WriteCP437(',  M)ouse');
			WriteCP437('?  ');

			repeat
				repeat until KeyPressed;
				charTyped := UpCase(ReadKey);
			until (charTyped = 'K')
				or (InputJoystickEnabled and (charTyped = 'J'))
				or (InputMouseEnabled and (charTyped = 'M'))
				or (charTyped = #27);
			Writeln;

			InputJoystickEnabled := false;
			InputMouseEnabled := false;
			case charTyped of
				'J': begin
					InputJoystickEnabled := true;
					InputCalibrateJoystick;
				end;
				'M': begin
					InputMouseEnabled := true;
				end;
			end;
			Writeln;
		end;
		InputConfigure := charTyped <> #27;
	end;

procedure InputReadWaitKey;
	begin
		repeat
			InputUpdate
		until InputKeyPressed <> #0;
	end;

begin
	InputLastDeltaX := 0;
	InputLastDeltaY := 0;
	InputDeltaX := 0;
	InputDeltaY := 0;
	InputShiftPressed := false;
	InputShiftAccepted := false;
	InputMouseX := 0;
	InputMouseY := 0;
	InputMouseActivationX := 60;
	InputMouseActivationY := 60;
	InputMouseButtonX := 0;
	InputMouseButtonY := 0;
	InputKeyBuffer := '';
end.
