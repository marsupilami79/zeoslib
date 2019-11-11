Unit uZMethodInThread;

Interface

Uses System.Classes;

Type
 TProcedureOfObject = Procedure Of Object;

 TZMethodInThread = Class(TThread)
 strict private
  _runmethod: TProcedureOfObject;
  _exceptionaddress: Pointer;
 protected
  Procedure Execute; Override;
 public
  Constructor Create(inMethod: TProcedureOfObject); ReIntroduce;
  Property ExceptionAddress: Pointer Read _exceptionaddress;
 End;

Implementation

Uses System.SysUtils;

Constructor TZMethodInThread.Create(inMethod: TProcedureOfObject);
Begin
 inherited Create(True);
 _runmethod := inMethod;
 _exceptionaddress := nil;
End;

Procedure TZMethodInThread.Execute;
Begin
 Try
  If Assigned(_runmethod) Then _runmethod;
 Except
  On E:Exception Do Begin
                    _exceptionaddress := ExceptAddr;
                    Raise;
                    End;
 End;
End;

End.
