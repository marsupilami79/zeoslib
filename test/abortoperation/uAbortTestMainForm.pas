Unit uAbortTestMainForm;

Interface

Uses Winapi.Windows, System.Classes, Vcl.Controls, Vcl.Forms, Data.DB, ZAbstractRODataset, ZAbstractDataset, ZDataset, Vcl.StdCtrls,
     ZAbstractConnection, ZConnection, Vcl.ExtCtrls;

Type
 TAbortTestMainForm = Class(TForm)
  SQLConnection: TZConnection;
  HostNameEdit: TEdit;
  UserNameEdit: TEdit;
  PasswordEdit: TEdit;
  DatabaseEdit: TEdit;
  ProtocolComboBox: TComboBox;
  HostNameLabel: TLabel;
  ProtocolLabel: TLabel;
  UserNameLabel: TLabel;
  PasswordLabel: TLabel;
  DatabaseLabel: TLabel;
  LogMemo: TMemo;
  TestButton: TButton;
  QueryEdit: TEdit;
  QueryLabel: TLabel;
  SQLQuery: TZQuery;
  Procedure FormCreate(Sender: TObject);
  Procedure FormClose(Sender: TObject; Var Action: TCloseAction);
  Procedure TestButtonClick(Sender: TObject);
 strict private
  _logcs: TRTLCriticalSection;
  _cancelsleep: Int64;
  _abortresult: Boolean;
  Procedure CallCancel;
  Procedure Log(inLineToLog: String);
  Procedure ResetComponents;
  Procedure SyncCancel;
 End;

Var
  AbortTestMainForm: TAbortTestMainForm;

Implementation

{$R *.dfm}

Uses uZMethodInThread, System.Diagnostics, System.SysUtils;

Procedure TAbortTestMainForm.CallCancel;
Begin
 Try
  Sleep(_cancelsleep);
  TThread.Synchronize(nil, SyncCancel);
  If _abortresult Then Log('Abort request was sent successfully')
    Else Log('Abort request could not be sent!');
 Except
  On E:Exception Do Log(E.ClassName + ' was raised while sending the abort request with the message: ' + E.Message);
 End;
End;

Procedure TAbortTestMainForm.FormClose(Sender: TObject; Var Action: TCloseAction);
Begin
 DeleteCriticalSection(_logcs);
End;

Procedure TAbortTestMainForm.FormCreate(Sender: TObject);
Begin
 ReportMemoryLeaksOnShutdown := True;
 InitializeCriticalSection(_logcs);
 SQLConnection.GetProtocolNames(ProtocolComboBox.Items);
 If ProtocolcomboBox.Items.Count > 0 Then ProtocolComboBox.ItemIndex := 0;
 ResetComponents;
End;

Procedure TAbortTestMainForm.Log(inLineToLog: String);
Begin
 EnterCriticalSection(_logcs);
 Try
  LogMemo.Lines.BeginUpdate;
  Try
   LogMemo.Lines.Add('[' + FormatDateTime('hh:nn:ss.zzz', Now) + '] ' + inLineToLog);
  Finally
   LogMemo.Lines.EndUpdate;
  End;
 Finally
  LeaveCriticalSection(_logcs);
 End;
End;

Procedure TAbortTestMainForm.ResetComponents;
Begin
 SQLQuery.Active := False;
 SQLQuery.SQL.Text := '';
 SQLConnection.Disconnect;
 SQLConnection.Protocol := '';
 SQLConnection.HostName := '';
 SQLConnection.User := '';
 SQLConnection.Password := '';
 SQLConnection.Database := '';
 Log('Components are reset.');
End;

Procedure TAbortTestMainForm.SyncCancel;
Begin
 _abortresult := SQLConnection.AbortOperation;
End;

Procedure TAbortTestMainForm.TestButtonClick(Sender: TObject);
Const
 RUNS = 5;
Var
 s: String;
 method: TProcedureOfObject;
 sw: TStopWatch;
 a: Integer;
 timetaken: Int64;
 methodrunning: Boolean;
 cancel, query: TZMethodInThread;
Begin
 Log('------------------------------------------');
 methodrunning := False;
 _abortresult := False;
 cancel := TZMethodInThread.Create(CallCancel);
 s := String(QueryEdit.Text).Trim;
 SQLQuery.SQL.Text := s;
 If s.Substring(0, s.IndexOf(' ')).ToLower = 'SELECT' Then method := SQLQuery.Open
   Else method := SQLQuery.ExecSQL;
 query := TZMethodInThread.Create(method);
 Try
  Try
   SQLConnection.Protocol := ProtocolComboBox.Text;
   SQLConnection.HostName := HostNameEdit.Text;
   SQLConnection.User := UserNameEdit.Text;
   SQLConnection.Password := PasswordEdit.Text;
   SQLConnection.Database := DatabaseEdit.Text;
   Log('Connecting to database...');
   SQLConnection.Connect;
   timetaken := 0;
   For a := 1 To RUNS Do
    Begin
     Log('Starting query run #' + a.ToString + ' / ' + RUNS.ToString + '...');
     sw := TStopWatch.StartNew;
     method;
     sw.Stop;
     timetaken := timetaken + sw.ElapsedMilliseconds;
     Log('Query finished in ' + sw.ElapsedMilliseconds.ToString + ' ms');
     SQLQuery.Close;
    End;
   timetaken := timetaken Div RUNS;
   Log('Average query runtime was ' + timetaken.ToString + ' ms. Starting AbortOperation test...');
   _cancelsleep := timetaken Div 4;
   cancel.Start;
   methodrunning := True;
   sw := TStopWatch.StartNew;
   query.Start;
   query.WaitFor;
   If query.FatalException <> nil Then Raise ExceptClass(query.FatalException.ClassType).Create(Exception(query.FatalException).Message) At query.ExceptionAddress
     Else Raise Exception.Create('Query finished, program flow returned');
  Except
   On E:Exception Do If Not methodrunning Then Log(E.ClassName + ' was raised with the message ' + E.Message)
                       Else Begin
                            sw.Stop;
                            Log(E.ClassName + ' was raised while running background query with the message ' + E.Message);
                            Log('Runtime was ' + sw.ElapsedMilliseconds.ToString + ' ms');
                            If sw.ElapsedMilliseconds <= (8 * timetaken Div 10) Then Log('Test passed')
                              Else Log('Test failed!');
                            End;
  End;
 Finally
  ResetComponents;
  FreeAndNil(cancel);
  FreeAndNil(query);
 End;
End;

End.
