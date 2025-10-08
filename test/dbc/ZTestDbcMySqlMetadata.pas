{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{           Tests for MySQL Database Metadata Class       }
{                                                         }
{         Originally written by Sergey Merkuriev          }
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

unit ZTestDbcMySqlMetadata;

interface

{$I ZDbc.inc}

{$IFNDEF ZEOS_DISABLE_MYSQL}

uses SysUtils, ZDbcIntfs, ZCompatibility, ZSqlTestCase,
 ZDbcMySql,{$IFDEF FPC}testregistry{$ELSE}TestFramework{$ENDIF};

type

 {** Implements a test case for TZMySqlMetadata. }
  TZTestMySqlMetadataCase = class(TZAbstractDbcSQLTestCase)
  private
    FMetadata: IZDatabaseMetadata;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
    function GetSupportedProtocols: string; override;

    property Metadata: IZDatabaseMetadata read FMetadata write FMetadata;
  published
    procedure TestGetProcedures;
    procedure TestGetProcedureColumns;
    procedure TestGetTables;
    procedure TestGetSchemas;
    procedure TestGetCatalogs;
    procedure TestGetTableTypes;
    procedure TestGetColumns;
    procedure TestGetColumnPrivileges;
    procedure TestGetTablePrivileges;
    procedure TestGetBestRowIdentifier;
  end;

{$ENDIF ZEOS_DISABLE_MYSQL}
implementation
{$IFNDEF ZEOS_DISABLE_MYSQL}

uses
  ZTestCase, ZDbcMetadata;

{ TZTestMySqlMetadataCase }

{**
  Gets an array of protocols valid for this test.
  @return an array of valid protocols
}
function TZTestMySqlMetadataCase.GetSupportedProtocols: string;
begin
  Result := pl_all_mysql;
end;

{**
   Create objects and allocate memory for variables
}
procedure TZTestMySqlMetadataCase.SetUp;
begin
  inherited SetUp;
  Metadata := Connection.GetMetadata;
end;

{**
   Destroy objects and free allocated memory for variables
}
procedure TZTestMySqlMetadataCase.TearDown;
begin
  Metadata := nil;
  inherited TearDown;
end;

{**
   Test method GetBestRowIdentifier
   <p><b>Note:</b><br>
   For adventure of the test it is necessary to execute sql
   <i>grant select(p_resume, p_redundant) on zeoslib.people to root@"%"</i></p>
}
procedure TZTestMySqlMetadataCase.TestGetBestRowIdentifier;
var
  ResultSet: IZResultSet;
begin
  ResultSet := Metadata.GetBestRowIdentifier('', '', 'people', 0, false);
  CheckEquals(BestRowIdentScopeIndex, ResultSet.FindColumn('SCOPE'));
  CheckEquals(BestRowIdentColNameIndex, ResultSet.FindColumn('COLUMN_NAME'));
  CheckEquals(BestRowIdentDataTypeIndex, ResultSet.FindColumn('DATA_TYPE'));
  CheckEquals(BestRowIdentTypeNameIndex, ResultSet.FindColumn('TYPE_NAME'));
  CheckEquals(BestRowIdentColSizeIndex, ResultSet.FindColumn('COLUMN_SIZE'));
  CheckEquals(BestRowIdentBufLengthIndex, ResultSet.FindColumn('BUFFER_LENGTH'));
  CheckEquals(BestRowIdentDecimalDigitsIndex, ResultSet.FindColumn('DECIMAL_DIGITS'));
  CheckEquals(BestRowIdentPseudoColumnIndex, ResultSet.FindColumn('PSEUDO_COLUMN'));

  Check(ResultSet.Next);
  CheckEquals('2', ResultSet.GetStringByName('SCOPE'));
  CheckEquals('p_id', ResultSet.GetStringByName('COLUMN_NAME'));
  CheckEquals(ord(stSmall), ResultSet.GetIntByName('DATA_TYPE'));
  CheckEquals('smallint', ResultSet.GetStringByName('TYPE_NAME'));
  CheckEquals('6', ResultSet.GetStringByName('COLUMN_SIZE'));
  CheckEquals('2', ResultSet.GetStringByName('BUFFER_LENGTH'));
  CheckEquals('0', ResultSet.GetStringByName('DECIMAL_DIGITS'));
  CheckEquals('1', ResultSet.GetStringByName('PSEUDO_COLUMN'));
  ResultSet.Close;
  ResultSet := nil;
end;

procedure TZTestMySqlMetadataCase.TestGetCatalogs;
var
  ResultSet: IZResultSet;
  DBFound: boolean;
  CatalogName: string;
  RealCatalogName: string;
begin
  DBFound := False;
  ResultSet := Metadata.GetCatalogs;
  RealCatalogName := (Connection as IZMySQLConnection).GetDatabaseName;
  CheckEquals(CatalogNameIndex, ResultSet.FindColumn('TABLE_CAT'));

  while ResultSet.Next do
  begin
    CatalogName := ResultSet.GetString(CatalogNameIndex);
    if CatalogName = RealCatalogName then
      DBFound := True;
  end;
  Check(DBFound);
  ResultSet.Close;
  ResultSet := nil;
end;

{**
   Test method GetColumnPrivileges
   <p><b>Note:</b><br>
   For adventure of the test it is necessary to execute sql
   <i>grant select on zeoslib.people to root@localhost;</i>
}
procedure TZTestMySqlMetadataCase.TestGetColumnPrivileges;
var
  ResultSet: IZResultSet;
begin
  try
    Connection.CreateStatement.ExecuteUpdate(
      'grant update(p_resume, p_redundant) on '+ConnectionConfig.Database+'.people to '+ConnectionConfig.UserName+'@'+ConnectionConfig.HostName);
  Except
    Fail('This test can''t pass if current user has no grant privilieges')
  end;

  ResultSet := Metadata.GetColumnPrivileges('', '', 'people', 'p_r%');
  CheckEquals(CatalogNameIndex, ResultSet.FindColumn('TABLE_CAT'));
  CheckEquals(SchemaNameIndex, ResultSet.FindColumn('TABLE_SCHEM'));
  CheckEquals(TableNameIndex, ResultSet.FindColumn('TABLE_NAME'));
  CheckEquals(ColumnNameIndex, ResultSet.FindColumn('COLUMN_NAME'));
  CheckEquals(TableColPrivGrantorIndex, ResultSet.FindColumn('GRANTOR'));
  CheckEquals(TableColPrivGranteeIndex, ResultSet.FindColumn('GRANTEE'));
  CheckEquals(TableColPrivPrivilegeIndex, ResultSet.FindColumn('PRIVILEGE'));
  CheckEquals(TableColPrivIsGrantableIndex, ResultSet.FindColumn('IS_GRANTABLE'));

  Check(ResultSet.Next, 'expected do find a first record in the returned metadata.');
  CheckEquals(uppercase(Database), uppercase(ResultSet.GetStringByName('TABLE_CAT')));
  CheckEquals('', ResultSet.GetStringByName('TABLE_SCHEM'));
  CheckEquals('people', ResultSet.GetStringByName('TABLE_NAME'));
  CheckEquals('p_redundant', ResultSet.GetStringByName('COLUMN_NAME'));
  CheckEquals(ConnectionConfig.UserName+'@'+ConnectionConfig.HostName, ResultSet.GetStringByName('GRANTOR'));
  CheckEquals(ConnectionConfig.UserName+'@'+ConnectionConfig.HostName, ResultSet.GetStringByName('GRANTEE'));
  CheckEquals('Update', ResultSet.GetStringByName('PRIVILEGE'));
  CheckEquals('', ResultSet.GetStringByName('IS_GRANTABLE'));

  Check(ResultSet.Next, 'expected do find a second record in the returned metadata.');
  CheckEquals(uppercase(Database), uppercase(ResultSet.GetStringByName('TABLE_CAT')));
  CheckEquals('', ResultSet.GetStringByName('TABLE_SCHEM'));
  CheckEquals('people', ResultSet.GetStringByName('TABLE_NAME'));
  CheckEquals('p_resume', ResultSet.GetStringByName('COLUMN_NAME'));
  CheckEquals(ConnectionConfig.UserName+'@'+ConnectionConfig.HostName, ResultSet.GetStringByName('GRANTOR'));
  CheckEquals(ConnectionConfig.UserName+'@'+ConnectionConfig.HostName, ResultSet.GetStringByName('GRANTEE'));
  CheckEquals('Update', ResultSet.GetStringByName('PRIVILEGE'));
  CheckEquals('', ResultSet.GetStringByName('IS_GRANTABLE'));

  ResultSet.Close;
  ResultSet := nil;
end;

{**
   Test for method GetColumns
}
procedure TZTestMySqlMetadataCase.TestGetColumns;
var
  ResultSet: IZResultSet;
begin
  ResultSet := Metadata.GetColumns('', '', 'people', 'p_r%');
  CheckEquals(CatalogNameIndex, ResultSet.FindColumn('TABLE_CAT'));
  CheckEquals(SchemaNameIndex, ResultSet.FindColumn('TABLE_SCHEM'));
  CheckEquals(TableNameIndex, ResultSet.FindColumn('TABLE_NAME'));
  CheckEquals(ColumnNameIndex, ResultSet.FindColumn('COLUMN_NAME'));
  CheckEquals(TableColColumnTypeIndex, ResultSet.FindColumn('DATA_TYPE'));
  CheckEquals(TableColColumnTypeNameIndex, ResultSet.FindColumn('TYPE_NAME'));
  CheckEquals(TableColColumnSizeIndex, ResultSet.FindColumn('COLUMN_SIZE'));
  CheckEquals(TableColColumnBufLengthIndex, ResultSet.FindColumn('BUFFER_LENGTH'));
  CheckEquals(TableColColumnDecimalDigitsIndex, ResultSet.FindColumn('DECIMAL_DIGITS'));
  CheckEquals(TableColColumnNumPrecRadixIndex, ResultSet.FindColumn('NUM_PREC_RADIX'));
  CheckEquals(TableColColumnNullableIndex, ResultSet.FindColumn('NULLABLE'));
  CheckEquals(TableColColumnRemarksIndex, ResultSet.FindColumn('REMARKS'));
  CheckEquals(TableColColumnColDefIndex, ResultSet.FindColumn('COLUMN_DEF'));
  CheckEquals(TableColColumnSQLDataTypeIndex, ResultSet.FindColumn('SQL_DATA_TYPE'));
  CheckEquals(TableColColumnSQLDateTimeSubIndex, ResultSet.FindColumn('SQL_DATETIME_SUB'));
  CheckEquals(TableColColumnCharOctetLengthIndex, ResultSet.FindColumn('CHAR_OCTET_LENGTH'));
  CheckEquals(TableColColumnOrdPosIndex, ResultSet.FindColumn('ORDINAL_POSITION'));
  CheckEquals(TableColColumnIsNullableIndex, ResultSet.FindColumn('IS_NULLABLE'));

  ResultSet.Next;
  CheckEquals(uppercase(Database), uppercase(ResultSet.GetStringByName('TABLE_CAT')));
  CheckEquals('', ResultSet.GetStringByName('TABLE_SCHEM'));
  CheckEquals('people', ResultSet.GetStringByName('TABLE_NAME'));
  CheckEquals('p_resume', ResultSet.GetStringByName('COLUMN_NAME'));
  CheckEquals(ord(stAsciiStream), ResultSet.GetIntByName('DATA_TYPE'));
  CheckEquals('TEXT', UpperCase(ResultSet.GetStringByName('TYPE_NAME')));
  CheckEquals(65535, ResultSet.GetIntByName('COLUMN_SIZE'));
  CheckEquals(65535, ResultSet.GetIntByName('BUFFER_LENGTH'));
  CheckEquals(0, ResultSet.GetIntByName('DECIMAL_DIGITS'));
  CheckEquals(0, ResultSet.GetIntByName('NUM_PREC_RADIX'));
  CheckEquals(1, ResultSet.GetIntByName('NULLABLE'));
  CheckEquals('', ResultSet.GetStringByName('REMARKS'));
  CheckEquals('', ResultSet.GetStringByName('COLUMN_DEF'));
  CheckEquals(0, ResultSet.GetIntByName('SQL_DATA_TYPE'));
  CheckEquals(0, ResultSet.GetIntByName('SQL_DATETIME_SUB'));
  CheckEquals(0, ResultSet.GetIntByName('CHAR_OCTET_LENGTH'));
  CheckEquals(1, ResultSet.GetIntByName('ORDINAL_POSITION'));
  CheckEquals('YES', ResultSet.GetStringByName('IS_NULLABLE'));

  ResultSet.Next;
  CheckEquals(uppercase(Database), uppercase(ResultSet.GetStringByName('TABLE_CAT')));
  CheckEquals('', ResultSet.GetStringByName('TABLE_SCHEM'));
  CheckEquals('people', ResultSet.GetStringByName('TABLE_NAME'));
  CheckEquals('p_redundant', ResultSet.GetStringByName('COLUMN_NAME'));
  CheckEquals(ord(stShort), ResultSet.GetIntByName('DATA_TYPE'));
  CheckEquals('TINYINT', UpperCase(ResultSet.GetStringByName('TYPE_NAME')));
  CheckEquals(4, ResultSet.GetIntByName('COLUMN_SIZE'));
  CheckEquals(1, ResultSet.GetIntByName('BUFFER_LENGTH'));
  CheckEquals(0, ResultSet.GetIntByName('DECIMAL_DIGITS'));
  CheckEquals(0, ResultSet.GetIntByName('NUM_PREC_RADIX'));
  CheckEquals(1, ResultSet.GetIntByName('NULLABLE'));
  CheckEquals('', ResultSet.GetStringByName('REMARKS'));
  CheckEquals('', ResultSet.GetStringByName('COLUMN_DEF'));
  CheckEquals(0, ResultSet.GetIntByName('SQL_DATA_TYPE'));
  CheckEquals(0, ResultSet.GetIntByName('SQL_DATETIME_SUB'));
  CheckEquals(0, ResultSet.GetIntByName('CHAR_OCTET_LENGTH'));
  CheckEquals(2, ResultSet.GetIntByName('ORDINAL_POSITION'));
  CheckEquals('YES', ResultSet.GetStringByName('IS_NULLABLE'));

  ResultSet.Close;
  ResultSet := nil;
end;

{**
   Test for method GetProcedureColumns
}
procedure TZTestMySqlMetadataCase.TestGetProcedureColumns;
var
  ResultSet: IZResultSet;
begin
  ResultSet := Metadata.GetProcedureColumns('', '', '', '');
  CheckEquals(CatalogNameIndex, ResultSet.FindColumn('PROCEDURE_CAT'));
  CheckEquals(SchemaNameIndex, ResultSet.FindColumn('PROCEDURE_SCHEM'));
  CheckEquals(ProcColProcedureNameIndex, ResultSet.FindColumn('PROCEDURE_NAME'));
  CheckEquals(ProcColColumnNameIndex, ResultSet.FindColumn('COLUMN_NAME'));
  CheckEquals(ProcColColumnTypeIndex, ResultSet.FindColumn('COLUMN_TYPE'));
  CheckEquals(ProcColDataTypeIndex, ResultSet.FindColumn('DATA_TYPE'));
  CheckEquals(ProcColTypeNameIndex, ResultSet.FindColumn('TYPE_NAME'));
  CheckEquals(ProcColPrecisionIndex, ResultSet.FindColumn('PRECISION'));
  CheckEquals(ProcColLengthIndex, ResultSet.FindColumn('LENGTH'));
  CheckEquals(ProcColScaleIndex, ResultSet.FindColumn('SCALE'));
  CheckEquals(ProcColRadixIndex, ResultSet.FindColumn('RADIX'));
  CheckEquals(ProcColNullableIndex, ResultSet.FindColumn('NULLABLE'));
  CheckEquals(ProcColRemarksIndex, ResultSet.FindColumn('REMARKS'));
  Check(ResultSet.Next);
  ResultSet.Close;
  ResultSet := nil;
end;

{**
   Test for method GetProcedures
}
procedure TZTestMySqlMetadataCase.TestGetProcedures;
var
  ResultSet: IZResultSet;
begin
  ResultSet := Metadata.GetProcedures('', '', '');
  CheckEquals(CatalogNameIndex, ResultSet.FindColumn('PROCEDURE_CAT'));
  CheckEquals(SchemaNameIndex, ResultSet.FindColumn('PROCEDURE_SCHEM'));
  CheckEquals(ProcedureNameIndex, ResultSet.FindColumn('PROCEDURE_NAME'));
  CheckEquals(ProcedureRemarksIndex, ResultSet.FindColumn('REMARKS'));
  CheckEquals(ProcedureTypeIndex, ResultSet.FindColumn('PROCEDURE_TYPE'));
  Check(ResultSet.Next);
  ResultSet.Close;
  ResultSet := nil;
end;

{**
   Test for method GetSchemas
}
procedure TZTestMySqlMetadataCase.TestGetSchemas;
var
  ResultSet: IZResultSet;
begin
  ResultSet := Metadata.GetSchemas;
  CheckEquals(SchemaColumnsTableSchemaIndex, ResultSet.FindColumn('TABLE_SCHEM'));
  Check(not ResultSet.Next);
  ResultSet.Close;
  ResultSet := nil;
end;

{**
   Test for method GetTablePrivileges
}
procedure TZTestMySqlMetadataCase.TestGetTablePrivileges;
var
  ResultSet: IZResultSet;
begin
  try
    Connection.CreateStatement.ExecuteUpdate(
      'grant select on '+ConnectionConfig.Database+'.people to '+ConnectionConfig.UserName+'@'+ConnectionConfig.HostName);
  Except
    Fail('This test can''t pass if current user has no grant privilieges')
  end;

  ResultSet := Metadata.GetTablePrivileges('', '', 'people');
  CheckEquals(CatalogNameIndex, ResultSet.FindColumn('TABLE_CAT'));
  CheckEquals(SchemaNameIndex, ResultSet.FindColumn('TABLE_SCHEM'));
  CheckEquals(TableNameIndex, ResultSet.FindColumn('TABLE_NAME'));
  CheckEquals(TablePrivGrantorIndex, ResultSet.FindColumn('GRANTOR'));
  CheckEquals(TablePrivGranteeIndex, ResultSet.FindColumn('GRANTEE'));
  CheckEquals(TablePrivPrivilegeIndex, ResultSet.FindColumn('PRIVILEGE'));
  CheckEquals(TablePrivIsGrantableIndex, ResultSet.FindColumn('IS_GRANTABLE'));

  Check(ResultSet.Next, 'expected to find a first record in the returned metadata.');
  CheckEquals(uppercase(Database), uppercase(ResultSet.GetStringByName('TABLE_CAT')));
  CheckEquals('', ResultSet.GetStringByName('TABLE_SCHEM'));
  CheckEquals('people', ResultSet.GetStringByName('TABLE_NAME'));
  CheckEquals(ConnectionConfig.UserName+'@'+ConnectionConfig.HostName, ResultSet.GetStringByName('GRANTOR'));
  CheckEquals(ConnectionConfig.UserName+'@'+ConnectionConfig.HostName, ResultSet.GetStringByName('GRANTEE'));
  CheckEquals('Select', ResultSet.GetStringByName('PRIVILEGE'));
  CheckEquals('', ResultSet.GetStringByName('IS_GRANTABLE'));
  ResultSet.Close;
  ResultSet := nil;
end;

{**
   Test for method GetTables
}
procedure TZTestMySqlMetadataCase.TestGetTables;
var
  ResultSet: IZResultSet;
begin
  ResultSet := Metadata.GetTables('', '', 'people', nil);
  CheckEquals(CatalogNameIndex, ResultSet.FindColumn('TABLE_CAT'));
  CheckEquals(SchemaNameIndex, ResultSet.FindColumn('TABLE_SCHEM'));
  CheckEquals(TableNameIndex, ResultSet.FindColumn('TABLE_NAME'));
  CheckEquals(TableColumnsSQLType, ResultSet.FindColumn('TABLE_TYPE'));
  CheckEquals(TableColumnsRemarks, ResultSet.FindColumn('REMARKS'));

  ResultSet.Next;
  CheckEquals(uppercase(Database), uppercase(ResultSet.GetStringByName('TABLE_CAT')));
  CheckEquals('', ResultSet.GetStringByName('TABLE_SCHEM'));
  CheckEquals('people', ResultSet.GetStringByName('TABLE_NAME'));
  CheckEquals('TABLE', ResultSet.GetStringByName('TABLE_TYPE'));
  CheckEquals('', ResultSet.GetStringByName('REMARKS'));
  ResultSet.Close;
  ResultSet := nil;
end;

{**
   Test for method GetTableTypes
}
procedure TZTestMySqlMetadataCase.TestGetTableTypes;
var
  ResultSet: IZResultSet;
begin
  ResultSet := Metadata.GetTableTypes;
  CheckEquals(TableTypeColumnTableTypeIndex, ResultSet.FindColumn('TABLE_TYPE'));

  ResultSet.Next;
  CheckEquals('TABLE', ResultSet.GetStringByName('TABLE_TYPE'));
  ResultSet.Close;
  ResultSet := nil;
end;

initialization
  RegisterTest('dbc',TZTestMySqlMetadataCase.Suite);
{$ENDIF ZEOS_DISABLE_MYSQL}

end.
