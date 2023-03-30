{
 * Main project file for BPatch.exe.
}


program BPatch;


{$APPTYPE CONSOLE}


uses
  UPatcher in 'UPatcher.pas',
  UBPatchIO in 'UBPatchIO.pas',
  UAppInfo in '..\Common\UAppInfo.pas',
  UErrors in '..\Common\UErrors.pas',
  UBPatchParams in 'UBPatchParams.pas',
  UCommonIO in '..\Common\UCommonIO.pas',
  UBaseParams in '..\Common\UBaseParams.pas',
  UBPatchInfoWriter in 'UBPatchInfoWriter.pas',
  UInfoWriter in '..\Common\UInfoWriter.pas',
  UBPatchMain in 'UBPatchMain.pas',
  UCheckSum in '..\Common\UCheckSum.pas';

{$Resource VBPatch.res}     // version information
{$Resource BPatchAssets.res}      // other resources

begin
  TMain.Run;
end.

