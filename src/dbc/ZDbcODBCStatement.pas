{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{           ODBC Database Connectivity Classes            }
{                                                         }
{            Originally written by EgonHugeist            }
{                                                         }
{*********************************************************}

{@********************************************************}
{    Copyright (c) 1999-2012 Zeos Development Group       }
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
{   http://sourceforge.net/p/zeoslib/tickets/ (BUGTRACKER)}
{   svn://svn.code.sf.net/p/zeoslib/code-0/trunk (SVN)    }
{                                                         }
{   http://www.sourceforge.net/projects/zeoslib.          }
{                                                         }
{                                                         }
{                                 Zeos Development Group. }
{********************************************************@}

unit ZDbcODBCStatement;

interface

{$I ZDbc.inc}

{$IFNDEF ZEOS_DISABLE_ODBC} //if set we have an empty unit
uses Types, Classes, {$IFDEF MSEgui}mclasses,{$ENDIF} SysUtils, FmtBCD,
  {$IF defined (WITH_INLINE) and defined(MSWINDOWS) and not defined(WITH_UNICODEFROMLOCALECHARS)}Windows, {$IFEND}
  ZCompatibility, ZDbcIntfs, ZDbcStatement, ZVariant, ZDbcProperties, ZDbcUtils,
  ZDbcODBCCon, ZPlainODBCDriver, ZDbcODBCUtils, ZCollections;

type
  PSQLHDBC = ^SQLHDBC;

  TZODBCHandleState = (hsNone, hsAllocated, hsExecuteDirect, hsPrepared, hsExecute);
  TZAbstractODBCStatement = class(TZAbstractPreparedStatement)
  private
    fPlainDriver: TZODBC3PlainDriver;
    fPHDBC: PSQLHDBC;
    fHSTMT: SQLHSTMT;
    fStreamSupport: Boolean;
    FHandleState: TZODBCHandleState;
    fZBufferLength: Integer;
    fStmtTimeOut: SQLULEN;
    fEnhancedColInfo: Boolean;
    fMoreResultsIndicator: TZMoreResultsIndicator;
    fLastAutoCommit: Boolean;
    FClientEncoding: TZCharEncoding;
    FODBCConnection: IZODBCConnection;
    FCallResultCache: TZCollection;
    FExecRETCODE: SQLRETURN;
    fParamBindings: PZODBCParamBindArray;
    procedure InternalExecute;
    procedure PrepareOpenedResultSetsForReusing;
    procedure FetchCallResults;
    function GetFirstResultSet: IZResultSet;
    procedure ClearCallResultCache;
  protected
    function ExecutDirect: RETCODE; virtual; abstract;
    procedure InternalPrepare; virtual;
    procedure CheckStmtError(RETCODE: SQLRETURN);
    procedure CheckDbcError(RETCODE: SQLRETURN);
    procedure HandleError(RETCODE: SQLRETURN; Handle: SQLHANDLE; HandleType: SQLSMALLINT);
    function InternalCreateResultSet: IZResultSet;
    procedure InternalBeforePrepare;
    function GetCurrentResultSet: IZResultSet;
    procedure ReleaseConnection; override;
  protected
    function SupportsSingleColumnArrays: Boolean;
  public
    constructor Create(const Connection: IZODBCConnection;
      var ConnectionHandle: SQLHDBC; const SQL: string; Info: TStrings);

    function ExecuteQueryPrepared: IZResultSet; override;
    function ExecuteUpdatePrepared: Integer; override;
    function ExecutePrepared: Boolean; override;

    procedure Prepare; override;
    procedure Unprepare; override;
    procedure AfterClose; override;
    procedure Cancel; override;

    function GetMoreResults: Boolean; override;
  end;

  TZAbstractODBCPreparedStatement = class(TZAbstractODBCStatement)
  private
    fDEFERPREPARE, //if set the stmt will be prepared immediatelly and we'll try to decribe params
    fBindImmediat: Boolean; //the param describe did fail! we'll try to bind the params with describe emulation
    fCurrentIterations: NativeUInt;
    procedure RaiseUnsupportedParamType(Index: Integer; SQLCType: SQLSMALLINT; SQLType: TZSQLType);
    procedure RaiseExceeded(Index: Integer);
    procedure SetPWideChar(Index: Integer; Value: PWideChar; WLen: LengthInt);
    procedure SetPAnsiChar(Index: Integer; Value: PAnsiChar; BLen: LengthInt);
    procedure BindSInteger(Index: Integer; SQLType: TZSQLType; Value: NativeInt);
    procedure BindUInteger(Index: Integer; SQLType: TZSQLType; Value: NativeUInt);
    procedure InternalBindDouble(Index: Integer; SQLType: TZSQLType; const Value: Double);
    procedure InitBind(Index, ValueCount: Integer; SQLType: TZSQLType; ActualLength: LengthInt = 0);
    procedure BindRaw(Index: Integer; const Value: RawByteString; CP: Word);
    procedure DescribeParameterFromODBC;
    procedure DescribeParameterFromBindList;
    procedure BindParam(Bind: PZODBCParamBind; ParameterNumber: SQLUSMALLINT);
    procedure BindArrayColumnWise(Index: Integer);

    procedure ReallocParamBindings(OldCount, NewCount: Integer);
  protected
    procedure CheckParameterIndex(var Value: Integer); override;
    procedure PrepareInParameters; override;
    procedure BindInParameters; override;
    procedure UnPrepareInParameters; override;
    procedure SetBindCapacity(Capacity: Integer); override;
  public
    constructor Create(const Connection: IZODBCConnection;
      var ConnectionHandle: SQLHDBC; const SQL: string; Info: TStrings);
  public
    procedure SetNull(Index: Integer; SQLType: TZSQLType);
    procedure SetBoolean(ParameterIndex: Integer; Value: Boolean);
    procedure SetByte(ParameterIndex: Integer; Value: Byte);
    procedure SetShort(ParameterIndex: Integer; Value: ShortInt);
    procedure SetWord(ParameterIndex: Integer; Value: Word);
    procedure SetSmall(ParameterIndex: Integer; Value: SmallInt);
    procedure SetUInt(ParameterIndex: Integer; Value: Cardinal);
    procedure SetInt(ParameterIndex: Integer; Value: Integer);
    procedure SetULong(Index: Integer; const Value: UInt64);
    procedure SetLong(Index: Integer; const Value: Int64);
    procedure SetFloat(Index: Integer; Value: Single);
    procedure SetDouble(Index: Integer; const Value: Double);
    procedure SetCurrency(Index: Integer; const Value: Currency);
    procedure SetBigDecimal(Index: Integer; const Value: TBCD);
    procedure SetDate(Index: Integer; const Value: TZDate); reintroduce; overload;
    procedure SetTime(Index: Integer; const Value: TZTime); reintroduce; overload;
    procedure SetTimestamp(Index: Integer; const Value: TZTimeStamp); reintroduce; overload;
    procedure SetBytes(Index: Integer; const Value: TBytes); reintroduce;
    procedure SetGUID(Index: Integer; const Value: TGUID); reintroduce;

    procedure SetString(Index: Integer; const Value: String); reintroduce;
    procedure SetUnicodeString(Index: Integer; const Value: ZWideString); reintroduce;
    procedure SetCharRec(Index: Integer; const Value: TZCharRec); reintroduce;
    {$IFNDEF NO_ANSISTRING}
    procedure SetAnsiString(Index: Integer; const Value: AnsiString); reintroduce;
    {$ENDIF}
    {$IFNDEF NO_UTF8STRING}
    procedure SetUTF8String(Index: Integer; const Value: UTF8String); reintroduce;
    {$ENDIF}
    procedure SetRawByteString(Index: Integer; const Value: RawByteString); reintroduce;

    procedure SetBlob(ParameterIndex: Integer; SQLType: TZSQLType; const Value: IZBlob); override;

    procedure ClearParameters; override;
    procedure RegisterParameter(ParameterIndex: Integer; SQLType: TZSQLType;
      ParamType: TZProcedureColumnType; const Name: String = ''; PrecisionOrSize: LengthInt = 0;
      Scale: LengthInt = 0); override;
  end;

  TZODBCPreparedStatementW = class(TZAbstractODBCPreparedStatement, IZPreparedStatement)
  protected
    FCachedQueryUni: TUnicodeStringDynArray;
    FIsParamIndex: TBooleanDynArray;
  protected
    function ExecutDirect: RETCODE; override;
    procedure InternalPrepare; override;
  public
    procedure Unprepare; override;
    function GetUnicodeEncodedSQL(const SQL: {$IF defined(FPC) and defined(WITH_RAWBYTESTRING)}RawByteString{$ELSE}String{$IFEND}): ZWideString; override;
  end;

  TZODBCStatementW = class(TZAbstractODBCStatement)
  protected
    function ExecutDirect: RETCODE; override;
  public
    constructor Create(const Connection: IZODBCConnection;
      var ConnectionHandle: SQLHDBC; Info: TStrings);
  end;

  TZODBCCallableStatementW = class(TZAbstractCallableStatement_W, IZCallableStatement)
  private
    fPHDBC: PSQLHDBC;
  protected
    function CreateExecutionStatement(const StoredProcName: String): TZAbstractPreparedStatement; override;
  public
    constructor Create(const Connection: IZConnection;
      var ConnectionHandle: SQLHDBC; const StoredProcOrFuncIdentifier: string;
      {$IFDEF AUTOREFCOUNT}const{$ENDIF}Info: TStrings);
  end;

  TZODBCPreparedStatementA = class(TZAbstractODBCPreparedStatement, IZPreparedStatement)
  protected
    FCachedQueryRaw: TRawByteStringDynArray;
    FIsParamIndex: TBooleanDynArray;
  protected
    function ExecutDirect: RETCODE; override;
    procedure InternalPrepare; override;
  public
    procedure Unprepare; override;
    function GetRawEncodedSQL(const SQL: {$IF defined(FPC) and defined(WITH_RAWBYTESTRING)}RawByteString{$ELSE}String{$IFEND}): RawByteString; override;
  end;

  TZODBCStatementA = class(TZAbstractODBCStatement)
  protected
    function ExecutDirect: RETCODE; override;
  public
    constructor Create(const Connection: IZODBCConnection;
      var ConnectionHandle: SQLHDBC; Info: TStrings);
  end;

  TZODBCCallableStatementA = class(TZAbstractCallableStatement_A, IZCallableStatement)
  private
    fPHDBC: PSQLHDBC;
  public
    constructor Create(const Connection: IZConnection;
      var ConnectionHandle: SQLHDBC; const StoredProcOrFuncIdentifier: string;
      {$IFDEF AUTOREFCOUNT}const{$ENDIF}Info: TStrings);
  protected
    function CreateExecutionStatement(const StoredProcName: String): TZAbstractPreparedStatement; override;
  end;

{$ENDIF ZEOS_DISABLE_ODBC} //if set we have an empty unit
implementation
{$IFNDEF ZEOS_DISABLE_ODBC} //if set we have an empty unit

uses Math, DateUtils, TypInfo, {$IFDEF WITH_UNITANSISTRINGS}AnsiStrings,{$ENDIF}
  ZSysUtils, ZMessages, ZEncoding, ZDbcResultSet, ZFastCode, ZDbcLogging,
  ZDbcODBCResultSet, ZDbcCachedResultSet, ZDbcGenericResolver,
  ZClasses, ZDbcMetadata;

var DefaultPreparableTokens: TPreparablePrefixTokens;

const
  NullInd: array[Boolean] of SQLLEN = (SQL_NO_NULLS, SQL_NULL_DATA);

type
  PLobArray = ^TLobArray;
  TLobArray = array[Byte] of IZBlob;

{ TZAbstractODBCStatement }

{**
  Cancels this <code>Statement</code> object if both the DBMS and
  driver support aborting an SQL statement.
  This method can be used by one thread to cancel a statement that
  is being executed by another thread.
}
procedure TZAbstractODBCStatement.Cancel;
begin
  if fHSTMT <> nil then
    CheckStmtError(FPlainDriver.SQLCancel(fHSTMT));
end;

procedure TZAbstractODBCStatement.CheckDbcError(RETCODE: SQLRETURN);
begin
  if RETCODE <> SQL_SUCCESS then
    HandleError(RETCODE, fPHDBC^, SQL_HANDLE_DBC);
end;

procedure TZAbstractODBCStatement.CheckStmtError(RETCODE: SQLRETURN);
begin
  if RETCODE <> SQL_SUCCESS then
    HandleError(RETCODE, fHSTMT, SQL_HANDLE_STMT);
end;

procedure TZAbstractODBCStatement.ClearCallResultCache;
var I: Integer;
  RS: IZResultSet;
begin
  for I := 0 to FCallResultCache.Count -1 do
    if Supports(FCallResultCache[i], IZResultSet, RS) then
      RS.Close;
  FreeAndNil(FCallResultCache);
end;

procedure TZAbstractODBCStatement.AfterClose;
begin
  if Assigned(fHSTMT) then begin
    fPlainDriver.SQLFreeHandle(SQL_HANDLE_STMT, fHSTMT);
    fHSTMT := nil;
  end;
end;

constructor TZAbstractODBCStatement.Create(const Connection: IZODBCConnection;
  var ConnectionHandle: SQLHDBC; const SQL: string; Info: TStrings);
begin
  inherited Create(Connection, SQL, Info);
  fPlainDriver := TZODBC3PlainDriver(Connection.GetPlainDriver.GetInstance);
  fStreamSupport := Connection.ODBCVersion >= {%H-}Word(SQL_OV_ODBC3_80);
  fPHDBC := @ConnectionHandle;
  FZBufferLength := {$IFDEF UNICODE}UnicodeToIntDef{$ELSE}RawToIntDef{$ENDIF}(ZDbcUtils.DefineStatementParameter(Self, DSProps_InternalBufSize, ''), 131072); //by default 128KB
  FEnhancedColInfo := StrToBoolEx(ZDbcUtils.DefineStatementParameter(Self, DSProps_EnhancedColumnInfo, 'True'));
  fStmtTimeOut := {$IFDEF UNICODE}UnicodeToIntDef{$ELSE}RawToIntDef{$ENDIF}(ZDbcUtils.DefineStatementParameter(Self, DSProps_StatementTimeOut, ''), SQL_QUERY_TIMEOUT_DEFAULT); //execution timeout in seconds by default 1
  fMoreResultsIndicator := TZMoreResultsIndicator(Ord(not Connection.GetMetadata.GetDatabaseInfo.SupportsMultipleResultSets));
  FClientEncoding := ConSettings^.ClientCodePage.Encoding;
  FODBCConnection := Connection;
end;

function TZAbstractODBCStatement.ExecutePrepared: Boolean;
var
  RowCount: SQLLEN;
  ColumnCount: SQLSMALLINT;
begin
  PrepareOpenedResultSetsForReusing;
  LastUpdateCount := 0;
  Prepare;
  BindInParameters;
  InternalExecute;
  if BindList.HasOutOrInOutOrResultParam then
    Result := Supports(FCallResultCache[0], IZResultSet, FLastResultSet)
  else begin
    CheckStmtError(fPlainDriver.SQLNumResultCols(fHSTMT, @ColumnCount));
    if ColumnCount > 0 then begin
      LastUpdateCount := -1;
      LastResultSet := GetCurrentResultSet;
    end else begin
      CheckStmtError(fPlainDriver.SQLRowCount(fHSTMT, @RowCount));
      LastUpdateCount := RowCount;
      LastResultSet := nil;
    end;
    Result := Assigned(LastResultSet);
  end;
end;

function TZAbstractODBCStatement.ExecuteQueryPrepared: IZResultSet;
var ColumnCount: SQLSMALLINT;
begin
  PrepareOpenedResultSetsForReusing;
  Prepare;
  BindInParameters;
  InternalExecute;
  CheckStmtError(fPlainDriver.SQLNumResultCols(fHSTMT, @ColumnCount));
  if BindList.HasOutOrInOutOrResultParam then begin
     FetchCallResults;
     Result := GetFirstResultSet;
  end else if ColumnCount > 0 then
    if Assigned(FOpenResultSet)
    then Result := IZResultSet(FOpenResultSet)
    else Result := GetCurrentResultSet
  else begin
    while GetMoreResults and (LastResultSet = nil) do ;
    Result := GetResultSet;
  end;
  if Result = nil then
    raise EZSQLException.Create(SCanNotOpenResultSet);
end;

function TZAbstractODBCStatement.ExecuteUpdatePrepared: Integer;
var RowCount: SQLLEN;
begin
  if Assigned(FOpenResultSet) then IZResultSet(FOpenResultSet).Close;
  if Assigned(LastResultSet) then LastResultSet.Close;
  FOpenResultSet := nil; LastResultSet := nil;
  Prepare;
  BindInParameters;
  LastUpdateCount := 0;
  InternalExecute;
  if BindList.HasOutOrInOutOrResultParam then
    Result := LastUpdateCount
  else begin
    CheckStmtError(fPlainDriver.SQLRowCount(fHSTMT, @RowCount));
    LastUpdateCount := LastUpdateCount + RowCount;
    Result := RowCount;
  end;
end;

procedure TZAbstractODBCStatement.FetchCallResults;
var CallResultCache: TZCollection;
  ColumnCount: SQLSMALLINT;
  RowCount: SQLLEN;
begin
  if FCallResultCache <> nil then
    ClearCallResultCache;
  CallResultCache := TZCollection.Create;
  CheckStmtError(fPlainDriver.SQLNumResultCols(fHSTMT, @ColumnCount));
  if (fMoreResultsIndicator <> mriHasNoMoreResults) and (ColumnCount > 0) then begin
    FLastResultSet := InternalCreateResultSet;
    CallResultCache.Add(Connection.GetMetadata.CloneCachedResultSet(FlastResultSet));
    (*EH: There is a problem i could not handle:
      if a {? = CALL() } of a SP using SQLExecute which returns !no! result shows this behavior:
      SQLNumResultCols returns a valid count
      but the columninfos are from sp_describe_undeclared_parameters ...
      -> the first fetch leads to an invalid cursor handle
    but if the sp returns a resultset everything is fine do far *)
    fMoreResultsIndicator := mriHasMoreResults;
  end else begin
    CheckStmtError(fPlainDriver.SQLRowCount(fHSTMT, @RowCount));
    LastUpdateCount := RowCount;
    CallResultCache.Add(TZAnyValue.CreateWithInteger(LastUpdateCount));
  end;
  while GetMoreresults do
    if LastResultSet <> nil then begin
      CallResultCache.Add(Connection.GetMetadata.CloneCachedResultSet(FLastResultSet));
      FLastResultSet.Close;
      FLastResultSet := nil;
      FOpenResultSet := nil;
    end else
      CallResultCache.Add(TZAnyValue.CreateWithInteger(LastUpdateCount));
  FCallResultCache := CallResultCache;
  FOutParamResultSet := TZParamODBCResultSet.Create(Self, SQL, fParamBindings, BindList.Count);
  if GetResultSetType <> rtForwardOnly then
    FOutParamResultSet := Connection.GetMetadata.CloneCachedResultSet(FOutParamResultSet);
end;

function TZAbstractODBCStatement.GetCurrentResultSet: IZResultSet;
var
  CachedResolver: IZCachedResolver;
  NativeResultSet: IZResultSet;
  CachedResultSet: TZCachedResultSet;
begin
  Result := nil;
  NativeResultSet := InternalCreateResultSet;
  if (GetResultSetConcurrency = rcUpdatable) or
     (GetResultSetType <> rtForwardOnly) then
  begin
    CachedResolver := TZGenericCachedResolver.Create(Self, NativeResultSet.GetMetaData);
    CachedResultSet := TZCachedResultSet.Create(NativeResultSet, SQL, CachedResolver, ConSettings);
    CachedResultSet.SetConcurrency(GetResultSetConcurrency);
    Result := CachedResultSet;
  end
  else
    Result := NativeResultSet;
  FOpenResultSet := Pointer(Result);
end;

function TZAbstractODBCStatement.GetFirstResultSet: IZResultSet;
var I: Integer;
begin
  Result := nil;
  if FCallResultCache <> nil then
    for I := 0 to FCallResultCache.Count -1 do
      if Supports(FCallResultCache[i], IZResultSet, Result) then begin
        FCallResultCache.Delete(I);
        Break;
      end;
end;

{**
  Moves to a <code>Statement</code> object's next result.  It returns
  <code>true</code> if this result is a <code>ResultSet</code> object.
  This method also implicitly closes any current <code>ResultSet</code>
  object obtained with the method <code>getResultSet</code>.

  <P>There are no more results when the following is true:
  <PRE>
        <code>(!getMoreResults() && (getUpdateCount() == -1)</code>
  </PRE>

 @return <code>true</code> if the next result is a <code>ResultSet</code> object;
   <code>false</code> if it is an update count or there are no more results
 @see #execute
}
function TZAbstractODBCStatement.GetMoreResults: Boolean;
var
  ColumnCount: SQLSMALLINT;
  RowCount: SQLLEN;
  RETCODE: SQLRETURN;
  RS: IZResultSet;
  AnyValue: IZAnyValue;
begin
  Result := False;
  if FCallResultCache <> nil then begin
    Result := FCallResultCache.Count > 0;
    if Result then begin
      if Supports(FCallResultCache[0], IZResultSet, RS) then begin
        LastResultSet := RS;
        LastUpdateCount := -1;
      end else begin
        FCallResultCache[0].QueryInterface(IZAnyValue, AnyValue);
        LastUpdateCount := AnyValue.GetInteger;
        LastResultSet := nil;
      end;
      FCallResultCache.Delete(0);
    end;
  end else if Connection.GetMetadata.GetDatabaseInfo.SupportsMultipleResultSets then begin
    RETCODE := fPlainDriver.SQLMoreResults(fHSTMT);
    if RETCODE = SQL_SUCCESS then begin
      Result := True;
      fMoreResultsIndicator := mriHasMoreResults;
      CheckStmtError(fPlainDriver.SQLNumResultCols(fHSTMT, @ColumnCount));
      if ColumnCount > 0
      then LastResultSet := GetCurrentResultSet
      else begin
        CheckStmtError(fPlainDriver.SQLRowCount(fHSTMT, @RowCount));
        LastUpdateCount := RowCount;
      end;
    end else if RETCODE = SQL_NO_DATA then begin
      if fMoreResultsIndicator <> mriHasMoreResults then
        fMoreResultsIndicator := mriHasNoMoreResults;
    end else
      CheckStmtError(RETCODE);
  end;
end;

procedure TZAbstractODBCStatement.HandleError(RETCODE: SQLRETURN;
  Handle: SQLHANDLE; HandleType: SQLSMALLINT);
begin
  CheckODBCError(RETCODE, Handle, HandleType, SQL, Self, FODBCConnection);
end;

procedure TZAbstractODBCStatement.InternalBeforePrepare;
begin
  if FCallResultCache <> nil then
    ClearCallResultCache;
  if not Assigned(fHSTMT) then begin
    CheckDbcError(fPlainDriver.SQLAllocHandle(SQL_HANDLE_STMT, fPHDBC^, fHSTMT));
    CheckStmtError(fPlainDriver.SQLSetStmtAttr(fHSTMT, SQL_ATTR_QUERY_TIMEOUT, SQLPOINTER(fStmtTimeOut), 0));
    fMoreResultsIndicator := mriUnknown;
    FHandleState := hsAllocated;
  end;
end;

function TZAbstractODBCStatement.InternalCreateResultSet: IZResultSet;
begin
  if (FClientEncoding = ceUTF16)
  then Result := TODBCResultSetW.Create(Self, fHSTMT, fPHDBC^, SQL, FODBCConnection,
    fZBufferLength, ChunkSize, FEnhancedColInfo)
  else Result := TODBCResultSetA.Create(Self, fHSTMT, fPHDBC^, SQL, FODBCConnection,
    fZBufferLength, ChunkSize, FEnhancedColInfo);
end;

procedure TZAbstractODBCStatement.InternalExecute;
  procedure MoveLateBoundData(var RETCODE: SQLRETURN);
  var I,l: Integer;
    ValuePtr: PIZLob;
    Buf: PAnsiChar; //simple to increment by compiler
    StrLen_or_Ind: SQLLEN;
  begin
    while RETCODE = SQL_NEED_DATA do begin
      RETCODE := fPlainDriver.SQLParamData(fHSTMT, @ValuePtr);
      if RetCode <> SQL_NEED_DATA then break;
      Assert(Assigned(ValuePtr), 'wrong descriptor token');
      {$R-}
      if (ValuePtr^ = nil) or ValuePtr^.IsEmpty
      then CheckStmtError(fPlainDriver.SQLPutData(fHSTMT, nil, SQL_NULL_DATA)) //set to null
      else begin
        Buf := ValuePtr^.GetBuffer;
        { put data chunked }
        L := ValuePtr^.Length;
        StrLen_or_Ind := Min(ChunkSize, L);
        for i := 1 to L div ChunkSize do begin
          CheckStmtError(fPlainDriver.SQLPutData(fHSTMT, Buf, StrLen_or_Ind));
          Inc(Buf, ChunkSize);
        end;
        StrLen_or_Ind := ValuePtr^.Length - NativeInt(({%H-}NativeUInt(Buf)-{%H-}NativeUInt(ValuePtr^.GetBuffer)));
        CheckStmtError(fPlainDriver.SQLPutData(fHSTMT, Buf, StrLen_or_Ind)); //final chunk
      end;
      {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    end;
  end;
  procedure FetchLateBoundData(var RETCODE: SQLRETURN);
  begin
    while RETCODE = SQL_PARAM_DATA_AVAILABLE do begin
//      CheckStmtError(fPlainDriver.SQLGetData(fPHSTMT^, ColumnIndex+1, ODBC_CType,
//        ColumnBuffer, CharOctedLength, StrLen_or_IndPtr))
    end;
  end;
begin
//  CheckStmtError(fPlainDriver.SQLFreeStmt(fHSTMT,SQL_CLOSE)); //handle a get data issue
  if DriverManager.HasLoggingListener then
    DriverManager.LogMessage(lcExecute, ConSettings^.Protocol, ASQL);
  if BindList.HasOutOrInOutOrResultParam then //first test with ExecuteDirect
    if FHandleState = hsPrepared then begin
      CheckStmtError(fPlainDriver.SQLFreeStmt(fHSTMT,SQL_CLOSE));
      FExecRETCODE := ExecutDirect;
      FHandleState := hsExecuteDirect;
    end else begin
      if FHandleState = hsExecuteDirect then begin
        InternalPrepare;
        FHandleState := hsExecute;
      end;
      FExecRETCODE := fPlainDriver.SQLExecute(fHSTMT)
    end
  else if Ord(FHandleState) >= Ord(hsPrepared) then begin
    FExecRETCODE := fPlainDriver.SQLExecute(fHSTMT);
    FHandleState := hsExecute;
  end else
    FExecRETCODE := ExecutDirect;
  if FExecRETCODE = SQL_NEED_DATA then
    MoveLateBoundData(FExecRETCODE)
  else if (FExecRETCODE = SQL_PARAM_DATA_AVAILABLE) then
    FetchLateBoundData(FExecRETCODE);
  if BindList.HasOutOrInOutOrResultParam then
    FetchCallResults;
  if not FExecRETCODE in [SQL_NO_DATA, SQL_SUCCESS] then
    CheckStmtError(FExecRETCODE);
end;

procedure TZAbstractODBCStatement.InternalPrepare;
begin
  FHandleState := hsExecuteDirect;
end;

procedure TZAbstractODBCStatement.Prepare;
begin
  if FCallResultCache <> nil then
    ClearCallResultCache;
  if not Assigned(fHSTMT) then begin
    CheckDbcError(fPlainDriver.SQLAllocHandle(SQL_HANDLE_STMT, fPHDBC^, fHSTMT));
    CheckStmtError(fPlainDriver.SQLSetStmtAttr(fHSTMT, SQL_ATTR_QUERY_TIMEOUT, SQLPOINTER(fStmtTimeOut), 0));
    fMoreResultsIndicator := mriUnknown;
    FHandleState := hsAllocated;
  end;
  if not Prepared then begin
    {EH commented!
     this options means performance loss even if docs explain it vice versa:
     https://docs.microsoft.com/en-us/sql/relational-databases/native-client-odbc-api/sqlsetstmtattr?view=sql-server-2017
    if Connection.GetServerProvider = spMSSQL then
      CheckStmtError(FPlainDriver.SQLSetStmtAttr(fHSTMT, SQL_SOPT_SS_CURSOR_OPTIONS, Pointer(SQL_CO_FFO),0));}
    InternalPrepare;
    inherited Prepare;
  end else if Ord(FHandleState) <> Ord(hsAllocated) then
    if Assigned(fHSTMT) and Assigned(fPHDBC^) then
      CheckStmtError(fPlainDriver.SQLFreeStmt(fHSTMT,SQL_CLOSE));
end;

procedure TZAbstractODBCStatement.PrepareOpenedResultSetsForReusing;
begin
  if Assigned(FOpenResultSet) then
    if fMoreResultsIndicator = mriHasMoreResults
    then IZResultSet(FOpenResultSet).Close
    else IZResultSet(FOpenResultSet).ResetCursor;
  if Assigned(LastResultSet) then
    if fMoreResultsIndicator <> mriHasMoreResults
    then LastResultSet.ResetCursor
    else begin
      LastResultSet.Close;
      LastResultSet := nil;
    end;
end;

procedure TZAbstractODBCStatement.ReleaseConnection;
begin
  inherited ReleaseConnection;
  FODBCConnection := nil;
end;

function TZAbstractODBCStatement.SupportsSingleColumnArrays: Boolean;
begin
  Result := FODBCConnection.GetArraySelectSupported;
end;

procedure TZAbstractODBCStatement.Unprepare;
begin
  inherited Unprepare;
  if FCallResultCache <> nil then
    ClearCallResultCache;
  if Assigned(fHSTMT) then begin
    FHandleState := hsNone;
    CheckStmtError(fPlainDriver.SQLFreeHandle(SQL_HANDLE_STMT, fHSTMT)); //<- does the trick to get a instance reused
    fHSTMT := nil;
  end;
end;

{ TZODBCPreparedStatementW }

function TZODBCPreparedStatementW.ExecutDirect: RETCODE;
begin
  Result := TODBC3UnicodePlainDriver(fPlainDriver).SQLExecDirectW(fHSTMT, Pointer(WSQL), Length(WSQL))
end;

function TZODBCPreparedStatementW.GetUnicodeEncodedSQL(
  const SQL: {$IF defined(FPC) and defined(WITH_RAWBYTESTRING)}RawByteString{$ELSE}String{$IFEND}): ZWideString;
var I: Integer;
  {$IFNDEF UNICODE}SQLWriter: TZUnicodeSQLStringWriter;{$ENDIF}
begin
  if Length(FCachedQueryUni) = 0 then begin
    FCachedQueryUni := ZDbcUtils.TokenizeSQLQueryUni(SQL, ConSettings,
      Connection.GetDriver.GetTokenizer, FIsParamIndex, nil,
      @DefaultPreparableTokens, FTokenMatchIndex);
    FCountOfQueryParams := 0;
    Result := ''; //init Result
    {$IFNDEF UNICODE}SQLWriter := TZUnicodeSQLStringWriter.Create(Length(SQL));{$ENDIF}
    for I := 0 to High(FCachedQueryUni) do begin
      {$IFNDEF UNICODE}SQLWriter.AddText(FCachedQueryUni[i], Result);{$ENDIF}
      Inc(FCountOfQueryParams, Ord(FIsParamIndex[i]));
    end;
    {$IFNDEF UNICODE}
    SQLWriter.Finalize(Result);
    FreeAndNil(SQLWriter);
    {$ELSE}
    Result := SQL;
    {$ENDIF}
    SetBindCapacity(FCountOfQueryParams);
  end else
    Result := inherited GetUnicodeEncodedSQL(SQL);
end;

procedure TZODBCPreparedStatementW.InternalPrepare;
begin
  fDEFERPREPARE := StrToBoolEx(ZDbcUtils.DefineStatementParameter(Self, DSProps_PreferPrepared, 'True')) and (FTokenMatchIndex <> -1);
  if fDEFERPREPARE then begin
    CheckStmtError(TODBC3UnicodePlainDriver(fPlainDriver).SQLPrepareW(fHSTMT, Pointer(WSQL), Length(WSQL)));
    FHandleState := hsPrepared;
    fBindImmediat := True;
  end else
    fBindImmediat := False;
end;

procedure TZODBCPreparedStatementW.Unprepare;
begin
  inherited;
  SetLength(FCachedQueryUni, 0);
end;

{ TZODBCPreparedStatementA }

function TZODBCPreparedStatementA.ExecutDirect: RETCODE;
begin
  Result := TODBC3RawPlainDriver(fPlainDriver).SQLExecDirect(fHSTMT, Pointer(ASQL), Length(ASQL));
end;

function TZODBCPreparedStatementA.GetRawEncodedSQL(
  const SQL: {$IF defined(FPC) and defined(WITH_RAWBYTESTRING)}RawByteString{$ELSE}String{$IFEND}): RawByteString;
var I: Integer;
  SQLWriter: TZRawSQLStringWriter;
begin
  if FCachedQueryRaw = nil then begin
    FCachedQueryRaw := ZDbcUtils.TokenizeSQLQueryRaw(SQL, ConSettings,
      Connection.GetDriver.GetTokenizer, FIsParamIndex, nil,
      @DefaultPreparableTokens, FTokenMatchIndex);
    FCountOfQueryParams := 0;
    Result := EmptyRaw; //init Result
    SQLWriter := TZRawSQLStringWriter.Create(Length(SQL));
    for I := 0 to High(FCachedQueryRaw) do begin
      SQLWriter.AddText(FCachedQueryRaw[i], Result);
      Inc(FCountOfQueryParams, Ord(FIsParamIndex[i]));
    end;
    SQLWriter.Finalize(Result);
    FreeAndNil(SQLWriter);
    SetBindCapacity(FCountOfQueryParams);
  end else
    Result := Inherited GetRawEncodedSQL(SQL);
end;

procedure TZODBCPreparedStatementA.InternalPrepare;
begin
  fDEFERPREPARE := StrToBoolEx(ZDbcUtils.DefineStatementParameter(Self, DSProps_PreferPrepared, 'True')) and (FTokenMatchIndex <> -1);
  if fDEFERPREPARE then begin
    CheckStmtError(TODBC3RawPlainDriver(fPlainDriver).SQLPrepare(fHSTMT, Pointer(ASQL), Length(ASQL)));
    FHandleState := hsPrepared;
    fBindImmediat := True;
  end else
    fBindImmediat := False;
end;

procedure TZODBCPreparedStatementA.Unprepare;
begin
  inherited;
  SetLength(FCachedQueryRaw, 0);
end;

{ TZAbstractODBCPreparedStatement }

procedure TZAbstractODBCPreparedStatement.BindSInteger(Index: Integer;
  SQLType: TZSQLType; Value: NativeInt);
var Bind: PZODBCParamBind;
begin
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    {$R-}
    Bind := @fParamBindings[Index];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    if (Bind.ParameterValuePtr = nil) or (Bind.ValueCount <> 1) or (not Bind.Described and (SQLType <> Bind.SQLType)) then
      InitBind(Index, 1, SQLType);
    case Bind.ValueType of
      SQL_C_BIT:      PByte(Bind.ParameterValuePtr)^     := Ord(Value <> 0);
      SQL_C_STINYINT: PShortInt(Bind.ParameterValuePtr)^ := ShortInt(Value);
      SQL_C_UTINYINT: PByte(Bind.ParameterValuePtr)^     := Byte(Value);
      SQL_C_SSHORT:   PSmallInt(Bind.ParameterValuePtr)^ := SmallInt(Value);
      SQL_C_USHORT:   PWord(Bind.ParameterValuePtr)^     := Word(Value);
      SQL_C_SLONG:    PInteger(Bind.ParameterValuePtr)^  := Integer(Value);
      SQL_C_ULONG:    PCardinal(Bind.ParameterValuePtr)^ := Cardinal(Value);
      SQL_C_SBIGINT:  PInt64(Bind.ParameterValuePtr)^    := Value;
      SQL_C_UBIGINT:  PUInt64(Bind.ParameterValuePtr)^   := UInt64(Value);
      SQL_C_TYPE_DATE, SQL_C_DATE,
      SQL_C_TYPE_TIME, SQL_C_TIME, SQL_C_SS_TIME2,
      SQL_C_TIMESTAMP, SQL_C_TYPE_TIMESTAMP, SQL_C_SS_TIMESTAMPOFFSET,
      SQL_C_FLOAT, SQL_C_DOUBLE: InternalBindDouble(Index, SQLType, Value);
      SQL_C_NUMERIC:  Curr2ODBCNumeric(Value, Bind.ParameterValuePtr);
      SQL_C_WCHAR:  begin
                      IntToUnicode(Value, @fWBuffer[SizeOf(Pointer)], @fWBuffer[0]);
                      SetPWideChar(Index, @fWBuffer[SizeOf(Pointer)], ZPPWideChar(@fWBuffer[0])^-PWideChar(@fWBuffer[SizeOf(Pointer)]));
                      Exit;
                    end;
      SQL_C_CHAR:   begin
                      IntToRaw(Value, @fABuffer[SizeOf(Pointer)], @fABuffer[0]);
                      SetPAnsiChar(Index, @fABuffer[SizeOf(Pointer)], PPAnsiChar(@fABuffer[0])^-PAnsiChar(@fABuffer[SizeOf(Pointer)]));
                      Exit;
                    end;
      else RaiseUnsupportedParamType(Index, Bind.ValueType, SQLType);
    end;
    PSQLLEN(Bind.StrLen_or_IndPtr)^ := SQL_NO_NULLS;
  end else
    BindList.Put(Index, SQLType, {$IFNDEF CPU64}P4Bytes{$ELSE}P8Bytes{$ENDIF}(@Value));
end;

const
  ODBCSQLTypeOrdinalMatrix: array[stBoolean..stDouble] of SQLSmallInt = (
    SQL_BIT,
    SQL_TINYINT, SQL_TINYINT, SQL_SMALLINT, SQL_SMALLINT, SQL_INTEGER, SQL_INTEGER, SQL_BIGINT, SQL_BIGINT,
    SQL_FLOAT, SQL_DOUBLE);

procedure TZAbstractODBCPreparedStatement.BindArrayColumnWise(Index: Integer);
var ArrayLen, MaxL, I: Integer;
  Arr: PZArray;
  DA: Pointer;
  P: PAnsiChar;
  SQL_DATE_STRUCT: PSQL_DATE_STRUCT absolute P;
  SQL_TIME_STRUCT: PSQL_TIME_STRUCT absolute P;
  SQL_SS_TIME2_STRUCT: PSQL_SS_TIME2_STRUCT absolute P;
  SQL_SS_TIMESTAMPOFFSET_STRUCT: PSQL_SS_TIMESTAMPOFFSET_STRUCT absolute P;
  SQL_TIMESTAMP_STRUCT: PSQL_TIMESTAMP_STRUCT absolute P;
  ParamDataLobs: PLobArray absolute P;
  TS: TZTimeStamp;
  D: TZDate absolute TS;
  T: TZTime absolute TS;
  PD: PZDate;
  PT: PZTime absolute PD;
  PTS: PZTimeStamp absolute PD;
  N: PSQLLENArray;
  Bind: PZODBCParamBind;
  SQLType: TZSQLType;
  Native, BindAgain: Boolean;
  DT: TDateTime;
{$R-}
  Procedure BindRawStrings(CP: Word);
  var I, B: Integer;
  begin
    if FClientEncoding = ceUTF16 then begin
      MaxL := (Bind.BufferLength shr 1) -1;
      for I := 0 to ArrayLen -1 do begin
        if IsNullFromArray(Arr, I)
        then N[I] := SQL_NULL_DATA
        else begin
          B := ZEncoding.PRaw2PUnicode(Pointer(TRawByteStringDynArray(DA)[i]), PWideChar(P), CP, LengthInt(Length(TRawByteStringDynArray(DA)[i])), LengthInt(MaxL)) shl 1;
          if B < Bind.BufferLength then begin
            PWord(P+B)^ := 0;
            N[I] := B;
          end else
            RaiseExceeded(Index);
        end;
        Inc(P, Bind.BufferLength);
      end;
    end else begin
      MaxL := Bind.BufferLength-1;
      if CP = FClientCP then
        for I := 0 to ArrayLen -1 do begin
          if IsNullFromArray(Arr, I)
          then N[I] := SQL_NULL_DATA
          else begin
            B := Length(TRawByteStringDynArray(DA)[i]);
            if B <= MaxL then begin
              if B > 0
              then Move(Pointer(TRawByteStringDynArray(DA)[i])^, P^, B+1)
              else PByte(P)^ := 0;
              N[I] := B;
            end else
              RaiseExceeded(Index)
          end;
          Inc(P, Bind.BufferLength);
        end
      else
        for I := 0 to ArrayLen -1 do begin
          if IsNullFromArray(Arr, I)
          then N[I] := SQL_NULL_DATA
          else begin
            B := ZEncoding.PRawToPRawBuf(Pointer(TRawByteStringDynArray(DA)[i]), P,
              Length(TRawByteStringDynArray(DA)[i]), MaxL, CP, FClientCP);
            if B <= MaxL then begin
              PByte(P+B)^ := 0;
              N[I] := B;
            end else
              RaiseExceeded(Index)
          end;
          Inc(P, Bind.BufferLength);
        end
    end;
  end;
  procedure BinLobs;
  var I: Integer;
    TmpLob: IZBlob;
  begin
    case SQLtype of
      stString,
      stUnicodeString: for I := 0 to ArrayLen-1 do begin
                        if IsNullFromArray(Arr, I) then begin
                          ParamDataLobs[I] := nil;
                        end else begin
                          case Arr.VArrayVariantType of
                            {$IFDEF UNICODE}vtString,{$ENDIF}
                            vtUnicodeString: ParamDataLobs[I] :=
                              TZAbstractClob.CreateWithData(Pointer(TUnicodeStringDynArray(DA)[i]),
                              Length(TUnicodeStringDynArray(DA)[i]), ConSettings);
                            vtCharRec: if TZCharRecDynArray(DA)[i].CP = zCP_UTF16
                              then ParamDataLobs[I] :=
                                TZAbstractClob.CreateWithData(TZCharRecDynArray(DA)[i].P,
                                  TZCharRecDynArray(DA)[i].Len, ConSettings)
                              else ParamDataLobs[I] :=
                                TZAbstractClob.CreateWithData(TZCharRecDynArray(DA)[i].P,
                                  TZCharRecDynArray(DA)[i].Len, TZCharRecDynArray(DA)[i].CP, ConSettings);
                            vtRawByteString: ParamDataLobs[I] :=
                                  TZAbstractClob.CreateWithData(Pointer(TRawByteStringDynArray(DA)[i]),
                                    Length(TRawByteStringDynArray(DA)[i]), FClientCP, ConSettings);
                            {$IFNDEF NO_UTF8STRING}
                            vtUTF8String: ParamDataLobs[I] :=
                              TZAbstractClob.CreateWithData(Pointer(TRawByteStringDynArray(DA)[i]),
                                  Length(TRawByteStringDynArray(DA)[i]), zCP_UTF8, ConSettings);
                            {$ENDIF}
                            {$IFNDEF NO_ANSISTRING}
                            vtAnsiString: ParamDataLobs[I] :=
                              TZAbstractClob.CreateWithData(Pointer(TRawByteStringDynArray(DA)[i]),
                                  Length(TRawByteStringDynArray(DA)[i]), ZOSCodePage, ConSettings);
                            {$ENDIF}
                            {$IFNDEF UNICODE}
                            vtString: if ConSettings^.AutoEncode then
                                        ParamDataLobs[I] :=
                                          TZAbstractClob.CreateWithData(Pointer(TRawByteStringDynArray(DA)[i]),
                                              Length(TRawByteStringDynArray(DA)[i]), zCP_None, ConSettings)
                                      else
                                        ParamDataLobs[I] :=
                                          TZAbstractClob.CreateWithData(Pointer(TRawByteStringDynArray(DA)[i]),
                                              Length(TRawByteStringDynArray(DA)[i]), FClientCP, ConSettings);
                            {$ENDIF}
                            else
                              raise EZSQLException.Create('Unsupported String Variant');
                          end;
                          if FClientEncoding = ceUTF16
                          then ParamDataLobs^[I].GetPWideChar
                          else ParamDataLobs[I].GetPAnsiChar(FClientCP);
                        end;
                        N[I] := SQL_DATA_AT_EXEC;
                      end;
      stBytes:          for I := 0 to ArrayLen-1 do begin
                          if (TBytesDynArray(DA)[i] = nil) or IsNullFromArray(Arr, I)
                          then  ParamDataLobs[I] := nil
                          else  ParamDataLobs[I] := TZAbstractBlob.CreateWithData(Pointer(TBytesDynArray(DA)[i]),
                            Length(TBytesDynArray(DA)[i]));
                          N[I] := SQL_DATA_AT_EXEC;
                        end;
      stAsciiStream, stUnicodeStream,
      stBinaryStream: begin
                        for I := 0 to ArrayLen-1 do begin
                          if (TInterfaceDynArray(DA)[i] <> nil) and (TInterfaceDynArray(DA)[i].QueryInterface(IZBlob, TmpLob) = S_OK) and not TmpLob.IsEmpty then begin
                            if not (Bind.SQLtype = stBinaryStream) then begin
                              if TmpLob.IsClob then
                                if FClientEncoding = ceUTF16 then
                                  TmpLob.GetPWideChar
                                else TmpLob.GetPAnsiChar(FClientCP)
                              else
                                raise Exception.Create('Fehlermeldung');
                            end;
                            ParamDataLobs[I] := TmpLob;
                          end else
                            ParamDataLobs[I] := nil;
                          N[I] := SQL_DATA_AT_EXEC;
                        end;
                      end;
      else Raise EZUnsupportedException.Create(SUnsupportedOperation);
    end;
  end;
begin
  Bind := @fParamBindings[Index];
  Arr := BindList[Index].Value;
  DA := Arr.VArray;
  ArrayLen := {%H-}PArrayLenInt({%H-}NativeUInt(DA) - ArrayLenOffSet)^{$IFDEF FPC}+1{$ENDIF}; //FPC returns High() for this pointer location
  SQLType := TZSQLType(Arr.VArrayType);
  if not Bind.Described  then
    if (Ord(SQLType) < Ord(stString)) then begin
      Bind.ParameterType := ConvertSQLTypeToODBCType(SQLType, Bind.ValueType, FClientEncoding);
      MaxL := CalcBufSize(0, Bind.ValueType, SQLType, ConSettings.ClientCodePage)
    end else if (Ord(SQLType) > Ord(stBytes)) then
      MaxL := 0 //streams
    else begin
      MaxL := 0;
      case Arr.VArrayVariantType of
        {$IFDEF UNICODE}vtString,{$ENDIF}
        vtUnicodeString: for I := 0 to ArrayLen -1 do
                            MaxL := Max(MaxL, Length(TUnicodeStringDynArray(DA)[i])*
                              (ConSettings.ClientCodePage.CharWidth*Ord(FClientEncoding <> ceUTF16)));
        {$IFNDEF UNICODE}vtString,{$ENDIF}
        {$IFNDEF NO_ANSISTRING}vtAnsiString,{$ENDIF}
        {$IFNDEF NO_UTF8STRING}vtUTF8String,{$ENDIF}
        vtRawByteString: for I := 0 to ArrayLen -1 do
                            MaxL := Max(MaxL, Length(TRawByteStringDynArray(DA)[i]));
        vtCharRec:       for I := 0 to ArrayLen -1 do
                            MaxL := Max(MaxL, Integer(TZCharRecDynArray(DA)[i].Len)*
                              (ConSettings.ClientCodePage.CharWidth*Ord((FClientEncoding <> ceUTF16) and (TZCharRecDynArray(DA)[i].CP = zCP_UTF16))));
        vtBytes:         for I := 0 to ArrayLen -1 do
                            MaxL := Max(MaxL, Length(TBytesDynArray(DA)[i]));
      end;
    end
  else MaxL := Bind.BufferLength;
  Native := (Arr.VArrayVariantType = vtNull) and
          (Ord(Bind.SQLType) >= Ord(stBoolean)) and (Ord(SQLType) >= Ord(stBoolean)) and (
          (((Ord(Bind.SQLType) <= Ord(stDouble)) and (Ord(SQLType) <= Ord(stDouble))) and (ODBCSQLTypeOrdinalMatrix[Bind.SQLType] = ODBCSQLTypeOrdinalMatrix[SQLType])) or
          ((Bind.SQLType = stGUID) and (SQLType = stGUID)));
  BindAgain := False;
  if Native and (ArrayLen > 1) then begin
    InitBind(Index, 0, SQLType, MaxL);
    Bind.ParameterValuePtr := DA;
    Bind.ValueCount := ArrayLen;
    GetMem(Bind.StrLen_or_IndPtr, ArrayLen * SizeOf(SQLLEN));
    BindAgain := True;
    N := PSQLLENArray(Bind.StrLen_or_IndPtr);
    if Arr.VIsNullArray <> nil then
      for I := 0 to ArrayLen -1 do
        N[I] := NullInd[IsNullFromArray(Arr, I)]
    else FillChar(N[0], SizeOf(SQLLEN)*ArrayLen, #0);
  end else begin
    if (Bind.ParameterValuePtr = nil) or (Bind.ValueCount <> ArrayLen) or (not Bind.Described and (Bind.SQLType <> SQLType)) then
      InitBind(Index, ArrayLen, SQLType, MaxL);
    N := PSQLLENArray(Bind.StrLen_or_IndPtr);
    P := Bind.ParameterValuePtr;
    case Bind.SQLType of
      stBoolean:      for I := 0 to ArrayLen -1 do begin
                        PByte(P+I)^ := Ord(ArrayValueToBoolean(Arr, I));
                        N[I] := NullInd[IsNullFromArray(Arr, I)];
                      end;
      stByte:         for I := 0 to ArrayLen -1 do begin
                        PByte(P+I)^ := ArrayValueToCardinal(Arr, I);
                        N[I] := NullInd[IsNullFromArray(Arr, I)];
                      end;
      stShort:        for I := 0 to ArrayLen -1 do begin
                        PShortInt(P+I)^ := ArrayValueToCardinal(Arr, I);
                        N[I] := NullInd[IsNullFromArray(Arr, I)];
                      end;
      stWord:         for I := 0 to ArrayLen -1 do begin
                        PWord(P+(I*SizeOf(Word)))^ := ArrayValueToCardinal(Arr, I);
                        N[I] := NullInd[IsNullFromArray(Arr, I)];
                      end;
      stSmall:        for I := 0 to ArrayLen -1 do begin
                        PSmallInt(P+(I*SizeOf(SmallInt)))^ := ArrayValueToInteger(Arr, I);
                        N[I] := NullInd[IsNullFromArray(Arr, I)];
                      end;
      stLongWord:     for I := 0 to ArrayLen -1 do begin
                        PCardinal(P+(I*SizeOf(Cardinal)))^ := ArrayValueToCardinal(Arr, I);
                        N[I] := NullInd[IsNullFromArray(Arr, I)];
                      end;
      stInteger:      for I := 0 to ArrayLen -1 do begin
                        PInteger(P+(I*SizeOf(Integer)))^ := ArrayValueToInteger(Arr, I);
                        N[I] := NullInd[IsNullFromArray(Arr, I)];
                      end;
      stULong:        for I := 0 to ArrayLen -1 do begin
                        PUInt64(P+(I*SizeOf(UInt64)))^ := ArrayValueToUInt64(Arr, I);
                        N[I] := NullInd[IsNullFromArray(Arr, I)];
                      end;
      stLong:         for I := 0 to ArrayLen -1 do begin
                        PInt64(P+(I*SizeOf(Int64)))^ := ArrayValueToInt64(Arr, I);
                        N[I] := NullInd[IsNullFromArray(Arr, I)];
                      end;
      stFloat:       for I := 0 to ArrayLen -1 do begin
                        PSingle(P+(I*SizeOf(Single)))^ := ArrayValueToDouble(Arr, I);
                        N[I] := NullInd[IsNullFromArray(Arr, I)];
                      end;
      stDouble:       for I := 0 to ArrayLen -1 do begin
                        PDouble(P+(I*SizeOf(Double)))^ := ArrayValueToDouble(Arr, I);
                        N[I] := NullInd[IsNullFromArray(Arr, I)];
                      end;
      stCurrency:     for I := 0 to ArrayLen -1 do begin
                        Curr2ODBCNumeric(ArrayValueToCurrency(Arr, I), PSQL_NUMERIC_STRUCT(P+(I*SizeOf(TSQL_NUMERIC_STRUCT))));
                        N[I] := NullInd[IsNullFromArray(Arr, I)];
                      end;
      stBigDecimal:   for I := 0 to ArrayLen -1 do begin
                        ArrayValueToBCD(Arr, i, PBCD(@fWBuffer[0])^);
                        BCD2SQLNumeric(PBCD(@fWBuffer[0])^, Pointer(P+(I*SizeOf(TSQL_NUMERIC_STRUCT))));
                        N[I] := NullInd[IsNullFromArray(Arr, I)];
                      end;
      stDate:         for I := 0 to ArrayLen -1 do begin
                        if IsNullFromArray(Arr, I) then
                          N[I] := SQL_NULL_DATA
                        else begin
                          if (Arr.VArrayVariantType in [vtNull, vtDateTime]) then begin
                            DecodeDateTimeToDate(TDateTimeDynArray(DA)[i], D);
                            PD := @D;
                          end else if Arr.VArrayVariantType = vtDate then
                            PD := @TZDateDynArray(DA)[i]
                          else begin
                            DT := ArrayValueToDate(Arr, I, ConSettings^.WriteFormatSettings);
                            DecodeDateTimeToDate(DT, D);
                            PD := @D;
                          end;
                          SQL_DATE_STRUCT.year := PD.Year;
                          if D.IsNegative then
                            SQL_DATE_STRUCT^.year := -SQL_DATE_STRUCT^.year;
                          SQL_DATE_STRUCT^.month := PD.Month;
                          SQL_DATE_STRUCT^.day := PD.Day;
                          N[I] := SQL_NO_NULLS;
                        end;
                        Inc(P, SizeOf(TSQL_DATE_STRUCT));
                      end;
      stTime:         for I := 0 to ArrayLen -1 do begin
                        if IsNullFromArray(Arr, I) then
                          N[I] := SQL_NULL_DATA
                        else begin
                          if (Arr.VArrayVariantType in [vtNull, vtDateTime]) then begin
                            DecodeDateTimeToTime(TDateTimeDynArray(DA)[i], T);
                            PT := @T;
                          end else if Arr.VArrayVariantType = vtDate then
                            PT := @TZTimeDynArray(DA)[i]
                          else begin
                            DT := ArrayValueTotime(Arr, I, ConSettings^.WriteFormatSettings);
                            DecodeDateTimeToTime(DT, T);
                            PT := @T;
                          end;
                          if Bind.ValueType = SQL_C_SS_TIME2 then begin
                            SQL_SS_TIME2_STRUCT.hour := PT.Hour;
                            SQL_SS_TIME2_STRUCT.minute := PT.Minute;
                            SQL_SS_TIME2_STRUCT.second := PT.Second;
                            SQL_SS_TIME2_STRUCT.fraction := PT.Fractions
                          end else begin
                            SQL_TIME_STRUCT.hour := PT.Hour;
                            SQL_TIME_STRUCT.minute := PT.Minute;
                            SQL_TIME_STRUCT.second := PT.Second;
                          end;
                          N[I] := SQL_NO_NULLS;
                        end;
                        if Bind.ValueType = SQL_C_SS_TIME2
                        then Inc(P, SizeOf(TSQL_SS_TIME2_STRUCT))
                        else Inc(P, SizeOf(TSQL_TIME_STRUCT));
                      end;
      stTimeStamp:    for I := 0 to ArrayLen -1 do begin
                        if IsNullFromArray(Arr, I) then
                          N[I] := SQL_NULL_DATA
                        else begin
                          if (Arr.VArrayVariantType in [vtNull, vtDateTime]) then begin
                            DecodeDateTimeToTimeStamp(TDateTimeDynArray(DA)[i], TS);
                            PTS := @TS;
                          end else if Arr.VArrayVariantType = vtTimeStamp then
                            PTS := @TZTimeStampDynArray(DA)[i]
                          else begin
                            DT := ArrayValueToDatetime(Arr, I, ConSettings^.WriteFormatSettings);
                            DecodeDateTimeToTimeStamp(DT, TS);
                            PTS := @TS;
                          end;
                          if Bind.ValueType = SQL_C_SS_TIMESTAMPOFFSET then begin
                            SQL_SS_TIMESTAMPOFFSET_STRUCT.year := Ts.Year;
                            if Ts.IsNegative then
                              SQL_SS_TIMESTAMPOFFSET_STRUCT.year := -SQL_SS_TIMESTAMPOFFSET_STRUCT.year;
                            SQL_SS_TIMESTAMPOFFSET_STRUCT.month := PTS.Month;
                            SQL_SS_TIMESTAMPOFFSET_STRUCT.day := PTS.Day;
                            SQL_SS_TIMESTAMPOFFSET_STRUCT.hour := PTS.Hour;
                            SQL_SS_TIMESTAMPOFFSET_STRUCT.minute := PTS.Minute;
                            SQL_SS_TIMESTAMPOFFSET_STRUCT.second := PTS.Second;
                            SQL_SS_TIMESTAMPOFFSET_STRUCT.fraction := PTS.Fractions;
                            SQL_SS_TIMESTAMPOFFSET_STRUCT.timezone_hour := PTS.TimeZoneHour;
                            SQL_SS_TIMESTAMPOFFSET_STRUCT.timezone_minute := PTS.TimeZoneMinute;
                          end else begin
                            SQL_TIMESTAMP_STRUCT.year := PTS.Year;
                            if Ts.IsNegative then
                              SQL_TIMESTAMP_STRUCT.year := -SQL_TIMESTAMP_STRUCT.year;
                            SQL_TIMESTAMP_STRUCT.month := PTS.Month;
                            SQL_TIMESTAMP_STRUCT.day := PTS.Day;
                            SQL_TIMESTAMP_STRUCT.hour := PTS.Hour;
                            SQL_TIMESTAMP_STRUCT.minute := PTS.Minute;
                            SQL_TIMESTAMP_STRUCT.second := PTS.Second;
                            SQL_TIMESTAMP_STRUCT.fraction := PTS.Fractions;
                          end;
                          N[I] := SQL_NO_NULLS;
                        end;
                        if Bind.ValueType = SQL_C_SS_TIMESTAMPOFFSET
                        then Inc(P, SizeOf(TSQL_SS_TIMESTAMPOFFSET_STRUCT))
                        else Inc(P, SizeOf(TSQL_TIMESTAMP_STRUCT));
                      end;
      stGUID:         for I := 0 to ArrayLen -1 do begin
                        ArrayValueToGUID(Arr, I, PGUID(P+(I*SizeOf(TGUID))));
                        N[I] := NullInd[IsNullFromArray(Arr, I)];
                      end;
      stString, stUnicodeString:
        case Arr.VArrayVariantType of
          {$IFDEF UNICODE}vtString,{$ENDIF}
          vtUnicodeString:  if FClientEncoding = ceUTF16 then
                              for I := 0 to ArrayLen -1 do begin
                                if IsNullFromArray(Arr, I) then
                                  N[I] := SQL_NULL_DATA
                                else begin
                                  MaxL := Length(TUnicodeStringDynArray(DA)[i]) shl 1;
                                  if MaxL < Bind.BufferLength then begin
                                    Move(Pointer(TUnicodeStringDynArray(DA)[i])^, P^, MaxL+2);
                                    N[I] := MaxL;
                                  end else
                                    RaiseExceeded(Index);
                                end;
                                Inc(P, Bind.BufferLength);
                              end
                            else
                              for I := 0 to ArrayLen -1 do begin
                                if IsNullFromArray(Arr, I) then
                                  N[I] := SQL_NULL_DATA
                                else begin
                                  MaxL := PUnicode2PRawBuf(Pointer(TUnicodeStringDynArray(DA)[i]),
                                    P, Length(TUnicodeStringDynArray(DA)[i]), Bind.BufferLength-1, FClientCP);
                                  if MaxL < Bind.BufferLength then begin
                                    Move(Pointer(TUnicodeStringDynArray(DA)[i])^, P^, MaxL +2);
                                    N[i] := MaxL;
                                    PByte(P+MaxL)^ := 0;
                                  end else
                                    RaiseExceeded(Index);
                                end;
                                Inc(P, Bind.BufferLength);
                              end;
          {$IFNDEF UNICODE}
          vtString: if ConSettings.AutoEncode then
                                     else BindRawStrings(FClientCP);
          {$ENDIF}
          {$IFNDEF NO_ANSISTRING}vtAnsiString: BindRawStrings(ZOSCodePage);{$ENDIF}
          {$IFNDEF NO_UTF8STRING}vtUTF8String: BindRawStrings(zCP_UTF8);{$ENDIF}
          vtRawByteString: BindRawStrings(FClientCP);
          vtCharRec:       for I := 0 to ArrayLen -1 do
                              MaxL := Max(MaxL, Integer(TZCharRecDynArray(DA)[i].Len));
        end;
      stBytes:              for I := 0 to ArrayLen -1 do begin
                              if IsNullFromArray(Arr, I)
                              then N[I] := SQL_NULL_DATA
                              else begin
                                MaxL := Length(TBytesDynArray(DA)[i]);
                                if MaxL <= Bind.BufferLength then begin
                                  if MaxL > 0
                                  then Move(Pointer(TBytesDynArray(DA)[i])^, P^, MaxL);
                                  N[I] := MaxL;
                                end else
                                  RaiseExceeded(Index)
                              end;
                              Inc(P, Bind.BufferLength);
                            end;
      stAsciiStream, stUnicodeStream, stBinaryStream: BinLobs;
    end;
  end;
  {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
  if BindAgain then
    BindParam(Bind, Index+1);
end;

procedure TZAbstractODBCPreparedStatement.BindInParameters;
var I: Integer;
begin
  if BindList.Count = 0 then
    exit;
  if (BatchDMLArrayCount > 0) then begin
    fLastAutoCommit := Connection.GetAutoCommit;
    for I := 0 to BindList.Count -1 do
      BindArrayColumnWise(I);
    if (fCurrentIterations <> NativeUInt(BatchDMLArrayCount)) then begin
      fCurrentIterations := BatchDMLArrayCount;
      CheckStmtError(fPlainDriver.SQLSetStmtAttr(fHSTMT, SQL_ATTR_PARAMSET_SIZE, SQLPOINTER(fCurrentIterations), 0));
    end;
  end else begin
    if (fCurrentIterations <> 1) then begin
      fCurrentIterations := 1;
      CheckStmtError(fPlainDriver.SQLSetStmtAttr(fHSTMT, SQL_ATTR_PARAMSET_SIZE, SQLPOINTER(fCurrentIterations), 0));
    end;
    if not fBindImmediat then begin
      DescribeParameterFromBindList;
      try
        fBindImmediat := True;
        BindList.BindValuesToStatement(Self);
      finally
        fBindImmediat := False;
      end;
    end;
  end;
  inherited BindInParameters;
end;

procedure TZAbstractODBCPreparedStatement.BindUInteger(Index: Integer;
  SQLType: TZSQLType; Value: NativeUInt);
var Bind: PZODBCParamBind;
begin
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    {$R-}
    Bind := @fParamBindings[Index];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    if (Bind.ParameterValuePtr = nil) or (Bind.ValueCount > 1) or (not Bind.Described and (SQLType <> Bind.SQLType)) then
      InitBind(Index, 1, SQLType);
    case Bind.ValueType of
      SQL_C_BIT:      PByte(Bind.ParameterValuePtr)^     := Ord(Value <> 0);
      SQL_C_STINYINT: PShortInt(Bind.ParameterValuePtr)^ := ShortInt(Value);
      SQL_C_UTINYINT: PByte(Bind.ParameterValuePtr)^     := Byte(Value);
      SQL_C_SSHORT:   PSmallInt(Bind.ParameterValuePtr)^ := SmallInt(Value);
      SQL_C_USHORT:   PWord(Bind.ParameterValuePtr)^     := Word(Value);
      SQL_C_SLONG:    PInteger(Bind.ParameterValuePtr)^  := Integer(Value);
      SQL_C_ULONG:    PCardinal(Bind.ParameterValuePtr)^ := Value;
      SQL_C_SBIGINT:  PInt64(Bind.ParameterValuePtr)^    := UInt64(Value);
      SQL_C_UBIGINT:  PUInt64(Bind.ParameterValuePtr)^   := UInt64(Value);
      SQL_C_TYPE_DATE, SQL_C_DATE,
      SQL_C_TYPE_TIME, SQL_C_TIME, SQL_C_SS_TIME2,
      SQL_C_TIMESTAMP, SQL_C_TYPE_TIMESTAMP, SQL_C_SS_TIMESTAMPOFFSET,
      SQL_C_FLOAT, SQL_C_DOUBLE:
                    begin
                      InternalBindDouble(Index, Bind.SQLType, Value);
                      Exit;
                    end;
      SQL_C_NUMERIC: Curr2ODBCNumeric(Value, Bind.ParameterValuePtr);
      SQL_C_WCHAR:  begin
                      IntToUnicode(Value, @fWBuffer[SizeOf(Pointer)], @fWBuffer[0]);
                      SetPWideChar(Index, @fWBuffer[SizeOf(Pointer)], ZPPWideChar(@fWBuffer[0])^-PWideChar(@fWBuffer[SizeOf(Pointer)]));
                      Exit;
                    end;
      SQL_C_CHAR:   begin
                      IntToRaw(Value, @fABuffer[SizeOf(Pointer)], @fABuffer[0]);
                      SetPAnsiChar(Index, @fABuffer[SizeOf(Pointer)], PPAnsiChar(@fABuffer[0])^-PAnsiChar(@fABuffer[SizeOf(Pointer)]));
                      Exit;
                    end;
      else RaiseUnsupportedParamType(Index, Bind.ValueType, SQLType);
    end;
    PSQLLEN(Bind.StrLen_or_IndPtr)^ := SQL_NO_NULLS;
  end else
    BindList.Put(Index, SQLType, {$IFNDEF CPU64}P4Bytes{$ELSE}P8Bytes{$ENDIF}(@Value));
end;

procedure TZAbstractODBCPreparedStatement.BindParam(Bind: PZODBCParamBind;
  ParameterNumber: SQLUSMALLINT);
var Desc: SQLHDesc;
begin
  CheckStmtError(fPlainDriver.SQLBindParameter(fHSTMT, ParameterNumber,//0=bookmark and Params do starts with 1
    Bind.InputOutputType, Bind.ValueType, Bind.ParameterType, Bind.ColumnSize,
    Bind.DecimalDigits * Ord(Bind.SQLType in [stCurrency, stBigDecimal, stDouble, stTime, stTimeStamp]),
      Bind.ParameterValuePtr, Bind.BufferLength, Bind.StrLen_or_IndPtr));
  if Bind.ValueType = SQL_C_NUMERIC then begin
    CheckStmtError(FPlainDriver.SQLGetStmtAttr(fHSTMT, SQL_ATTR_APP_PARAM_DESC, @Desc, 0, nil));
    CheckStmtError(FPlainDriver.SQLSetDescField(Desc, ParameterNumber, SQL_DESC_TYPE, SQLPointer(SQL_NUMERIC), SQL_IS_SMALLINT));
    CheckStmtError(FPlainDriver.SQLSetDescField(Desc, ParameterNumber, SQL_DESC_CONCISE_TYPE, SQLPointer(SQL_C_NUMERIC), SQL_IS_SMALLINT));
    CheckStmtError(FPlainDriver.SQLSetDescField(Desc, ParameterNumber, SQL_DESC_PRECISION, SQLPointer(Bind.ColumnSize), SQL_IS_INTEGER));
    CheckStmtError(FPlainDriver.SQLSetDescField(Desc, ParameterNumber, SQL_DESC_SCALE, SQLPointer(Bind.DecimalDigits), SQL_IS_SMALLINT));
    CheckStmtError(FPlainDriver.SQLSetDescField(Desc, ParameterNumber, SQL_DESC_DATA_PTR, Bind.ParameterValuePtr, SQL_IS_POINTER));
  end;
end;

procedure TZAbstractODBCPreparedStatement.BindRaw(Index: Integer;
  const Value: RawByteString; CP: Word);
var Bind: PZODBCParamBind;
  L: LengthInt;
begin
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    L := Length(Value);
    {$R-}
    Bind := @fParamBindings[Index];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    if (Bind.ParameterValuePtr = nil) or (Bind.ValueCount > 1) or (not Bind.Described and ((not (Bind.SQLType in [stString, StUnicodeString])) or (Bind.BufferLength < L+1))) then
      InitBind(Index, 1, stString, Length(Value));
    if Bind.SQLType in [stAsciiStream, stUnicodeStream] then begin
      if Value = ''
      then PIZlob(Bind.ParameterValuePtr)^ := TZAbstractClob.CreateWithData(PEmptyAnsiString, 0, CP, ConSettings)
      else PIZlob(Bind.ParameterValuePtr)^ := TZAbstractClob.CreateWithData(Pointer(Value), L, CP, ConSettings);
      if FClientEncoding = ceUTF16
      then PIZlob(Bind.ParameterValuePtr)^.GetPWideChar
      else if CP <> FClientCP then
        PIZlob(Bind.ParameterValuePtr)^.GetPAnsiChar(CP);
      Bind.StrLen_or_IndPtr^ := SQL_DATA_AT_EXEC;
    end else case Bind.ValueType of
      SQL_C_WCHAR:    begin
                        PSQLLEN(Bind.StrLen_or_IndPtr)^ := PRaw2PUnicode(Pointer(Value), Bind.ParameterValuePtr, CP, L, LengthInt(Bind.ColumnSize)) shl 1;
                        if PSQLLEN(Bind.StrLen_or_IndPtr)^ >= Bind.BufferLength then
                          RaiseExceeded(Index);
                        PWord(PAnsiChar(Bind.ParameterValuePtr)+PSQLLEN(Bind.StrLen_or_IndPtr)^)^ := 0;
                      end;
      SQL_C_CHAR:     begin
                        PSQLLEN(Bind.StrLen_or_IndPtr)^ := ZEncoding.PRawToPRawBuf(Pointer(Value),
                          Bind.ParameterValuePtr, L, Bind.ColumnSize, CP, FClientCP);
                        if PSQLLEN(Bind.StrLen_or_IndPtr)^ >= Bind.BufferLength then
                          RaiseExceeded(Index);
                        PByte(PAnsiChar(Bind.ParameterValuePtr)+PSQLLEN(Bind.StrLen_or_IndPtr)^)^ := 0;
                      end;
      else SetPAnsiChar(Index, Pointer(Value), L);
    end;
  end else
    BindList.Put(Index, stString, Value, CP);
end;

procedure TZAbstractODBCPreparedStatement.CheckParameterIndex(var Value: Integer);
begin
  if not Prepared then
    Prepare;
  if (BindList.Capacity < Value+1) then
    if fBindImmediat
    then raise EZSQLException.Create(SInvalidInputParameterCount)
    else inherited CheckParameterIndex(Value);
end;

procedure TZAbstractODBCPreparedStatement.ClearParameters;
begin
  inherited ClearParameters;
end;

constructor TZAbstractODBCPreparedStatement.Create(
  const Connection: IZODBCConnection; var ConnectionHandle: SQLHDBC;
  const SQL: string; Info: TStrings);
begin
  inherited Create(Connection, ConnectionHandle, SQL, Info);
  fCurrentIterations := 1;
end;

procedure TZAbstractODBCPreparedStatement.DescribeParameterFromBindList;
var
  Idx: SQLUSMALLINT;
  Bind: PZODBCParamBind;
  BindValue: PZBindValue;
  L: LengthInt;
label MinBuf;
begin
  for idx := 0 to BindList.Count -1 do begin
    {$R-}
    Bind := @fParamBindings[Idx];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    BindValue := BindList[IDX];
    Bind.SQLtype := BindValue.SQLType;
    Bind.InputOutputType := ODBCInputOutputType[BindValue.SQLtype in [stAsciiStream, stUnicodeStream, stBinaryStream]][BindValue.ParamType];
    Bind.ParameterType := ConvertSQLTypeToODBCType(BindValue.SQLtype, Bind.ValueType, ConSettings.ClientCodePage.Encoding);
    if not Bind.Described then //no registered param?
      if BindValue.BindType = zbtNull then
        goto MinBuf
      else case Bind.SQLtype  of
        stAsciiStream, stUnicodeStream, stBinaryStream:
            Bind.BufferLength := SizeOf(Pointer); //range check issue on CalcBufSize
        stString, stUnicodeString: begin
            case BindValue.BindType of
              zbtRawString, zbtUTF8String{$IFNDEF NEXTGEN},zbtAnsiString{$ENDIF}: L := Length(RawByteString(BindValue.Value));
              zbtUniString: L := Length(ZWideString(BindValue.Value));
              zbtCharByRef: L := PZCharRec(BindValue.Value).Len;
              zbtBinByRef:  L := PZBufRec(BindValue.Value).Len;
              else L := Length(TBytes(BindValue.Value));
            end;
            Bind.ColumnSize := Math.Max(Bind.ColumnSize, L);
            if (Bind.SQLType <> stBytes) then
              if (ConSettings.ClientCodePage^.Encoding = ceUTF16)
              then L := L shl 1
              else L := L * ConSettings.ClientCodePage^.CharWidth;
            L := ((L shr 3)+1) shl 3; //8 Byte align
            Bind.BufferLength := Max(L, Bind.BufferLength);
          end;
        stBytes:  begin
                    case BindValue.BindType of
                      zbtBinByRef:  Bind.BufferLength := PZBufRec(BindValue.Value).Len;
                      else Bind.BufferLength := Length(TBytes(BindValue.Value));
                    end;
                    Bind.BufferLength := ((Bind.BufferLength shr 3)+1) shl 3; //8Byte align + Reserved bytes
                  end;
        stTimeStamp: begin
                      Bind.ColumnSize := 23;
                      Bind.DecimalDigits := 3;
                      Bind.BufferLength := SizeOf(TSQL_TIMESTAMP_STRUCT);
                    end;
        else
MinBuf:   Bind.BufferLength := CalcBufSize(0, Bind.ValueType, Bind.SQLType, ConSettings^.ClientCodePage)
      end
  end;
end;

procedure TZAbstractODBCPreparedStatement.DescribeParameterFromODBC;
var
  Idx: SQLUSMALLINT;
  ParameterCount: SQLSMALLINT;
  UnSigned: Boolean;
  Status: SQLRETURN;
  Bind: PZODBCParamBind;
begin
  Status := fPlainDriver.SQLNumParams(fHSTMT, @ParameterCount);
  if Status <> SQL_SUCCESS then begin
    fBindImmediat := False;
    CheckStmtError(Status);
  end;
  if ParameterCount > 0 then begin
    if ParameterCount <> BindList.Count then
      SetParamCount(ParameterCount);
    for Idx := 0 to ParameterCount-1 do begin
      {$R-}
      Bind := @fParamBindings[Idx];
      {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
      Status := fPlainDriver.SQLDescribeParam(fHSTMT, Idx +1, //0=bookmark and Params do starts with 1
        @Bind.ParameterType, @Bind.ColumnSize, @Bind.DecimalDigits, @Bind.Nullable);
      if Status <> SQL_SUCCESS then
        CheckStmtError(Status);
      // this is the only type where unsigned is correct
      UnSigned := (Bind.ParameterType = SQL_BIGINT) and (Bind.ColumnSize = 20);
      //get "best" TZSQLType -> ODBC does not returns the C-Data types
      Bind.SQLType := ConvertODBCTypeToSQLType(Bind.ParameterType,
        Bind.DecimalDigits, Bind.ColumnSize, Unsigned, Consettings, @Bind.ValueType);
      //note: Code is prepared to handle any case of Param-Directions  except fetching returned data
      if (Bind.SQLtype in [stAsciiStream, stUnicodeStream, stBinaryStream])
      then Bind.BufferLength := SizeOf(Pointer) //range check issue on CalcBufSize
      else Bind.BufferLength := CalcBufSize(Bind.ColumnSize,
          Bind.ValueType, Bind.SQLType, ConSettings^.ClientCodePage);
      Bind.InputOutputType := ODBCInputOutputType[False
        { incomplete -> Bind.SQLtype in [stAsciiStream, stUnicodeStream, stBinaryStream]}][pctIn];
      if Bind.SQLType = stTimeStamp then begin
        Bind.ColumnSize := 23;
        Bind.DecimalDigits := 3;
      end;
      Bind.Described := True;
    end;
    fBindImmediat := True;
    CheckStmtError(fPlainDriver.SQLSetStmtAttr(fHSTMT, SQL_ATTR_PARAM_BIND_TYPE, nil, 0))
  end;
end;

procedure TZAbstractODBCPreparedStatement.InternalBindDouble(Index: Integer;
  SQLType: TZSQLType; const Value: Double);
var Bind: PZODBCParamBind;
  Year, fraction: Word;
begin
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    {$R-}
    Bind := @fParamBindings[Index];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    if (Bind.ParameterValuePtr = nil) or (Bind.ValueCount > 1) or (not Bind.Described and (SQLType <> Bind.SQLType)) then
      InitBind(Index, 1, SQLType);
    case Bind.ValueType of
      SQL_C_BIT:      PByte(Bind.ParameterValuePtr)^     := Byte(Value <> 0);
      SQL_C_STINYINT: PShortInt(Bind.ParameterValuePtr)^ := Trunc(Value);
      SQL_C_UTINYINT: PByte(Bind.ParameterValuePtr)^     := Trunc(Value);
      SQL_C_SSHORT:   PSmallInt(Bind.ParameterValuePtr)^ := Trunc(Value);
      SQL_C_USHORT:   PWord(Bind.ParameterValuePtr)^     := Trunc(Value);
      SQL_C_SLONG:    PInteger(Bind.ParameterValuePtr)^  := Trunc(Value);
      SQL_C_ULONG:    PCardinal(Bind.ParameterValuePtr)^ := Trunc(Value);
      SQL_C_SBIGINT:  PInt64(Bind.ParameterValuePtr)^    := Trunc(Value);
      SQL_C_UBIGINT:  PUInt64(Bind.ParameterValuePtr)^ := {$IFDEF WITH_UINT64_C1118_ERROR}Int64ToUint64{$ENDIF}(Trunc(Value));
      SQL_C_TYPE_DATE, SQL_C_DATE: begin
          DecodeDate(Value, Year, PSQL_DATE_STRUCT(Bind.ParameterValuePtr)^.month,
            PSQL_DATE_STRUCT(Bind.ParameterValuePtr)^.day);
          PSQL_DATE_STRUCT(Bind.ParameterValuePtr)^.year := year;
        end;
      SQL_C_TYPE_TIME, SQL_C_TIME: begin
          DecodeTime(Value, PSQL_TIME_STRUCT(Bind.ParameterValuePtr)^.hour,
            PSQL_TIME_STRUCT(Bind.ParameterValuePtr)^.minute,
            PSQL_TIME_STRUCT(Bind.ParameterValuePtr)^.second, fraction);
        end;
      SQL_C_SS_TIME2: begin
          //https://bytes.com/topic/sql-server/answers/851494-sql-state-22003-numeric-value-out-range-time-data-type
//          PSQLLEN(StrLen_or_IndPtr)^ := SizeOf(TSQL_SS_TIME2_STRUCT);
          DecodeTime(Value, PSQL_SS_TIME2_STRUCT(Bind.ParameterValuePtr)^.hour,
            PSQL_SS_TIME2_STRUCT(Bind.ParameterValuePtr)^.minute,
            PSQL_SS_TIME2_STRUCT(Bind.ParameterValuePtr)^.second, fraction);
          //https://msdn.microsoft.com/de-de/library/bb677243%28v=sql.120%29.aspx
          PSQL_SS_TIME2_STRUCT(Bind.ParameterValuePtr)^.fraction := fraction*1000000;
        end;
      SQL_C_TIMESTAMP, SQL_C_TYPE_TIMESTAMP: begin
          DecodeDateTime(Value, Year, PSQL_TIMESTAMP_STRUCT(Bind.ParameterValuePtr)^.month,
            PSQL_TIMESTAMP_STRUCT(Bind.ParameterValuePtr)^.day,
            PSQL_TIMESTAMP_STRUCT(Bind.ParameterValuePtr)^.hour, PSQL_TIMESTAMP_STRUCT(Bind.ParameterValuePtr)^.minute,
            PSQL_TIMESTAMP_STRUCT(Bind.ParameterValuePtr)^.second, fraction);
          PSQL_TIMESTAMP_STRUCT(Bind.ParameterValuePtr)^.year := year;
          PSQL_TIMESTAMP_STRUCT(Bind.ParameterValuePtr)^.fraction := fraction*1000000;
            //https://social.msdn.microsoft.com/Forums/sqlserver/en-US/ac1b5a6d-5e64-4603-9c92-b75ba4e51bf2/error-22008-datetime-field-overflow-when-inserting-a-record-with-datetime2-field-via-odbc?forum=sqldataaccess
        end;
      SQL_C_SS_TIMESTAMPOFFSET: begin
          DecodeDateTime(Value, Year, PSQL_SS_TIMESTAMPOFFSET_STRUCT(Bind.ParameterValuePtr)^.month,
            PSQL_SS_TIMESTAMPOFFSET_STRUCT(Bind.ParameterValuePtr)^.day,
            PSQL_SS_TIMESTAMPOFFSET_STRUCT(Bind.ParameterValuePtr)^.hour,
            PSQL_SS_TIMESTAMPOFFSET_STRUCT(Bind.ParameterValuePtr)^.minute,
            PSQL_SS_TIMESTAMPOFFSET_STRUCT(Bind.ParameterValuePtr)^.second, fraction);
          PSQL_SS_TIMESTAMPOFFSET_STRUCT(Bind.ParameterValuePtr)^.year := year;
          PSQL_SS_TIMESTAMPOFFSET_STRUCT(Bind.ParameterValuePtr)^.fraction := fraction*1000000;
            //https://social.msdn.microsoft.com/Forums/sqlserver/en-US/ac1b5a6d-5e64-4603-9c92-b75ba4e51bf2/error-22008-datetime-field-overflow-when-inserting-a-record-with-datetime2-field-via-odbc?forum=sqldataaccess
        end;
      SQL_C_FLOAT:  PSingle(Bind.ParameterValuePtr)^ := Value;
      SQL_C_DOUBLE: PDouble(Bind.ParameterValuePtr)^ := Value;
      SQL_C_NUMERIC: Curr2ODBCNumeric(Value, Bind.ParameterValuePtr);
      SQL_C_WCHAR:  begin
          case SQLType of
            stFloat, stDouble, stCurrency,
            stBigDecimal: SetPWideChar(Index, @fWBuffer[0], FloatToSQLUnicode(Value, @fWBuffer[0]));
            stTime: SetPWideChar(Index, @fWBuffer[0], ZSysUtils.DateTimeToUnicodeSQLTime(Value, @fWBuffer[0], ConSettings^.WriteFormatSettings, False));
            stDate: SetPWideChar(Index, @fWBuffer[0], ZSysUtils.DateTimeToUnicodeSQLDate(Value, @fWBuffer[0], ConSettings^.WriteFormatSettings, False));
            stTimeStamp: SetPWideChar(Index, @fWBuffer[0], ZSysUtils.DateTimeToUnicodeSQLTimeStamp(Value, @fWBuffer[0], ConSettings^.WriteFormatSettings, False));
          end;
          Exit;
        end;
      SQL_C_CHAR:   begin
          case SQLType of
            stFloat, stDouble, stCurrency,
            stBigDecimal: SetPAnsiChar(Index, @fABuffer[0], FloatToSQLRaw(Value, @fABuffer[0]));
            stTime: SetPAnsiChar(Index, @fABuffer[0], ZSysUtils.DateTimeToRawSQLTime(Value, @fABuffer[0], ConSettings^.WriteFormatSettings, False));
            stDate: SetPAnsiChar(Index, @fABuffer[0], ZSysUtils.DateTimeToRawSQLDate(Value, @fABuffer[0], ConSettings^.WriteFormatSettings, False));
            stTimeStamp: SetPAnsiChar(Index, @fABuffer[0], ZSysUtils.DateTimeToRawSQLTimeStamp(Value, @fABuffer[0], ConSettings^.WriteFormatSettings, False));
          end;
          Exit;
        end;
      else RaiseUnsupportedParamType(Index, Bind.ValueType, SQlType);
    end;
    PSQLLEN(Bind.StrLen_or_IndPtr)^ := SQL_NO_NULLS;
  end else {$IFNDEF CPU64}
    if SQLType = stFloat then begin
      PSingle(@fABuffer[0])^ := Value;
      BindList.Put(Index, SQLType, P4Bytes(@fABuffer[0]));
    end else
    {$ENDIF}
      BindList.Put(Index, SQLType, P8Bytes(@Value));
end;

procedure TZAbstractODBCPreparedStatement.InitBind(Index, ValueCount: Integer;
  SQLType: TZSQLType; ActualLength: LengthInt);
var BindAgain: Boolean;
  ODBC_CType: SQLSMALLINT;
  Bind: PZODBCParamBind;
  label ReAlloc;
  procedure FlushLobs;
  var J: Integer;
  begin
    for j := 0 to Bind.ValueCount -1 do
      {$R-}PLobArray(Bind.ParameterValuePtr)[j] := nil;{$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
  end;
begin
  {$R-}
  Bind := @fParamBindings[Index];
  {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
  BindAgain := (Bind.ParameterValuePtr = nil) or (Bind.InputOutputType <> ODBCInputOutputType[SQLType in [stAsciiStream, stUnicodeStream, stBinaryStream]][BindList[Index].ParamType]);
  if (SQLType in [stString, stAsciiStream]) and (FClientEncoding = ceUTF16)
  then SQLType := TZSQLType(Ord(SQLType)+1)
  else if (SQLType in [stUnicodeString, stUnicodeStream]) and (FClientEncoding <> ceUTF16) then
    SQLType := TZSQLType(Ord(SQLType)-1);

  if (Bind.SQLType <> SQLType) or (Ord(SQLType) >= Ord(stAsciistream)) then begin
    if not Bind.Described or ((Ord(SQLType) <= Ord(stLong)) and (Bind.ParameterType = ODBCSQLTypeOrdinalMatrix[SQLType])) then begin
      {$IFDEF FPC}ODBC_CType := 0;{$ENDIF}
      Bind.SQLType := SQLType;
      Bind.ParameterType := ConvertSQLTypeToODBCType(SQLType, ODBC_CType, FClientEncoding);;
      Bind.ValueType := ODBC_CType;
      BindAgain := True;
      if not Bind.Described then begin
        if (Ord(SQLType) >= Ord(stAsciistream)) then begin
          ActualLength := SizeOf(Pointer);
          Bind.ColumnSize := Max(LengthInt(IZBlob(BindList[Index].Value).Length), Bind.ColumnSize);
        end else if (Ord(SQLType) < Ord(stString)) then
          ActualLength := CalcBufSize(ActualLength, ODBC_CType, SQLType, ConSettings.ClientCodePage);
        if ActualLength <> Bind.BufferLength then
          goto ReAlloc;
      end;
    end;
  end;
  if (ValueCount <> Bind.ValueCount) then begin
    BindAgain := True;
    if Bind.ValueCount > 0 then
      FreeMem(Bind.StrLen_or_IndPtr, Bind.ValueCount * SizeOf(SQLLEN));
    if ValueCount > 0 //FPC heaptrc shows us 0 Bytes unreleased mem ?
    then GetMem(Bind.StrLen_or_IndPtr, ValueCount * SizeOf(SQLLEN))
    else Bind.StrLen_or_IndPtr := nil;
  end;
  if not Bind.Described and (SQLType in [stBytes, stString, stUnicodeString]) and
     ((Bind.BufferLength shr Ord(SQLType = stUnicodeString)-Ord(SQLType <> stBytes)) < ActualLength) then begin
    BindAgain := True;
    ActualLength := ((((ActualLength shl Ord(SQLType = stUnicodeString))-1) shr 3)+1) shl 3; //8Byte align
    Bind.BufferLength := ActualLength;
ReAlloc:
    if not Bind.ExternalMem and (Bind.ParameterValuePtr <> nil)
    then FreeMem(Bind.ParameterValuePtr, Bind.BufferLength*Bind.ValueCount);
    if ValueCount > 0 //FPC heaptrc shows us 0 Bytes unreleased mem ?
    then GetMem(Bind.ParameterValuePtr, Bind.BufferLength*ValueCount)
    else Bind.ParameterValuePtr := nil;
  end else if (Ord(Bind.SQLType) < Ord(stAsciiStream)) then
    if (Bind.ParameterValuePtr = nil) and (ValueCount> 0)
    then GetMem(Bind.ParameterValuePtr, Bind.BufferLength * ValueCount)
    else goto ReAlloc
  else begin
    if not Bind.ExternalMem and (Bind.ParameterValuePtr <> nil) then begin
      FlushLobs;
      FreeMem(Bind.ParameterValuePtr, Bind.ValueCount*SizeOf(Pointer));
      Bind.ParameterValuePtr := nil;
    end;
    Bind.BufferLength := SizeOf(Pointer);
    GetMem(Bind.ParameterValuePtr, SizeOf(Pointer)*ValueCount);
    FillChar(Bind.ParameterValuePtr^, SizeOf(Pointer)*ValueCount, #0);
  end;
  Bind.ValueCount := ValueCount;
  Bind.ExternalMem := ValueCount = 0;
  if BindAgain and (ValueCount > 0) then
    BindParam(Bind, Index+1);
end;

procedure TZAbstractODBCPreparedStatement.PrepareInParameters;
begin
  if fBindImmediat then
    DescribeParameterFromODBC;
end;

procedure TZAbstractODBCPreparedStatement.RaiseExceeded(Index: Integer);
begin
  raise EZSQLException.Create(Format(cSParamValueExceeded, [Index{$IFNDEF GENERIC_INDEX}+1{$ENDIF}])+LineEnding+
    'Stmt: '+GetSQL);
end;

procedure TZAbstractODBCPreparedStatement.RaiseUnsupportedParamType(Index: Integer;
  SQLCType: SQLSMALLINT; SQLType: TZSQLType);
begin
  raise EZSQLException.Create('Index: '+ZFastCode.IntToStr(Index{$IFNDEF GENERIC_INDEX}+1{$ENDIF})+
    ', ODBC-C-Type: '+ZFastCode.IntToStr(SQLCType)+', SQLType: '+GetEnumName(TypeInfo(TZSQLType), Ord(SQLType))+
    LineEnding+SUnsupportedParameterType+LineEnding+ 'Stmt: '+GetSQL);
end;

procedure TZAbstractODBCPreparedStatement.ReallocParamBindings(OldCount,
  NewCount: Integer);
var
  I, j: Integer;
  Bind: PZODBCParamBind;
begin
  {first clean mem of binds we don't need any more}
  if (fParamBindings <> nil) then
    for i := OldCount-1 downto NewCount do begin
      {$R-}
      Bind := @fParamBindings[I];
      {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
      Bind.ParamName := '';
      if not Bind.ExternalMem and (Bind.ParameterValuePtr <> nil) then begin
        if Ord(Bind.SQLType) >= Ord(stAsciiStream) then
          for j := 0 to Bind.ValueCount -1 do
            {$R-}
            PLobArray(Bind.ParameterValuePtr)[j] := nil;
            {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
        FreeMem(Bind.ParameterValuePtr)
      end;
      FreeMem(Bind.StrLen_or_IndPtr);
    end;
  ReallocMem(fParamBindings, NewCount*SizeOf(TZODBCParamBind));
  if fParamBindings <> nil then begin
    FillChar((PAnsichar(fParamBindings)+(OldCount*SizeOf(TZODBCParamBind)))^,
      ((NewCount-OldCount)*SizeOf(TZODBCParamBind)), {$IFDEF Use_FastCodeFillChar}#0{$ELSE}0{$ENDIF});
    for i := OldCount to NewCount-1 do begin
      {$R-}
      GetMem(fParamBindings[I].StrLen_or_IndPtr, SizeOf(SQLLEN));
      fParamBindings[I].ValueCount := 1;
      {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    end;
  end;
end;

procedure TZAbstractODBCPreparedStatement.RegisterParameter(
  ParameterIndex: Integer; SQLType: TZSQLType; ParamType: TZProcedureColumnType;
  const Name: String; PrecisionOrSize, Scale: LengthInt);
var Bind: PZODBCParamBind;
begin
  inherited RegisterParameter(ParameterIndex, SQLType, ParamType, Name, PrecisionOrSize, Scale);
  {$R-}
  Bind := @fParamBindings[ParameterIndex];
  {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
  Bind.InputOutputType := ODBCInputOutputType[SQLType in [stAsciiStream, stUnicodeStream, stBinaryStream]][ParamType] ;
  if not Bind.Described then begin
    Bind.Described := True;
    Bind.SQLType := SQLType;
    if (SQLtype in [stAsciiStream, stUnicodeStream, stBinaryStream])
    then Bind.BufferLength := SizeOf(Pointer) //range check issue on CalcBufSize
    else if (SQLtype in [stString, stUnicodeString, stBytes]) then begin
      Bind.BufferLength := ((PrecisionOrSize shr 3)+1) shl 3; //8Byte align + Reserved bytes
      if (Bind.SQLType <> stBytes) then
        if (ConSettings.ClientCodePage^.Encoding = ceUTF16)
        then Bind.BufferLength := Bind.BufferLength shl 1
        else Bind.BufferLength := Bind.BufferLength * ConSettings.ClientCodePage^.CharWidth;
    end else Bind.BufferLength := CalcBufSize(0, Bind.ValueType, Bind.SQLType, ConSettings^.ClientCodePage);
    if Bind.SQLType = stTimeStamp then begin
      Bind.ColumnSize := 23;
      Bind.DecimalDigits := 3;
    end else if SQLType in [stCurrency, stBigDecimal] then begin
      Bind.ColumnSize := Scale;
      Bind.DecimalDigits := Scale;
    end;
  end;
  Bind.ParamName := Name;
  if (Bind.ParameterValuePtr = nil) then
    InitBind(ParameterIndex, 1, SQLType);
end;

{$IFNDEF NO_ANSISTRING}
procedure TZAbstractODBCPreparedStatement.SetAnsiString(Index: Integer;
  const Value: AnsiString);
begin
  BindRaw(Index{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, Value, ZOSCodePage);
end;
{$ENDIF}

procedure TZAbstractODBCPreparedStatement.SetBigDecimal(Index: Integer;
  const Value: TBCD);
var Bind: PZODBCParamBind;
begin
  {$IFNDEF GENERIC_INDEX}Index := Index-1;{$ENDIF}
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    {$R-}
    Bind := @fParamBindings[Index];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    PSQLLEN(Bind.StrLen_or_IndPtr)^ := SQL_NO_NULLS;
    if (Bind.ParameterValuePtr = nil) or (Bind.ValueCount > 1) or (Bind.ValueCount > 1) or (not Bind.Described and (stCurrency <> Bind.SQLType)) then
      InitBind(Index, 1, stCurrency);
    case Bind.ValueType of
      SQL_C_BIT:      PByte(Bind.ParameterValuePtr)^     := Ord(BCDCompare(NullBCD, Value) <> 0);
      SQL_C_STINYINT: PShortInt(Bind.ParameterValuePtr)^ := BCD2Int64(Value);
      SQL_C_SSHORT:   PSmallInt(Bind.ParameterValuePtr)^ := BCD2Int64(Value);
      SQL_C_SLONG:    PInteger(Bind.ParameterValuePtr)^  := BCD2Int64(Value);
      SQL_C_UTINYINT: PByte(Bind.ParameterValuePtr)^     := BCD2Int64(Value);
      SQL_C_USHORT:   PWord(Bind.ParameterValuePtr)^     := BCD2Int64(Value);
      SQL_C_ULONG:    PCardinal(Bind.ParameterValuePtr)^ := BCD2Int64(Value);
      SQL_C_SBIGINT:  BCD2Int64(Value, PInt64(Bind.ParameterValuePtr)^);
      SQL_C_UBIGINT:  BCD2UInt64(Value, PUInt64(Bind.ParameterValuePtr)^);
      SQL_C_FLOAT:    PSingle(Bind.ParameterValuePtr)^   := BCDToDouble(Value);
      SQL_C_DOUBLE:   PDouble(Bind.ParameterValuePtr)^   := BCDToDouble(Value);
      SQL_C_NUMERIC:  ZDbcUtils.BCD2SQLNumeric(Value, PDB_NUMERIC(Bind.ParameterValuePtr));
      SQL_C_WCHAR:    SetPWideChar(Index, @fWBuffer[0], ZSysUtils.BcdToUni(Value, @fWBuffer[0], '.'));
      SQL_C_CHAR:     SetPAnsiChar(Index, @fABuffer[0], ZSysUtils.BcdToRaw(Value, @fABuffer[0], '.'));
      else RaiseUnsupportedParamType(Index, Bind.ValueType, stBigDecimal);
    end;
  end else
    BindList.Put(Index, Value);
end;

{**
  Sets the designated parameter to a <code>java.math.BigDecimal</code> value.
  The driver converts this to an SQL <code>NUMERIC</code> value when
  it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZAbstractODBCPreparedStatement.SetBindCapacity(Capacity: Integer);
var OldCap: Integer;
begin
  OldCap := BindList.Capacity;
  inherited SetBindCapacity(Capacity);
  if OldCap <> Capacity then
    ReallocParamBindings(OldCap, Capacity);
end;

procedure TZAbstractODBCPreparedStatement.SetBlob(ParameterIndex: Integer;
  SQLType: TZSQLType; const Value: IZBlob);
var Bind: PZODBCParamBind;
begin
  inherited;
  if fBindImmediat then begin
    {$R-}
    {$IFNDEF GENERIC_INDEX}
    ParameterIndex := ParameterIndex-1;
    {$ENDIF}
    Bind := @fParamBindings[ParameterIndex];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    if (FClientEncoding = ceUTF16) and (SQLType = stAsciiStream) then
      SQLType := stUnicodeStream
    else if (FClientEncoding <> ceUTF16) and (SQLType = stUnicodeStream) then
      SQLType := stAsciiStream;
    if (Bind.ParameterValuePtr = nil) or (Bind.ValueCount > 1) or (not Bind.Described and (SQLType <> Bind.SQLType)) then
      InitBind(ParameterIndex, 1, SQLType);
    if (Value = nil) or Value.IsEmpty
    then Bind.StrLen_or_IndPtr^ := SQL_NULL_DATA
    else begin
      if Bind.SQLType <> stBinaryStream then
        if Value.IsClob then
          if FClientEncoding = ceUTF16
          then Value.GetPWideChar
          else Value.GetPAnsiChar(FClientCP)
        else if (FClientEncoding <> ceUTF16) then begin
          fRawTemp := GetValidatedAnsiStringFromBuffer(Value.GetBuffer, Value.Length, ConSettings);
          inherited SetBlob(ParameterIndex{$IFNDEF GENERIC_INDEX}+1{$ENDIF}, stAsciiStream,
            TZAbstractCLob.CreateWithData(Pointer(fRawTemp),
            Length(fRawTemp), ConSettings^.ClientCodePage.CP, ConSettings));
        end;
      if Bind.SQLType in [stAsciiStream, stUnicodeStream, stBinaryStream] then begin
        PIZLob(Bind.ParameterValuePtr)^ := IZBlob(BindList[ParameterIndex].Value);
        Bind.StrLen_or_IndPtr^ := SQL_DATA_AT_EXEC
      end else if (SQLType = stBinaryStream) or (FClientEncoding <> ceUTF16) then
        SetPAnsiChar(ParameterIndex, Value.GetBuffer, Value.Length)
      else SetPWideChar(ParameterIndex, Value.GetPWideChar, Value.Length)
    end;
  end;
end;

{**
  Sets the designated parameter to a Java <code>boolean</code> value.
  The driver converts this
  to an SQL <code>BIT</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZAbstractODBCPreparedStatement.SetBoolean(ParameterIndex: Integer;
  Value: Boolean);
begin
  if fBindImmediat then
    BindSInteger(ParameterIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, stBoolean,
      Ord(Value))
  else BindList.Put(ParameterIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, Value);
end;

{**
  Sets the designated parameter to a Java <code>unsigned 8Bit int</code> value.
  The driver converts this
  to an SQL <code>BYTE</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZAbstractODBCPreparedStatement.SetByte(ParameterIndex: Integer; Value: Byte);
begin
  BindUInteger(ParameterIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, stByte, Cardinal(Value))
end;

{**
  Sets the designated parameter to a Java array of bytes.  The driver converts
  this to an SQL <code>VARBINARY</code> or <code>LONGVARBINARY</code>
  (depending on the argument's size relative to the driver's limits on
  <code>VARBINARY</code> values) when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZAbstractODBCPreparedStatement.SetBytes(Index: Integer;
  const Value: TBytes);
var Bind: PZODBCParamBind;
begin
  {$IFNDEF GENERIC_INDEX}Index := Index-1;{$ENDIF}
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    {$R-}
    Bind := @fParamBindings[Index];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    if (Bind.ParameterValuePtr = nil) or (Bind.ValueCount > 1) or (not Bind.Described and ((stBytes <> Bind.SQLType) or (Bind.BufferLength < Length(Value)))) then
      InitBind(Index, 1, stBytes);
    if Bind.SQLType = stBinaryStream then begin
      PIZlob(Bind.ParameterValuePtr)^ := TZAbstractBlob.CreateWithData(Pointer(Value), Length(Value));
      Bind.StrLen_or_IndPtr^ := SQL_DATA_AT_EXEC;
    end else case Bind.ValueType of
      SQL_C_BINARY:   begin
                        PSQLLEN(Bind.StrLen_or_IndPtr)^ := Length(Value);
                        if PSQLLEN(Bind.StrLen_or_IndPtr)^ > Bind.BufferLength then
                          RaiseExceeded(Index);
                        Move(Pointer(Value)^, Bind.ParameterValuePtr^, PSQLLEN(Bind.StrLen_or_IndPtr)^);
                      end;
      SQL_C_GUID:     if Length(Value) = 16
                      then PGUID(Bind.ParameterValuePtr)^ := PGUID(Value)^
                      else RaiseExceeded(Index);
      else RaiseUnsupportedParamType(Index, Bind.ValueType, stCurrency);
    end;
  end else
    BindList.Put(Index, stByte, Value);
end;

procedure TZAbstractODBCPreparedStatement.SetCharRec(Index: Integer;
  const Value: TZCharRec);
begin
  {$IFNDEF GENERIC_INDEX}Index := Index-1;{$ENDIF}
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    if Value.CP = zCP_UTF16 then
      SetPWideChar(Index, Value.P, Value.Len)
    else if (FClientEncoding = ceUTF16) or (Value.CP <> FClientCP) then begin
      FUniTemp := PRawToUnicode(Value.P, Value.Len, Value.CP);
      SetPWideChar(Index, Pointer(FUniTemp), Length(FUniTemp));
    end else
     SetPAnsiChar(Index, Value.P, Value.Len)
  end else
    BindList.Put(Index, stString, Value.P, Value.Len, Value.CP);
end;

{**
  Sets the designated parameter to a Java <code>currency</code> value.
  The driver converts this
  to an SQL <code>CURRENCY</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZAbstractODBCPreparedStatement.SetCurrency(Index: Integer;
  const Value: Currency);
var Bind: PZODBCParamBind;
begin
  {$IFNDEF GENERIC_INDEX}Index := Index-1;{$ENDIF}
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    {$R-}
    Bind := @fParamBindings[Index];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    PSQLLEN(Bind.StrLen_or_IndPtr)^ := SQL_NO_NULLS;
    if (Bind.ParameterValuePtr = nil) or (Bind.ValueCount > 1) or (Bind.ValueCount > 1) or (not Bind.Described and (stCurrency <> Bind.SQLType)) then
      InitBind(Index, 1, stCurrency);
    case Bind.ValueType of
      SQL_C_BIT:      PByte(Bind.ParameterValuePtr)^     := Ord(Value <> 0);
      SQL_C_STINYINT: PShortInt(Bind.ParameterValuePtr)^ := Trunc(Value);
      SQL_C_UTINYINT: PByte(Bind.ParameterValuePtr)^     := Trunc(Value);
      SQL_C_SSHORT:   PSmallInt(Bind.ParameterValuePtr)^ := Trunc(Value);
      SQL_C_USHORT:   PWord(Bind.ParameterValuePtr)^     := Trunc(Value);
      SQL_C_SLONG:    PInteger(Bind.ParameterValuePtr)^  := Trunc(Value);
      SQL_C_ULONG:    PCardinal(Bind.ParameterValuePtr)^ := Trunc(Value);
      SQL_C_SBIGINT:  PInt64(Bind.ParameterValuePtr)^    := Trunc(Value);
      SQL_C_UBIGINT:  PUInt64(Bind.ParameterValuePtr)^   := {$IFDEF WITH_UINT64_C1118_ERROR}Int64ToUint64{$ENDIF}(Trunc(Value));
      SQL_C_FLOAT:    PSingle(Bind.ParameterValuePtr)^   := Value;
      SQL_C_DOUBLE:   PDouble(Bind.ParameterValuePtr)^   := Value;
      SQL_C_NUMERIC:  Curr2ODBCNumeric(Value, PSQL_NUMERIC_STRUCT(Bind.ParameterValuePtr));
      SQL_C_WCHAR:    begin
                        CurrToUnicode(Value, @fWBuffer[SizeOf(Pointer)], @fWBuffer[0]);
                        SetPWideChar(Index, @fWBuffer[SizeOf(Pointer)], ZPPWideChar(@fWBuffer[0])^ - PWideChar(@fWBuffer[SizeOf(Pointer)]));
                      end;
      SQL_C_CHAR:     begin
                        CurrToRaw(Value, @fABuffer[SizeOf(Pointer)], @fABuffer[0]);
                        SetPAnsiChar(Index, @fABuffer[SizeOf(Pointer)], PPAnsiChar(@fABuffer[0])^ - PAnsiChar(@fABuffer[SizeOf(Pointer)]));
                      end;
      else RaiseUnsupportedParamType(Index, Bind.ValueType, stCurrency);
    end;
  end else
    BindList.Put(Index, stCurrency, P8Bytes(@Value));
end;

{**
  Sets the designated parameter to a <code<java.sql.Date</code> value.
  The driver converts this to an SQL <code>DATE</code>
  value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZAbstractODBCPreparedStatement.SetDate(Index: Integer;
  const Value: TZDate);
var Bind: PZODBCParamBind;
  DT: TDateTime;
  Len: LengthInt;
begin
  {$IFNDEF GENERIC_INDEX}Index := Index-1;{$ENDIF}
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    {$R-}
    Bind := @fParamBindings[Index];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    if (Bind.ParameterValuePtr = nil) or (Bind.ValueCount > 1) or (not Bind.Described and (Bind.SQLType <> stDate)) then
      InitBind(Index, 1, stDate);
    case Bind.ValueType of
      SQL_C_TYPE_DATE, SQL_C_DATE:
        with PSQL_DATE_STRUCT(Bind.ParameterValuePtr)^ do begin
          Year := Value.Year;
          if Value.IsNegative then
            Year := -Year;
          Month := Value.Month;
          Day := Value.Day;
        end;
      SQL_C_TYPE_TIME,
      SQL_C_TIME:     FillChar(Bind.ParameterValuePtr^, SizeOf(TSQL_TIME_STRUCT), #0);
      SQL_C_SS_TIME2: FillChar(Bind.ParameterValuePtr^, SizeOf(TSQL_SS_TIME2_STRUCT), #0);
      SQL_C_TIMESTAMP, SQL_C_TYPE_TIMESTAMP: begin
          FillChar(Bind.ParameterValuePtr^, SizeOf(TSQL_TIMESTAMP_STRUCT), #0);
          With PSQL_TIMESTAMP_STRUCT(Bind.ParameterValuePtr)^ do begin
            Year := Value.Year;
            if Value.IsNegative then
              Year := -Year;
            Month := Value.Month;
            Day := Value.Day;
          end;
        end;
      SQL_C_SS_TIMESTAMPOFFSET: begin
          FillChar(Bind.ParameterValuePtr^, SizeOf(TSQL_SS_TIMESTAMPOFFSET_STRUCT), #0);
          With PSQL_SS_TIMESTAMPOFFSET_STRUCT(Bind.ParameterValuePtr)^ do begin
            Year := Value.Year;
            if Value.IsNegative then
              Year := -Year;
            Month := Value.Month;
            Day := Value.Day;
          end;
        end;
      SQL_C_WCHAR:  begin
              Len := DateToUni(Value.Year, Value.Month, Value.Day,
                @fWBuffer[0], ConSettings^.WriteFormatSettings.DateFormat, False, Value.IsNegative);
              SetPWideChar(Index, @fWBuffer[0], Len);
              Exit;
            end;
      SQL_C_CHAR:  begin
              Len := DateToRaw(Value.Year, Value.Month, Value.Day,
                @fABuffer[0], ConSettings^.WriteFormatSettings.DateFormat, False, Value.IsNegative);
              SetPAnsiChar(Index, @fABuffer[0], Len);
              Exit;
            end;
      else  begin
              if TryDateToDateTime(Value, DT{%H-})
              then InternalBindDouble(Index, stDate, DT)
              else BindSInteger(Index, stDate, 1);
              Exit;
            end;
    end;
    PSQLLEN(Bind.StrLen_or_IndPtr)^ := SQL_NO_NULLS;
  end else
    BindList.Put(Index, Value);
end;

{**
  Sets the designated parameter to a Java <code>double</code> value.
  The driver converts this
  to an SQL <code>DOUBLE</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZAbstractODBCPreparedStatement.SetDouble(Index: Integer;
  const Value: Double);
begin
  InternalBindDouble(Index{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, stDouble, Value)
end;

{**
  Sets the designated parameter to a Java <code>float</code> value.
  The driver converts this
  to an SQL <code>FLOAT</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZAbstractODBCPreparedStatement.SetFloat(Index: Integer;
  Value: Single);
begin
  InternalBindDouble(Index{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, stFloat, Value)
end;

{**
  Sets the designated parameter to a GUID.
  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZAbstractODBCPreparedStatement.SetGUID(Index: Integer;
  const Value: TGUID);
var Bind: PZODBCParamBind;
begin
  {$IFNDEF GENERIC_INDEX}Index := Index-1;{$ENDIF}
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    {$R-}
    Bind := @fParamBindings[Index];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    PSQLLEN(Bind.StrLen_or_IndPtr)^ := SQL_NO_NULLS;
    if (Bind.ParameterValuePtr = nil) or (Bind.ValueCount > 1) or (not Bind.Described and (stGUID <> Bind.SQLType)) then
      InitBind(Index, 1, stGUID);
    case Bind.ValueType of
      SQL_C_BINARY:   begin
                        PSQLLEN(Bind.StrLen_or_IndPtr)^ := SizeOf(TGUID);
                        if PSQLLEN(Bind.StrLen_or_IndPtr)^ > Bind.BufferLength then
                          RaiseExceeded(Index);
                        PGUID(Bind.ParameterValuePtr)^ := Value;
                      end;
      SQL_C_GUID:     PGUID(Bind.ParameterValuePtr)^ := Value;
      SQL_C_CHAR:     begin
                        if Bind.BufferLength < 36 then
                          RaiseExceeded(Index);
                        PSQLLEN(Bind.StrLen_or_IndPtr)^ := 36;
                        GUIDToBuffer(@Value.D1, PAnsiChar(Bind.ParameterValuePtr), []);
                      end;
      SQL_C_WCHAR:    begin
                        if Bind.BufferLength < 36*2 then
                          RaiseExceeded(Index);
                        PSQLLEN(Bind.StrLen_or_IndPtr)^ := 36*2;
                        GUIDToBuffer(@Value.D1, PWideChar(Bind.ParameterValuePtr), []);
                      end;
      else RaiseUnsupportedParamType(Index, Bind.ValueType, stCurrency);
    end;
  end else
    BindList.Put(Index, Value);
end;

{**
  Sets the designated parameter to a Java <code>int</code> value.
  The driver converts this
  to an SQL <code>INTEGER</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZAbstractODBCPreparedStatement.SetInt(ParameterIndex, Value: Integer);
begin
  BindSInteger(ParameterIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, stInteger, Value)
end;

{**
  Sets the designated parameter to a Java <code>long</code> value.
  The driver converts this
  to an SQL <code>BIGINT</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZAbstractODBCPreparedStatement.SetLong(Index: Integer; const Value: Int64);
{$IFDEF CPU64}
begin
  BindSInteger(Index{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, stLong, Value)
{$ELSE}
var Bind: PZODBCParamBind;
begin
  {$IFNDEF GENERIC_INDEX}Index := Index-1;{$ENDIF}
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    {$R-}
    Bind := @fParamBindings[Index];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    if (Bind.ParameterValuePtr = nil) or (Bind.ValueCount > 1) or (not Bind.Described and (stLong <> Bind.SQLType)) then
      InitBind(Index, 1, stLong);
    case Bind.ValueType of
      SQL_C_BIT:      PByte(Bind.ParameterValuePtr)^     := Ord(Value <> 0);
      SQL_C_STINYINT: PShortInt(Bind.ParameterValuePtr)^ := ShortInt(Value);
      SQL_C_UTINYINT: PByte(Bind.ParameterValuePtr)^     := Byte(Value);
      SQL_C_SSHORT:   PSmallInt(Bind.ParameterValuePtr)^ := SmallInt(Value);
      SQL_C_USHORT:   PWord(Bind.ParameterValuePtr)^     := Word(Value);
      SQL_C_SLONG:    PInteger(Bind.ParameterValuePtr)^  := Integer(Value);
      SQL_C_ULONG:    PCardinal(Bind.ParameterValuePtr)^ := Cardinal(Value);
      SQL_C_SBIGINT:  PInt64(Bind.ParameterValuePtr)^    := Value;
      SQL_C_UBIGINT:  PUInt64(Bind.ParameterValuePtr)^   := UInt64(Value);
      SQL_C_TYPE_DATE, SQL_C_DATE,
      SQL_C_TYPE_TIME, SQL_C_TIME, SQL_C_SS_TIME2,
      SQL_C_TIMESTAMP, SQL_C_TYPE_TIMESTAMP, SQL_C_SS_TIMESTAMPOFFSET,
      SQL_C_FLOAT, SQL_C_DOUBLE: InternalBindDouble(Index, stULong, Value);
      SQL_C_NUMERIC: Curr2ODBCNumeric(Value, Bind.ParameterValuePtr);
      SQL_C_WCHAR:  begin
                      IntToUnicode(Value, @fWBuffer[SizeOf(Pointer)], @fWBuffer[0]);
                      SetPWideChar(Index, @fWBuffer[SizeOf(Pointer)], ZPPWideChar(@fWBuffer[0])^-PWideChar(@fWBuffer[SizeOf(Pointer)]));
                      Exit;
                    end;
      SQL_C_CHAR:   begin
                      IntToRaw(Value, @fABuffer[SizeOf(Pointer)], @fABuffer[0]);
                      SetPAnsiChar(Index, @fABuffer[SizeOf(Pointer)], PPAnsiChar(@fABuffer[0])^-PAnsiChar(@fABuffer[SizeOf(Pointer)]));
                      Exit;
                    end;
      else RaiseUnsupportedParamType(Index, Bind.ValueType, stULong);
    end;
    PSQLLEN(Bind.StrLen_or_IndPtr)^ := SQL_NO_NULLS;
  end else
    BindList.Put(Index, stULong, P8Bytes(@Value));
{$ENDIF}
end;

{**
  Sets the designated parameter to SQL <code>NULL</code>.
  <P><B>Note:</B> You must specify the parameter's SQL type.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param sqlType the SQL type code defined in <code>java.sql.Types</code>
}
procedure TZAbstractODBCPreparedStatement.SetNull(Index: Integer;
  SQLType: TZSQLType);
var Bind: PZODBCParamBind;
begin
  {$IFNDEF GENERIC_INDEX}Index := Index-1;{$ENDIF}
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    {$R-}
    Bind := @fParamBindings[Index];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    if (Bind.ParameterValuePtr = nil) or (Bind.ValueCount > 1) or (not Bind.Described and (Bind.SQLType <> SQLType)) then
      InitBind(Index, 1, SQLType);
    Bind.StrLen_or_IndPtr^ := SQL_NULL_DATA;
  end else
    BindList.SetNull(Index, SQLType);
end;

procedure TZAbstractODBCPreparedStatement.SetPAnsiChar(Index: Integer;
  Value: PAnsiChar; BLen: LengthInt);
var Bind: PZODBCParamBind;
begin
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    {$R-}
    Bind := @fParamBindings[Index];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    if (Bind.ParameterValuePtr = nil) or (Bind.ValueCount > 1) or (not Bind.Described and (Bind.BufferLength <= BLen)) then
      InitBind(Index, 1, stString);
    if Bind.SQLType in [stAsciiStream, stUnicodeStream] then begin
      if Value = nil then Value := PEmptyAnsiString;
      PIZlob(Bind.ParameterValuePtr)^ := TZAbstractClob.CreateWithData(Value, BLen, FClientCP, ConSettings);
      Bind.StrLen_or_IndPtr^ := SQL_DATA_AT_EXEC;
    end else case Bind.ValueType of
      SQL_C_BIT:      PByte(Bind.ParameterValuePtr)^     := Ord(StrToBoolEx(Value, Value+BLen, True, False));
      SQL_C_STINYINT: PShortInt(Bind.ParameterValuePtr)^ := RawToIntDef(Value, Value+BLen, 0);
      SQL_C_UTINYINT: PByte(Bind.ParameterValuePtr)^     := RawToIntDef(Value, Value+BLen, 0);
      SQL_C_SSHORT:   PSmallInt(Bind.ParameterValuePtr)^ := RawToIntDef(Value, Value+BLen, 0);
      SQL_C_USHORT:   PWord(Bind.ParameterValuePtr)^     := RawToIntDef(Value, Value+BLen, 0);
      SQL_C_SLONG:    PInteger(Bind.ParameterValuePtr)^  := RawToIntDef(Value, Value+BLen, 0);
      SQL_C_ULONG:    PCardinal(Bind.ParameterValuePtr)^ := Cardinal(RawToInt64Def(Value, Value+BLen, 0));
      SQL_C_SBIGINT:  PInt64(Bind.ParameterValuePtr)^    := RawToInt64Def(Value, Value+BLen, 0);
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
      SQL_C_UBIGINT:  PUInt64(Bind.ParameterValuePtr)^   := RawToUInt64Def(Value, Value+BLen, 0);
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}
      {SQL_C_TYPE_DATE, SQL_C_DATE,
      SQL_C_TYPE_TIME, SQL_C_TIME, SQL_C_SS_TIME2,
      SQL_C_TIMESTAMP, SQL_C_TYPE_TIMESTAMP, SQL_C_SS_TIMESTAMPOFFSET,}
      SQL_C_FLOAT:    PSingle(Bind.ParameterValuePtr)^   := RawToFloatDef(Value, AnsiChar('.'), 0);
      SQL_C_DOUBLE:   PDouble(Bind.ParameterValuePtr)^   := RawToFloatDef(Value, AnsiChar('.'), 0);
      SQL_C_NUMERIC: if Bind.SQLType = stCurrency then begin
                        RawToFloatDef(Value, AnsiChar('.'), 0, PCurrency(@fABuffer[0])^);
                        Curr2ODBCNumeric(PCurrency(@fABuffer[0])^, PSQL_NUMERIC_STRUCT(Bind.ParameterValuePtr));
                      end else begin
                        //ZFastCode.UnicodeToFloatDef(Value, '.', 0, PDouble(@fABuffer[0])^);
                        Raise EZUnsupportedException.Create(SUnsupportedOperation);
                      end;
      SQL_C_WCHAR:  begin
                      PSQLLEN(Bind.StrLen_or_IndPtr)^ := ZEncoding.PRaw2PUnicodeBuf(Value, BLen, Bind.ColumnSize, Bind.ParameterValuePtr, FClientCP) shl 1;
                      if PSQLLEN(Bind.StrLen_or_IndPtr)^ > Bind.BufferLength then
                        RaiseExceeded(Index);
                      Exit;
                    end;
      SQL_C_BINARY,
      SQL_C_CHAR:   begin
                      if BLen > Bind.BufferLength-1 then
                        RaiseExceeded(Index);
                      Move(Value^, PAnsiChar(Bind.ParameterValuePtr)^, BLen);
                      PSQLLEN(Bind.StrLen_or_IndPtr)^ := BLen;
                      PByte(PAnsiChar(Bind.ParameterValuePtr)+Blen)^ := 0;
                      Exit;
                    end;
      else RaiseUnsupportedParamType(Index, Bind.ValueType, stUnicodeString);
    end;
    PSQLLEN(Bind.StrLen_or_IndPtr)^ := SQL_NO_NULLS;
  end else begin
    ZSetString(Value, BLen, fRawTemp);
    BindList.Put(Index, stString, fRawTemp, FClientCP);
  end;
end;

procedure TZAbstractODBCPreparedStatement.SetPWideChar(Index: Integer;
  Value: PWideChar; WLen: LengthInt);
var Bind: PZODBCParamBind;
begin
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    {$R-}
    Bind := @fParamBindings[Index];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    if (Bind.ParameterValuePtr = nil) or (Bind.ValueCount > 1) or (not Bind.Described and (Bind.BufferLength <= WLen shl 1)) then
      InitBind(Index, 1, stUnicodeString);
    if Bind.SQLType in [stAsciiStream, stUnicodeStream] then begin
      if Value = nil then Value := PEmptyUnicodeString;
      PIZlob(Bind.ParameterValuePtr)^ := TZAbstractClob.CreateWithData(Value, WLen, ConSettings);
      Bind.StrLen_or_IndPtr^ := SQL_DATA_AT_EXEC;
    end else case Bind.ValueType of
      SQL_C_BIT:      PByte(Bind.ParameterValuePtr)^      := Ord(StrToBoolEx(Value, Value+WLen, True, False));
      SQL_C_STINYINT: PShortInt(Bind.ParameterValuePtr)^  := UnicodeToIntDef(Value, Value+WLen, 0);
      SQL_C_UTINYINT: PByte(Bind.ParameterValuePtr)^      := UnicodeToIntDef(Value, Value+WLen, 0);
      SQL_C_SSHORT:   PSmallInt(Bind.ParameterValuePtr)^  := UnicodeToIntDef(Value, Value+WLen, 0);
      SQL_C_USHORT:   PWord(Bind.ParameterValuePtr)^      := UnicodeToIntDef(Value, Value+WLen, 0);
      SQL_C_SLONG:    PInteger(Bind.ParameterValuePtr)^   := UnicodeToIntDef(Value, Value+WLen, 0);
      SQL_C_ULONG:    PCardinal(Bind.ParameterValuePtr)^  := Cardinal(UnicodeToInt64Def(Value, Value+WLen, 0));
      SQL_C_SBIGINT:  PInt64(Bind.ParameterValuePtr)^     := UnicodeToInt64Def(Value, Value+WLen, 0);
      SQL_C_UBIGINT:  PUInt64(Bind.ParameterValuePtr)^    := UnicodeToUInt64Def(Value, Value+WLen, 0);
      {SQL_C_TYPE_DATE, SQL_C_DATE,
      SQL_C_TYPE_TIME, SQL_C_TIME, SQL_C_SS_TIME2,
      SQL_C_TIMESTAMP, SQL_C_TYPE_TIMESTAMP, SQL_C_SS_TIMESTAMPOFFSET,}
      SQL_C_FLOAT:    PSingle(Bind.ParameterValuePtr)^    := UnicodeToFloatDef(Value, WideChar('.'), 0);
      SQL_C_DOUBLE:   PDouble(Bind.ParameterValuePtr)^    := UnicodeToFloatDef(Value, WideChar('.'), 0);
      SQL_C_NUMERIC:  if Bind.SQLType = stCurrency then begin
                        ZFastCode.UnicodeToFloatDef(Value, WideChar('.'), 0, PCurrency(@fABuffer[0])^);
                        Curr2ODBCNumeric(PCurrency(@fABuffer[0])^, PSQL_NUMERIC_STRUCT(Bind.ParameterValuePtr));
                      end else begin
                        //ZFastCode.UnicodeToFloatDef(Value, '.', 0, PDouble(@fABuffer[0])^);
                        Raise EZUnsupportedException.Create(SUnsupportedOperation);
                      end;
      SQL_C_WCHAR:  begin
                      WLen := WLen shl 1;
                      if WLen < Bind.BufferLength then begin
                        Move(Value^, Bind.ParameterValuePtr^, WLen);
                        PWord(PAnsiChar(Bind.ParameterValuePtr)+WLen)^ := Ord(#0);
                      end else
                        RaiseExceeded(Index);
                      PSQLLEN(Bind.StrLen_or_IndPtr)^ := WLen;
                      Exit;
                    end;
      SQL_C_CHAR:   begin
                      PSQLLEN(Bind.StrLen_or_IndPtr)^ := PUnicode2PRawBuf(Value, Bind.ParameterValuePtr, WLen, Bind.BufferLength, ClientCP);
                      if PSQLLEN(Bind.StrLen_or_IndPtr)^ > Bind.BufferLength-1 then
                        RaiseExceeded(Index);
                      PByte(PAnsiChar(Bind.ParameterValuePtr)+PSQLLEN(Bind.StrLen_or_IndPtr)^)^ := Ord(#0);
                      Exit;
                    end;
      else RaiseUnsupportedParamType(Index, Bind.ValueType, stUnicodeString);
    end;
    PSQLLEN(Bind.StrLen_or_IndPtr)^ := SQL_NO_NULLS;
  end else begin
    System.SetString(fUniTemp, Value, WLen);
    BindList.Put(Index, stUnicodeString, fUniTemp);
  end;
end;

procedure TZAbstractODBCPreparedStatement.SetRawByteString(Index: Integer;
  const Value: RawByteString);
begin
  BindRaw(Index{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, Value, FClientCP);
end;

{**
  Sets the designated parameter to a Java <code>ShortInt</code> value.
  The driver converts this
  to an SQL <code>ShortInt</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZAbstractODBCPreparedStatement.SetShort(ParameterIndex: Integer;
  Value: ShortInt);
begin
  BindSInteger(ParameterIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, stShort, Integer(Value))
end;

{**
  Sets the designated parameter to a Java <code>SmallInt</code> value.
  The driver converts this
  to an SQL <code>ShortInt</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZAbstractODBCPreparedStatement.SetSmall(ParameterIndex: Integer;
  Value: SmallInt);
begin
  BindSInteger(ParameterIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, stSmall, Integer(Value))
end;

{**
  Sets the designated parameter to a Java <code>String</code> value.
  The driver converts this
  to an SQL <code>VARCHAR</code> or <code>LONGVARCHAR</code> value
  (depending on the argument's
  size relative to the driver's limits on <code>VARCHAR</code> values)
  when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZAbstractODBCPreparedStatement.SetString(Index: Integer;
  const Value: String);
{$IFNDEF UNICODE}
var Bind: PZODBCParamBind;
{$ENDIF}
begin
  {$IFDEF UNICODE}
  SetPWideChar(Index{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, Pointer(Value), Length(Value));
  {$ELSE}
  {$IFNDEF GENERIC_INDEX}Index := Index-1;{$ENDIF}
  if ConSettings.AutoEncode and (Value <> '') then begin
    CheckParameterIndex(Index);
    if fBindImmediat then begin
      {$R-}
      Bind := @fParamBindings[Index];
      {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
      if (Bind.ValueType = SQL_C_WCHAR) then begin
        fUniTemp := ZRawToUnicode(Value, FClientCP);
        SetUnicodeString(Index{$IFNDEF GENERIC_INDEX}+1{$ENDIF}, fUniTemp);
      end else if (Bind.ValueType = SQL_C_CHAR) then begin
        fRawTemp := ConSettings.ConvFuncs.ZStringToRaw(Value, ConSettings.CTRL_CP, FClientCP);
        BindRaw(Index, FRawTemp, FClientCP);
      end else
       SetPAnsiChar(Index, Pointer(Value), Length(Value))
    end else if FClientEncoding = ceUTF16 then begin
      fUniTemp := ZRawToUnicode(Value, FClientCP);
      BindList.Put(Index, stUnicodeString, fUniTemp);
    end else begin
      fRawTemp := ConSettings.ConvFuncs.ZStringToRaw(Value, ConSettings.CTRL_CP, FClientCP);
      BindList.Put(Index, stString, Value, FClientCP);
    end;
  end else BindRaw(Index, Value, FClientCP);
  {$ENDIF}
end;

{**
  Sets the designated parameter to a <code>java.sql.Time</code> value.
  The driver converts this to an SQL <code>TIME</code> value
  when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZAbstractODBCPreparedStatement.SetTime(Index: Integer;
  const Value: TZTime);
var Bind: PZODBCParamBind;
  DT: TDateTime;
  Len: LengthInt;
begin
  {$IFNDEF GENERIC_INDEX}Index := Index-1;{$ENDIF}
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    {$R-}
    Bind := @fParamBindings[Index];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    if (Bind.ParameterValuePtr = nil) or (Bind.ValueCount > 1) or (not Bind.Described and (Bind.SQLType <> stTime)) then
      InitBind(Index, 1, stTime);
    case Bind.ValueType of
      SQL_C_TYPE_DATE, SQL_C_DATE: FillChar(Bind.ParameterValuePtr^, SizeOf(TSQL_DATE_STRUCT), #0);
      SQL_C_TYPE_TIME,
      SQL_C_TIME:     with PSQL_TIME_STRUCT(Bind.ParameterValuePtr)^ do begin
                        if SizeOf(TSQL_TIME_STRUCT) = SizeOf(TZTime)-6 then
                          PSQL_TIME_STRUCT(Bind.ParameterValuePtr)^ := PSQL_TIME_STRUCT(@Value.Hour)^
                        else begin
                          Hour := Value.Hour;
                          Minute := Value.Minute;
                          Second := Value.Second;
                        end;
                      end;
      SQL_C_SS_TIME2: with PSQL_SS_TIME2_STRUCT(Bind.ParameterValuePtr)^ do begin
                        if SizeOf(TSQL_SS_TIME2_STRUCT) = SizeOf(TZTime)-2 then
                          PSQL_SS_TIME2_STRUCT(Bind.ParameterValuePtr)^ := PSQL_SS_TIME2_STRUCT(@Value.Hour)^
                        else begin
                          Hour := Value.Hour;
                          Minute := Value.Minute;
                          Second := Value.Second;
                          Fraction := Value.Fractions
                        end;
                      end;
      SQL_C_TIMESTAMP, SQL_C_TYPE_TIMESTAMP: begin
                        With PSQL_TIMESTAMP_STRUCT(Bind.ParameterValuePtr)^ do begin
                          Year := cPascalIntegralDatePart.Year;
                          Month := cPascalIntegralDatePart.Month;
                          Day := cPascalIntegralDatePart.Day;
                          Hour := Value.Hour;
                          Minute := Value.Minute;
                          Second := Value.Second;
                          fraction := Value.Fractions;
                        end;
                      end;
      SQL_C_SS_TIMESTAMPOFFSET:
                        With PSQL_SS_TIMESTAMPOFFSET_STRUCT(Bind.ParameterValuePtr)^ do begin
                          Year := cPascalIntegralDatePart.Year;
                          Month := cPascalIntegralDatePart.Month;
                          Day := cPascalIntegralDatePart.Day;
                          Hour := Value.Hour;
                          Minute := Value.Minute;
                          Second := Value.Second;
                          Fraction := Value.Fractions;
                          timezone_hour := 0;
                          timezone_minute := 0;
                        end;
      SQL_C_WCHAR:  begin
              Len := TimeToUni(Value.Hour, Value.Minute, Value.Second, Value.Fractions,
                @fWBuffer[0], ConSettings^.WriteFormatSettings.TimeFormat, False, Value.IsNegative);
              SetPWideChar(Index, @fWBuffer[0], Len);
              Exit;
            end;
      SQL_C_CHAR:  begin
              Len := TimeToRaw(Value.Hour, Value.Minute, Value.Second, Value.Fractions,
                @fABuffer[0], ConSettings^.WriteFormatSettings.TimeFormat, False, Value.IsNegative);
              SetPAnsiChar(Index, @fABuffer[0], Len);
              Exit;
            end;
      else  begin
              if TryTimeToDateTime(Value, DT{%H-})
              then InternalBindDouble(Index, stTime, DT)
              else BindSInteger(Index, stTime, 1);
              Exit;
            end;
      end;
    PSQLLEN(Bind.StrLen_or_IndPtr)^ := SQL_NO_NULLS;
  end else
    BindList.Put(Index, Value);
end;

{**
  Sets the designated parameter to a <code>java.sql.Timestamp</code> value.
  The driver converts this to an SQL <code>TIMESTAMP</code> value
  when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZAbstractODBCPreparedStatement.SetTimestamp(Index: Integer;
  const Value: TZTimeStamp);
var Bind: PZODBCParamBind;
  DT: TDateTime;
  Len: LengthInt;
begin
  {$IFNDEF GENERIC_INDEX}Index := Index-1;{$ENDIF}
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    {$R-}
    Bind := @fParamBindings[Index];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    if (Bind.ParameterValuePtr = nil) or (Bind.ValueCount > 1) or (not Bind.Described and (Bind.SQLType <> stTimeStamp)) then
      InitBind(Index, 1, stTimeStamp);
    case Bind.ValueType of
      SQL_C_TYPE_DATE,
      SQL_C_DATE:       with PSQL_DATE_STRUCT(Bind.ParameterValuePtr)^ do begin
                          Year := Value.Year;
                          if Value.IsNegative then
                            Year := -Year;
                          Month := Value.Month;
                          Day := Value.Day;
                        end;
      SQL_C_TYPE_TIME,
      SQL_C_TIME:       with PSQL_TIME_STRUCT(Bind.ParameterValuePtr)^ do begin
                          Hour := Value.Hour;
                          Minute := Value.Minute;
                          Second := Value.Second;
                        end;
      SQL_C_SS_TIME2:   with PSQL_SS_TIME2_STRUCT(Bind.ParameterValuePtr)^ do begin
                          Hour := Value.Hour;
                          Minute := Value.Minute;
                          Second := Value.Second;
                          Fraction := Value.Fractions
                        end;
      SQL_C_TIMESTAMP, SQL_C_TYPE_TIMESTAMP:
                        With PSQL_TIMESTAMP_STRUCT(Bind.ParameterValuePtr)^ do begin
                          Year := Value.Year;
                          Month := Value.Month;
                          Day := Value.Day;
                          Hour := Value.Hour;
                          Minute := Value.Minute;
                          Second := Value.Second;
                          fraction := Value.Fractions;
                          if Value.IsNegative then
                            Year := -Year;
                        end;
      SQL_C_SS_TIMESTAMPOFFSET:
                        With PSQL_SS_TIMESTAMPOFFSET_STRUCT(Bind.ParameterValuePtr)^ do begin
                          Year := Value.Year;
                          Month := Value.Month;
                          Day := Value.Day;
                          Hour := Value.Hour;
                          Minute := Value.Minute;
                          Second := Value.Second;
                          Fraction := Value.Fractions;
                          timezone_hour := Value.TimeZoneHour;
                          timezone_minute := Value.TimeZoneMinute;
                          if Value.IsNegative then
                            Year := -Year;
                        end;
      SQL_C_WCHAR:  begin
              Len := ZSysUtils.DateTimeToUni(Value.Year, Value.Month, Value.Day,
                Value.Hour, Value.Minute, Value.Second, Value.Fractions,
                @fWBuffer[0], ConSettings^.WriteFormatSettings.TimeFormat, False, Value.IsNegative);
              SetPWideChar(Index, @fWBuffer[0], Len);
              Exit;
            end;
      SQL_C_CHAR:  begin
              Len := ZSysUtils.DateTimeToUni(Value.Year, Value.Month, Value.Day,
                Value.Hour, Value.Minute, Value.Second, Value.Fractions,
                @fABuffer[0], ConSettings^.WriteFormatSettings.TimeFormat, False, Value.IsNegative);
              SetPAnsiChar(Index, @fABuffer[0], Len);
              Exit;
            end;
      else  begin
              if TryTimeStampToDateTime(Value, DT{%H-})
              then InternalBindDouble(Index, stTimeStamp, DT)
              else BindSInteger(Index, stTimeStamp, 1);
              Exit;
            end;
    end;
    PSQLLEN(Bind.StrLen_or_IndPtr)^ := SQL_NO_NULLS;
  end else
    BindList.Put(Index, Value);
end;

{**
  Sets the designated parameter to a Java <code>usigned 32bit int</code> value.
  The driver converts this
  to an SQL <code>INTEGER</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZAbstractODBCPreparedStatement.SetUInt(ParameterIndex: Integer;
  Value: Cardinal);
begin
  BindUInteger(ParameterIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, stLongWord, Value)
end;

{**
  Sets the designated parameter to a Java <code>unsigned long long</code> value.
  The driver converts this
  to an SQL <code>BIGINT</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZAbstractODBCPreparedStatement.SetULong(Index: Integer; const Value: UInt64);
{$IFDEF CPU64}
begin
  BindUInteger(Index{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, stULong, Value)
{$ELSE}
var Bind: PZODBCParamBind;
begin
  {$IFNDEF GENERIC_INDEX}Index := Index-1;{$ENDIF}
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    {$R-}
    Bind := @fParamBindings[Index];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    if (Bind.ParameterValuePtr = nil) or (Bind.ValueCount > 1) or (not Bind.Described and (stULong <> Bind.SQLType)) then
      InitBind(Index, 1, stULong);
    case Bind.ValueType of
      SQL_C_BIT:      PByte(Bind.ParameterValuePtr)^     := Ord(Value <> 0);
      SQL_C_STINYINT: PShortInt(Bind.ParameterValuePtr)^ := ShortInt(Value);
      SQL_C_UTINYINT: PByte(Bind.ParameterValuePtr)^     := Byte(Value);
      SQL_C_SSHORT:   PSmallInt(Bind.ParameterValuePtr)^ := SmallInt(Value);
      SQL_C_USHORT:   PWord(Bind.ParameterValuePtr)^     := Word(Value);
      SQL_C_SLONG:    PInteger(Bind.ParameterValuePtr)^  := Integer(Value);
      SQL_C_ULONG:    PCardinal(Bind.ParameterValuePtr)^ := Cardinal(Value);
      SQL_C_SBIGINT:  PInt64(Bind.ParameterValuePtr)^    := Int64(Value);
      SQL_C_UBIGINT:  PUInt64(Bind.ParameterValuePtr)^   := Value;
      SQL_C_TYPE_DATE, SQL_C_DATE,
      SQL_C_TYPE_TIME, SQL_C_TIME, SQL_C_SS_TIME2,
      SQL_C_TIMESTAMP, SQL_C_TYPE_TIMESTAMP, SQL_C_SS_TIMESTAMPOFFSET,
      SQL_C_FLOAT, SQL_C_DOUBLE: InternalBindDouble(Index, stLong, Value);
      SQL_C_NUMERIC:  Curr2ODBCNumeric(Value, Bind.ParameterValuePtr);
      SQL_C_WCHAR:  begin
                      IntToUnicode(Value, @fWBuffer[SizeOf(Pointer)], @fWBuffer[0]);
                      SetPWideChar(Index, @fWBuffer[SizeOf(Pointer)], ZPPWideChar(@fWBuffer[0])^-PWideChar(@fWBuffer[SizeOf(Pointer)]));
                      Exit;
                    end;
      SQL_C_CHAR:   begin
                      IntToRaw(Value, @fABuffer[SizeOf(Pointer)], @fABuffer[0]);
                      SetPAnsiChar(Index, @fABuffer[SizeOf(Pointer)], PPAnsiChar(@fABuffer[0])^-PAnsiChar(@fWBuffer[SizeOf(Pointer)]));
                      Exit;
                    end;
      else RaiseUnsupportedParamType(Index, Bind.ValueType, stLong);
    end;
    PSQLLEN(Bind.StrLen_or_IndPtr)^ := SQL_NO_NULLS;
  end else
    BindList.Put(Index, stLong, P8Bytes(@Value));
{$ENDIF}
end;

{**
  Sets the designated parameter to a Java <code>UnicodeString</code> value.
  The driver converts this
  to an SQL <code>VARCHAR</code> or <code>LONGVARCHAR</code> value
  (depending on the argument's
  size relative to the driver's limits on <code>VARCHAR</code> values)
  when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZAbstractODBCPreparedStatement.SetUnicodeString(Index: Integer;
  const Value: ZWideString);
var Bind: PZODBCParamBind;
begin
  {$IFNDEF GENERIC_INDEX}Index := Index-1;{$ENDIF}
  CheckParameterIndex(Index);
  if fBindImmediat then begin
    {$R-}
    Bind := @fParamBindings[Index];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    PSQLLEN(Bind.StrLen_or_IndPtr)^ := SQL_NO_NULLS;
    if (Bind.ParameterValuePtr = nil) or (Bind.ValueCount > 1) or (not Bind.Described and ((stUnicodeString <> Bind.SQLType) or (Bind.BufferLength < (Length(Value)+1) shl 1))) then
      InitBind(Index, 1, stUnicodeString);
    case Bind.ValueType of
      SQL_C_WChar:    if Bind.SQLType in [stString, stUnicodeString] then begin
                        PSQLLEN(Bind.StrLen_or_IndPtr)^ := Length(Value) shl 1;
                        if PSQLLEN(Bind.StrLen_or_IndPtr)^ >= Bind.BufferLength then
                          RaiseExceeded(Index);
                        Move(Pointer(Value)^, Bind.ParameterValuePtr^, PSQLLEN(Bind.StrLen_or_IndPtr)^);
                        PWord(PAnsiChar(Bind.ParameterValuePtr)+PSQLLEN(Bind.StrLen_or_IndPtr)^)^ := 0;
                      end else
                        SetPWideChar(Index, Pointer(Value), Length(Value));
      else SetPWideChar(Index, Pointer(Value), Length(Value));
    end;
  end else
    BindList.Put(Index, stUnicodeString, Value);
end;

{$IFNDEF NO_UTF8STRING}
procedure TZAbstractODBCPreparedStatement.SetUTF8String(Index: Integer;
  const Value: UTF8String);
begin
  BindRaw(Index{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, Value, zCP_UTF8);
end;
{$ENDIF}

{**
  Sets the designated parameter to a Java <code>unsigned 16bit int</code> value.
  The driver converts this
  to an SQL <code>WORD</code> value when it sends it to the database.

  @param parameterIndex the first parameter is 1, the second is 2, ...
  @param x the parameter value
}
procedure TZAbstractODBCPreparedStatement.SetWord(ParameterIndex: Integer; Value: Word);
begin
  BindUInteger(ParameterIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, stWord, Cardinal(Value))
end;

{**
  Removes eventual structures for binding input parameters.
}
procedure TZAbstractODBCPreparedStatement.UnPrepareInParameters;
begin
  try
    if Assigned(fHSTMT) and Assigned(fPHDBC^) then
      CheckStmtError(fPlainDriver.SQLFreeStmt(fHSTMT,SQL_RESET_PARAMS));
  finally
    inherited UnPrepareInParameters;
  end;
end;

{ TZODBCCallableStatementW }

constructor TZODBCCallableStatementW.Create(const Connection: IZConnection;
  var ConnectionHandle: SQLHDBC; const StoredProcOrFuncIdentifier: string;
  {$IFDEF AUTOREFCOUNT}const{$ENDIF}Info: TStrings);
begin
  inherited Create(Connection, StoredProcOrFuncIdentifier, Info);
  fPHDBC := @ConnectionHandle
end;

function TZODBCCallableStatementW.CreateExecutionStatement(
  const StoredProcName: String): TZAbstractPreparedStatement;
var  I: Integer;
  SQL: SQLString;
  SQLWriter: TZSQLStringWriter;
begin
  //https://docs.microsoft.com/en-us/sql/relational-databases/native-client-ole-db-how-to/results/execute-stored-procedure-with-rpc-and-process-output?view=sql-server-2017
  SQL := '{? = CALL ';
  I := Length(StoredProcName);
  i := I + 20+BindList.Count shl 1;
  SQLWriter := TZSQLStringWriter.Create(I);
  SQLWriter.AddText(StoredProcName, SQL);
  if BindList.Count > 1 then
    SQLWriter.AddChar('(', SQL);
  for i := 1 to BindList.Count-1 do
    SQLWriter.AddText('?,', SQL);
  if BindList.Count > 1 then begin
    SQLWriter.CancelLastComma(SQL);
    SQLWriter.AddChar(')', SQL);
  end;
  SQLWriter.AddChar('}', SQL);
  SQLWriter.Finalize(SQL);
  FreeAndNil(SQLWriter);
  Result := TZODBCPreparedStatementW.Create(Connection as IZODBCConnection, fPHDBC^, SQL, Info);
  TZODBCPreparedStatementW(Result).Prepare;
end;

{ TZODBCCallableStatementA }

constructor TZODBCCallableStatementA.Create(
  const Connection: IZConnection; var ConnectionHandle: SQLHDBC;
  const StoredProcOrFuncIdentifier: string;
  {$IFDEF AUTOREFCOUNT}const{$ENDIF} Info: TStrings);
begin
  inherited Create(Connection, StoredProcOrFuncIdentifier, Info);
  fPHDBC := @ConnectionHandle
end;

function TZODBCCallableStatementA.CreateExecutionStatement(
  const StoredProcName: String): TZAbstractPreparedStatement;
var  I: Integer;
  SQL: SQLString;
  SQLWriter: TZSQLStringWriter;
begin
  //https://docs.microsoft.com/en-us/sql/relational-databases/native-client-ole-db-how-to/results/execute-stored-procedure-with-rpc-and-process-output?view=sql-server-2017
  SQL := '{? = CALL ';
  I := Length(StoredProcName);
  i := I + 20+BindList.Count shl 1;
  SQLWriter := TZSQLStringWriter.Create(I);
  SQLWriter.AddText(StoredProcName, SQL);
  if BindList.Count > 1 then
    SQLWriter.AddChar('(', SQL);
  for i := 1 to BindList.Count-1 do
    SQLWriter.AddText('?,', SQL);
  if BindList.Count > 1 then begin
    SQLWriter.CancelLastComma(SQL);
    SQLWriter.AddChar(')', SQL);
  end;
  SQLWriter.AddChar('}', SQL);
  SQLWriter.Finalize(SQL);
  FreeAndNil(SQLWriter);
  Result := TZODBCPreparedStatementA.Create(Connection as IZODBCConnection, fPHDBC^, SQL, Info);
  TZODBCPreparedStatementA(Result).Prepare;
end;

{ TZODBCStatementW }

constructor TZODBCStatementW.Create(const Connection: IZODBCConnection;
  var ConnectionHandle: SQLHDBC; Info: TStrings);
begin
  inherited Create(Connection, ConnectionHandle, '', Info);
end;

function TZODBCStatementW.ExecutDirect: RETCODE;
begin
  Result := TODBC3UnicodePlainDriver(fPlainDriver).SQLExecDirectW(fHSTMT, Pointer(WSQL), Length(WSQL))
end;

{ TZODBCStatementA }

constructor TZODBCStatementA.Create(const Connection: IZODBCConnection;
  var ConnectionHandle: SQLHDBC; Info: TStrings);
begin
  inherited Create(Connection, ConnectionHandle, '', Info);
end;

function TZODBCStatementA.ExecutDirect: RETCODE;
begin
  Result := TODBC3RawPlainDriver(fPlainDriver).SQLExecDirect(fHSTMT, Pointer(fASQL), Length(fASQL))
end;

initialization

SetLength(DefaultPreparableTokens, 6);
DefaultPreparableTokens[0].MatchingGroup := 'DELETE';
DefaultPreparableTokens[1].MatchingGroup := 'INSERT';
DefaultPreparableTokens[2].MatchingGroup := 'UPDATE';
DefaultPreparableTokens[3].MatchingGroup := 'SELECT';
DefaultPreparableTokens[4].MatchingGroup := 'CALL';
DefaultPreparableTokens[5].MatchingGroup := 'SET';

{$ENDIF ZEOS_DISABLE_ODBC} //if set we have an empty unit
end.


