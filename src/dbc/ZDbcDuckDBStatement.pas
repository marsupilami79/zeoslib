{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{             DuckDB Connectivity Classes                 }
{                                                         }
{        Originally written by Jan Baumgarten             }
{                                                         }
{*********************************************************}

{@********************************************************}
{    Copyright (c) 1999-2020 Zeos Development Group       }
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
{  http://zeoslib.sourceforge.net  (FORUM)                }
{  http://sourceforge.net/p/zeoslib/tickets/ (BUGTRACKER) }
{  http://svn.code.sf.net/p/zeoslib/code-0/trunk (SVN)    }
{                                                         }
{  http://www.sourceforge.net/projects/zeoslib.           }
{                                                         }
{                                                         }
{                                 Zeos Development Group. }
{********************************************************@}

unit ZDbcDuckDBStatement;

interface

{$I ZDbc.inc}

{$IFNDEF ZEOS_DISABLE_DUCKDB} //if set we have an empty unit
uses
  Classes, {$IFDEF MSEgui}mclasses,{$ENDIF} SysUtils,
  {$IF defined(UNICODE) and not defined(WITH_UNICODEFROMLOCALECHARS)}Windows,{$IFEND}
  ZDbcIntfs, ZDbcBeginnerStatement, ZDbcLogging,
  ZCompatibility, ZVariant, ZDbcGenericResolver, ZDbcCachedResultSet,
  ZDbcUtils,
  ZPlainDuckDb;

type
  { TZDuckDBPreparedStatement }

  {** Dbc Layer Web Proxy Prepared SQL statement interface. }
  IZDuckDBPreparedStatement = interface(IZPreparedStatement)
    ['{32D326DA-9D29-492A-9556-890FB1454757}']
  end;

  TZDbcDuckDBPreparedStatement = class(TZAbstractBeginnerPreparedStatement, IZDuckDBPreparedStatement)
  private
  protected
    FPlainDriver: TZDuckDBPlainDriver;
    FStatement: TDuckDB_Prepared_Statement;
    procedure CheckDuckDbError(AStatement: TDuckDB_Prepared_Statement);
    procedure BindParams;
    function CreateResultSet(Const DuckResult: TDuckDB_Result): IZResultSet;
  public
    constructor Create(const Connection: IZConnection; const SQL: string; Info: TStrings);

    /// <summary>
    ///   Executes the SQL query in this PreparedStatement object
    ///   and returns the result set generated by the query.
    /// </summary>
    /// <returns>
    ///   a ResultSet object that contains the data produced by the
    ///   query; never null
    /// </returns>
    function ExecuteQueryPrepared: IZResultSet; override;
    /// <summary>
    ///   Executes the SQL INSERT, UPDATE or DELETE statement
    ///   in this <code>PreparedStatement</code> object.
    ///   In addition,
    ///   SQL statements that return nothing, such as SQL DDL statements,
    ///   can be executed.
    /// </summary>
    /// <returns>
    ///   either the row count for INSERT, UPDATE or DELETE statements;
    ///   or 0 for SQL statements that return nothing
    /// </returns>
    function ExecuteUpdatePrepared: Integer; override;
    /// <summary>
    ///  Executes any kind of SQL statement.
    ///  Some prepared statements return multiple results; the <code>execute</code>
    ///  method handles these complex statements as well as the simpler
    ///  form of statements handled by the methods <code>executeQuery</code>
    ///  and <code>executeUpdate</code>.
    /// </summary>
    /// <returns>
    ///   True if there is an IZResultSet. False Otherwise.
    /// </returns>
    /// <see>
    ///   IZStatement.Execute
    /// </see>
    /// <remarks>
    ///   The result definition has been taken from the JDBC docs on PreparedStatement.execute()
    /// </remarks>
    function ExecutePrepared: Boolean; override;
  end;

{$ENDIF ZEOS_DISABLE_DUCKDB} //if set we have an empty unit
implementation
{$IFNDEF ZEOS_DISABLE_DUCKDB} //if set we have an empty unit

uses
  {$IFDEF WITH_UNITANSISTRINGS}AnsiStrings, {$ENDIF}
  ZSysUtils, ZFastCode, ZMessages, ZDbcDuckDB, ZDbcDuckDBResultSet, ZDbcDuckDBUtils,
  ZEncoding, ZTokenizer, ZClasses, ZDbcResultSetMetadata,
  Variants, ZExceptions, FmtBcd
  {$IF defined(NO_INLINE_SIZE_CHECK) and not defined(UNICODE) and defined(MSWINDOWS)},Windows{$IFEND}
  {$IFDEF NO_INLINE_SIZE_CHECK}, Math{$ENDIF};

function ZTimeToDuckTime(const ZTime: TZTime): TDuckDb_Time;
begin
  Result.micros := ZTime.Hour;                 //fill with hours
  Result.micros := Result.micros * 60 + ZTime.Minute; //convert hours to minutes and add minutes
  Result.micros := Result.micros * 60 + ZTime.Second; //convert minutes to seconds and add seconds
  Result.micros := Result.micros * 1000000 + ZTime.Fractions div 1000; // convert seconds to micro seconds and add micro seconds
end;

function ZTimeStampToDuckTimeStamp(ZTimeStamp: TZTimeStamp): TDuckDb_TimeStamp;
begin
  Result.micros := Trunc(EncodeDate(ZTimeStamp.Year, ZTimeStamp.Month, ZTimeStamp.Day));
  Result.micros := Result.micros - DuckDBDateShift;              // days since 1970-01-01
  Result.micros := Result.micros * 24 + ZTimeStamp.Hour;   // hours since 1970-01-01
  Result.micros := Result.micros * 60 + ZTimeStamp.Minute; // minutes since 1970-01-01
  Result.micros := Result.micros * 60 + ZTimeStamp.Second; // seconds since 1970-01-01
  Result.micros := Result.micros * 1000 * 1000 + ZTimeStamp.Fractions div 1000; // microseconds since 1970-01-01
end;

{ TZDbcDuckDBPreparedStatement }

procedure TZDbcDuckDBPreparedStatement.CheckDuckDbError(AStatement: TDuckDB_Prepared_Statement);
var
  ErrorMsg: UTF8String;
begin
  ErrorMsg := FPlainDriver.DuckDB_Prepare_Error(AStatement);
  raise EZSQLException.Create({$IFDEF UNICODE}UTF8Decode(ErrorMsg){$ELSE}ErrorMsg{$ENDIF});
end;

constructor TZDbcDuckDBPreparedStatement.Create(const Connection: IZConnection; const SQL: string; Info: TStrings);
begin
  inherited;
  FPlainDriver := (Connection as IZDbcDuckDBConnection).GetPlainDriver;
  ResultSetType := rtScrollInsensitive;
end;

function TZDbcDuckDBPreparedStatement.CreateResultSet(Const DuckResult: TDuckDB_Result): IZResultSet;
var
  NativeResultSet: TZDbcDuckDBResultSet;
  CachedResultSet: TZCachedResultSet;
  CachedResolver: IZCachedResolver;
begin
  NativeResultSet := TZDbcDuckDBResultSet.Create(Self as IZStatement, Connection, SQL, DuckResult);
  NativeResultSet.SetConcurrency(rcReadOnly);
  LastUpdateCount := NativeResultSet.GetUpdateCount;

  if (GetResultSetType = rtForwardOnly) or (GetResultSetConcurrency = rcUpdatable) then
    NativeResultSet.SetType(rtForwardOnly);

  if GetResultSetConcurrency = rcUpdatable then
  begin
    CachedResolver := TZGenericCachedResolver.Create(self as IZStatement, NativeResultSet.GetMetaData) as IZCachedResolver;
    CachedResultSet := TZCachedResultSet.Create(NativeResultSet, SQL, CachedResolver, ConSettings);
    CachedResultSet.SetConcurrency(rcUpdatable);
    LastResultSet := CachedResultSet;
    Result := CachedResultSet;
  end else begin
    LastResultSet := NativeResultSet;
    Result := NativeResultSet;
  end;
  if Result <> nil then
    FOpenResultSet := Pointer(Result);
end;

function TZDbcDuckDBPreparedStatement.ExecuteQueryPrepared: IZResultSet;
begin
  ExecutePrepared;
  Result := LastResultSet;
end;

function TZDbcDuckDBPreparedStatement.ExecuteUpdatePrepared: Integer;
begin
  ExecutePrepared;
  Result := LastUpdateCount;
end;

function TZDbcDuckDBPreparedStatement.ExecutePrepared: Boolean;
var
  xSQL: UTF8String;
  Res: TDuckDB_State;
  DuckResult: TDuckDB_Result;
begin
  // free a previous prepared statement, if there is one
  FPlainDriver.DuckDB_Destroy_Prepare(@FStatement);

  xSQL := {$IFDEF UNICODE}UTF8Encode(FWSQL){$ELSE}FASQL{$ENDIF};
  Res := FPlainDriver.DuckDB_Prepare(
    (GetConnection as IZDbcDuckDBConnection).GetConnectionHandle,
    PAnsiChar(xSQL), @FStatement);
  if Res <> DuckDBSuccess then
     CheckDuckDbError(FStatement);
  BindParams;
  if FPlainDriver.DuckDB_Execute_Prepared(FStatement, @DuckResult) <> DuckDBSuccess then
    (GetConnection as IZDbcDuckDBConnection).CheckDuckDbError(@DuckResult);

  LastUpdateCount := FPlainDriver.DuckDB_Rows_Changed(@DuckResult);
  if FPlainDriver.DuckDB_Result_Return_Type(DuckResult) = DUCKDB_RESULT_TYPE_QUERY_RESULT then begin
    CreateResultSet(DuckResult);
    Result := True;
  end else begin
    Result := False;
    LastResultSet := nil;
  end;

  inherited ExecutePrepared;
end;

procedure TZDbcDuckDBPreparedStatement.BindParams;
var
  ParamCount: Integer;
  x: Integer;
  TempStr: UTF8String;
  TempDuckDate: TDuckDb_Date;
  TempZTime: TZTime;
  TempDuckTime: TDuckDb_Time;
  TempZTimeStamp: TZTimeStamp;
  TempDuckTimeStamp: TDuckDb_TimeStamp;
  TempBlob: IZBlob;
  TempBytes: TBytes;
  TempRawByteString: RawByteString;

  procedure RaiseBindError(ParamIdx: Integer; ParamType: String);
  begin
    EZSQLException.CreateFmt('Could not bind parameter %d as type %s', [ParamIdx, ParamType]);
  end;
begin
  ParamCount := FPlainDriver.DuckDB_NParams(FStatement);
  if ParamCount <> InParamCount then
     raise EZSQLException.Create('DuckDB and Zeos have different opinions about the parameter count.');
  for x := 0 to ParamCount - 1 do begin
    if ClientVarManager.IsNull(InParamValues[x]) then begin
      if FPlainDriver.DuckDB_Bind_Null(FStatement, x) <> DuckDBSuccess then
         RaiseBindError(x, 'null');
    end else begin
      case InParamTypes[x] of
        stBoolean:
          if FPlainDriver.DuckDB_Bind_Boolean(FStatement, x, ClientVarManager.GetAsBoolean(InParamValues[x])) <> DuckDBSuccess then
             RaiseBindError(x, 'boolean');
        stShort:
          if FPlainDriver.DuckDB_Bind_UInt8(FStatement, x, ClientVarManager.GetAsInteger(InParamValues[x])) <> DuckDBSuccess then
             RaiseBindError(x, 'uint8');
        stByte:
          if FPlainDriver.DuckDB_Bind_Int8(FStatement, x, ClientVarManager.GetAsInteger(InParamValues[x])) <> DuckDBSuccess then
             RaiseBindError(x, 'int8');
        stWord:
          if FPlainDriver.DuckDB_Bind_UInt16(FStatement, x, ClientVarManager.GetAsInteger(InParamValues[x])) <> DuckDBSuccess then
             RaiseBindError(x, 'uint16');
        stSmall:
          if FPlainDriver.DuckDB_Bind_Int16(FStatement, x, ClientVarManager.GetAsInteger(InParamValues[x])) <> DuckDBSuccess then
             RaiseBindError(x, 'int16');
        stLongWord:
          if FPlainDriver.DuckDB_Bind_UInt32(FStatement, x, ClientVarManager.GetAsInteger(InParamValues[x])) <> DuckDBSuccess then
             RaiseBindError(x, 'uint32');
        stInteger:
          if FPlainDriver.DuckDB_Bind_Int32(FStatement, x, ClientVarManager.GetAsInteger(InParamValues[x])) <> DuckDBSuccess then
             RaiseBindError(x, 'int32');
        stULong:
          if FPlainDriver.DuckDB_Bind_Uint64(FStatement, x, ClientVarManager.GetAsInteger(InParamValues[x])) <> DuckDBSuccess then
             RaiseBindError(x, 'uint64');
        stLong:
          if FPlainDriver.DuckDB_Bind_int64(FStatement, x, ClientVarManager.GetAsInteger(InParamValues[x])) <> DuckDBSuccess then
             RaiseBindError(x, 'int64');
        stFloat:
          if FPlainDriver.DuckDB_Bind_Float(FStatement, x, ClientVarManager.GetAsDouble(InParamValues[x])) <> DuckDBSuccess then
             RaiseBindError(x, 'float');
        stDouble, stCurrency, stBigDecimal:
          if FPlainDriver.DuckDB_Bind_Double(FStatement, x, ClientVarManager.GetAsDouble(InParamValues[x])) <> DuckDBSuccess then
             RaiseBindError(x, 'double');
        stString, stUnicodeString: begin
            TempStr := ClientVarManager.GetAsUTF8String(InParamValues[x]);
            if FPlainDriver.DuckDB_Bind_Varchar_Length(FStatement, x, PAnsiChar(TempStr), Length(TempStr)) <> DuckDBSuccess then
               RaiseBindError(x, 'varchar');
          end;
        stDate: begin
            TempDuckDate.days := Trunc(ClientVarManager.GetAsDateTime(InParamValues[x])) - DuckDBDateShift;
            if FPlainDriver.DuckDB_Bind_Date(FStatement, x, TempDuckDate) <> DuckDBSuccess then
               RaiseBindError(x, 'date');
          end;
        stTime: begin
            ClientVarManager.GetAsTime(InParamValues[x], TempZTime);
            TempDuckTime := ZTimeToDuckTime(TempZTime);
            if FPlainDriver.DuckDB_Bind_Time(FStatement, x, TempDuckTime) <> DuckDBSuccess then
              RaiseBindError(x, 'time');
          end;
        stTimestamp: begin
            ClientVarManager.GetAsTimeStamp(InParamValues[x], TempZTimeStamp);
            TempDuckTimeStamp := ZTimeStampToDuckTimeStamp(TempZTimeStamp);
            if FPlainDriver.DuckDB_Bind_Timestamp(FStatement, x, TempDuckTimeStamp) <> DuckDBSuccess then
              RaiseBindError(x, 'timestamp');
          end;
        stAsciiStream, stUnicodeStream: begin
            if (InParamValues[x].VType = vtInterface) and Supports(InParamValues[x].VInterface, IZBlob, TempBlob) then
              TempStr := TempBlob.GetUTF8String
            else
              TempStr := ClientVarManager.GetAsUTF8String(InParamValues[x]);
            if FPlainDriver.DuckDB_Bind_Varchar_Length(FStatement, x, PAnsiChar(TempStr), Length(TempStr)) <> DuckDBSuccess then
               RaiseBindError(x, 'varchar');
          end;
        stBinaryStream: begin
            if (InParamValues[x].VType = vtInterface) and Supports(InParamValues[x].VInterface, IZBlob, TempBlob) then begin
              TempBytes := TempBlob.GetBytes;
              try
                if FPlainDriver.DuckDB_Bind_Blob(FStatement, x, Pointer(@TempBytes[0]), Length(TempBytes)) <> DuckDBSuccess then
                  RaiseBindError(x, 'blob');
              finally
                Setlength(TempBytes, 0);
              end;
            end else begin
              raise EZSQLException.Create('Conversion of parameter to stBinaryStream is not supported (yet).');
            end;
          end;
        stBytes: begin
            TempRawByteString:= InParamValues[x].VRawByteString;
            if FPlainDriver.DuckDB_Bind_Blob(FStatement, x, Pointer(PansiChar(TempRawByteString)), Length(TempRawByteString)) <> DuckDBSuccess then
              RaiseBindError(x, 'blob');
          end;
        else
          raise EZSQLException.Create('Conversion of parameter ' + SysUtils.IntToStr(x) + ' is not supported (yet).');
      end;
    end;
  end;
end;

{$ENDIF ZEOS_DISABLE_DUCKDB} //if set we have an empty unit
end.
