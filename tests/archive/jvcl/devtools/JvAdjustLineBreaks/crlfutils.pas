{$I JVCL.INC}
unit crlfutils;

interface

procedure Run;
implementation
uses
  Windows, SysUtils, Classes;

procedure ShowHelp;
begin
  writeln('');
  writeln('JEDI CR(LF) version 0.1: LF->CRLF and CRLF->LF converter.');
  writeln('===================================================');
  writeln('Usage:');
  writeln('crlf [options] <filemask> [options] <filemask> (etc)');
  writeln('');
  writeln('where [options] can be any combination of:');
  writeln('  /s - recurse into sub-folders from this point on');
  writeln('  /c - compare before write: only write if file has changed (default)');
  writeln('  /u - do NOT compare before write: always write');
  writeln('  /l - convert to Linux line breaks (LF) (default on Linux)');
  writeln('  /w - convert to Windows line breaks (CRLF) (default on Windows)');
  writeln('');
  writeln('<filemask> accepts wildcards (* and ?).');
  writeln('');
  writeln('Example:');
  writeln('========');
  writeln('crlf /u /l *.pas /c /w /s *.dfm');
  writeln('Converts the pas files to LF (always writes) and the dfm files to CRLF (writes if modified). Recurses into sub-folders when searching for dfm''s.');
  writeln('');
  writeln('Example:');
  writeln('========');
  writeln('crlf *.pas *.dfm');
  writeln('Converts the pas and dfm files to LF on Linux and CRLF on Windows (system default). Always checks before write (no /u option).');
  writeln('');
  writeln('');
  writeln('NOTE: if you compiled using Delphi 5 or earlier, CRLF->LF is NOT supported!');
end;

procedure ConvertFile(const Filename:string;ToWindows,CompareBeforeWrite:boolean);
{$IFDEF COMPILER6_UP}
const
  cStyle:array[boolean] of TTextLineBreakStyle = (tlbsLF,tlbsCRLF);
{$ENDIF COMPILER6_UP}
var
  F:TFileStream;
  tmp,tmp2:string;
begin
  F := TFileStream.Create(Filename,fmOpenReadWrite or fmShareExclusive );
  try
    SetLength(tmp,F.Size);
    if F.Size > 0 then
    begin
      F.Read(tmp[1],F.Size);
      if CompareBeforeWrite then
        tmp2 := tmp;
      tmp := AdjustLineBreaks(tmp{$IFDEF COMPILER6_UP},cStyle[ToWindows]{$ENDIF});
      if CompareBeforeWrite and (tmp = tmp2) then
        Exit;
      F.Size := 0;
      F.Write(tmp[1],Length(tmp));
    end;
  finally
    F.Free;
  end;
end;

function ConvertFiles(const FileMask:string;ToWindows,CompareBeforeWrite,Recurse:boolean):integer;
var
  SearchHandle:DWORD;
  FindData:TWin32FindData;
  APath:string;
begin
  Result := 0;
  APath := ExtractFilePath(Filemask);
  SearchHandle := FindFirstFile(PChar(Filemask),FindData);
  if SearchHandle <> INVALID_HANDLE_VALUE then
  try
    repeat
      if (FindData.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY = 0) then
      begin
        if (FindData.dwFileAttributes and FILE_ATTRIBUTE_READONLY = FILE_ATTRIBUTE_READONLY) then
          writeln('ERROR: ',FindData.cFileName,' is read-only!')
        else
        begin
          writeln(FindData.cFileName);
          ConvertFile(APath + FindData.cFileName,ToWindows,CompareBeforeWrite);
          Inc(Result);
        end;
      end
      else if Recurse and (FindData.cFileName[0] <> '.') then
        ConvertFiles(IncludeTrailingPathdelimiter(APath + FindData.cFileName) + ExtractFilename(Filemask),ToWindows,CompareBeforeWrite,true);
    until not FindNextFile(SearchHandle,FindData);
  finally
    Windows.FindClose(SearchHandle);
  end;
end;

procedure Run;
const
  cCurrentOS:array[boolean] of PChar = ('(CRLF->LF)','(LF->CRLF)');
var
  ToWindows,CompareBeforeWrite,Recurse:boolean;
  i,Count:integer;
begin
  // cmd line: -l *.pas *.dfm *.txt -c -w *.xfm
  // where
  // -l - convert CRLF to LF (to linux)
  // -w - convert LF to CRLF (to windows)
  // -c - check content: only write if file has changed (default)
  // -u - never check content: always write

  Count := 0;
  if ParamCount = 0 then
  begin
    ShowHelp;
    Exit;
  end;
  CompareBeforeWrite := true;
  Recurse := false;
  // set depending on target
  ToWindows := true;
  {$IFDEF LINUX}
  ToWindows := false;
  {$ENDIF}
  for i := 1 to ParamCount do
  begin
    if SameText(ParamStr(i),'/l') or SameText(ParamStr(i),'-l') then
    begin
      ToWindows := false;
      writeln('Converting ', cCurrentOS[ToWindows],':');
      Continue;
    end
    else if SameText(ParamStr(i),'/w') or SameText(ParamStr(i),'-w') then
    begin
      ToWindows := true;
      writeln('Converting ', cCurrentOS[ToWindows],':');
      Continue;
    end
    else if SameText(ParamStr(i),'/?') or SameText(ParamStr(i),'-?') or
       SameText(ParamStr(i),'/h') or SameText(ParamStr(i),'-h')then
    begin
      ShowHelp;
      Exit;
    end
    else if SameText(ParamStr(i),'/c') or SameText(ParamStr(i),'-c') then
    begin
      CompareBeforeWrite := true;
      Continue;
    end
    else if SameText(ParamStr(i),'/u') or SameText(ParamStr(i),'-u') then
    begin
      CompareBeforeWrite := false;
      Continue;
    end
    else if SameText(ParamStr(i),'/s') or SameText(ParamStr(i),'-s') then
    begin
      Recurse := true;
      Continue;
    end
    else
      Inc(Count,ConvertFiles(ExpandUNCFilename(ParamStr(i)),ToWindows,CompareBeforeWrite,Recurse));
  end;
  writeln('');
  writeln('Done: ', Count,' files converted.');
end;

end.
