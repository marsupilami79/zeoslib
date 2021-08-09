{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{            Test Case for Query Components               }
{                                                         }
{          Originally written by Sergey Seroukhov         }
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

unit ZTestStoredProcedure;

interface
{$I ZComponent.inc}

uses
  {$IFDEF FPC}testregistry{$ELSE}TestFramework{$ENDIF}, Db, SysUtils,
  ZGenericSqlToken, ZSqlTestCase, ZStoredProcedure;

type
  {** Implements a generic test case for class TZStoredProc. }
  TZTestStoredProcedure = class(TZAbstractCompSQLTestCase)
  private
    StoredProc: TZStoredProc;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  end;

  {** Implements a test case for class TZStoredProc. }
  TZTestInterbaseStoredProcedure = class(TZTestStoredProcedure)
  protected
//    function GetSupportedProtocols: string; override;
    function SupportsConfig(Config: TZConnectionConfig): Boolean; override;
  published
    procedure TestStoredProc;
    procedure Test_abtest;
    procedure Test_abtest_bigint;
  end;


  {** Implements a test case for class TZStoredProc. }
  TZTestDbLibStoredProcedure = class(TZTestStoredProcedure)
  protected
    function GetSupportedProtocols: string; override;
  published
    procedure TestStoredProc;
  end;

  {** Impleme nts a test case for class TZStoredProc. }
  TZTestPostgreSQLStoredProcedure = class(TZTestStoredProcedure)
  protected
    function GetSupportedProtocols: string; override;
  published
    procedure Test_abtest;
    procedure Test_nonames;
    procedure Test_onename;
    procedure Test_noout;
    procedure Test_composite;
    procedure Test_mixedorder;
    procedure Test_set;
    procedure Test_proc_abtest;
  end;

  {** Implements a test case for class TZStoredProc. }
  TZTestMySQLStoredProcedure = class(TZTestStoredProcedure)
  protected
    function GetSupportedProtocols: string; override;
  published
    procedure Test_abtest;
    procedure Test_TEST_All_TYPES;
    procedure Test_FuncReturnInteger;
    procedure Test_ALL_PARAMS_IN;
    procedure MultipleVaryingResultSets;
  end;


  {** Implements a test case for class TZStoredProc. }
  TZTestADOStoredProcedure = class(TZTestStoredProcedure)
  protected
    function GetSupportedProtocols: string; override;
  published
    procedure ADO_Test_abtest;
    procedure ADO_Test_procedure1;
  end;

  {** Implements a test case for class TZStoredProc. }

  { TZTestOracleStoredProcedure }

  TZTestOracleStoredProcedure = class(TZTestStoredProcedure)
  protected
    function GetSupportedProtocols: string; override;
    procedure abtest(prefix:string ='');
    procedure myfuncInOutReturn(prefix:string ='');
    procedure simple_func(prefix:string ='');
    procedure simplefunc(prefix:string ='');
    procedure MYPACKAGE(prefix:string ='');
  published
    procedure ORA_Test_abtest;
    procedure ORA_Test_myfuncInOutReturn;
    procedure ORA_Test_simple_func;
    procedure ORA_Test_simplefunc;
    procedure ORA_Test_packaged;
    procedure ORA_Test_Owner_packaged;
    procedure ORA_Test_MYPACKAGE;
    procedure ORA_Test_Owner_MYPACKAGE;
    procedure ORA_Test_IS_ACCOUNT_SERVE;
  end;

implementation

uses Classes, ZSysUtils, ZDbcIntfs, ZDbcPostgreSQL, ZDatasetUtils,
  ZCompatibility, ZVariant, ZEncoding, Variants;


{ TZTestStoredProcedure }

{**
  Prepares initial data before each test.
}
procedure TZTestStoredProcedure.SetUp;
begin
  inherited SetUp;
  StoredProc := TZStoredProc.Create(Connection);
  StoredProc.Connection := Connection;
  StoredProc.ParamCheck := True;
end;

{**
  Removes data after each test.
}
procedure TZTestStoredProcedure.TearDown;
begin
  StoredProc.Close;
  StoredProc.Free;
  inherited TearDown;
end;

{**
  Gets an array of protocols valid for this test.
  @return an array of valid protocols
}
//function TZTestInterbaseStoredProcedure.GetSupportedProtocols: string;
//begin
//  Result := pl_all_interbase;
//end;

function TZTestInterbaseStoredProcedure.SupportsConfig(Config: TZConnectionConfig): Boolean;
begin
  Result := Config.Provider = spIB_FB;
end;

{**
  Gets a connection URL string.
  @return a built connection URL string.
}
{**
   Testing executil stored procedures
}
procedure TZTestInterbaseStoredProcedure.TestStoredProc;
begin
  StoredProc.StoredProcName := 'PROCEDURE1';

  CheckEquals(2, StoredProc.Params.Count);
  CheckEquals('P1', StoredProc.Params[0].Name);
  CheckEquals(ptInput, StoredProc.Params[0].ParamType);
  CheckEquals('R1', StoredProc.Params[1].Name);
  CheckEquals(ptOutput, StoredProc.Params[1].ParamType);
  StoredProc.ParamByName('P1').AsInteger := 12345;
  StoredProc.ExecProc;
  CheckEquals(12346, StoredProc.ParamByName('R1').AsInteger);
  CheckEquals(2, StoredProc.Params.Count);
end;

{**
   Testing executil stored procedures
}
procedure TZTestInterbaseStoredProcedure.Test_abtest;
var
  i, P2: integer;
  S: String;
begin
  StoredProc.StoredProcName := 'ABTEST';
  CheckEquals(5, StoredProc.Params.Count);
  CheckEquals('P1', StoredProc.Params[0].Name);
  CheckEquals(ptInput, StoredProc.Params[0].ParamType);
  CheckEquals('P2', StoredProc.Params[1].Name);
  CheckEquals(ptInput, StoredProc.Params[1].ParamType);
  CheckEquals('P3', StoredProc.Params[2].Name);
  CheckEquals(ptInput, StoredProc.Params[2].ParamType);
  CheckEquals('P4', StoredProc.Params[3].Name);
  CheckEquals(ptOutput, StoredProc.Params[3].ParamType);
  CheckEquals('P5', StoredProc.Params[4].Name);
  CheckEquals(ptOutput, StoredProc.Params[4].ParamType);

  StoredProc.ParamByName('P1').AsInteger := 50;
  StoredProc.ParamByName('P2').AsInteger := 100;
  StoredProc.ParamByName('P3').AsString := 'a';
  StoredProc.ExecProc;
  CheckEquals(600, StoredProc.ParamByName('P4').AsInteger);
  CheckEquals('aa', StoredProc.ParamByName('P5').AsString);
  CheckEquals(5, StoredProc.Params.Count);

  StoredProc.Prepare;
  S := 'a';
  P2 := 100;
  for i:= 1 to 9 do
  begin
    StoredProc.Params[0].AsInteger:= i;
    StoredProc.Params[1].AsInteger:= P2;
    StoredProc.Params[2].AsString:= S;
    StoredProc.ExecProc;
    CheckEquals(S+S, StoredProc.ParamByName('P5').AsString);
    Check(VarIsStr(StoredProc.ParamByName('P5').Value));
    CheckEquals(I*10+P2, StoredProc.ParamByName('P4').AsInteger);
    S := S+'a';
    P2 := 100 - I;
  end;
  StoredProc.Params[0].AsInteger:= 50;
  StoredProc.Params[2].AsString:= 'a';
  for i:= 1 to 9 do begin
    StoredProc.Close;
    StoredProc.Params[1].Value :=  i;
    StoredProc.Open;
    while not StoredProc.Eof do
      StoredProc.Next;
  end;
  StoredProc.Unprepare;
  StoredProc.Open;
  StoredProc.ParamByName('P1').AsInteger := 50;
  StoredProc.ParamByName('P2').AsInteger := 100;
  StoredProc.ParamByName('P3').AsString := 'a';
  StoredProc.Open;
end;

procedure TZTestInterbaseStoredProcedure.Test_abtest_bigint;
var
  i: integer;
begin
  StoredProc.StoredProcName := 'ABTEST_BIGINT';
  StoredProc.Params[0].AsInteger:= 50;
  StoredProc.Params[2].AsString:= 'a';
  for i:= 1 to 9 do begin
    StoredProc.Close;
    StoredProc.Params[1].Value :=  i;
    StoredProc.Open;
    while not StoredProc.Eof do
      StoredProc.Next;
  end;
end;

{ TZTestDbLibStoredProcedure }

{**
  Gets an array of protocols valid for this test.
  @return an array of valid protocols
}
function TZTestDbLibStoredProcedure.GetSupportedProtocols: string;
begin
  Result := 'sybase, mssql,OleDB';
end;

{**
   Testing executil stored procedures
}
procedure TZTestDbLibStoredProcedure.TestStoredProc;
begin
  StoredProc.StoredProcName := 'procedure1';

  CheckEquals(3, StoredProc.Params.Count);
  CheckEquals('@RETURN_VALUE', StoredProc.Params[0].Name);
  CheckEquals('@p1', StoredProc.Params[1].Name);
  CheckEquals(ptInput, StoredProc.Params[1].ParamType);
  CheckEquals('@r1', StoredProc.Params[2].Name);
  CheckEquals(ptResult, StoredProc.Params[0].ParamType);

  StoredProc.Params[1].AsInteger := 12345;
  StoredProc.ExecProc;
  CheckEquals(12346, StoredProc.Params[2].AsInteger);
  CheckEquals(3, StoredProc.Params.Count);
end;

{ TZTestPosgreSQLStoredProcedure }

{**
  Prepares initial data before each test.
}
function TZTestPostgreSQLStoredProcedure.GetSupportedProtocols: string;
begin
  Result := pl_all_postgresql;
end;

{**
   Testing executil stored procedures
}
procedure TZTestPostgreSQLStoredProcedure.Test_abtest;
var
  i: integer;
begin
  StoredProc.StoredProcName := '"ABTEST"';
  CheckEquals(5, StoredProc.Params.Count);
  CheckEquals('p1', StoredProc.Params[0].Name);
  CheckEquals(ptInput, StoredProc.Params[0].ParamType);
  CheckEquals('p2', StoredProc.Params[1].Name);
  CheckEquals(ptInput, StoredProc.Params[1].ParamType);
  CheckEquals('p3', StoredProc.Params[2].Name);
  CheckEquals(ptInput, StoredProc.Params[2].ParamType);
  CheckEquals('p4', StoredProc.Params[3].Name);
  CheckEquals(ptOutput,StoredProc.Params[3].ParamType);
  CheckEquals('p5', StoredProc.Params[4].Name);
  CheckEquals(ptOutput,StoredProc.Params[4].ParamType);

  StoredProc.ParamByName('p1').AsInteger := 50;
  StoredProc.ParamByName('p2').AsInteger := 100;
  StoredProc.ParamByName('p3').AsString := 'a';
  StoredProc.ExecProc;
  CheckEquals(600, StoredProc.ParamByName('p4').AsInteger);
  CheckEquals('aa', StoredProc.ParamByName('p5').AsString);
  CheckEquals(5, StoredProc.Params.Count);

  StoredProc.Prepare;
  for i:= 0 to 9 do
  begin
    StoredProc.Params[0].AsInteger:= i;
    StoredProc.Params[1].AsInteger:= 100;
    StoredProc.Params[2].AsString:= 'a';
    StoredProc.ExecProc;
  end;
  StoredProc.Unprepare;
  StoredProc.Open;
  StoredProc.ParamByName('p1').AsInteger := 50;
  StoredProc.ParamByName('p2').AsInteger := 100;
  StoredProc.ParamByName('p3').AsString := 'a';
  StoredProc.Open;
end;

procedure TZTestPostgreSQLStoredProcedure.Test_composite;
begin
  StoredProc.StoredProcName := 'proc_composite';
  CheckEquals(4, StoredProc.Params.Count);
  CheckEquals('p1', StoredProc.Params[0].Name);
  CheckEquals(ptInput,StoredProc.Params[0].ParamType);
  CheckEquals('p2', StoredProc.Params[1].Name);
  CheckEquals(ptInput,StoredProc.Params[1].ParamType);
  CheckEquals('f1', StoredProc.Params[2].Name);
  CheckEquals(ptResult,StoredProc.Params[2].ParamType);
  CheckEquals('f2', StoredProc.Params[3].Name);
  CheckEquals(ptResult,StoredProc.Params[3].ParamType);

  StoredProc.ParamByName('p1').AsInteger := 50;
  StoredProc.ParamByName('p2').AsInteger := 100;
  StoredProc.ExecProc;
  CheckEquals(50, StoredProc.ParamByName('f1').AsInteger);
  CheckEquals(100, StoredProc.ParamByName('f2').AsInteger);
 // StoredProc.Unprepare;

  StoredProc.ParamByName('p1').AsInteger := 20;
  StoredProc.ParamByName('p2').AsInteger := 30;
  StoredProc.Open;
  CheckEquals(20, StoredProc.ParamByName('f1').AsInteger);
  CheckEquals(30, StoredProc.ParamByName('f2').AsInteger);
  CheckEquals(2, StoredProc.FieldCount);
  CheckEquals(20, StoredProc.Fields[0].AsInteger);
  CheckEquals(30, StoredProc.Fields[1].AsInteger);
end;

procedure TZTestPostgreSQLStoredProcedure.Test_mixedorder;
begin
  StoredProc.StoredProcName := 'proc_mixedorder';
  CheckEquals(3, StoredProc.Params.Count);
  CheckEquals('p1', StoredProc.Params[0].Name);
  CheckEquals(ptOutput,StoredProc.Params[0].ParamType);
  CheckEquals('p2', StoredProc.Params[1].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[1].ParamType);
  CheckEquals('p3', StoredProc.Params[2].Name);
  CheckEquals(ptInput,StoredProc.Params[2].ParamType);

  StoredProc.ParamByName('p2').AsInteger := 50;
  StoredProc.ParamByName('p3').AsInteger := 100;
  StoredProc.ExecProc;
  CheckEquals(150, StoredProc.ParamByName('p1').AsInteger);
  CheckEquals(5000, StoredProc.ParamByName('p2').AsInteger);
  //StoredProc.Unprepare;

  StoredProc.ParamByName('p2').AsInteger := 20;
  StoredProc.ParamByName('p3').AsInteger := 30;
  StoredProc.Open;
  CheckEquals(50, StoredProc.ParamByName('p1').AsInteger);
  CheckEquals(600, StoredProc.ParamByName('p2').AsInteger);
  CheckEquals(2, StoredProc.FieldCount);
  CheckEquals(50, StoredProc.Fields[0].AsInteger);
  CheckEquals(600, StoredProc.Fields[1].AsInteger);
end;

procedure TZTestPostgreSQLStoredProcedure.Test_nonames;
begin
  StoredProc.StoredProcName := 'proc_nonames';
  CheckEquals(3, StoredProc.Params.Count);
  CheckEquals('$1', StoredProc.Params[0].Name);
  CheckEquals(ptInput,StoredProc.Params[0].ParamType);
  CheckEquals('$2', StoredProc.Params[1].Name);
  CheckEquals(ptInput,StoredProc.Params[1].ParamType);
  CheckEquals('$3', StoredProc.Params[2].Name);
  CheckEquals(ptOutput,StoredProc.Params[2].ParamType);

  StoredProc.ParamByName('$1').AsInteger := 50;
  StoredProc.ParamByName('$2').AsInteger := 100;
  StoredProc.ExecProc;
  CheckEquals(150, StoredProc.ParamByName('$3').AsInteger);
 // StoredProc.Unprepare;

  StoredProc.ParamByName('$1').AsInteger := 20;
  StoredProc.ParamByName('$2').AsInteger := 30;
  StoredProc.Open;
  CheckEquals(50, StoredProc.ParamByName('$3').AsInteger);
  CheckEquals(1, StoredProc.FieldCount);
  CheckEquals(50, StoredProc.Fields[0].AsInteger);
end;

procedure TZTestPostgreSQLStoredProcedure.Test_noout;
begin
  StoredProc.StoredProcName := 'proc_noout';
  CheckEquals(3, StoredProc.Params.Count);
  CheckEquals('p1', StoredProc.Params[0].Name);
  CheckEquals(ptInput,StoredProc.Params[0].ParamType);
  CheckEquals('', StoredProc.Params[1].Name);
  CheckEquals(ptInput,StoredProc.Params[1].ParamType);
  CheckEquals('returnValue', StoredProc.Params[2].Name);
  CheckEquals(ptResult,StoredProc.Params[2].ParamType);

  StoredProc.ParamByName('p1').AsInteger := 50;
  StoredProc.Params[1].AsInteger := 100;
  StoredProc.ExecProc;
  CheckEquals(150, StoredProc.Params[2].AsInteger);
 // StoredProc.Unprepare;

  StoredProc.ParamByName('p1').AsInteger := 20;
  StoredProc.Params[1].AsInteger := 30;
  StoredProc.Open;
  CheckEquals(50, StoredProc.Params[2].AsInteger);
  CheckEquals(1, StoredProc.FieldCount);
  CheckEquals(50, StoredProc.Fields[0].AsInteger);
end;

procedure TZTestPostgreSQLStoredProcedure.Test_onename;
begin
  StoredProc.StoredProcName := 'proc_onename';
  CheckEquals(3, StoredProc.Params.Count);
  CheckEquals('p1', StoredProc.Params[0].Name);
  CheckEquals(ptInput,StoredProc.Params[0].ParamType);
  CheckEquals('', StoredProc.Params[1].Name);
  CheckEquals(ptInput,StoredProc.Params[1].ParamType);
  CheckEquals('', StoredProc.Params[2].Name);
  CheckEquals(ptOutput,StoredProc.Params[2].ParamType);

  StoredProc.ParamByName('p1').AsInteger := 50;
  StoredProc.Params[1].AsInteger := 100;
  StoredProc.ExecProc;
  CheckEquals(150, StoredProc.Params[2].AsInteger);
 // StoredProc.Unprepare;

  StoredProc.ParamByName('p1').AsInteger := 20;
  StoredProc.Params[1].AsInteger := 30;
  StoredProc.Open;
  CheckEquals(50, StoredProc.Params[2].AsInteger);
  CheckEquals(1, StoredProc.FieldCount);
  CheckEquals(50, StoredProc.Fields[0].AsInteger);
end;

procedure TZTestPostgreSQLStoredProcedure.Test_proc_abtest;
var I: Integer;
begin
  Connection.Connect;
  Check(Connection.Connected);
  if (Connection.DbcConnection as IZPostgreSQLConnection).GetServerMajorVersion < 11 then
    Exit;
  StoredProc.StoredProcName := '"PROC_ABTEST"';
  CheckEquals(5, StoredProc.Params.Count);
  CheckEquals('p1', StoredProc.Params[0].Name);
  CheckEquals(ptInput,StoredProc.Params[0].ParamType);
  CheckEquals('p2', StoredProc.Params[1].Name);
  CheckEquals(ptInput,StoredProc.Params[1].ParamType);
  CheckEquals('p3', StoredProc.Params[2].Name);
  CheckEquals(ptInput,StoredProc.Params[2].ParamType);
  CheckEquals('p4', StoredProc.Params[3].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[3].ParamType);
  CheckEquals('p5', StoredProc.Params[4].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[4].ParamType);

  StoredProc.ParamByName('p1').AsInteger := 50;
  StoredProc.ParamByName('p2').AsInteger := 100;
  StoredProc.ParamByName('p3').AsString := 'a';
  StoredProc.ExecProc;
  CheckEquals(600, StoredProc.ParamByName('p4').AsInteger);
  CheckEquals('aa', StoredProc.ParamByName('p5').AsString);
  CheckEquals(5, StoredProc.Params.Count);

  StoredProc.Prepare;
  for i:= 0 to 9 do
  begin
    StoredProc.Params[0].AsInteger:= i;
    StoredProc.Params[1].AsInteger:= 100;
    StoredProc.Params[2].AsString:= 'a';
    StoredProc.ExecProc;
  end;
  StoredProc.Unprepare;
  StoredProc.Open;
  StoredProc.ParamByName('p1').AsInteger := 50;
  StoredProc.ParamByName('p2').AsInteger := 100;
  StoredProc.ParamByName('p3').AsString := 'a';
  StoredProc.Open;
end;

procedure TZTestPostgreSQLStoredProcedure.Test_set;
begin
  StoredProc.StoredProcName := 'proc_set';
  CheckEquals(1, StoredProc.Params.Count);
  CheckEquals('returnValue', StoredProc.Params[0].Name);
  CheckEquals(ptResult,StoredProc.Params[0].ParamType);

  StoredProc.ExecProc;
  CheckEquals('Volvo', StoredProc.ParamByName('returnValue').AsString);
  //StoredProc.Unprepare;

  StoredProc.Open;
  CheckEquals('Volvo', StoredProc.ParamByName('returnValue').AsString);
  CheckEquals(1, StoredProc.FieldCount);
  CheckEquals('Volvo', StoredProc.Fields[0].AsString);
  StoredProc.Next;
  CheckEquals('Laboratoy', StoredProc.Fields[0].AsString);
end;

{ TZTestMySQLStoredProcedure }
function TZTestMySQLStoredProcedure.GetSupportedProtocols: string;
begin
  Result := pl_all_mysql;
end;

procedure TZTestMySQLStoredProcedure.Test_abtest;
var
  i, P2: integer;
  S: String;
begin
  StoredProc.StoredProcName := 'ABTEST';
  CheckEquals(5, StoredProc.Params.Count);
  CheckEquals('P1', StoredProc.Params[0].Name);
  CheckEquals(ptInput, StoredProc.Params[0].ParamType);
  CheckEquals(ftInteger, StoredProc.Params[0].DataType);
  CheckEquals('P2', StoredProc.Params[1].Name);
  CheckEquals(ptInput, StoredProc.Params[1].ParamType);
  CheckEquals(ftInteger, StoredProc.Params[1].DataType);
  CheckEquals('P3', StoredProc.Params[2].Name);
  CheckEquals(ptInput, StoredProc.Params[2].ParamType);
  CheckStringParamType(StoredProc.Params[2], Connection.ControlsCodePage);
  CheckEquals('P4', StoredProc.Params[3].Name);
  CheckEquals(ptOutput, StoredProc.Params[3].ParamType);
  CheckEquals(ftInteger, StoredProc.Params[3].DataType);
  CheckEquals('P5', StoredProc.Params[4].Name);
  CheckEquals(ptOutput, StoredProc.Params[4].ParamType);
  CheckStringParamType(StoredProc.Params[4], Connection.ControlsCodePage);

  StoredProc.ParamByName('P1').AsInteger := 50;
  StoredProc.ParamByName('P2').AsInteger := 100;
  StoredProc.ParamByName('P3').AsString := 'a';
  StoredProc.ExecProc;
  CheckEquals(600, StoredProc.ParamByName('P4').AsInteger);
  CheckEquals('aa', StoredProc.ParamByName('P5').AsString);
  CheckEquals(5, StoredProc.Params.Count);

  CheckEquals(ftInteger, StoredProc.Params[0].DataType);
  CheckEquals(ftInteger, StoredProc.Params[1].DataType);
  {$IFNDEF DISABLE_ZPARAM}
  CheckStringParamType(StoredProc.Params[2], Connection.ControlsCodePage);
  {$ELSE}
    {$IFDEF DELPHI14_UP}
  CheckEquals(ftWideString,StoredProc.Params[2].DataType);
    {$ELSE}
  CheckEquals(ftString,StoredProc.Params[2].DataType);
    {$ENDIF}
  {$ENDIF}
  CheckEquals(ftInteger,StoredProc.Params[3].DataType);
  CheckStringParamType(StoredProc.Params[4], Connection.ControlsCodePage);

  S := 'a';
  P2 := 100;
  for i:= 1 to 9 do
  begin
    StoredProc.Params[0].AsInteger:= i;
    StoredProc.Params[1].AsInteger:= P2;
    StoredProc.Params[2].AsString:= S;
    StoredProc.ExecProc;
    CheckEquals(S+S, StoredProc.ParamByName('P5').AsString);
    CheckEquals(I*10+P2, StoredProc.ParamByName('P4').AsInteger);
    S := S+'a';
    P2 := 100 - I;
  end;

  S := StoredProc.ParamByName('P4').AsString +
    ' ' + StoredProc.ParamByName('P5').AsString;
  StoredProc.ParamByName('P1').AsInteger := 50;
  StoredProc.ParamByName('P2').AsInteger := 100;
  StoredProc.ParamByName('P3').AsString := 'a';
  CheckEquals('P4', StoredProc.Params[3].Name);
  CheckEquals('P5', StoredProc.Params[4].Name);
  StoredProc.Open;

  CheckEquals(2, StoredProc.Fields.Count);
  CheckEquals(ftInteger,StoredProc.Fields[0].DataType);
  CheckStringFieldType(StoredProc.Fields[1], Connection.ControlsCodePage);

  CheckStringParamType(StoredProc.Params[4], Connection.ControlsCodePage);
end;

procedure TZTestMySQLStoredProcedure.Test_TEST_All_TYPES;
const Str1: {$IFNDEF UNICIDE}WideString{$ELSE}UnicodeString{$ENDIF} = #$0410#$0431#$0440#$0430#$043a#$0430#$0434#$0430#$0431#$0440#$0430; // Abrakadabra in Cyrillic letters
var
  SQLTime: TDateTime;
  TempBytes: TBytes;
  CP: Word;
  ConSettings: PZConSettings;
begin
  Connection.Connect;
  Check(Connection.Connected);
  ConSettings := connection.DbcConnection.GetConSettings;
  CP := ConSettings.ClientCodePage.CP;
  //eh the russion abrakadabra can no be mapped to other charsets then:
  if (Connection.ControlsCodePage = cGET_ACP) and {no unicode strings or utf8 allowed}
    not ((ZOSCodePage = zCP_UTF8) or (ZOSCodePage = zCP_WIN1251) or (ZOSCodePage = zcp_DOS855) or (ZOSCodePage = zCP_KOI8R)) then
    Exit;
  if not ((CP = zCP_UTF8) or (CP = zCP_WIN1251) or (CP = zcp_DOS855) or (CP = zCP_KOI8R))
    {add some more if you run into same issue !!} then
    Exit;
  StoredProc.StoredProcName := 'TEST_All_TYPES';
  CheckEquals(28, StoredProc.Params.Count);

  CheckEquals('P1', StoredProc.Params[0].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[0].ParamType);
  CheckEquals({$IFDEF WITH_FTSHORTINT}ftShortInt{$ELSE}ftSmallInt{$ENDIF},StoredProc.Params[0].DataType);

  CheckEquals('P2', StoredProc.Params[1].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[1].ParamType);
  CheckEquals({$IFDEF WITH_FTSHORTINT}ftShortInt{$ELSE}ftSmallInt{$ENDIF},StoredProc.Params[1].DataType);

  CheckEquals('P3', StoredProc.Params[2].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[2].ParamType);
  CheckEquals(ftSmallInt,StoredProc.Params[2].DataType);

  CheckEquals('P4', StoredProc.Params[3].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[3].ParamType);
  CheckEquals(ftInteger,StoredProc.Params[3].DataType);

  CheckEquals('P5', StoredProc.Params[4].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[4].ParamType);
  CheckEquals(ftInteger,StoredProc.Params[4].DataType);

  CheckEquals('P6', StoredProc.Params[5].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[5].ParamType);
  CheckEquals(ftLargeInt,StoredProc.Params[5].DataType);

  CheckEquals('P7', StoredProc.Params[6].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[6].ParamType);
  CheckEquals(ftFloat,StoredProc.Params[6].DataType);

  CheckEquals('P8', StoredProc.Params[7].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[7].ParamType);
  CheckEquals(ftFloat,StoredProc.Params[7].DataType);

  CheckEquals('P9', StoredProc.Params[8].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[8].ParamType);
  CheckEquals(ftFmtBCD,StoredProc.Params[8].DataType);

  CheckEquals('P10', StoredProc.Params[9].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[9].ParamType);
  CheckEquals(ftLargeInt,StoredProc.Params[9].DataType);

  CheckEquals('P11', StoredProc.Params[10].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[10].ParamType);
  CheckStringParamType(StoredProc.Params[10], Connection.ControlsCodePage);

  CheckEquals('P12', StoredProc.Params[11].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[11].ParamType);
  CheckEquals(ftDate,StoredProc.Params[11].DataType);

  CheckEquals('P13', StoredProc.Params[12].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[12].ParamType);
  CheckEquals(ftTime,StoredProc.Params[12].DataType);

  CheckEquals('P14', StoredProc.Params[13].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[13].ParamType);
  CheckEquals(ftWord,StoredProc.Params[13].DataType);

  CheckEquals('P15', StoredProc.Params[14].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[14].ParamType);
  CheckEquals(ftDateTime,StoredProc.Params[14].DataType);

  CheckEquals('P16', StoredProc.Params[15].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[15].ParamType);
  CheckEquals(ftDateTime,StoredProc.Params[15].DataType);

  CheckEquals('P17', StoredProc.Params[16].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[16].ParamType);
  CheckEquals(ftVarBytes,StoredProc.Params[16].DataType);

  CheckEquals('P18', StoredProc.Params[17].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[17].ParamType);
  CheckEquals(ftBlob,StoredProc.Params[17].DataType);

  CheckEquals('P19', StoredProc.Params[18].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[18].ParamType);
  CheckEquals(ftBlob,StoredProc.Params[18].DataType);

  CheckEquals('P20', StoredProc.Params[19].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[19].ParamType);
  CheckEquals(ftBlob,StoredProc.Params[19].DataType);

  CheckEquals('P21', StoredProc.Params[20].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[20].ParamType);
  CheckStringParamType(StoredProc.Params[10], Connection.ControlsCodePage);


  CheckEquals('P22', StoredProc.Params[21].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[21].ParamType);
  CheckMemoParamType(StoredProc.Params[21], Connection.ControlsCodePage);

  CheckEquals('P23', StoredProc.Params[22].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[22].ParamType);
  CheckMemoParamType(StoredProc.Params[22], Connection.ControlsCodePage);

  CheckEquals('P24', StoredProc.Params[23].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[23].ParamType);
  CheckMemoParamType(StoredProc.Params[23], Connection.ControlsCodePage);

  CheckEquals('P25', StoredProc.Params[24].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[24].ParamType);
  CheckEquals(ftVarBytes,StoredProc.Params[24].DataType);

  CheckEquals('P26', StoredProc.Params[25].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[25].ParamType);
  CheckStringParamType(StoredProc.Params[25], Connection.ControlsCodePage);

  CheckEquals('P27', StoredProc.Params[26].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[26].ParamType);
  CheckEquals(ftInteger,StoredProc.Params[26].DataType);

  CheckEquals('P28', StoredProc.Params[27].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[27].ParamType);
  CheckEquals(ftInteger,StoredProc.Params[27].DataType);

  StoredProc.Params[0].AsSmallInt := 10; //TINYINT(4);
  StoredProc.Params[1].AsSmallInt := 20; //TINYINT(1);
  StoredProc.Params[2].AsSmallInt := 30; //SMALLINT(6)
  StoredProc.Params[3].AsInteger := 1000;
  StoredProc.Params[4].AsInteger := 2000;
  StoredProc.Params[5].AsInteger := 30000;
  SQLTime := SysUtils.EncodeTime(11,57,12,0)+EncodeDate(2017, 7, 13);
  StoredProc.Params[6].AsFloat := SQLTime;
  StoredProc.Params[7].AsFloat := SQLTime;
  StoredProc.Params[8].AsFloat := SQLTime;
  StoredProc.Params[9].AsInteger := 40000;
  StoredProc.Params[10].{$IFDEF WITH_VIRTUAL_TFIELD_ASWIDESTRING}AsWideString{$ELSE}Value{$ENDIF} := Str1;
  StoredProc.Params[11].AsDate := SQLTime;
  StoredProc.Params[12].AsTime := SQLTime;
  StoredProc.Params[13].AsSmallInt := 40;
  StoredProc.Params[14].AsDateTime := SQLTime;
  StoredProc.Params[15].AsDateTime := SQLTime;
  StoredProc.Params[20].{$IFDEF WITH_VIRTUAL_TFIELD_ASWIDESTRING}AsWideString{$ELSE}Value{$ENDIF} := Str1;
  StoredProc.Params[21].{$IFDEF WITH_VIRTUAL_TFIELD_ASWIDESTRING}AsWideString{$ELSE}Value{$ENDIF} := Str1;
  StoredProc.Params[22].{$IFDEF WITH_VIRTUAL_TFIELD_ASWIDESTRING}AsWideString{$ELSE}Value{$ENDIF} := Str1;
  StoredProc.Params[23].{$IFDEF WITH_VIRTUAL_TFIELD_ASWIDESTRING}AsWideString{$ELSE}Value{$ENDIF} := Str1;
  StoredProc.Params[24].Value := StrToBytes(AnsiString('121415'));
  StoredProc.Params[25].AsString := 'a';
  StoredProc.Params[26].AsInteger := 50000;
  StoredProc.Params[27].AsInteger := 60000;
  StoredProc.ExecProc;
  CheckEquals(28, StoredProc.Params.Count);
  StoredProc.Open;
  CheckEquals(28, StoredProc.Fields.Count);

  CheckEquals('P1', StoredProc.Fields[0].DisplayName);
  CheckEquals(10, StoredProc.Fields[0].AsInteger);
  CheckEquals({$IFDEF WITH_FTSHORTINT}ftShortInt{$ELSE}ftSmallInt{$ENDIF},StoredProc.Fields[0].DataType);

  CheckEquals('P2', StoredProc.Fields[1].DisplayName);
  CheckEquals(20, StoredProc.Fields[1].AsInteger);
  CheckEquals({$IFDEF WITH_FTSHORTINT}ftShortInt{$ELSE}ftSmallInt{$ENDIF},StoredProc.Fields[1].DataType);

  CheckEquals('P3', StoredProc.Fields[2].DisplayName);
  CheckEquals(30, StoredProc.Fields[2].AsInteger);
  CheckEquals(ftSmallint,StoredProc.Fields[2].DataType);

  CheckEquals('P4', StoredProc.Fields[3].DisplayName);
  CheckEquals(1000, StoredProc.Fields[3].AsInteger);
  CheckEquals(ftInteger,StoredProc.Fields[3].DataType);

  CheckEquals('P5', StoredProc.Fields[4].DisplayName);
  CheckEquals(2000, StoredProc.Fields[4].AsInteger);
  CheckEquals(ftInteger,StoredProc.Fields[4].DataType);

  CheckEquals('P6', StoredProc.Fields[5].DisplayName);
  CheckEquals(30000, StoredProc.Fields[5].AsInteger);
  CheckEquals(ftLargeInt,StoredProc.Fields[5].DataType);

  CheckEquals('P7', StoredProc.Fields[6].DisplayName);
  CheckEquals(True, Abs(SQLTime - StoredProc.Fields[6].AsFloat) < FLOAT_COMPARE_PRECISION);
  CheckEquals(ftFloat,StoredProc.Fields[6].DataType);

  CheckEquals('P8', StoredProc.Fields[7].DisplayName);
//  CheckEquals(True, Abs(SQLTime - StoredProc.Fields[7].AsFloat) < FLOAT_COMPARE_PRECISION_SINGLE);
  CheckEquals(ftFloat,StoredProc.Fields[7].DataType);

  CheckEquals('P9', StoredProc.Fields[8].DisplayName);
  //CheckEquals(SQLTime, StoredProc.Fields[8].AsFloat);
  CheckEquals(ftFmtBCD,StoredProc.Fields[8].DataType);

  CheckEquals('P10', StoredProc.Fields[9].DisplayName);
  CheckEquals(40000, StoredProc.Fields[9].AsInteger);
  CheckEquals(ftLargeInt,StoredProc.Fields[9].DataType);

  CheckEquals('P11', StoredProc.Fields[10].DisplayName);
  {$IFDEF UNICODE}
  CheckEquals(Str1, StoredProc.Fields[10].AsString, 'P11 String');
  {$ELSE}
  If Connection.ControlsCodePage = cCP_UTF16
  then CheckEquals(Str1, StoredProc.Fields[10].{$IFDEF WITH_VIRTUAL_TFIELD_ASWIDESTRING}AsWideString{$ELSE}Value{$ENDIF}, 'P11 String')
  else CheckEquals(Str1, StoredProc.Fields[10], 'P11 String');
  {$ENDIF}
  CheckStringFieldType(StoredProc.Fields[10], Connection.ControlsCodePage);

  CheckEquals('P12', StoredProc.Fields[11].DisplayName);
  CheckEquals(Int(SQLTime), StoredProc.Fields[11].AsDateTime);
  CheckEquals(ftDate,StoredProc.Fields[11].DataType);

  CheckEquals('P13', StoredProc.Fields[12].DisplayName);
  CheckEquals(StrToTime(TimeToStr(SQLTime)), StoredProc.Fields[12].AsDateTime);
  CheckEquals(ftTime,StoredProc.Fields[12].DataType);

  CheckEquals('P14', StoredProc.Fields[13].DisplayName);
  CheckEquals(2040, StoredProc.Fields[13].AsInteger);
  CheckEquals(ftWord,StoredProc.Fields[13].DataType);

  CheckEquals('P15', StoredProc.Fields[14].DisplayName);
  CheckEquals(DateTimeToStr(SQLTime), DateTimeToStr(StoredProc.Fields[14].AsDateTime));
  CheckEquals(ftDateTime,StoredProc.Fields[14].DataType);

  CheckEquals('P16', StoredProc.Fields[15].DisplayName);
  CheckEquals(DateTimeToStr(SQLTime), DateTimeToStr(StoredProc.Fields[15].AsDateTime));
  CheckEquals(ftDateTime,StoredProc.Fields[15].DataType);

  CheckEquals('P17', StoredProc.Fields[16].DisplayName);
  CheckEquals(ftBlob, StoredProc.Fields[16].DataType); //mysql returns FIELD_TYPE_BLOB which is 64kb by default -> fall back to ftBlob

  CheckEquals('P18', StoredProc.Fields[17].DisplayName);
  CheckEquals(ftBlob,StoredProc.Fields[17].DataType);

  CheckEquals('P19', StoredProc.Fields[18].DisplayName);
  CheckEquals(ftBlob,StoredProc.Fields[18].DataType);

  CheckEquals('P20', StoredProc.Fields[19].DisplayName);
  CheckEquals(ftBlob,StoredProc.Fields[19].DataType);

  CheckEquals('P21', StoredProc.Fields[20].DisplayName);

  CheckEquals(Str1, StoredProc.Fields[20], 'P21 String');
  CheckMemoFieldType(StoredProc.Fields[20], Connection.ControlsCodePage);

  CheckEquals('P22', StoredProc.Fields[21].DisplayName);
  CheckEquals(Str1, StoredProc.Fields[21], 'P21 String');
  CheckMemoFieldType(StoredProc.Fields[21], Connection.ControlsCodePage);

  CheckEquals('P23', StoredProc.Fields[22].DisplayName);
  CheckEquals(Str1, StoredProc.Fields[22], 'P23 String');
  CheckMemoFieldType(StoredProc.Fields[22], Connection.ControlsCodePage);

  CheckEquals('P24', StoredProc.Fields[23].DisplayName);
  CheckEquals(Str1, StoredProc.Fields[23], 'P24 String');
  CheckMemoFieldType(StoredProc.Fields[23], Connection.ControlsCodePage);

  CheckEquals('P25', StoredProc.Fields[24].DisplayName);
  TempBytes :=StrToBytes(RawByteString('121415'));
  CheckEquals(TempBytes,
    {$IFDEF TPARAM_HAS_ASBYTES}
    TBytes(StoredProc.Fields[24].AsBytes)
    {$ELSE}
    StrToBytes(StoredProc.Fields[24].AsString)
    {$ENDIF});
  CheckEquals(ftVarBytes,StoredProc.Fields[24].DataType);

  CheckEquals('P26', StoredProc.Fields[25].DisplayName);
  CheckEquals('a', StoredProc.Fields[25].AsString);
  CheckStringFieldType(StoredProc.Fields[25], Connection.ControlsCodePage);

  CheckEquals('P27', StoredProc.Fields[26].DisplayName);
  CheckEquals(50000, StoredProc.Fields[26].AsInteger);
  CheckEquals(ftInteger,StoredProc.Fields[26].DataType);

  CheckEquals('P28', StoredProc.Fields[27].DisplayName);
  CheckEquals(60000, StoredProc.Fields[27].AsInteger);
  CheckEquals(ftInteger,StoredProc.Fields[27].DataType);
end;

procedure TZTestMySQLStoredProcedure.Test_FuncReturnInteger;
begin
  StoredProc.StoredProcName := 'FuncReturnInteger';
  CheckEquals(2, StoredProc.Params.Count);

  CheckEquals('ReturnValue', StoredProc.Params[0].Name);
  CheckEquals(ptResult,StoredProc.Params[0].ParamType);
  CheckEquals(ftInteger,StoredProc.Params[0].DataType);

  CheckEquals('p_in', StoredProc.Params[1].Name);
  CheckEquals(ptInput,StoredProc.Params[1].ParamType);
  CheckEquals(ftInteger,StoredProc.Params[1].DataType);

  StoredProc.Params[1].AsInteger := 100;
  StoredProc.ExecProc;

  CheckEquals('ReturnValue', StoredProc.Params[0].Name);
  CheckEquals(ptResult,StoredProc.Params[0].ParamType);
  CheckEquals(ftInteger,StoredProc.Params[0].DataType);
  CheckEquals(110, StoredProc.Params[0].AsInteger);

  StoredProc.Params[1].AsInteger := 200;
  StoredProc.Open;
  CheckEquals(1, StoredProc.Fields.Count);

  CheckEquals('ReturnValue', StoredProc.Fields[0].DisplayName);
  CheckEquals(ftInteger,StoredProc.Fields[0].DataType);
  CheckEquals(210, StoredProc.Fields[0].AsInteger);
end;

procedure TZTestMySQLStoredProcedure.Test_ALL_PARAMS_IN;
begin
  StoredProc.StoredProcName := 'ALL_PARAMS_IN';
  CheckEquals(2, StoredProc.Params.Count);

  CheckEquals('p_id', StoredProc.Params[0].Name);
  CheckEquals(ptInput,StoredProc.Params[0].ParamType);
  CheckEquals(ftInteger,StoredProc.Params[0].DataType);

  CheckEquals('p_name', StoredProc.Params[1].Name);
  CheckEquals(ptInput,StoredProc.Params[1].ParamType);
  CheckStringParamType(StoredProc.Params[1], Connection.ControlsCodePage);
  StoredProc.Params[0].AsInteger := 2;
  StoredProc.Params[1].AsString := 'Yan Pater';
  StoredProc.Open;

  CheckEquals(8, StoredProc.Fields.Count);
  CheckEquals(2, StoredProc.RecordCount);
end;

procedure TZTestMySQLStoredProcedure.MultipleVaryingResultSets;
var B: Boolean;
begin
  StoredProc.StoredProcName := 'MultipleVaryingResultSets';
  CheckEquals(3, StoredProc.Params.Count);

  CheckEquals('p_in', StoredProc.Params[0].Name);
  CheckEquals(ptInput,StoredProc.Params[0].ParamType);
  CheckEquals(ftInteger,StoredProc.Params[0].DataType);

  CheckEquals('p_out', StoredProc.Params[1].Name);
  CheckEquals(ptOutput,StoredProc.Params[1].ParamType);
  CheckEquals(ftInteger,StoredProc.Params[1].DataType);

  CheckEquals('p_inout', StoredProc.Params[2].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[2].ParamType);
  CheckEquals(ftInteger,StoredProc.Params[2].DataType);

  StoredProc.Params[0].AsInteger := 100;
  StoredProc.Params[1].AsInteger := 200;
  StoredProc.Params[2].AsInteger := 300;
//  StoredProc.ExecProc;
  StoredProc.Open;

  for B := Low(Boolean) to High(Boolean) do begin
    CheckFalse(StoredProc.EOR, 'Resultset is not last');
    CheckTrue(StoredProc.BOR, 'Resultset is first');

    //5 Resultsets Returned What now?

    //The call resultset is retieved..
    CheckEquals(3, StoredProc.Fields.Count);

    CheckEquals('p_in', StoredProc.Fields[0].DisplayName);
    CheckEquals(ftInteger,StoredProc.Fields[0].DataType);
    CheckEquals(100, StoredProc.Fields[0].AsInteger);

    CheckEquals('p_inout', StoredProc.Fields[1].DisplayName);
    CheckEquals(ftInteger,StoredProc.Fields[1].DataType);
    CheckEquals(300, StoredProc.Fields[1].AsInteger);

    CheckEquals('p_out', StoredProc.Fields[2].DisplayName);
    CheckEquals(ftInteger,StoredProc.Fields[2].DataType);
    CheckEquals(0, StoredProc.Fields[2].AsInteger);

    {check second resultset}
    StoredProc.NextResultSet;

    CheckEquals(3, StoredProc.Fields.Count);

    CheckEquals('p_inout', StoredProc.Fields[0].DisplayName);
    CheckEquals(ftInteger,StoredProc.Fields[0].DataType);
    CheckEquals(300, StoredProc.Fields[0].AsInteger);

    CheckEquals('p_in', StoredProc.Fields[1].DisplayName);
    CheckEquals(ftInteger,StoredProc.Fields[1].DataType);
    CheckEquals(100, StoredProc.Fields[1].AsInteger);

    CheckEquals('p_out', StoredProc.Fields[2].DisplayName);
    CheckEquals(ftInteger,StoredProc.Fields[2].DataType);
    CheckEquals(200, StoredProc.Fields[2].AsInteger);

    {check third resultset}
    StoredProc.NextResultSet;

    CheckEquals(2, StoredProc.Fields.Count);

    CheckEquals('p_in', StoredProc.Fields[0].DisplayName);
    CheckEquals(ftInteger,StoredProc.Fields[0].DataType);
    CheckEquals(100, StoredProc.Fields[0].AsInteger);

    CheckEquals('p_inout', StoredProc.Fields[1].DisplayName);
    CheckEquals(ftInteger,StoredProc.Fields[1].DataType);
    CheckEquals(300, StoredProc.Fields[1].AsInteger);

    {check fourth resultset}
    StoredProc.NextResultSet;

    CheckEquals(1, StoredProc.Fields.Count);
    CheckEquals('10', StoredProc.Fields[0].DisplayName);
    // behavior inconsistency between mysql and mariadb:
    // mysql maps const ordinals to Largeint, mariadb to integer(if in range)
  //  CheckEquals(ftLargeInt,StoredProc.Fields[0].DataType);
    CheckEquals(10, StoredProc.Fields[0].AsInteger);

    CheckTrue(StoredProc.EOR, 'End of results');
    CheckFalse(StoredProc.BOR, 'Begin of results');

    {check third resultset again}
    StoredProc.PreviousResultSet;

    CheckEquals(2, StoredProc.Fields.Count);

    CheckEquals('p_in', StoredProc.Fields[0].DisplayName);
    CheckEquals(ftInteger,StoredProc.Fields[0].DataType);
    CheckEquals(100, StoredProc.Fields[0].AsInteger);

    CheckEquals('p_inout', StoredProc.Fields[1].DisplayName);
    CheckEquals(ftInteger,StoredProc.Fields[1].DataType);
    CheckEquals(300, StoredProc.Fields[1].AsInteger);

    CheckFalse(StoredProc.EOR, 'End of results');
    CheckFalse(StoredProc.BOR, 'Begin of results');

    StoredProc.LastResultSet;
    CheckTrue(StoredProc.EOR, 'End of results');

    if not B then
      StoredProc.FirstResultSet;
  end;
end;

{ TZTestADOStoredProcedure }
procedure TZTestADOStoredProcedure.ADO_Test_procedure1;
begin
  StoredProc.StoredProcName := 'procedure1';

  CheckEquals(3, StoredProc.Params.Count);
  CheckEquals('@RETURN_VALUE', StoredProc.Params[0].Name);
  CheckEquals('@p1', StoredProc.Params[1].Name);
  CheckEquals(ptInput,StoredProc.Params[1].ParamType);
  CheckEquals('@r1', StoredProc.Params[2].Name);
  CheckEquals(ptResult,StoredProc.Params[0].ParamType);

  StoredProc.Params[1].AsInteger := 12345;
  StoredProc.ExecProc;
  CheckEquals(12346, StoredProc.Params[2].AsInteger);
  CheckEquals(3, StoredProc.Params.Count);
end;

function TZTestADOStoredProcedure.GetSupportedProtocols: string;
begin
  Result := 'ado,OleDB,odbc_w,odbc_a,MSSQL,Sybase';
end;

procedure TZTestADOStoredProcedure.ADO_Test_abtest;
var
  i, P2: integer;
  S: String;
begin
  StoredProc.StoredProcName := 'ABTEST';
  CheckEquals(6, StoredProc.Params.Count);
  CheckEquals('@RETURN_VALUE', StoredProc.Params[0].Name);
  CheckEquals(ptResult, StoredProc.Params[0].ParamType);
  CheckEquals(ftInteger, StoredProc.Params[0].DataType);
  CheckEquals('@p1', StoredProc.Params[1].Name);
  CheckEquals(ptInput, StoredProc.Params[1].ParamType);
  CheckEquals(ftInteger, StoredProc.Params[1].DataType);
  CheckEquals('@p2', StoredProc.Params[2].Name);
  CheckEquals(ptInput, StoredProc.Params[2].ParamType);
  CheckEquals(ftInteger, StoredProc.Params[2].DataType);
  CheckEquals('@p3', StoredProc.Params[3].Name);
  CheckEquals(ptInput, StoredProc.Params[3].ParamType);
  CheckStringParamType(StoredProc.Params[3], Connection.ControlsCodePage);
  CheckEquals('@p4', StoredProc.Params[4].Name);
  CheckEquals(ptInputOutput, StoredProc.Params[4].ParamType);
  CheckEquals(ftInteger, StoredProc.Params[4].DataType);
  CheckEquals('@p5', StoredProc.Params[5].Name);
  CheckEquals(ptInputOutput, StoredProc.Params[5].ParamType);
  CheckStringParamType(StoredProc.Params[5], Connection.ControlsCodePage);

  StoredProc.ParamByName('@p1').AsInteger := 50;
  StoredProc.ParamByName('@p2').AsInteger := 100;
  StoredProc.ParamByName('@p3').AsString := 'a';
  StoredProc.ExecProc;
  CheckEquals(600, StoredProc.ParamByName('@p4').AsInteger);
  CheckEquals('aa', StoredProc.ParamByName('@p5').AsString);
  CheckEquals(6, StoredProc.Params.Count);

  CheckEquals(ftInteger, StoredProc.Params[1].DataType);
  CheckEquals(ftInteger, StoredProc.Params[2].DataType);
  {$IFNDEF DISABLE_ZPARAM}
  CheckStringParamType(StoredProc.Params[3], Connection.ControlsCodePage);
  {$ELSE}
    {$IFDEF DELPHI14_UP}
  CheckEquals(ftWideString, StoredProc.Params[3].DataType);
    {$ELSE}
  CheckEquals(ftString, StoredProc.Params[3].DataType);
    {$ENDIF}
  {$ENDIF}
  CheckEquals(ftInteger, StoredProc.Params[4].DataType);
  CheckStringParamType(StoredProc.Params[5], Connection.ControlsCodePage);

  StoredProc.Prepare;
  S := 'a';
  P2 := 100;
  for i:= 1 to 9 do
  begin
    StoredProc.Params[1].AsInteger:= i;
    StoredProc.Params[2].AsInteger:= P2;
    StoredProc.Params[3].AsString:= S;
    StoredProc.ExecProc;
    CheckEquals(S+S, StoredProc.ParamByName('@p5').AsString);
    CheckEquals(I*10+P2, StoredProc.ParamByName('@p4').AsInteger);
    S := S+'a';
    P2 := 100 - I;
  end;
  StoredProc.Unprepare;
  S := StoredProc.ParamByName('@p4').AsString +
    ' ' + StoredProc.ParamByName('@p5').AsString;
  StoredProc.ParamByName('@p1').AsInteger := 50;
  StoredProc.ParamByName('@p2').AsInteger := 100;
  StoredProc.ParamByName('@p3').AsString := 'a';
  CheckEquals('@p3', StoredProc.Params[3].Name);
  CheckEquals('@p4', StoredProc.Params[4].Name);
  StoredProc.Open;

  CheckEquals(3, StoredProc.Fields.Count);
  CheckEquals(ftInteger,StoredProc.Fields[0].DataType);
  CheckEquals('@RETURN_VALUE', StoredProc.Fields[0].FieldName);
  CheckEquals(ftInteger, StoredProc.Fields[1].DataType); //oledb correctly describes the params
  CheckEquals('@p4', StoredProc.Fields[1].FieldName);
  CheckStringFieldType(StoredProc.Fields[2], Connection.ControlsCodePage);
  CheckEquals('@p5', StoredProc.Fields[2].FieldName);
end;

{ TZTestOracleStoredProcedure }
function TZTestOracleStoredProcedure.GetSupportedProtocols: string;
begin
  Result := 'oracle';
end;

procedure TZTestOracleStoredProcedure.abtest(prefix: string);
var
  i, P2: integer;
  S: String;
begin
  StoredProc.StoredProcName := prefix+'ABTEST';
  CheckEquals(5, StoredProc.Params.Count);
  CheckEquals('P1', StoredProc.Params[0].Name);
  CheckEquals(ptInput, StoredProc.Params[0].ParamType);
  CheckEquals(ftFmtBCD, StoredProc.Params[0].DataType);
  CheckEquals('P2', StoredProc.Params[1].Name);
  CheckEquals(ptInput, StoredProc.Params[1].ParamType);
  CheckEquals(ftFmtBCD, StoredProc.Params[1].DataType);
  CheckEquals('P3', StoredProc.Params[2].Name);
  CheckEquals(ptInput, StoredProc.Params[2].ParamType);
  CheckStringParamType(StoredProc.Params[2], Connection.ControlsCodePage);
  CheckEquals('P4', StoredProc.Params[3].Name);
  CheckEquals(ptOutput, StoredProc.Params[3].ParamType);
  CheckEquals(ftFmtBCD, StoredProc.Params[3].DataType);
  CheckEquals('P5', StoredProc.Params[4].Name);
  CheckEquals(ptOutput, StoredProc.Params[4].ParamType);
  CheckStringParamType(StoredProc.Params[4], Connection.ControlsCodePage);

  StoredProc.ParamByName('P1').AsInteger := 50;
  StoredProc.ParamByName('P2').AsInteger := 100;
  StoredProc.ParamByName('P3').AsString := 'a';
  StoredProc.ExecProc;
  {$IF defined(FPC) and defined(DISABLE_ZPARAM)}
  if (StoredProc.ParamByName('P4').DataType = ftFmtBCD) then
    try
      CheckEquals(600, StoredProc.ParamByName('P4').AsInteger);
      Fail('New FPC can resolve BCD Variant to Integer! add a Define and mark as resolved!');
    except
      CheckEquals('600', StoredProc.ParamByName('P4').AsString, 'P4 is different');
    end
  else
  {$IFEND}
  CheckEquals(600, StoredProc.ParamByName('P4').AsInteger);
  CheckEquals('aa', StoredProc.ParamByName('P5').AsString);
  CheckEquals(5, StoredProc.Params.Count);

{$IFDEF DISABLE_ZPARAM}
  CheckEquals(ftInteger, StoredProc.Params[0].DataType);
  CheckEquals(ftInteger, StoredProc.Params[1].DataType);
  {$IFDEF DELPHI14_UP}
  CheckEquals(ftWideString, StoredProc.Params[2].DataType);
  {$ELSE}
  CheckEquals(ftString, StoredProc.Params[2].DataType);
  {$ENDIF}
  //CheckEquals(ftInteger,StoredProc.Params[3].DataType);
  CheckStringParamType(StoredProc.Params[4], Connection.ControlsCodePage);
{$ELSE}
  CheckEquals(ftFmtBCD, StoredProc.Params[0].DataType);
  CheckEquals(ftFmtBCD, StoredProc.Params[1].DataType);
  CheckStringParamType(StoredProc.Params[2], Connection.ControlsCodePage);
  CheckEquals(ftFmtBCD, StoredProc.Params[3].DataType);
  CheckStringParamType(StoredProc.Params[4], Connection.ControlsCodePage);
{$ENDIF}

  StoredProc.Prepare;
  S := 'a';
  P2 := 100;
  for i:= 1 to 9 do
  begin
    StoredProc.Params[0].AsInteger:= i;
    StoredProc.Params[1].AsInteger:= P2;
    StoredProc.Params[2].AsString:= S;
    StoredProc.ExecProc;
    CheckEquals(S+S, StoredProc.ParamByName('P5').AsString);
    {$IF defined(FPC) and defined(DISABLE_ZPARAM)}
    if (StoredProc.ParamByName('P4').DataType = ftFmtBCD) then
      try
        CheckEquals(I*10+P2, StoredProc.ParamByName('P4').AsInteger);
        Fail('New FPC can resolve BCD Variant to Integer! add a Define and mark as resolved!');
      except
        CheckEquals(IntToStr(I*10+P2), StoredProc.ParamByName('P4').AsString, 'P4 is different');
      end
    else
    {$IFEND}
    CheckEquals(I*10+P2, StoredProc.ParamByName('P4').AsInteger);
    S := S+'a';
    P2 := 100 - I;
  end;
  StoredProc.Unprepare;
  S := StoredProc.ParamByName('P4').AsString +
    ' ' + StoredProc.ParamByName('P5').AsString;
  StoredProc.ParamByName('P1').AsInteger := 50;
  StoredProc.ParamByName('P2').AsInteger := 100;
  StoredProc.ParamByName('P3').AsString := 'a';
  CheckEquals('P4', StoredProc.Params[3].Name);
  CheckEquals('P5', StoredProc.Params[4].Name);
  StoredProc.Open;

  Try
    CheckEquals(2, ord(StoredProc.Fields.Count));
    CheckEquals(ftFmtBCD, StoredProc.Params[0].DataType);
    CheckEquals(ftFmtBCD, StoredProc.Params[1].DataType);
    CheckStringParamType(StoredProc.Params[2], Connection.ControlsCodePage);
    CheckEquals(ftFmtBCD, StoredProc.Params[3].DataType);
    CheckStringParamType(StoredProc.Params[4], Connection.ControlsCodePage);
    CheckEquals(ftFmtBCD, StoredProc.Fields[0].DataType);
    CheckStringFieldType(StoredProc.Fields[1], Connection.ControlsCodePage);
    CheckEquals(600, StoredProc.FieldByName('P4').AsInteger);
    CheckEquals('aa', StoredProc.FieldByName('P5').AsString);
  Finally
    StoredProc.Close;
  End;
end;

procedure TZTestOracleStoredProcedure.myfuncInOutReturn(prefix: string);
begin
  StoredProc.StoredProcName := prefix+'"myfuncInOutReturn"';
  CheckEquals(2, StoredProc.Params.Count);

  CheckEquals('ReturnValue', StoredProc.Params[0].Name);
  CheckEquals(ptResult,StoredProc.Params[0].ParamType);
  CheckStringParamType(StoredProc.Params[0], Connection.ControlsCodePage);

  CheckEquals('X', StoredProc.Params[1].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[1].ParamType);
  CheckStringParamType(StoredProc.Params[1], Connection.ControlsCodePage);


  StoredProc.ParamByName('x').AsString := 'a';
  StoredProc.ExecProc;

  CheckEquals('aoutvalue', StoredProc.ParamByName('x').AsString);
  CheckEquals('returned string', StoredProc.ParamByName('ReturnValue').AsString);
  CheckEquals(2, StoredProc.Params.Count);

  StoredProc.Open;
  Try
    CheckEquals(2, StoredProc.Fields.Count);
    CheckStringFieldType(StoredProc.Fields[1], Connection.ControlsCodePage);
    CheckEquals('X', StoredProc.Fields[1].DisplayName);
    CheckStringFieldType(StoredProc.Fields[0], Connection.ControlsCodePage);
    CheckEquals('ReturnValue', StoredProc.Fields[0].DisplayName);

    CheckEquals('aoutvalueoutvalue', StoredProc.ParamByName('X').AsString);
    CheckEquals('returned string', StoredProc.ParamByName('ReturnValue').AsString);
  Finally
    StoredProc.Close;
  End;
end;

procedure TZTestOracleStoredProcedure.simple_func(prefix: string);
begin
  StoredProc.StoredProcName := prefix+'simple_func';
  CheckEquals(1, StoredProc.Params.Count);
  CheckEquals('ReturnValue', StoredProc.Params[0].Name);
  CheckEquals(ptResult,StoredProc.Params[0].ParamType);
  //CheckEquals(ftInteger,StoredProc.Params[0].DataType);

  StoredProc.ExecProc;

  {$IFDEF FPC}
  if (StoredProc.ParamByName('ReturnValue').DataType = ftFmtBCD) then
    try
      CheckEquals(1111, StoredProc.ParamByName('ReturnValue').AsInteger);
      Fail('New FPC can resolve BCD Variant to Integer! add a Define and mark as resolved!');
    except
      CheckEquals('1111', StoredProc.ParamByName('ReturnValue').AsString, 'ReturnValue is different');
    end
  else
  {$ENDIF}
  CheckEquals(1111, StoredProc.ParamByName('ReturnValue').AsInteger);
  CheckEquals(1, StoredProc.Params.Count);
end;

procedure TZTestOracleStoredProcedure.simplefunc(prefix: string);
begin
  StoredProc.StoredProcName := prefix+'simplefunc';
  CheckEquals(1, StoredProc.Params.Count);
  CheckEquals('ReturnValue', StoredProc.Params[0].Name);
  CheckEquals(ptResult,StoredProc.Params[0].ParamType);
  //CheckEquals(ftInteger,StoredProc.Params[0].DataType);

  StoredProc.ExecProc;

  {$IFDEF FPC}
  if (StoredProc.ParamByName('ReturnValue').DataType = ftFmtBCD) then
    try
      CheckEquals(2222, StoredProc.ParamByName('ReturnValue').AsInteger);
      Fail('New FPC can resolve BCD Variant to Integer! add a Define and mark as resolved!');
    except
      CheckEquals('2222', StoredProc.ParamByName('ReturnValue').AsString, 'ReturnValue is different');
    end
  else
  {$ENDIF}
  CheckEquals(2222, StoredProc.ParamByName('ReturnValue').AsInteger);
  CheckEquals(1, StoredProc.Params.Count);
end;

procedure TZTestOracleStoredProcedure.MYPACKAGE(prefix: string);
begin
  StoredProc.StoredProcName := prefix+'MYPACKAGE';
  CheckEquals(9, StoredProc.Params.Count);

  CheckEquals('ABTEST_P1', StoredProc.Params[0].Name);
  CheckEquals(ptInput,StoredProc.Params[0].ParamType);
  //CheckEquals(ftInteger,StoredProc.Params[0].DataType);

  CheckEquals('ABTEST_P2', StoredProc.Params[1].Name);
  CheckEquals(ptInput,StoredProc.Params[1].ParamType);
  //CheckEquals(ftInteger,StoredProc.Params[1].DataType);

  CheckEquals('ABTEST_P3', StoredProc.Params[2].Name);
  CheckEquals(ptInput,StoredProc.Params[2].ParamType);
  CheckStringParamType(StoredProc.Params[2], Connection.ControlsCodePage);

  CheckEquals('ABTEST_P4', StoredProc.Params[3].Name);
  CheckEquals(ptOutput,StoredProc.Params[3].ParamType);
  //CheckEquals(ftInteger,StoredProc.Params[3].DataType);

  CheckEquals('ABTEST_P5', StoredProc.Params[4].Name);
  CheckEquals(ptOutput,StoredProc.Params[4].ParamType);
  CheckStringParamType(StoredProc.Params[4], Connection.ControlsCodePage);

  CheckEquals('myfuncInOutReturn_ReturnValue', StoredProc.Params[5].Name);
  CheckEquals(ptResult,StoredProc.Params[5].ParamType);
  CheckStringParamType(StoredProc.Params[5], Connection.ControlsCodePage);

  CheckEquals('myfuncInOutReturn_X', StoredProc.Params[6].Name);
  CheckEquals(ptInputOutput,StoredProc.Params[6].ParamType);
  CheckStringParamType(StoredProc.Params[6], Connection.ControlsCodePage);

  CheckEquals('SIMPLE_FUNC_ReturnValue', StoredProc.Params[7].Name);
  CheckEquals(ptResult,StoredProc.Params[7].ParamType);
  //CheckEquals(ftInteger,StoredProc.Params[7].DataType);

  CheckEquals('SIMPLEFUNC_ReturnValue', StoredProc.Params[8].Name);
  CheckEquals(ptResult,StoredProc.Params[8].ParamType);
  //CheckEquals(ftInteger,StoredProc.Params[8].DataType);

  StoredProc.ParamByName('myfuncInOutReturn_X').AsString := 'myfuncInOutReturn';
  StoredProc.ParamByName('ABTEST_P1').AsInteger := 50;
  StoredProc.ParamByName('ABTEST_P2').AsInteger := 100;
  StoredProc.ParamByName('ABTEST_P3').AsString := 'abc';
  StoredProc.ExecProc;
  {$IFDEF FPC}
  if (StoredProc.ParamByName('ABTEST_P4').DataType = ftFmtBCD) then
    try
      CheckEquals(600, StoredProc.ParamByName('ABTEST_P4').AsInteger);
      Fail('New FPC can resolve BCD Variant to Integer! add a Define and mark as resolved!');
    except
      CheckEquals('600', StoredProc.ParamByName('ABTEST_P4').AsString, 'ABTEST_P4 is different');
    end
  else
  {$ENDIF}
  CheckEquals(600, StoredProc.ParamByName('ABTEST_P4').AsInteger);
  CheckEquals('abcabc', StoredProc.ParamByName('ABTEST_P5').AsString);
  CheckEquals('myfuncInOutReturnoutvalue', StoredProc.ParamByName('myfuncInOutReturn_X').AsString);
  CheckEquals('returned string', StoredProc.ParamByName('myfuncInOutReturn_ReturnValue').AsString);
  {$IFDEF FPC}
  if (StoredProc.ParamByName('SIMPLE_FUNC_ReturnValue').DataType = ftFmtBCD) then
    try
      CheckEquals(1111, StoredProc.ParamByName('SIMPLE_FUNC_ReturnValue').AsInteger);
      Fail('New FPC can resolve BCD Variant to Integer! add a Define and mark as resolved!');
    except
      CheckEquals('1111', StoredProc.ParamByName('SIMPLE_FUNC_ReturnValue').AsString, 'SIMPLE_FUNC_ReturnValue is different');
    end
  else
  {$ENDIF}
  CheckEquals(1111, StoredProc.ParamByName('SIMPLE_FUNC_ReturnValue').AsInteger);
  {$IFDEF FPC}
  if (StoredProc.ParamByName('SIMPLEFUNC_ReturnValue').DataType = ftFmtBCD) then
    try
      CheckEquals(2222, StoredProc.ParamByName('SIMPLEFUNC_ReturnValue').AsInteger);
      Fail('New FPC can resolve BCD Variant to Integer! add a Define and mark as resolved!');
    except
      CheckEquals('2222', StoredProc.ParamByName('SIMPLEFUNC_ReturnValue').AsString, 'SIMPLEFUNC_ReturnValue is different');
    end
  else
  {$ENDIF}
  CheckEquals(2222, StoredProc.ParamByName('SIMPLEFUNC_ReturnValue').AsInteger);

  StoredProc.Open;

  CheckEquals('abcabc', StoredProc.ParamByName('ABTEST_P5').AsString);
  CheckEquals('myfuncInOutReturnoutvalueoutvalue', StoredProc.ParamByName('myfuncInOutReturn_X').AsString);
  CheckEquals('returned string', StoredProc.ParamByName('myfuncInOutReturn_ReturnValue').AsString);

  {$IFDEF FPC}
  if (StoredProc.ParamByName('SIMPLE_FUNC_ReturnValue').DataType = ftFmtBCD) then
    try
      CheckEquals(1111, StoredProc.ParamByName('SIMPLE_FUNC_ReturnValue').AsInteger);
      Fail('New FPC can resolve BCD Variant to Integer! add a Define and mark as resolved!');
    except
      CheckEquals('1111', StoredProc.ParamByName('SIMPLE_FUNC_ReturnValue').AsString, 'SIMPLE_FUNC_ReturnValue is different');
    end
  else
  {$ENDIF}
  CheckEquals(1111, StoredProc.ParamByName('SIMPLE_FUNC_ReturnValue').AsInteger);
  {$IFDEF FPC}
  if (StoredProc.ParamByName('SIMPLEFUNC_ReturnValue').DataType = ftFmtBCD) then
    try
      CheckEquals(2222, StoredProc.ParamByName('SIMPLEFUNC_ReturnValue').AsInteger);
      Fail('New FPC can resolve BCD Variant to Integer! add a Define and mark as resolved!');
    except
      CheckEquals('2222', StoredProc.ParamByName('SIMPLEFUNC_ReturnValue').AsString, 'SIMPLESIMPLEFUNC_ReturnValueFUNC_ReturnValue is different');
    end
  else
  {$ENDIF}
  CheckEquals(2222, StoredProc.ParamByName('SIMPLEFUNC_ReturnValue').AsInteger);

  StoredProc.Close;
  StoredProc.Open;

  CheckEquals(600, StoredProc.FieldByName('ABTEST_P4').AsInteger);
  CheckEquals('abcabc', StoredProc.FieldByName('ABTEST_P5').AsString);
  CheckEquals('myfuncInOutReturnoutvalueoutvalueoutvalue', StoredProc.FieldByName('myfuncInOutReturn_X').AsString);
  CheckEquals('returned string', StoredProc.FieldByName('myfuncInOutReturn_ReturnValue').AsString);
  CheckEquals(1111, StoredProc.FieldByName('SIMPLE_FUNC_ReturnValue').AsInteger);
  CheckEquals(2222, StoredProc.FieldByName('SIMPLEFUNC_ReturnValue').AsInteger);
end;

procedure TZTestOracleStoredProcedure.ORA_Test_abtest;
begin
  abtest();
end;

procedure TZTestOracleStoredProcedure.ORA_Test_myfuncInOutReturn;
begin
  myfuncInOutReturn();
end;

procedure TZTestOracleStoredProcedure.ORA_Test_simple_func;
begin
  simple_func();
end;

procedure TZTestOracleStoredProcedure.ORA_Test_simplefunc;
begin
  simplefunc();
end;

procedure TZTestOracleStoredProcedure.ORA_Test_packaged;
begin
  abtest('MYPACKAGE.');
  myfuncInOutReturn('MYPACKAGE.');
  simple_func('MYPACKAGE.');
  simplefunc('MYPACKAGE.');
end;

procedure TZTestOracleStoredProcedure.ORA_Test_Owner_packaged;
begin
  abtest(Connection.user+'.MYPACKAGE.');
  myfuncInOutReturn(Connection.user+'.MYPACKAGE.');
  simple_func(Connection.user+'.MYPACKAGE.');
  simplefunc(Connection.user+'.MYPACKAGE.');
end;

procedure TZTestOracleStoredProcedure.ORA_Test_MYPACKAGE;
begin
  MYPACKAGE;
end;

procedure TZTestOracleStoredProcedure.ORA_Test_Owner_MYPACKAGE;
begin
  MYPACKAGE(Connection.user+'.');
end;

procedure TZTestOracleStoredProcedure.ORA_Test_IS_ACCOUNT_SERVE;
begin
  StoredProc.StoredProcName := 'IS_ACCOUNT_SERVE';
  CheckEquals(3, StoredProc.Params.Count);
  StoredProc.ParamByName('p_MIFARE_ID').AsString := '1a2b3c4d';
  StoredProc.ExecProc;
  CheckEquals('OK', StoredProc.ParamByName('P_MSG').AsString);

  {$IFDEF FPC}
  if (StoredProc.ParamByName('ReturnValue').DataType = ftFmtBCD) then
    try
      CheckEquals(1, StoredProc.ParamByName('ReturnValue').AsInteger);
      Fail('New FPC can resolve BCD Variant to Integer! add a Define and mark as resolved!');
    except
      CheckEquals('1', StoredProc.ParamByName('ReturnValue').AsString, 'ReturnValue is different');
    end
  else
  {$ELSE}
  CheckEquals(1, StoredProc.ParamByName('ReturnValue').AsInteger);
  {$ENDIF}
  StoredProc.ExecProc;
  CheckEquals('OK', StoredProc.ParamByName('P_MSG').AsString);
  {$IFDEF FPC}
  if (StoredProc.ParamByName('ReturnValue').DataType = ftFmtBCD) then
    try
      CheckEquals(1, StoredProc.ParamByName('ReturnValue').AsInteger);
      Fail('New FPC can resolve BCD Variant to Integer! add a Define and mark as resolved!');
    except
      CheckEquals('1', StoredProc.ParamByName('ReturnValue').AsString, 'ReturnValue is different');
    end
  else
  {$ELSE}
  CheckEquals(1, StoredProc.ParamByName('ReturnValue').AsInteger);
  {$ENDIF}
end;

initialization
  RegisterTest('component',TZTestInterbaseStoredProcedure.Suite);
  RegisterTest('component',TZTestDbLibStoredProcedure.Suite);
  RegisterTest('component',TZTestPostgreSQLStoredProcedure.Suite);
  RegisterTest('component',TZTestMySQLStoredProcedure.Suite);
  RegisterTest('component',TZTestADOStoredProcedure.Suite);
  RegisterTest('component',TZTestOracleStoredProcedure.Suite);
//  RegisterTest('component',TZTestStoredProcedure.Suite);
end.
