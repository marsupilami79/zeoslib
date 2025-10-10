{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{            Test Case for Connection Components          }
{                                                         }
{*********************************************************}

{@********************************************************}
{    Copyright (c) 1999-2006 Zeos Development Group       }
{                                                         }
{ License Agreement:                                      }
{                                                         }
{ This library is distributed in the hope that it will be }
{ useful, but WITHOUT ANY WARRANTY; without even the      }
{ implied warranty of MERCHANTABILITY or FITNESS FOR      }
{ A PARTICULAR PURPOSE.  See the GNU Lesser General       }
{ Public License for more details.                        }
{                                                         }
{ The source code of the ZEOS Libraries and packages are  }
{ distributed under the Library GNU General Public        }
{ License (see the file COPYING / COPYING.ZEOS)           }
{ with the following  modification:                       }
{ As a special exception, the copyright holders of this   }
{ library give you permission to link this library with   }
{ independent modules to produce an executable,           }
{ regardless of the license terms of these independent    }
{ modules, and to copy and distribute the resulting       }
{ executable under terms of your choice, provided that    }
{ you also meet, for each linked independent module,      }
{ the terms and conditions of the license of that module. }
{ An independent module is a module which is not derived  }
{ from or based on this library. If you modify this       }
{ library, you may extend this exception to your version  }
{ of the library, but you are not obligated to do so.     }
{ If you do not wish to do so, delete this exception      }
{ statement from your version.                            }
{                                                         }
{                                                         }
{ The project web site is located on:                     }
{   http://zeos.firmos.at  (FORUM)                        }
{   http://zeosbugs.firmos.at (BUGTRACKER)                }
{   svn://zeos.firmos.at/zeos/trunk (SVN Repository)      }
{                                                         }
{   http://www.sourceforge.net/projects/zeoslib.          }
{   http://www.zeoslib.sourceforge.net                    }
{                                                         }
{                                                         }
{                                                         }
{                                 Zeos Development Group. }
{********************************************************@}

unit ZTestConnection;

interface
{$I ZComponent.inc}

uses
  {$IFDEF FPC}testregistry{$ELSE}TestFramework{$ENDIF}, SysUtils, ZSqlTestCase,
  ZFormatSettings, ZTestCase;

type

  {** Implements a test case for class TZReadOnlyQuery. }
  TZTestConnectionCase = class(TZAbstractCompSQLTestCase)
  private
    gloUserName,gloPassword : string;
  protected
    procedure SetUp; override;
    procedure ConnLogin(Sender: TObject; var Username:string ; var Password: string);
  published
    procedure TestLibrary;
    procedure TestExecuteDirect;
    procedure TestExecuteDirect2;
    procedure TestLoginPromptConnection;
    procedure TestIdentifierQuotes;
    procedure TestTransactionBehavior;
   end;

  TZTestFormatSettings = class(TZAbstractTestCase)
  protected
    FormatSettings: TZFormatSettings;
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure Test_AMPM_WithFractions;
  end;

implementation

uses Classes, ZSysUtils, ZDbcIntfs, ZDbcProperties
  {$IFNDEF DISABLE_INTERBASE_AND_FIREBIRD}, ZDbcInterbaseFirebirdMetadata{$ENDIF};

{ TZTestExecSQLCase }

{**
  Prepares initial data before each test.
}
procedure TZTestConnectionCase.SetUp;
begin
  inherited SetUp;

  Connection.Connect;
end;

{**
  Runs a test for ExecuteDirect.
}
procedure TZTestConnectionCase.TestExecuteDirect;
var
  l_bool : boolean;
begin
  l_bool := Connection.ExecuteDirect('insert into department (dep_id,dep_name) Values (89,''Dept89'')');
  CheckEquals(true, l_bool);
  l_bool := Connection.ExecuteDirect('delete from department where dep_id = 89');
  CheckEquals(true, l_bool);
end;

{**
  Runs a test for ExecuteUpdateDirect.
}
procedure TZTestConnectionCase.TestExecuteDirect2;
var
  l_int  : integer;
  l_bool : boolean;
begin
  l_bool := Connection.ExecuteDirect('insert into department (dep_id,dep_name) Values (87,''Dept87'')',l_int);
  CheckEquals(true, l_bool);
  CheckEquals(1, l_int);
  l_bool := Connection.ExecuteDirect('insert into department (dep_id,dep_name) Values (88,''Dept88'')',l_int);
  CheckEquals(true, l_bool);
  CheckEquals(1, l_int);
  l_bool := Connection.ExecuteDirect('delete from department where dep_id between 87 and 88',l_int);
  CheckEquals(true, l_bool);
  CheckEquals(2, l_int);
  l_bool := Connection.ExecuteDirect('delete from department where dep_id between 87 and 88',l_int);
  CheckEquals(true, l_bool);
  CheckEquals(0, l_int);
end;

procedure TZTestConnectionCase.TestLoginPromptConnection;
var
  locUserName,locPassword : string;
  DataBaseStrings: TStrings;
  HostVersion: Integer;
begin
  DataBaseStrings := SplitString(Connection.DataBase, ';');
  Check(DataBaseStrings <> nil);
  //Connection.Properties.Values[ConnProps_Timeout] := '2'; that still doesn't work with Jenkins
  try
    if (Connection.Protocol = 'mssql') then begin
      Connection.Connect;
      Check(Connection.Connected);
      HostVersion := Connection.DbcConnection.GetHostVersion;
      if (HostVersion >= ZSysUtils.EncodeSQLVersioning(8,0,0)) and (HostVersion < ZSysUtils.EncodeSQLVersioning(9,0,0)) then
        Fail('Making this test fail to get everything else tested for SQL Server 2000. This test hangs forever with FreeTDS and SQL 2000.');
    end;
    locUserName := Connection.User;
    locPassword := Connection.Password;
    Connection.Disconnect;
    Connection.LoginPrompt := true;
  //  Connection.User := '';
  //  Connection.Password := '';
    gloUserName := 'x';
    gloPassword := 'y';
    Connection.OnLogin := ConnLogin;
    try
      Connection.Connect;
      if (Connection.DbcConnection.GetServerProvider <> spSQLite)
{$IF DEFINED(ENABLE_ODBC) OR DEFINED(ENABLE_OLEDB) OR DEFINED(ENABLE_ADO)}
        and not StrToBoolEx(DataBaseStrings.Values[ConnProps_TrustedConnection])
        and not StrToBoolEx(DataBaseStrings.Values[ConnProps_Trusted])
{$IFEND}
{$IF DEFINED(ENABLE_FIREBIRD) OR DEFINED(ENABLE_INTERBASE)}
        and not ((Connection.DbcConnection.GetServerProvider = spIB_FB) and //in case of embedded this test is not resolvable
          (Connection.DbcConnection.GetMetadata.GetDatabaseInfo as IZInterbaseDatabaseInfo).HostIsFireBird and
          (Connection.DbcConnection.GetHostVersion >= 3000000) and (Connection.HostName = ''))
{$IFEND}
      then
        Fail('We never expect to reach this place. It means we were allowed to login using invalid user credentials.');
    except
      CheckEquals(false,Connection.Connected);
    end;
    Connection.Disconnect;
    gloUserName := locUserName;
    gloPassword := locPassword;
    Connection.Connect;
    CheckEquals(true,Connection.Connected);
  finally
    FreeAndNil(DataBaseStrings);
  end;
end;

procedure TZTestConnectionCase.TestTransactionBehavior;
begin
  CheckEquals(Ord(tiNone), Ord(Connection.TransactIsolationLevel));
  if Protocol = 'ado' then
    Exit; //ado just starts a transaction if a query is fired #):
  Connection.Disconnect;
  Connection.AutoCommit := False;
  Connection.TransactIsolationLevel := tiSerializable;
  try
    Connection.StartTransaction; // behavior change of 7.3+ starttransaction can be called only if we are connected
    Fail('Inserted wrong StartTransaction behavior');
  except on E: Exception do
    CheckNotTestFailure(E);
  end;
  Connection.Connect;
  CheckEquals(2, Connection.StartTransaction, 'The txn-level');
  Connection.Disconnect;
  Connection.AutoCommit := True;
  Connection.Connect;
  CheckEquals(1, Connection.StartTransaction, 'The txn-level');
  CheckFalse(Connection.AutoCommit, 'AutoCommit should be disabled');
  CheckEquals(2, Connection.StartTransaction, 'The txn-level');
  Connection.Rollback;
  Connection.Rollback;
  try
    Connection.Rollback;
    Fail('Wrong Rollback behavior');
  except on E: Exception do
    CheckNotTestFailure(E);
  end;
  Check(Connection.AutoCommit, 'AutoCommit should be enabled');
  CheckEquals(1, Connection.StartTransaction, 'The txn-level');
  CheckFalse(Connection.AutoCommit, 'AutoCommit should be disabled');
  Connection.Commit;
  try
    Connection.Commit;
    Fail('Wrong Commit behavior');
  except on E: Exception do
    CheckNotTestFailure(E);
  end;
  Check(Connection.AutoCommit, 'AutoCommit should be enabled');
  (* CheckEquals(1, Connection.StartTransaction, 'The txn-level');
  try
    Connection.Disconnect;
    Fail('Wrong Disconnect behavior: transaction is active');
  except on E: Exception do
    CheckNotTestFailure(E);
  end; *)
  Connection.Disconnect;
end;

procedure TZTestConnectionCase.TestLibrary;
var CurrentLib: String;
begin
  if not (ProtocolType in [protODBC,protADO,protOleDB]) then
  begin
    Connection.Disconnect;
    CurrentLib := Connection.LibraryLocation;
    Connection.LibraryLocation:='dummy.dll';
    try
      Connection.Connect;
      Fail('Incorrect behavior dummy.dll does not exist');
    except on E: Exception do
      CheckNotTestFailure(E);
    end;
    Check(not Connection.Connected);
    Connection.LibraryLocation := CurrentLib;
    Connection.Connect;
    Check(Connection.Connected);
//   {$ifdef fpc}Fail{$else}Status{$endif}('Info: '+Connection.Protocol+
//          ' Driver version: '+ Connection.ClientVersionStr+
//          ' Server version: '+ Connection.ServerVersionStr);
  end
  else
    BlankCheck;
end;

{$IFDEF FPC} {$PUSH} {$WARN 5024 off : Parameter "Sender" not used} {$ENDIF}
procedure TZTestConnectionCase.ConnLogin(Sender: TObject; var Username:string ; var Password: string);
begin
   UserName := gloUserName;
   Password := gloPassword;
end;
{$IFDEF FPC} {$POP} {$ENDIF}

procedure TZTestConnectionCase.TestIdentifierQuotes;
begin
  try
    Connection.Connect;
    CheckNotEquals('', Connection.DbcConnection.GetMetadata.GetDatabaseInfo.GetIdentifierQuoteString);
    Connection.Disconnect;

    Connection.Properties.Add(ConnProps_IdentifierQuotes+'=');
    Connection.Connect;
    CheckEquals('', Connection.DbcConnection.GetMetadata.GetDatabaseInfo.GetIdentifierQuoteString);
    Connection.Disconnect;
    Connection.Properties.Delete(Connection.Properties.IndexOfName(ConnProps_IdentifierQuotes));

    Connection.Properties.Values[ConnProps_IdentifierQuotes] := '{}';
    Connection.Connect;
    CheckEquals('{}', Connection.DbcConnection.GetMetadata.GetDatabaseInfo.GetIdentifierQuoteString);
    Connection.Disconnect;
  finally
    Connection.Properties.Delete(Connection.Properties.IndexOfName(ConnProps_IdentifierQuotes));
  end;
end;

{ TZTestFormatSettings }

procedure TZTestFormatSettings.SetUp;
begin
  inherited;
  FormatSettings := TZFormatSettings.Create(nil);
end;

procedure TZTestFormatSettings.TearDown;
begin
  FreeAndNil(FormatSettings);
  inherited;

end;

procedure TZTestFormatSettings.Test_AMPM_WithFractions;
var Dest: String;
begin
  FormatSettings.DisplayTimeFormatSettings.Format := 'hh:mm:ss am/pm';
  FormatSettings.DisplayTimeFormatSettings.SecondFractionSeperator := ',';
  Dest := '';
  FormatSettings.DisplayTimeFormatSettings.TryTimeToString(Dest, 11, 12, 13, 123456789, 9, False);
  CheckEquals('11:12:13,123456789 am', Dest);
  FormatSettings.DisplayTimeFormatSettings.TryTimeToString(Dest, 23, 12, 13, 123456789, 9, False);
  CheckEquals('11:12:13,123456789 pm', Dest);
end;

initialization
  RegisterTest('component',TZTestConnectionCase.Suite);
  RegisterTest('component',TZTestFormatSettings.Suite);
end.
