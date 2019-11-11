program AbortTest;

uses
  Vcl.Forms,
  uAbortTestMainForm in 'uAbortTestMainForm.pas' {AbortTestMainForm},
  uZMethodInThread in 'uZMethodInThread.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TAbortTestMainForm, AbortTestMainForm);
  Application.Run;
end.
