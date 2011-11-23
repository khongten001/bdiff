{
 * UBDiff.pas
 *
 * Main program logic for BDiff.
 *
 * Based on bdiff.c by Stefan Reuther, copyright (c) 1999 Stefan Reuther
 * <Streu@gmx.de>.
 *
 * Copyright (c) 2003-2011 Peter D Johnson (www.delphidabbler.com).
 *
 * $Rev$
 * $Date$
 *
 * THIS SOFTWARE IS PROVIDED "AS-IS", WITHOUT ANY EXPRESS OR IMPLIED WARRANTY.
 * IN NO EVENT WILL THE AUTHORS BE HELD LIABLE FOR ANY DAMAGES ARISING FROM THE
 * USE OF THIS SOFTWARE.
 *
 * For conditions of distribution and use see the LICENSE file of visit
 * http://www.delphidabbler.com/software/bdiff/license
}


unit UBDiff;


interface


{ Program's main interface code: called from the project file }
procedure Main;


implementation

{$IOCHECKS OFF}

uses
  // Delphi
  SysUtils, Windows,
  // Project
  UAppInfo, UBDiffParams, UBDiffTypes, UBDiffUtils, UBlkSort, UErrors,
  UFileData, ULogger, UPatchWriters;

const
  FORMAT_VERSION  = '02';       // binary diff file format version
  BUFFER_SIZE     = 4096;       // size of buffer used to read files


{ Structure for a matching block }
type
  TMatch = record
    OldOffset: Cardinal;
    NewOffset: Cardinal;
    BlockLength: Cardinal;
  end;
  PMatch = ^TMatch;

{ Global variables }
var
  gMinMatchLength: Cardinal = 24; // default minimum match length
  gFormat: TFormat = FMT_QUOTED;  // default output format

{ Find maximum-length match }
function FindMaxMatch(OldFile: TFileData; SortedOldData: PBlock;
  SearchText: PSignedAnsiChar; SearchTextLength: Cardinal): TMatch;
var
  FoundPos: Cardinal;
  FoundLen: Cardinal;
begin
  Result.BlockLength := 0;  {no match}
  Result.NewOffset := 0;
  while (SearchTextLength <> 0) do
  begin
    FoundLen := FindString(
      OldFile.Data,
      SortedOldData,
      OldFile.Size,
      SearchText,
      SearchTextLength,
      FoundPos
    );
    if FoundLen >= gMinMatchLength then
    begin
      Result.OldOffset := FoundPos;
      Result.BlockLength := FoundLen;
      Exit;
    end;
    Inc(SearchText);
    Inc(Result.NewOffset);
    Dec(SearchTextLength);
  end;
end;


{ Main routine: generate diff }
procedure CreateDiff(OldFileName, NewFileName: string; Logger: TLogger);
var
  OldFile: TFileData;
  NewFile: TFileData;
  NewOffset: Cardinal;
  ToDo: Cardinal;
  SortedOldData: PBlock;
  Match: TMatch;
  PatchWriter: TPatchWriter;
begin
  { initialize }
  OldFile := nil;
  NewFile := nil;
  SortedOldData := nil;
  PatchWriter := TPatchWriterFactory.Instance(gFormat);
  try
    Logger.Log('loading old file');
    OldFile := TFileData.Create(OldFileName);
    Logger.Log('loading new file');
    NewFile := TFileData.Create(NewFileName);
    Logger.Log('block sorting old file');
    SortedOldData := BlockSort(OldFile.Data, OldFile.Size);
    if not Assigned(SortedOldData) then
      Error('virtual memory exhausted');
    Logger.Log('generating patch');
    PatchWriter.Header(OldFile.Name, NewFile.Name, OldFile.Size, NewFile.Size);
    { main loop }
    ToDo := NewFile.Size;
    NewOffset := 0;
    while (ToDo <> 0) do
    begin
      { invariant: nofs + todo = len2 }
      Match := FindMaxMatch(
        OldFile, SortedOldData, @NewFile.Data[NewOffset], ToDo
      );
      if Match.BlockLength <> 0 then
      begin
        { found a match }
        if Match.NewOffset <> 0 then
          { preceded by a "copy" block }
          PatchWriter.Add(@NewFile.Data[NewOffset], Match.NewOffset);
        Inc(NewOffset, Match.NewOffset);
        Dec(ToDo, Match.NewOffset);
        PatchWriter.Copy(
          NewFile.Data, NewOffset, Match.OldOffset, Match.BlockLength
        );
        Inc(NewOffset, Match.BlockLength);
        Dec(ToDo, Match.BlockLength);
      end
      else
      begin
        PatchWriter.Add(@NewFile.Data[NewOffset], ToDo);
        Break;
      end;
    end;
    Logger.Log('done');
  finally
    // finally section new to v1.1
    if Assigned(SortedOldData) then
      FreeMem(SortedOldData);
    OldFile.Free;
    NewFile.Free;
    PatchWriter.Free;
  end;
end;

{ Display help screen  }
procedure DisplayHelp;
begin
  TIO.WriteStrFmt(
    TIO.StdOut,
    '%0:s: binary ''diff'' - compare two binary files'#13#10#13#10
      + 'Usage: %0:s [options] old-file new-file [>patch-file]'#13#10#13#10
      + 'Difference between old-file and new-file written to standard output'
      + #13#10#13#10
      + 'Valid options:'#13#10
      + ' -q                   Use QUOTED format'#13#10
      + ' -f                   Use FILTERED format'#13#10
      + ' -b                   Use BINARY format'#13#10
      + '       --format=FMT   Use format FMT (''quoted'', ''filter[ed]'' '
      + 'or ''binary'')'#13#10
      + ' -m N  --min-equal=N  Minimum equal bytes to recognize an equal chunk'
      + #13#10
      + ' -o FN --output=FN    Set output file name (instead of stdout)'#13#10
      + ' -V    --verbose      Show status messages'#13#10
      + ' -h    --help         Show this help screen'#13#10
      + ' -v    --version      Show version information'#13#10
      + #13#10
      + '(c) copyright 1999 Stefan Reuther <Streu@gmx.de>'#13#10
      + '(c) copyright 2003-2009 Peter Johnson (www.delphidabbler.com)'#13#10,
    [ProgramFileName]
  );
end;

{ Display version }
procedure DisplayVersion;
begin
  // NOTE: original code displayed compile date using C's __DATE__ macro. Since
  // there is no Pascal equivalent of __DATE__ we display update date of program
  // file instead
  TIO.WriteStrFmt(
    TIO.StdOut,
    '%s-%s %s '#13#10,
    [ProgramBaseName, ProgramVersion, ProgramExeDate]
  );
end;

{ Main routine: parses arguments and creates diff using CreateDiff() }
procedure Main;
var
  PatchFileHandle: Integer;
  Params: TParams;
  Logger: TLogger;
begin
  ExitCode := 0;

  Params := TParams.Create;
  try
    try
      Params.Parse;

      if Params.Help then
      begin
        DisplayHelp;
        Exit;
      end;

      if Params.Version then
      begin
        DisplayVersion;
        Exit;
      end;

      gMinMatchLength := Params.MinEqual;
      gFormat := Params.Format;

      if (Params.PatchFileName <> '') and (Params.PatchFileName <> '-') then
      begin
        // redirect standard output to patch file
        PatchFileHandle := FileCreate(Params.PatchFileName);
        if PatchFileHandle <= 0 then
          OSError;
        TIO.RedirectStdOut(PatchFileHandle);
      end;

      // create the diff
      Logger := TLoggerFactory.Instance(Params.Verbose);
      try
        CreateDiff(Params.OldFileName, Params.NewFileName, Logger);
      finally
        Logger.Free;
      end;

    finally
      Params.Free;
    end;
  except
    on E: Exception do
    begin
      ExitCode := 1;
      TIO.WriteStrFmt(
        TIO.StdErr, '%0:s: %1:s'#13#10, [ProgramFileName, E.Message]
      );
    end;
  end;
end;

end.

