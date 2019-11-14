{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{           MySQL Database Connectivity Classes           }
{                                                         }
{        Originally written by Sergey Seroukhov           }
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

{EH: First of all read this:
  http://blog.ulf-wendel.de/2008/pdo_mysqlnd-prepared-statements-again/}

unit ZDbcMySqlResultSet;

interface

{$I ZDbc.inc}

{$IFNDEF ZEOS_DISABLE_MYSQL} //if set we have an empty unit
uses
{$IFDEF USE_SYNCOMMONS}
  SynCommons, SynTable,
{$ENDIF USE_SYNCOMMONS}
  FmtBCD, Classes, {$IFDEF MSEgui}mclasses,{$ENDIF} SysUtils, Types,
  {$IFNDEF NO_UNIT_CONTNRS}Contnrs,{$ENDIF} ZClasses,
  ZDbcIntfs, ZDbcResultSet, ZDbcResultSetMetadata, ZCompatibility, ZDbcCache,
  ZDbcCachedResultSet, ZDbcGenericResolver, ZDbcMySqlStatement, ZDbcMySqlUtils,
  ZPlainMySqlDriver, ZPlainMySqlConstants, ZSelectSchema, ZVariant;

type
  {** Implements MySQL ResultSet Metadata. }
  TZMySQLResultSetMetadata = class(TZAbstractResultSetMetadata)
  private
    FHas_ExtendedColumnInfos: Boolean;
  protected
    procedure ClearColumn(ColumnInfo: TZColumnInfo); override;
    procedure LoadColumns; override;
  public
    constructor Create(const Metadata: IZDatabaseMetadata; const SQL: string;
      ParentResultSet: TZAbstractResultSet);
  public
    function GetCatalogName(ColumnIndex: Integer): string; override;
    function GetColumnName(ColumnIndex: Integer): string; override;
    function GetColumnType(ColumnIndex: Integer): TZSQLType; override;
    function GetSchemaName(ColumnIndex: Integer): string; override;
    function GetTableName(ColumnIndex: Integer): string; override;
    function IsAutoIncrement(ColumnIndex: Integer): Boolean; override;
  end;

  { Interbase Error Class}
  EZMySQLConvertError = class(EZSQLException);
  {** Implements MySQL ResultSet. }

  { TZAbstractMySQLResultSet }

  TZAbstractMySQLResultSet = class(TZAbstractReadOnlyResultSet_A, IZResultSet)
  private //common
    FFirstRowFetched: boolean; //we can't seek to a negative index -> hook BeforeFirst state
    FFieldCount: ULong;
    FPMYSQL: PPMYSQL; //address of the MYSQL connection handle
    FMYSQL_aligned_BINDs: PMYSQL_aligned_BINDs; //offset descriptor structures
    FIsOutParamResult: Boolean; //is the result a `Result of Out params?
    procedure InitColumnBinds(Bind: PMYSQL_aligned_BIND; MYSQL_FIELD: PMYSQL_FIELD;
      FieldOffsets: PMYSQL_FIELDOFFSETS; Iters: Integer);
  private //connection resultset
    FQueryHandle: PZMySQLResult; //a query handle
    FRowHandle: PZMySQLRow; //current row handle
    FPlainDriver: TZMySQLPlainDriver; //our api holder object
    FLengthArray: PULongArray; //for non prepareds a Length array
    fServerCursor: Boolean; //fetch row by row from server?
   private { prepared stmt }
    fBindBufferAllocated: Boolean; //are the bindbuffers mysql writes in allocated?
    FFetchStatus: Integer; //the FFetchStatus of mysql_stmt_fetch
    FMYSQL_STMT: PMYSQL_STMT; //the prepared stmt handle
    FPMYSQL_STMT: PPMYSQL_STMT; //address of the prepared stmt handle
    //FBindOffSets: PMYSQL_BINDOFFSETS;
    FMYSQL_Col_BIND_Address: PPointer; //the buffer mysql writes in
    FTempBlob: IZBlob; //temporary Lob
    FClosing: Boolean;
    FClientCP: Word;
    function CreateMySQLConvertError(ColumnIndex: Integer; DataType: TMysqlFieldType): EZMySQLConvertError;
  protected
    procedure Open; override;
  public
    constructor Create(const PlainDriver: TZMySQLPlainDriver;
      const Statement: IZStatement; const SQL: string; IsOutParamResult: Boolean;
      PMYSQL: PPMYSQL; PMYSQL_STMT: PPMYSQL_STMT; MYSQL_ColumnsBinding: PMYSQL_ColumnsBinding; AffectedRows: PInteger;
      out OpenCursorCallback: TOpenCursorCallback);
    destructor Destroy; override;
    procedure BeforeClose; override;
    procedure AfterClose; override;
    procedure ReleaseImmediat(const Sender: IImmediatelyReleasable;
      var AError: EZSQLConnectionLost); override;

    function IsNull(ColumnIndex: Integer): Boolean;
    function GetPAnsiChar(ColumnIndex: Integer; out Len: NativeUInt): PAnsiChar; overload;
    function GetPWideChar(ColumnIndex: Integer; out Len: NativeUInt): PWideChar; overload;
    function GetBoolean(ColumnIndex: Integer): Boolean;
    function GetInt(ColumnIndex: Integer): Integer;
    function GetUInt(ColumnIndex: Integer): Cardinal;
    function GetLong(ColumnIndex: Integer): Int64;
    function GetULong(ColumnIndex: Integer): UInt64;
    function GetFloat(ColumnIndex: Integer): Single;
    function GetDouble(ColumnIndex: Integer): Double;
    function GetCurrency(ColumnIndex: Integer): Currency;
    procedure GetBigDecimal(ColumnIndex: Integer; var Result: TBCD);
    procedure GetGUID(ColumnIndex: Integer; var Result: TGUID);
    function GetBytes(ColumnIndex: Integer): TBytes;
    procedure GetDate(ColumnIndex: Integer; var Result: TZDate); reintroduce; overload;
    procedure GetTime(ColumnIndex: Integer; var Result: TZTime); reintroduce; overload;
    procedure GetTimeStamp(ColumnIndex: Integer; var Result: TZTimeStamp); reintroduce; overload;
    function GetBlob(ColumnIndex: Integer): IZBlob;

    {$IFDEF USE_SYNCOMMONS}
    procedure ColumnsToJSON(JSONWriter: TJSONWriter; JSONComposeOptions: TZJSONComposeOptions = [jcoEndJSONObject]);
    {$ENDIF USE_SYNCOMMONS}
    //EH: keep that override 4 all descendants: seek_data is dead slow in a forward only mode
    function Next: Boolean; reintroduce;

    procedure ResetCursor; override;
    procedure OpenCursor; virtual;
  end;

  TZMySQL_Store_ResultSet = class(TZAbstractMySQLResultSet)
  public
    function MoveAbsolute(Row: Integer): Boolean; override;
    procedure ResetCursor; override;
    procedure OpenCursor; override;
  end;

  TZMySQL_Use_ResultSet = class(TZAbstractMySQLResultSet)
  public
    procedure ResetCursor; override;
    procedure OpenCursor; override;
    procedure AfterConstruction; override;
  end;

  {** Implements a cached resolver with MySQL specific functionality. }
  TZMySQLCachedResolver = class (TZGenericCachedResolver, IZCachedResolver)
  private
    FPMYSQL: PPMySQL;
    FMYSQL_STMT: PPMYSQL_STMT;
    FPlainDriver: TZMySQLPlainDriver;
    FAutoColumnIndex: Integer;
  public
    constructor Create(const PlainDriver: TZMySQLPlainDriver; MySQL: PPMySQL;
      MYSQL_STMT: PPMYSQL_STMT; const Statement: IZStatement;
      const Metadata: IZResultSetMetadata);

    procedure FormWhereClause({$IFDEF AUTOREFCOUNT}const {$ENDIF}Columns: TObjectList;
      {$IFDEF AUTOREFCOUNT}const {$ENDIF}SQLWriter: TZSQLStringWriter;
      {$IFDEF AUTOREFCOUNT}const {$ENDIF}OldRowAccessor: TZRowAccessor; var Result: SQLString); override;
    procedure PostUpdates(const Sender: IZCachedResultSet; UpdateType: TZRowUpdateType;
      OldRowAccessor, NewRowAccessor: TZRowAccessor); override;

    {BEGIN of PATCH [1185969]: Do tasks after posting updates. ie: Updating AutoInc fields in MySQL }
    procedure UpdateAutoIncrementFields(const Sender: IZCachedResultSet; {%H-}UpdateType: TZRowUpdateType;
      OldRowAccessor, NewRowAccessor: TZRowAccessor; const {%H-}Resolver: IZCachedResolver); override;
    {END of PATCH [1185969]: Do tasks after posting updates. ie: Updating AutoInc fields in MySQL }
  end;

  TZMySQLPreparedClob = Class(TZAbstractClob)
  public
    constructor Create(const PlainDriver: TZMySQLPlainDriver; Bind: PMYSQL_aligned_BIND;
      StmtHandle: PPMYSQL_STMT; ColumnIndex: Cardinal; const Sender: IImmediatelyReleasable);
  End;

  TZMySQLPreparedBlob = Class(TZAbstractBlob)
  public
    constructor Create(const PlainDriver: TZMySQLPlainDriver; Bind: PMYSQL_aligned_BIND;
      StmtHandle: PMySql_Stmt; ColumnIndex: Cardinal; const Sender: IImmediatelyReleasable);
  End;

{$ENDIF ZEOS_DISABLE_MYSQL} //if set we have an empty unit
implementation
{$IFNDEF ZEOS_DISABLE_MYSQL} //if set we have an empty unit

uses
  Math, {$IFDEF WITH_UNITANSISTRINGS}AnsiStrings,{$ENDIF}
  ZFastCode, ZSysUtils, ZMessages, ZEncoding,
  ZDbcMySQL, ZDbcUtils, ZDbcMetadata, ZDbcLogging;

{ TZMySQLResultSetMetadata }

procedure TZMySQLResultSetMetadata.ClearColumn(ColumnInfo: TZColumnInfo);
begin
  ColumnInfo.ReadOnly := True;
  ColumnInfo.Writable := False;
  ColumnInfo.DefinitelyWritable := False;
end;

{**
  Constructs this object and assignes the main properties.
  @param Metadata a database metadata object.
  @param SQL an SQL query statement.
  @param ColumnsInfo a collection of columns info.
}
constructor TZMySQLResultSetMetadata.Create(const Metadata: IZDatabaseMetadata;
  const SQL: string; ParentResultSet: TZAbstractResultSet);
begin
  inherited Create(Metadata, SQL, ParentResultSet);
  FHas_ExtendedColumnInfos := TZMySQLPlainDriver(MetaData.GetConnection.GetIZPlainDriver.GetInstance).mysql_get_client_version > 40000;
end;

{**
  Gets the designated column's table's catalog name.
  @param ColumnIndex the first column is 1, the second is 2, ...
  @return column name or "" if not applicable
}
function TZMySQLResultSetMetadata.GetCatalogName(ColumnIndex: Integer): string;
begin
  if not FHas_ExtendedColumnInfos and not Loaded
  then LoadColumns;
  Result := TZColumnInfo(ResultSet.ColumnsInfo[ColumnIndex{$IFNDEF GENERIC_INDEX} - 1{$ENDIF}]).CatalogName;
end;

{**
  Get the designated column's name.
  @param ColumnIndex the first column is 1, the second is 2, ...
  @return column name
}
function TZMySQLResultSetMetadata.GetColumnName(ColumnIndex: Integer): string;
begin
  if not FHas_ExtendedColumnInfos and not Loaded
  then LoadColumns;
  Result := TZColumnInfo(ResultSet.ColumnsInfo[ColumnIndex{$IFNDEF GENERIC_INDEX} - 1{$ENDIF}]).ColumnName;
end;

{**
  Retrieves the designated column's SQL type.
  @param column the first column is 1, the second is 2, ...
  @return SQL type from java.sql.Types
}
function TZMySQLResultSetMetadata.GetColumnType(ColumnIndex: Integer): TZSQLType;
begin {EH: does anyone know why the LoadColumns was made? Note the column-types are perfect determinable on MySQL}
  //if not Loaded then
    // LoadColumns;
  Result := TZColumnInfo(ResultSet.ColumnsInfo[ColumnIndex{$IFNDEF GENERIC_INDEX} - 1{$ENDIF}]).ColumnType;
end;

{**
  Get the designated column's table's schema.
  @param ColumnIndex the first column is 1, the second is 2, ...
  @return schema name or "" if not applicable
}
function TZMySQLResultSetMetadata.GetSchemaName(ColumnIndex: Integer): string;
begin
  Result := TZColumnInfo(ResultSet.ColumnsInfo[ColumnIndex{$IFNDEF GENERIC_INDEX} - 1{$ENDIF}]).SchemaName;
end;

{**
  Gets the designated column's table name.
  @param ColumnIndex the first ColumnIndex is 1, the second is 2, ...
  @return table name or "" if not applicable
}
function TZMySQLResultSetMetadata.GetTableName(ColumnIndex: Integer): string;
begin
  if not FHas_ExtendedColumnInfos and not Loaded
  then LoadColumns;
  Result := TZColumnInfo(ResultSet.ColumnsInfo[ColumnIndex{$IFNDEF GENERIC_INDEX} - 1{$ENDIF}]).TableName;
end;

{**
  Indicates whether the designated column is automatically numbered, thus read-only.
  @param ColumnIndex the first column is 1, the second is 2, ...
  @return <code>true</code> if so; <code>false</code> otherwise
}
function TZMySQLResultSetMetadata.IsAutoIncrement(
  ColumnIndex: Integer): Boolean;
begin
  Result := TZColumnInfo(ResultSet.ColumnsInfo[ColumnIndex{$IFNDEF GENERIC_INDEX} - 1{$ENDIF}]).AutoIncrement;
end;

{**
  Initializes columns with additional data.
}
procedure TZMySQLResultSetMetadata.LoadColumns;
var
  Current: TZColumnInfo;
  I: Integer;
  TableColumns: IZResultSet;
begin
  if not FHas_ExtendedColumnInfos then
    inherited LoadColumns
  else if Metadata.GetConnection.GetDriver.GetStatementAnalyser.DefineSelectSchemaFromQuery(Metadata.GetConnection.GetDriver.GetTokenizer, SQL) <> nil then
    for I := 0 to ResultSet.ColumnsInfo.Count - 1 do begin
      Current := TZColumnInfo(ResultSet.ColumnsInfo[i]);
      ClearColumn(Current);
      if Current.TableName = '' then
        continue;
      TableColumns := Metadata.GetColumns(Current.CatalogName, Current.SchemaName, Metadata.AddEscapeCharToWildcards(Metadata.GetIdentifierConvertor.Quote(Current.TableName)),'');
      if TableColumns <> nil then begin
        TableColumns.BeforeFirst;
        while TableColumns.Next do
          if TableColumns.GetString(ColumnNameIndex) = Current.ColumnName then begin
            FillColumInfoFromGetColumnsRS(Current, TableColumns, Current.ColumnName);
            Break;
          end;
      end;
    end;
  Loaded := True;
end;

{ TZAbstractMySQLResultSet }

{$IFDEF USE_SYNCOMMONS}
procedure TZAbstractMySQLResultSet.ColumnsToJSON(JSONWriter: TJSONWriter;
  JSONComposeOptions: TZJSONComposeOptions);
var
  C: Cardinal;
  H, I: Integer;
  P: PAnsiChar;
  Bind: PMYSQL_aligned_BIND;
  MS: Word;
label FinalizeDT;
begin
  if JSONWriter.Expand then
    JSONWriter.Add('{');
  if Assigned(JSONWriter.Fields) then
    H := High(JSONWriter.Fields) else
    H := High(JSONWriter.ColNames);
  {$R-}
  for I := 0 to H do begin
    if Pointer(JSONWriter.Fields) = nil then
      C := I else
      C := JSONWriter.Fields[i];
    Bind := @FMYSQL_aligned_BINDs[C];
    if fBindBufferAllocated then begin
      if Bind^.is_null = 1 then
        if JSONWriter.Expand then begin
          if not (jcsSkipNulls in JSONComposeOptions) then begin
            JSONWriter.AddString(JSONWriter.ColNames[C]);
            JSONWriter.AddShort('null,')
          end else
            Continue;
        end else
          JSONWriter.AddShort('null,')
      else begin
        if JSONWriter.Expand then
          JSONWriter.AddString(JSONWriter.ColNames[C]);
        case Bind^.buffer_type_address^ of
          //FIELD_TYPE_DECIMAL,
          FIELD_TYPE_TINY       : if Bind^.is_unsigned_address^ = 0
                                  then JSONWriter.Add(PShortInt(Bind^.Buffer)^)
                                  else JSONWriter.AddU(PByte(Bind^.Buffer)^);
          FIELD_TYPE_SHORT      : if Bind^.is_unsigned_address^ = 0
                                  then JSONWriter.Add(PSmallInt(Bind^.Buffer)^)
                                  else JSONWriter.AddU(PWord(Bind^.Buffer)^);
          FIELD_TYPE_LONG       : if Bind^.is_unsigned_address^ = 0
                                  then JSONWriter.Add(PInteger(Bind^.Buffer)^)
                                  else JSONWriter.AddU(PCardinal(Bind^.Buffer)^);
          FIELD_TYPE_FLOAT      : JSONWriter.AddSingle(PSingle(Bind^.Buffer)^);
          FIELD_TYPE_DOUBLE     : JSONWriter.AddDouble(PDouble(Bind^.Buffer)^);
          FIELD_TYPE_LONGLONG   : if Bind^.is_unsigned_address^ = 0
                                  then JSONWriter.Add(PInt64(Bind^.Buffer)^)
                                  else JSONWriter.AddNoJSONEscapeUTF8(ZFastCode.IntToRaw(PUInt64(Bind^.Buffer)^));
          FIELD_TYPE_NEWDECIMAL,
          FIELD_TYPE_DECIMAL    : JSONWriter.AddNoJSONEscape(Bind^.Buffer,Bind^.Length[0]);
          FIELD_TYPE_YEAR       : JSONWriter.AddU(PWord(Bind^.Buffer)^);
          FIELD_TYPE_NULL       : JSONWriter.AddShort('null');
          FIELD_TYPE_TIMESTAMP,
          FIELD_TYPE_DATETIME   : begin
                                    if jcoDATETIME_MAGIC in JSONComposeOptions then
                                      JSONWriter.AddNoJSONEscape(@JSON_SQLDATE_MAGIC_QUOTE_VAR,4)
                                    else if jcoMongoISODate in JSONComposeOptions then
                                      JSONWriter.AddShort('ISODate("')
                                    else JSONWriter.Add('"');
                                    DateToIso8601PChar(@FTinyBuffer[0], True, PMYSQL_TIME(Bind^.Buffer)^.Year,
                                      PMYSQL_TIME(Bind^.Buffer)^.Month, PMYSQL_TIME(Bind^.Buffer)^.Day);
                                    MS := ((PMYSQL_TIME(Bind^.Buffer)^.second_part) * Byte(ord(jcoMilliseconds in JSONComposeOptions)) div 1000000);
                                    TimeToIso8601PChar(@FTinyBuffer[10], True, PMYSQL_TIME(Bind^.Buffer)^.Hour,
                                      PMYSQL_TIME(Bind^.Buffer)^.Minute, PMYSQL_TIME(Bind^.Buffer)^.Second, MS, 'T', jcoMilliseconds in JSONComposeOptions);
                                    if (jcoMilliseconds in JSONComposeOptions)
                                    then JSONWriter.AddNoJSONEscape(@FTinyBuffer[0],23)
                                    else JSONWriter.AddNoJSONEscape(@FTinyBuffer[0],19);
                                    goto FinalizeDT;
                                  end;
          FIELD_TYPE_DATE,
          FIELD_TYPE_NEWDATE    : begin
                                    if jcoDATETIME_MAGIC in JSONComposeOptions then
                                      JSONWriter.AddNoJSONEscape(@JSON_SQLDATE_MAGIC_QUOTE_VAR,4)
                                    else if jcoMongoISODate in JSONComposeOptions then
                                      JSONWriter.AddShort('ISODate("')
                                    else JSONWriter.Add('"');
                                    DateToIso8601PChar(@FTinyBuffer[0], True, PMYSQL_TIME(Bind^.Buffer)^.Year,
                                      PMYSQL_TIME(Bind^.Buffer)^.Month, PMYSQL_TIME(Bind^.Buffer)^.Day);
                                    JSONWriter.AddNoJSONEscape(@FTinyBuffer[0],10);
                                    goto FinalizeDT;
                                  end;
          FIELD_TYPE_TIME       : begin
                                    if jcoMongoISODate in JSONComposeOptions then
                                      JSONWriter.AddShort('ISODate("0000-00-00')
                                    else if jcoDATETIME_MAGIC in JSONComposeOptions then
                                      JSONWriter.AddNoJSONEscape(@JSON_SQLDATE_MAGIC_QUOTE_VAR,4)
                                    else JSONWriter.AddShort('"');
                                    MS := (PMYSQL_TIME(Bind^.Buffer)^.second_part) div 1000000;
                                    TimeToIso8601PChar(@FTinyBuffer[0], True, PMYSQL_TIME(Bind^.Buffer)^.Hour,
                                      PMYSQL_TIME(Bind^.Buffer)^.Minute, PMYSQL_TIME(Bind^.Buffer)^.Second, MS, 'T', jcoMilliseconds in JSONComposeOptions);
                                    if jcoMilliseconds in JSONComposeOptions
                                    then JSONWriter.AddNoJSONEscape(@FTinyBuffer[0],12)
                                    else JSONWriter.AddNoJSONEscape(@FTinyBuffer[0],8);
                                    goto FinalizeDT;
                                  end;
          FIELD_TYPE_BIT        : if Bind^.Length[0] = 1
                                  then JSONWriter.AddShort(JSONBool[PByte(Bind^.Buffer)^ <> 0])
                                  else JSONWriter.WrBase64(Pointer(Bind^.Buffer), Bind^.Length[0], True);
          MYSQL_TYPE_JSON: if (Bind^.Buffer <> nil) then
                            JSONWriter.AddNoJSONEscape(Pointer(Bind^.Buffer), Bind^.Length[0])
                        else if Bind^.Length[0] < SizeOf(FTinyBuffer) then begin
                          Bind^.buffer_address^ := @FTinyBuffer[0];
                          Bind^.buffer_Length_address^ := SizeOf(FTinyBuffer)-1; //mysql sets $0 on to of data and corrupts our mem
                          FPlainDriver.mysql_stmt_fetch_column(FMYSQL_STMT, Bind^.mysql_bind, C, 0);
                          Bind^.buffer_address^ := nil;
                          Bind^.buffer_Length_address^ := 0;
                          JSONWriter.AddNoJSONEscape(@FTinyBuffer[0], Bind^.Length[0]);
                        end else begin
                          FTempBlob := TZMySQLPreparedClob.Create(FplainDriver,
                            Bind, FPMYSQL^, C{$IFNDEF GENERIC_INDEX}+1{$ENDIF}, Self);
                          P := FTempBlob.GetPAnsiChar(zCP_UTF8);
                          JSONWriter.AddNoJSONEscape(P, FTempBlob.Length);
                        end;
          FIELD_TYPE_ENUM,
          FIELD_TYPE_SET,
          FIELD_TYPE_VARCHAR,
          FIELD_TYPE_VAR_STRING,
          FIELD_TYPE_STRING,
          FIELD_TYPE_TINY_BLOB,
          FIELD_TYPE_MEDIUM_BLOB,
          FIELD_TYPE_LONG_BLOB,
          FIELD_TYPE_BLOB,
          FIELD_TYPE_GEOMETRY   :
                        if (Bind^.Buffer <> nil) then
                          if Bind^.Binary then
                            JSONWriter.WrBase64(Pointer(Bind^.Buffer), Bind^.Length[0], True)
                          else begin
                            JSONWriter.Add('"');
                            JSONWriter.AddJSONEscape(Pointer(Bind^.Buffer), Bind^.Length[0]);
                            JSONWriter.Add('"');
                          end
                        else if Bind^.Length[0] < SizeOf(FTinyBuffer) then begin
                          Bind^.buffer_address^ := @FTinyBuffer[0];
                          Bind^.buffer_Length_address^ := SizeOf(FTinyBuffer)-1; //mysql sets $0 on to of data and corrupts our mem
                          FPlainDriver.mysql_stmt_fetch_column(FMYSQL_STMT, Bind^.mysql_bind, C, 0);
                          Bind^.buffer_address^ := nil;
                          Bind^.buffer_Length_address^ := 0;
                          if Bind^.binary then
                            JSONWriter.WrBase64(@FTinyBuffer[0], Bind^.Length[0], True)
                          else begin
                            JSONWriter.Add('"');
                            JSONWriter.AddJSONEscape(@FTinyBuffer[0], Bind^.Length[0]);
                            JSONWriter.Add('"');
                          end;
                        end else if Bind^.binary then begin
                          FTempBlob := TZMySQLPreparedBlob.Create(FplainDriver,
                            Bind, FPMYSQL^, C{$IFNDEF GENERIC_INDEX}+1{$ENDIF}, Self);
                          JSONWriter.WrBase64(FTempBlob.GetBuffer, FTempBlob.Length, True)
                        end else begin
                          JSONWriter.Add('"');
                          FTempBlob := TZMySQLPreparedClob.Create(FplainDriver,
                            Bind, FPMYSQL^, C{$IFNDEF GENERIC_INDEX}+1{$ENDIF}, Self);
                          P := FTempBlob.GetPAnsiChar(zCP_UTF8);
                          JSONWriter.AddJSONEscape(P, FTempBlob.Length);
                          JSONWriter.Add('"');
                        end;
        end;
      end
    end else begin
      P := PMYSQL_ROW(FRowHandle)[C];
      if P = nil then
        if JSONWriter.Expand then begin
          if not (jcsSkipNulls in JSONComposeOptions) then begin
            JSONWriter.AddString(JSONWriter.ColNames[C]);
            JSONWriter.AddShort('null,')
          end else
            Continue;
        end else
          JSONWriter.AddShort('null,')
      else begin
        if JSONWriter.Expand then
          JSONWriter.AddString(JSONWriter.ColNames[C]);
        case Bind.buffer_type_address^ of
          FIELD_TYPE_DECIMAL,
          FIELD_TYPE_TINY,
          FIELD_TYPE_SHORT,
          FIELD_TYPE_LONG,
          FIELD_TYPE_FLOAT,
          FIELD_TYPE_DOUBLE,
          FIELD_TYPE_LONGLONG,
          FIELD_TYPE_INT24,
          FIELD_TYPE_YEAR,
          FIELD_TYPE_NEWDECIMAL : JSONWriter.AddNoJSONEscape(P, FLengthArray^[C]);
          FIELD_TYPE_NULL       : JSONWriter.AddShort('null');
          FIELD_TYPE_TIMESTAMP,
          FIELD_TYPE_DATETIME   : begin
                                    if jcoDATETIME_MAGIC in JSONComposeOptions then
                                      JSONWriter.AddNoJSONEscape(@JSON_SQLDATE_MAGIC_QUOTE_VAR,4)
                                    else if jcoMongoISODate in JSONComposeOptions then
                                      JSONWriter.AddShort('ISODate("')
                                    else JSONWriter.Add('"');
                                    JSONWriter.AddNoJSONEscape(P, FLengthArray^[C]);
                                    goto FinalizeDT;
                                  end;
          FIELD_TYPE_DATE,
          FIELD_TYPE_NEWDATE    : begin
                                    if jcoDATETIME_MAGIC in JSONComposeOptions then
                                      JSONWriter.AddNoJSONEscape(@JSON_SQLDATE_MAGIC_QUOTE_VAR,4)
                                    else if jcoMongoISODate in JSONComposeOptions then
                                      JSONWriter.AddShort('ISODate("')
                                    else JSONWriter.Add('"');
                                    JSONWriter.AddNoJSONEscape(P, FLengthArray^[C]);
                                    goto FinalizeDT;
                                  end;
          FIELD_TYPE_TIME       : begin
                                    if jcoMongoISODate in JSONComposeOptions then
                                      JSONWriter.AddShort('ISODate("0000-00-00T')
                                    else if jcoDATETIME_MAGIC in JSONComposeOptions then begin
                                      JSONWriter.AddNoJSONEscape(@JSON_SQLDATE_MAGIC_QUOTE_VAR,4);
                                      JSONWriter.Add('T');
                                    end else JSONWriter.AddShort('"T');
                                    JSONWriter.AddNoJSONEscape(P, FLengthArray^[C]);
FinalizeDT:                         if jcoMongoISODate in JSONComposeOptions
                                    then JSONWriter.AddShort('Z)"')
                                    else JSONWriter.Add('"');
                                  end;
          FIELD_TYPE_BIT        : if FLengthArray^[C] = 1 then
                                    JSONWriter.AddShort(JSONBool[PByte(P)^ <> 0]) else
                                    JSONWriter.WrBase64(P, FLengthArray^[C], True);
          FIELD_TYPE_ENUM       : if TZColumnInfo(ColumnsInfo[C]).ColumnType = stBoolean then
                                    JSONWriter.AddShort(JSONBool[UpCase(P^) = 'Y'])
                                  else begin
                                    JSONWriter.Add('"');
                                    JSONWriter.AddJSONEscape(P, FLengthArray^[C]);
                                    JSONWriter.Add('"');
                                  end;
          FIELD_TYPE_SET        : begin
                                    JSONWriter.Add('"');
                                    JSONWriter.AddJSONEscape(P, FLengthArray^[C]);
                                    JSONWriter.Add('"');
                                  end;
          MYSQL_TYPE_JSON:        JSONWriter.AddNoJSONEscape(P, FLengthArray^[C]);
          FIELD_TYPE_VARCHAR,
          FIELD_TYPE_TINY_BLOB,
          FIELD_TYPE_MEDIUM_BLOB,
          FIELD_TYPE_LONG_BLOB,
          FIELD_TYPE_BLOB,
          FIELD_TYPE_VAR_STRING,
          FIELD_TYPE_STRING     : if not Bind.binary then begin
                                    JSONWriter.Add('"');
                                    JSONWriter.AddJSONEscape(P, FLengthArray^[C]);
                                    JSONWriter.Add('"');
                                  end else
                                    JSONWriter.WrBase64(P, FLengthArray^[C], True);
          FIELD_TYPE_GEOMETRY   : JSONWriter.WrBase64(P, FLengthArray^[C], True);
        end;
      end;
    end;
    JSONWriter.Add(',');
  end;
  if jcoEndJSONObject in JSONComposeOptions then
  begin
    JSONWriter.CancelLastComma; // cancel last ','
    if JSONWriter.Expand then
      JSONWriter.Add('}');
  end;
  {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
end;
{$ENDIF USE_SYNCOMMONS}

{**
  Constructs this object, assignes main properties and
  opens the record set.
  @param PlainDriver a native MySQL plain driver.
  @param Statement a related SQL statement object.
  @param Handle a MySQL specific query handle.
  @param UseResult <code>True</code> to use results,
    <code>False</code> to store result.
}
constructor TZAbstractMySQLResultSet.Create(const PlainDriver: TZMySQLPlainDriver;
  const Statement: IZStatement; const SQL: string; IsOutParamResult: Boolean;
  PMYSQL: PPMYSQL; PMYSQL_STMT: PPMYSQL_STMT; MYSQL_ColumnsBinding: PMYSQL_ColumnsBinding;
  AffectedRows: PInteger; out OpenCursorCallback: TOpenCursorCallback);
//var ClientVersion: ULong;
begin
  inherited Create(Statement, SQL, TZMySQLResultSetMetadata.Create(
    Statement.GetConnection.GetMetadata, SQL, Self),
      Statement.GetConnection.GetConSettings);
  FClientCP := ConSettings.ClientCodePage.CP;
  fServerCursor := Self is TZMySQL_Use_ResultSet;
  FMYSQL_Col_BIND_Address := @MYSQL_ColumnsBinding.MYSQL_Col_BINDs;
  FMYSQL_aligned_BINDs := MYSQL_ColumnsBinding.MYSQL_aligned_BINDs;
  FFieldCount := MYSQL_ColumnsBinding.FieldCount;
  FPMYSQL := PMYSQL;
  FPMYSQL_STMT := PMYSQL_STMT;
  FMYSQL_STMT  := FPMYSQL_STMT^;
  FQueryHandle := nil;
  FRowHandle := nil;
//  FFieldCount := 0;
  FPlainDriver := PlainDriver;
  ResultSetConcurrency := rcReadOnly;
  OpenCursorCallback := OpenCursor;
  //hooking very old versions -> we use this struct for some more logic
{  ClientVersion := FPlainDriver.mysql_get_client_version;
  FBindOffsets := GetBindOffsets(FPlainDriver.IsMariaDBDriver, Max(40101, ClientVersion));}
  FIsOutParamResult := IsOutParamResult;
  Open;
  if Assigned(AffectedRows) then
    AffectedRows^ := LastRowNo;
end;

function TZAbstractMySQLResultSet.CreateMySQLConvertError(ColumnIndex: Integer;
  DataType: TMysqlFieldType): EZMySQLConvertError;
begin
  Result := EZMySQLConvertError.Create(Format(SErrorConvertionField,
        [TZColumnInfo(ColumnsInfo[ColumnIndex]).ColumnLabel, IntToStr(Ord(DataType))]));
end;

destructor TZAbstractMySQLResultSet.Destroy;
begin
  //ReallocBindBuffer(FColBuffer, FMYSQL_aligned_BINDs, FBindOffsets, FFieldCount, 0, Ord(fBindBufferAllocated));
  inherited Destroy;
end;

procedure TZAbstractMySQLResultSet.BeforeClose;
begin
  FClosing := True;
  inherited BeforeClose;
end;

{**
  Opens this recordset.
}
procedure TZAbstractMySQLResultSet.Open;
const One: PAnsiChar = '1';
var
  I: Integer;
  FieldHandle: PMYSQL_FIELD;
  QueryHandle: PZMySQLResult;
  FieldOffsets: PMYSQL_FIELDOFFSETS;
  MySQL_FieldType_Bit_1_IsBoolean: Boolean;
begin
  FieldOffsets := GetFieldOffsets(FPlainDriver.mysql_get_client_version);
  MySQL_FieldType_Bit_1_IsBoolean := (GetStatement.GetConnection as IZMySQLConnection).MySQL_FieldType_Bit_1_IsBoolean;
  if FPMYSQL_STMT^ = nil then begin
    OpenCursor;
    QueryHandle := FQueryHandle;
  end else begin
    if FIsOutParamResult then begin
      FMYSQL_STMT := FPMYSQL_STMT^;
      if Assigned(FPlainDriver.mysql_stmt_attr_set517UP)
      then FPlainDriver.mysql_stmt_attr_set517UP(FPMYSQL_STMT^,STMT_ATTR_UPDATE_MAX_LENGTH,one)
      else FPlainDriver.mysql_stmt_attr_set(FPMYSQL_STMT^,STMT_ATTR_UPDATE_MAX_LENGTH,one);
      if FPlainDriver.mysql_stmt_store_result(FPMYSQL_STMT^) <> 0 then
        checkMySQLError(FPlainDriver, FPMYSQL^, FMYSQL_STMT, lcOther, 'mysql_stmt_store_result', Self);
    end;
    if FFieldCount > 0
    then QueryHandle := FPlainDriver.mysql_stmt_result_metadata(FMYSQL_STMT)
    else QueryHandle := nil;
    fBindBufferAllocated := True;
  end;
  if QueryHandle = nil then
    raise EZSQLException.Create(SCanNotRetrieveResultSetData);
  { Fills the column info. }
  for I := 0 to FFieldCount -1 do begin
    FPlainDriver.mysql_field_seek(QueryHandle, I);
    FieldHandle := FPlainDriver.mysql_fetch_field(QueryHandle);
    if FieldHandle = nil then
      Break;
    {$R-}
    InitColumnBinds(@FMYSQL_aligned_BINDs[I], FieldHandle, FieldOffsets, Ord(fBindBufferAllocated));
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    ColumnsInfo.Add(GetMySQLColumnInfoFromFieldHandle(FieldHandle, FieldOffsets,
      ConSettings, MySQL_FieldType_Bit_1_IsBoolean));
  end;

  if fBindBufferAllocated then begin
    FPlainDriver.mysql_free_result(QueryHandle);
    OpenCursor;
  end;
  inherited Open;
end;

procedure TZAbstractMySQLResultSet.OpenCursor;
var
  I: Integer;
  Bind: PMYSQL_aligned_BIND;
begin
  if (FMYSQL_STMT = nil) and (FPMYSQL_STMT <> nil) and (FPMYSQL_STMT^ <> nil) then
    FMYSQL_STMT := FPMYSQL_STMT^;
  if FMYSQL_STMT <> nil then begin
    if not fBindBufferAllocated then begin
      for I := 0 to Self.ColumnsInfo.Count -1 do begin
        {$R-}
        Bind := @FMYSQL_aligned_BINDs[I];
        {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
        if Bind^.buffer_length_address^ > 0 then begin
          GetMem(Bind^.Buffer, (((bind^.buffer_length_address^-Byte(Ord(bind^.buffer_type_address^ <> FIELD_TYPE_STRING))) shr 3)+1) shl 3); //8Byte aligned
          Bind^.buffer_address^ := Bind^.buffer;
        end;
      end;
      fBindBufferAllocated := True;
    end;
    if (FPlainDriver.mysql_stmt_bind_result(FMYSQL_STMT,FMYSQL_Col_BIND_Address^)<>0) then
      checkMySQLError(FPlainDriver, FPMYSQL^, FMYSQL_STMT, lcOther, 'mysql_stmt_bind_result', Self);
  end;
end;

procedure TZAbstractMySQLResultSet.ReleaseImmediat(
  const Sender: IImmediatelyReleasable; var AError: EZSQLConnectionLost);
begin
  FQueryHandle := nil;
  FRowHandle := nil;
  FMYSQL_STMT := nil;
  inherited ReleaseImmediat(Sender, AError);
end;

procedure TZAbstractMySQLResultSet.ResetCursor;
var Handle: Pointer;
begin
  if not Closed then
    FFirstRowFetched := False;
    if fBindBufferAllocated then begin
      Handle := FMYSQL_STMT;
      FMYSQL_STMT := nil;
      //test if more results are pendding
      if (Handle <> nil) and not FClosing and (FIsOutParamResult or ({not FPlainDriver.IsMariaDBDriver and} (Assigned(FPlainDriver.mysql_stmt_more_results) and (FPlainDriver.mysql_stmt_more_results(FPMYSQL_STMT^) = 1))))
      then Close
      else inherited ResetCursor;
    end else begin
      Handle := FQueryHandle;
      FQueryHandle := nil;
      if (Handle <> nil) and not FClosing and (FPlainDriver.mysql_more_results(FPMYSQL^) = 1)
      then Close
      else inherited ResetCursor;
    end;
end;

{**
  Releases this <code>ResultSet</code> object's database and
  JDBC resources immediately instead of waiting for
  this to happen when it is automatically closed.

  <P><B>Note:</B> A <code>ResultSet</code> object
  is automatically closed by the
  <code>Statement</code> object that generated it when
  that <code>Statement</code> object is closed,
  re-executed, or is used to retrieve the next result from a
  sequence of multiple results. A <code>ResultSet</code> object
  is also automatically closed when it is garbage collected.
}
procedure TZAbstractMySQLResultSet.AfterClose;
begin
  FQueryHandle := nil;
  FRowHandle := nil;
  FMYSQL_STMT := nil;
  inherited AfterClose;
end;

{**
  Indicates if the value of the designated column in the current row
  of this <code>ResultSet</code> object is Null.

  @param columnIndex the first column is 1, the second is 2, ...
  @return if the value is SQL <code>NULL</code>, the
    value returned is <code>true</code>. <code>false</code> otherwise.
}
function TZAbstractMySQLResultSet.IsNull(ColumnIndex: Integer): Boolean;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckClosed;
{$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex-1;
  {$ENDIF}
  if fBindBufferAllocated
  {$R-}
  then Result := FMYSQL_aligned_BINDs[ColumnIndex].is_null = 1
  else Result := (FRowHandle = nil) or (PMYSQL_ROW(FRowHandle)[ColumnIndex] = nil);
  {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
  LastWasNull := Result;
end;

{**
  Moves the cursor down one row from its current position.
  A <code>ResultSet</code> cursor is initially positioned
  before the first row; the first call to the method
  <code>next</code> makes the first row the current row; the
  second call makes the second row the current row, and so on.

  <P>If an input stream is open for the current row, a call
  to the method <code>next</code> will
  implicitly close it. A <code>ResultSet</code> object's
  warning chain is cleared when a new row is read.

  @return <code>true</code> if the new current row is valid;
    <code>false</code> if there are no more rows
}
function TZAbstractMySQLResultSet.Next: Boolean;
begin
  { Checks for maximum row. }
  Result := False;
  if (Closed) or (fBindBufferAllocated and not Assigned(FMYSQL_STMT)) or
     ((MaxRows > 0) and (RowNo >= MaxRows)) or (RowNo > LastRowNo) then
    Exit;
  if (RowNo = 0) and FFirstRowFetched then begin //if moveAbsolute(0) was called
    Result := True;
    FFirstRowFetched := False;
  end else if fBindBufferAllocated then begin
    FFetchStatus := FPlainDriver.mysql_stmt_fetch(FMYSQL_STMT);
    if FFetchStatus in [STMT_FETCH_OK, MYSQL_DATA_TRUNCATED] then
      Result := True
    else if FFetchStatus = STMT_FETCH_ERROR then
      checkMySQLError(FPlainDriver, FPMYSQL^, FMYSQL_STMT, lcOther, '', Self);
  end else begin
    if (FQueryHandle = nil) then begin
      FQueryHandle := FPlainDriver.mysql_store_result(FPMYSQL^);
      if Assigned(FQueryHandle) then
        LastRowNo := FPlainDriver.mysql_num_rows(FQueryHandle);
    end;
    FRowHandle := FPlainDriver.mysql_fetch_row(FQueryHandle);
    if FRowHandle <> nil then begin
      Result := True;
      FLengthArray := FPlainDriver.mysql_fetch_lengths(FQueryHandle);
    end else
      FLengthArray := nil;
  end;
  if Result then begin
    RowNo := RowNo + 1;
    if LastRowNo < RowNo then
      LastRowNo := RowNo;
  end else if fServerCursor then begin
    LastRowNo := RowNo;
    RowNo := RowNo+1;
  end else
    RowNo := RowNo+1;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>PAnsiChar</code> in the Delphi programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @param Len the Length of the PAnsiChar String
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZAbstractMySQLResultSet.GetPAnsiChar(ColumnIndex: Integer; out Len: NativeUInt): PAnsiChar;
var
  ColBind: PMYSQL_aligned_BIND;
  Status: Integer;
label set_results;
begin
  {$IFNDEF DISABLE_CHECKING}
  CheckClosed;
  if (fBindBufferAllocated and (FMYSQL_STMT = nil)) or
     (not fBindBufferAllocated and (FRowHandle = nil)) then
    raise EZSQLException.Create(SRowDataIsNotAvailable);
  {$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex-1;
  {$ENDIF}
  if fBindBufferAllocated then begin
    {$R-}
    ColBind := @FMYSQL_aligned_BINDs[ColumnIndex];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    LastWasNull := ColBind^.is_null =1;
    if LastWasNull then begin
      Result := nil;
      Len := 0;
    end else begin
      case ColBind^.buffer_type_address^ of
        FIELD_TYPE_TINY: begin
            if ColBind^.is_unsigned_address^ = 0
            then IntToRaw(Integer(PShortInt(ColBind^.buffer)^), @FTinyBuffer, @Result)
            else IntToRaw(Cardinal(PByte(ColBind^.buffer)^), @FTinyBuffer, @Result);
            goto set_results;
          end;
        FIELD_TYPE_SHORT: begin
            if ColBind^.is_unsigned_address^ = 0
            then IntToRaw(Integer(PSmallInt(ColBind^.buffer)^), @FTinyBuffer, @Result)
            else IntToRaw(Cardinal(PWord(ColBind^.buffer)^), @FTinyBuffer, @Result);
            goto set_results;
          end;
        FIELD_TYPE_LONG: begin
            if ColBind^.is_unsigned_address^ = 0
            then IntToRaw(PInteger(ColBind^.buffer)^, @FTinyBuffer, @Result)
            else IntToRaw(PCardinal(ColBind^.buffer)^, @FTinyBuffer, @Result);
            goto set_results;
          end;
        FIELD_TYPE_FLOAT: begin
            Len := FloatToSQLRaw(PSingle(ColBind^.buffer)^, @FTinyBuffer);
            Result := @FTinyBuffer;
          end;
        FIELD_TYPE_DOUBLE: begin
            Len := FloatToSQLRaw(PDouble(ColBind^.buffer)^, @FTinyBuffer);
            Result := @FTinyBuffer;
          end;
        FIELD_TYPE_NULL: begin
            Result := nil;
            Len := 0;
          end;
        FIELD_TYPE_TIMESTAMP, FIELD_TYPE_DATETIME:
          begin
            Result := @FTinyBuffer[0];
            Len := DateTimeToRaw(PMYSQL_TIME(ColBind^.buffer)^.Year,
              PMYSQL_TIME(ColBind^.buffer)^.Month, PMYSQL_TIME(ColBind^.buffer)^.Day,
              PMYSQL_TIME(ColBind^.buffer)^.Hour, PMYSQL_TIME(ColBind^.buffer)^.Minute,
              PMYSQL_TIME(ColBind^.buffer)^.Second, 0{PMYSQL_TIME(ColBind^.buffer)^.second_part},
              Result, ConSettings^.ReadFormatSettings.DateTimeFormat,
              False, PMYSQL_TIME(ColBind^.buffer)^.neg <> 0);
          end;
        FIELD_TYPE_LONGLONG: begin
            if ColBind^.is_unsigned_address^ = 0
            then IntToRaw(PInt64(ColBind^.buffer)^, @FTinyBuffer, @Result)
            else IntToRaw(PUInt64(ColBind^.buffer)^, @FTinyBuffer, @Result);
            goto set_results;
          end;
        FIELD_TYPE_DATE, FIELD_TYPE_NEWDATE: begin
            Result := @FTinyBuffer;
            Len := DateToRaw(PMYSQL_TIME(ColBind^.buffer)^.Year,
              PMYSQL_TIME(ColBind^.buffer)^.Month, PMYSQL_TIME(ColBind^.buffer)^.Day,
              Result, ConSettings^.ReadFormatSettings.DateFormat, False, PMYSQL_TIME(ColBind^.buffer)^.neg <> 0);
          end;
        FIELD_TYPE_TIME: begin
            Result := @FTinyBuffer;
            Len := TimeToRaw(PMYSQL_TIME(ColBind^.buffer)^.Hour,
              PMYSQL_TIME(ColBind^.buffer)^.Minute,
              PMYSQL_TIME(ColBind^.buffer)^.Second, 0{PMYSQL_TIME(ColBind^.buffer)^.second_part},
              @FTinyBuffer, ConSettings^.ReadFormatSettings.TimeFormat, False, PMYSQL_TIME(ColBind^.buffer)^.neg <> 0);
          end;
        FIELD_TYPE_YEAR: begin
            IntToRaw(Cardinal(PWord(ColBind^.buffer)^), @FTinyBuffer, @Result);
set_Results:Len := Result - PAnsiChar(@FTinyBuffer);
            Result := @FTinyBuffer;
          end;
        FIELD_TYPE_NEWDECIMAL,
        FIELD_TYPE_DECIMAL,
        FIELD_TYPE_BIT,//http://dev.mysql.com/doc/refman/5.0/en/bit-type.html
        FIELD_TYPE_ENUM, FIELD_TYPE_SET, FIELD_TYPE_STRING:
          begin
            Result := ColBind^.buffer;
            Len := ColBind^.length[0];
            Exit;
          end;
        FIELD_TYPE_TINY_BLOB, FIELD_TYPE_MEDIUM_BLOB, FIELD_TYPE_LONG_BLOB,
        FIELD_TYPE_BLOB, FIELD_TYPE_GEOMETRY, MYSQL_TYPE_JSON:
            if ColBind.buffer <> nil then begin
              Result := ColBind^.buffer;
              Len := ColBind^.length[0];
            end else if ColBind^.Length[0] < SizeOf(FTinyBuffer) then begin
              ColBind^.buffer_address^ := @FTinyBuffer[0];
              ColBind^.buffer_Length_address^ := SizeOf(FTinyBuffer)-1; //mysql sets $0 on to of data and corrupts our mem
              Status := FPlainDriver.mysql_stmt_fetch_column(FMYSQL_STMT, ColBind^.mysql_bind, ColumnIndex, 0);
              ColBind^.buffer_address^ := nil;
              ColBind^.buffer_Length_address^ := 0;
              Result := @FTinyBuffer[0];
              if Status <> 0 then
                if Status = STMT_FETCH_ERROR
                then raise EZSQLException.Create('Fetch error')
                else checkMySQLError(FPlainDriver, FPMYSQL^, FMYSQL_STMT, lcOther, 'mysql_stmt_fetch_column', Self);
              Len := ColBind^.Length[0];
            end else begin
              FTempBlob := GetBlob(ColumnIndex{$IFNDEF GENERIC_INDEX}+1{$ENDIF});
              Len := FTempBlob.Length;
              Result := FTempBlob.GetBuffer;
            end;
        else raise CreateMySQLConvertError(ColumnIndex, ColBind^.buffer_type_address^);
      end;
    end;
  end else begin
    {$R-}
    Len := FLengthArray^[ColumnIndex];
    Result := PMYSQL_ROW(FRowHandle)[ColumnIndex];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    LastWasNull := Result = nil;
  end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>PWideChar</code> in the Delphi programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @param Len the length of UCS2 string in codepoints
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZAbstractMySQLResultSet.GetPWideChar(ColumnIndex: Integer;
  out Len: NativeUInt): PWideChar;
var ColBind: PMYSQL_aligned_BIND;
  Status: Integer;
label set_results, set_from_tmp;
begin
  {$IFNDEF DISABLE_CHECKING}
  CheckClosed;
  if (fBindBufferAllocated and (FMYSQL_STMT = nil)) or
     (not fBindBufferAllocated and (FRowHandle = nil)) then
    raise EZSQLException.Create(SRowDataIsNotAvailable);
  {$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex-1;
  {$ENDIF}
  {$R-}
  ColBind := @FMYSQL_aligned_BINDs[ColumnIndex];
  {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
  if fBindBufferAllocated then begin
    LastWasNull := ColBind^.is_null =1;
    if LastWasNull then begin
      Result := nil;
      Len := 0;
    end else begin
      case ColBind^.buffer_type_address^ of
        FIELD_TYPE_TINY: begin
            if ColBind^.is_unsigned_address^ = 0
            then IntToUnicode(Integer(PShortInt(ColBind^.buffer)^), @FTinyBuffer, @Result)
            else IntToUnicode(Cardinal(PByte(ColBind^.buffer)^), @FTinyBuffer, @Result);
            goto set_results;
          end;
        FIELD_TYPE_SHORT: begin
            if ColBind^.is_unsigned_address^ = 0
            then IntToUnicode(Integer(PSmallInt(ColBind^.buffer)^), @FTinyBuffer, @Result)
            else IntToUnicode(Cardinal(PWord(ColBind^.buffer)^), @FTinyBuffer, @Result);
            goto set_results;
          end;
        FIELD_TYPE_LONG: begin
            if ColBind^.is_unsigned_address^ = 0
            then IntToUnicode(PInteger(ColBind^.buffer)^, @FTinyBuffer, @Result)
            else IntToUnicode(PCardinal(ColBind^.buffer)^, @FTinyBuffer, @Result);
            goto set_results;
          end;
        FIELD_TYPE_FLOAT: begin
            Len := FloatToSQLUnicode(PSingle(ColBind^.buffer)^, @FTinyBuffer);
            Result := @FTinyBuffer;
          end;
        FIELD_TYPE_DOUBLE: begin
            Len := FloatToSQLUnicode(PDouble(ColBind^.buffer)^, @FTinyBuffer);
            Result := @FTinyBuffer;
          end;
        FIELD_TYPE_NULL: begin
            Result := nil;
            Len := 0;
          end;
        FIELD_TYPE_TIMESTAMP, FIELD_TYPE_DATETIME: begin
            Result := @FTinyBuffer[0];
            Len := DateTimeToUni(PMYSQL_TIME(ColBind^.buffer)^.Year,
              PMYSQL_TIME(ColBind^.buffer)^.Month, PMYSQL_TIME(ColBind^.buffer)^.Day,
              PMYSQL_TIME(ColBind^.buffer)^.Hour, PMYSQL_TIME(ColBind^.buffer)^.Minute,
              PMYSQL_TIME(ColBind^.buffer)^.Second, 0{PMYSQL_TIME(ColBind^.buffer)^.second_part},
              Result, ConSettings^.ReadFormatSettings.DateTimeFormat, False,
              PMYSQL_TIME(ColBind^.buffer)^.neg <> 0);
          end;
        FIELD_TYPE_LONGLONG: begin
            if ColBind^.is_unsigned_address^ = 0
            then IntToUnicode(PInt64(ColBind^.buffer)^, @FTinyBuffer, @Result)
            else IntToUnicode(PUInt64(ColBind^.buffer)^, @FTinyBuffer, @Result);
            goto set_results;
          end;
        FIELD_TYPE_DATE, FIELD_TYPE_NEWDATE: begin
            Result := @FTinyBuffer;
            Len := DateToUni(PMYSQL_TIME(ColBind^.buffer)^.Year,
              PMYSQL_TIME(ColBind^.buffer)^.Month, PMYSQL_TIME(ColBind^.buffer)^.Day,
              Result, ConSettings^.ReadFormatSettings.DateFormat, False,
              PMYSQL_TIME(ColBind^.buffer)^.neg <> 0);
          end;
        FIELD_TYPE_TIME: begin
            Len := TimeToUni(PMYSQL_TIME(ColBind^.buffer)^.Hour,
              PMYSQL_TIME(ColBind^.buffer)^.Minute, PMYSQL_TIME(ColBind^.buffer)^.Second,
              0{PMYSQL_TIME(ColBind^.buffer)^.second_part},
              @FTinyBuffer, ConSettings^.ReadFormatSettings.TimeFormat, False,
              PMYSQL_TIME(ColBind^.buffer)^.neg <> 0);
            Result := @FTinyBuffer;
          end;
        FIELD_TYPE_YEAR: begin
            IntToUnicode(Cardinal(PWord(ColBind^.buffer)^), @FTinyBuffer, @Result);
set_Results:Len := Result - PWideChar(@FTinyBuffer);
            Result := @FTinyBuffer;
          end;
        FIELD_TYPE_NEWDECIMAL,
        FIELD_TYPE_DECIMAL,
        FIELD_TYPE_BIT,//http://dev.mysql.com/doc/refman/5.0/en/bit-type.html
        FIELD_TYPE_ENUM, FIELD_TYPE_SET, FIELD_TYPE_STRING,
        FIELD_TYPE_TINY_BLOB, FIELD_TYPE_MEDIUM_BLOB, FIELD_TYPE_LONG_BLOB,
        FIELD_TYPE_BLOB, FIELD_TYPE_GEOMETRY, MYSQL_TYPE_JSON:
            if ColBind.buffer <> nil then begin
              if ColBind^.binary
              then FUniTemp := Ascii7ToUnicodeString(ColBind^.buffer, ColBind^.length[0])
              else FUniTemp := PRawToUnicode(ColBind^.buffer, ColBind^.length[0], FClientCP);
              goto set_from_tmp;
            end else if ColBind^.Length[0] < SizeOf(FTinyBuffer) then begin
              ColBind^.buffer_address^ := @FTinyBuffer[0];
              ColBind^.buffer_Length_address^ := SizeOf(FTinyBuffer)-1; //mysql sets $0 on to of data and corrupts our mem
              Status := FPlainDriver.mysql_stmt_fetch_column(FMYSQL_STMT, ColBind^.mysql_bind, ColumnIndex, 0);
              ColBind^.buffer_address^ := nil;
              ColBind^.buffer_Length_address^ := 0;
              Result := @FTinyBuffer[0];
              if Status <> 0 then
                if Status = STMT_FETCH_ERROR
                then raise EZSQLException.Create('Fetch error')
                else checkMySQLError(FPlainDriver, FPMYSQL^, FMYSQL_STMT, lcOther, 'mysql_stmt_fetch_column', Self);
              if ColBind^.binary
              then FUniTemp := Ascii7ToUnicodeString(@FTinyBuffer[0], ColBind^.length[0])
              else FUniTemp := PRawToUnicode(@FTinyBuffer[0], ColBind^.length[0], FClientCP);
              if ColBind^.binary
              then FUniTemp := Ascii7ToUnicodeString(ColBind^.buffer, ColBind^.length[0])
              else FUniTemp := PRawToUnicode(ColBind^.buffer, ColBind^.length[0], FClientCP);
              goto set_from_tmp;
            end else begin
              FTempBlob := GetBlob(ColumnIndex{$IFNDEF GENERIC_INDEX}+1{$ENDIF});
              if FTempBlob.IsClob then begin
                Result := FTempBlob.GetPWideChar;
                Len := FTempBlob.Length shr 1;
              end else begin
                FUniTemp := Ascii7ToUnicodeString(FTempBlob.GetBuffer, FTempBlob.Length);
                goto set_from_tmp;
              end;
            end;
        else raise CreateMySQLConvertError(ColumnIndex, ColBind^.buffer_type_address^);
      end;
    end;
  end else begin
    {$R-}
    if PMYSQL_ROW(FRowHandle)[ColumnIndex] = nil then begin
      Result := nil;
      Len := 0;
      LastWasNull := True;
    end else begin
      LastWasNull := False;
      if (ColBind^.buffer_type_address^ in [ FIELD_TYPE_ENUM, FIELD_TYPE_SET,
          FIELD_TYPE_STRING, FIELD_TYPE_TINY_BLOB, FIELD_TYPE_MEDIUM_BLOB,
          FIELD_TYPE_LONG_BLOB, FIELD_TYPE_BLOB, MYSQL_TYPE_JSON]) and not ColBind^.binary
      then FUniTemp := PRawToUnicode(PMYSQL_ROW(FRowHandle)[ColumnIndex], FLengthArray^[ColumnIndex], FClientCP)
      else FUniTemp := Ascii7ToUnicodeString(PMYSQL_ROW(FRowHandle)[ColumnIndex], FLengthArray^[ColumnIndex]);
set_from_tmp:
      Len := Length(FUniTemp);
      if Len <> 0
      then Result := Pointer(FUniTemp)
      else Result := PEmptyUnicodeString;
    end;
  end;
  {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
end;

procedure TZAbstractMySQLResultSet.InitColumnBinds(Bind: PMYSQL_aligned_BIND;
  MYSQL_FIELD: PMYSQL_FIELD; FieldOffsets: PMYSQL_FIELDOFFSETS; Iters: Integer);
begin
  Bind^.is_unsigned_address^ := Ord(PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.flags)^ and UNSIGNED_FLAG <> 0);
  bind^.buffer_type_address^ := PMysqlFieldType(NativeUInt(MYSQL_FIELD)+FieldOffsets._type)^; //safe initialtype
  if FieldOffsets.charsetnr > 0
  then bind^.binary := (PUInt(NativeUInt(MYSQL_FIELD)+NativeUInt(FieldOffsets.charsetnr))^ = 63) and (PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.flags)^ and BINARY_FLAG <> 0)
  else bind^.binary := (PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.flags)^ and BINARY_FLAG <> 0);
  if bind^.buffer_type_address^ = FIELD_TYPE_GEOMETRY then //MySQL does not accept Type 255 as binding type
    bind^.buffer_type_address^ := FIELD_TYPE_BLOB;

  case bind^.buffer_type_address^ of
    FIELD_TYPE_BIT: case PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.length)^ of
                      0..8  : Bind^.Length[0] := SizeOf(Byte);
                      9..16 : Bind^.Length[0] := SizeOf(Word);
                      17..32: Bind^.Length[0] := SizeOf(Cardinal);
                      else    Bind^.Length[0] := SizeOf(UInt64);
                    end;
    FIELD_TYPE_DATE,
    FIELD_TYPE_TIME,
    FIELD_TYPE_DATETIME,
    FIELD_TYPE_TIMESTAMP:   Bind^.Length[0] := sizeOf(TMYSQL_TIME);
    FIELD_TYPE_TINY:        Bind^.Length[0] := 1;
    FIELD_TYPE_SHORT:       Bind^.Length[0] := 2;
    FIELD_TYPE_LONG:        Bind^.Length[0] := 4;
    FIELD_TYPE_LONGLONG:    Bind^.Length[0] := 8;
    FIELD_TYPE_INT24: begin//we've no 3Byte integers... so let's convert them
        Bind^.Length[0] := 4;
        bind^.buffer_type_address^ := FIELD_TYPE_LONG;
      end;
    FIELD_TYPE_FLOAT, FIELD_TYPE_DOUBLE: begin
        if PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.length)^ = 12 then begin
          Bind^.Length[0] := SizeOf(Single);
          bind^.buffer_type_address^ := FIELD_TYPE_FLOAT
        end else begin
          Bind^.Length[0] := SizeOf(Double);
          bind^.buffer_type_address^ := FIELD_TYPE_DOUBLE;
        end;
        bind^.decimals := PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.decimals)^;
      end;
    MYSQL_TYPE_JSON,
    FIELD_TYPE_BLOB,
    FIELD_TYPE_TINY_BLOB,
    FIELD_TYPE_MEDIUM_BLOB,
    FIELD_TYPE_LONG_BLOB,
    FIELD_TYPE_GEOMETRY:    if FIsOutParamResult
                            then Bind^.Length[0] := PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.max_length)^
                            else Bind^.Length[0] := 0;//http://bugs.mysql.com/file.php?id=12361&bug_id=33086
    FIELD_TYPE_VARCHAR,
    FIELD_TYPE_VAR_STRING,
    FIELD_TYPE_STRING,
    FIELD_TYPE_ENUM, FIELD_TYPE_SET: begin
        bind^.buffer_type_address^ := FIELD_TYPE_STRING;
        Bind^.Length[0] := PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.length)^;
      end;
    FIELD_TYPE_NEWDECIMAL,
    FIELD_TYPE_DECIMAL:
      if PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.decimals)^ = 0 then begin
        if PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.length)^ <= Byte(2+(Ord(PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.flags)^ and UNSIGNED_FLAG <> 0))) then begin
          bind^.buffer_type_address^ := FIELD_TYPE_TINY;
          Bind^.Length[0] := 1;
        end else if PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.length)^ <= Byte(4+(Ord(PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.flags)^ and UNSIGNED_FLAG <> 0))) then begin
          Bind^.Length[0] := 2;
          bind^.buffer_type_address^ := FIELD_TYPE_SHORT;
        end else if PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.length)^ <= Byte(9+(Ord(PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.flags)^ and UNSIGNED_FLAG <> 0))) then begin
          bind^.buffer_type_address^ := FIELD_TYPE_LONG;
          Bind^.Length[0] := 4;
        end else if PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.length)^ <= Byte(18+(Ord(PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.flags)^ and UNSIGNED_FLAG <> 0))) then begin
          bind^.buffer_type_address^ := FIELD_TYPE_LONGLONG;
          Bind^.Length[0] := 8;
        end else begin
          Bind^.Length[0] := PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.length)^;
          bind^.decimals := PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.decimals)^;
        end;
      end else begin
        Bind^.Length[0] := PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.length)^;
        bind^.decimals := PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.decimals)^;
        //see: http://www.iskm.org/mysql56/libmysql_8c_source.html / setup_one_fetch_function mysql always converts the decimal_t record to a string
      end;
    else begin
      Bind^.Length[0] := (((PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.length)^) shr 3)+1) shl 3; //8Byte Aligned
    end;
    //Length := MYSQL_FIELD^.length;
  end;
  if (bind^.Length[0] = 0) or (Iters = 0)
  then Bind^.Buffer := nil
  else ReallocMem(Bind^.Buffer, ((((bind^.Length^[0]+Byte(Ord(bind^.buffer_type_address^ in [FIELD_TYPE_STRING, FIELD_TYPE_NEWDECIMAL, FIELD_TYPE_DECIMAL]))) shr 3)+1) shl 3) ); //8Byte aligned
  Bind^.buffer_address^ := Bind^.buffer;
  Bind^.buffer_length_address^ := bind^.Length[0];
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>boolean</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>false</code>
}
function TZAbstractMySQLResultSet.GetBoolean(ColumnIndex: Integer): Boolean;
var
  Buffer: PAnsiChar;
  Len: ULong;
  ColBind: PMYSQL_aligned_BIND;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stBoolean);
{$ENDIF}
  Result := False;
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex-1;
  {$ENDIF}
  {$R-}
  ColBind := @FMYSQL_aligned_BINDs[ColumnIndex];
  {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
  if fBindBufferAllocated then begin
    LastWasNull := ColBind^.is_null =1;
    if not LastWasNull then
      //http://dev.mysql.com/doc/refman/5.1/de/numeric-types.html
      Case ColBind^.buffer_type_address^ of
        FIELD_TYPE_TINY:
          if ColBind^.is_unsigned_address^ = 0 then
            Result := PShortInt(ColBind^.buffer)^ <> 0
          else
            Result := PByte(ColBind^.buffer)^ <> 0;
        FIELD_TYPE_SHORT:
          if ColBind^.is_unsigned_address^ = 0 then
            Result := PSmallInt(ColBind^.buffer)^ <> 0
          else
            Result := PWord(ColBind^.buffer)^ <> 0;
        FIELD_TYPE_LONG:
          if ColBind^.is_unsigned_address^ = 0 then
            Result := PInteger(ColBind^.buffer)^ <> 0
          else
            Result := PCardinal(ColBind^.buffer)^ <> 0;
        FIELD_TYPE_FLOAT:     Result := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(PSingle(ColBind^.buffer)^) <> 0;
        FIELD_TYPE_DOUBLE:    Result := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(PDouble(ColBind^.buffer)^) <> 0;
        FIELD_TYPE_LONGLONG:
          if ColBind^.is_unsigned_address^ = 0 then
            Result := PInt64(ColBind^.buffer)^ <> 0
          else
            Result := PUInt64(ColBind^.buffer)^ <> 0;
        FIELD_TYPE_YEAR:
          Result := PWord(ColBind^.buffer)^ <> 0;
        FIELD_TYPE_STRING,
        FIELD_TYPE_NEWDECIMAL,
        FIELD_TYPE_DECIMAL,
        FIELD_TYPE_ENUM, FIELD_TYPE_SET:
          Result := StrToBoolEx(PAnsiChar(ColBind^.buffer), True, False);
        FIELD_TYPE_BIT://http://dev.mysql.com/doc/refman/5.0/en/bit-type.html
          case ColBind^.Length[0]  of
            1: Result := PByte(ColBind^.buffer)^ <> 0;
            2: Result := ReverseWordBytes(ColBind^.buffer)  <> 0;
            3, 4: Result := ReverseLongWordBytes(ColBind^.buffer, ColBind^.Length[0] ) <> 0;
            else //5..8: makes compiler happy
              Result := ReverseQuadWordBytes(ColBind^.buffer, ColBind^.Length[0] ) <> 0;
            end;
            //http://dev.mysql.com/doc/refman/5.0/en/bit-type.html
        FIELD_TYPE_TINY_BLOB, FIELD_TYPE_MEDIUM_BLOB, FIELD_TYPE_LONG_BLOB,
        FIELD_TYPE_BLOB, FIELD_TYPE_GEOMETRY:
          if ( ColBind^.Length[0]  > 0 ) and (ColBind^.Length[0]  < 12{Max Int32 Length = 11} ) then
          begin
            ColBind^.buffer_address^ := @FTinyBuffer[0];
            ColBind^.buffer_Length_address^ := SizeOf(FTinyBuffer)-1;//mysql sets $0 on to of data and corrupts our mem
            FPlainDriver.mysql_stmt_fetch_column(FMYSQL_STMT, ColBind^.mysql_bind, ColumnIndex, 0);
            ColBind^.buffer_address^ := nil;
            ColBind^.buffer_Length_address^ := 0;
            Result := StrToBoolEx(PAnsiChar(@FTinyBuffer[0]), @FTinyBuffer[ColBind^.Length[0]]);
          end;
      end
  end else begin
    {$R-}
    Buffer := PMYSQL_ROW(FRowHandle)[ColumnIndex];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    LastWasNull := Buffer = nil;
    if not LastWasNull then
      if ColBind^.buffer_type_address^ = FIELD_TYPE_BIT then begin
        {$R-}
        Len := FLengthArray[ColumnIndex];
        {$IFDEF RangeCheckEnabled} {$R+} {$ENDIF}
        case Len of
          1: Result := PByte(Buffer)^ <> 0;
          2: Result := ReverseWordBytes(Buffer) <> 0;
          3, 4: Result := ReverseLongWordBytes(Buffer, Len) <> 0;
          else //5..8: makes compiler happy
            Result := ReverseQuadWordBytes(Buffer, Len) <> 0;
        end
      end else Result := StrToBoolEx(Buffer, True, False);
  end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  an <code>int</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZAbstractMySQLResultSet.GetInt(ColumnIndex: Integer): Integer;
var
  Buffer: PAnsiChar;
  Len: Ulong;
  ColBind: PMYSQL_aligned_BIND;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stInteger);
{$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex-1;
  {$ENDIF}
  {$R-}
  ColBind := @FMYSQL_aligned_BINDs[ColumnIndex];
  {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
  Result := 0;
  if fBindBufferAllocated then begin
    LastWasNull := ColBind^.is_null =1;
    if not LastWasNull then
      //http://dev.mysql.com/doc/refman/5.1/de/numeric-types.html
      Case ColBind^.buffer_type_address^ of
        FIELD_TYPE_TINY:  if ColBind^.is_unsigned_address^ = 0
                          then Result := PShortInt(ColBind^.buffer)^
                          else Result := PByte(ColBind^.buffer)^;
        FIELD_TYPE_SHORT: if ColBind^.is_unsigned_address^ = 0
                          then Result := PSmallInt(ColBind^.buffer)^
                          else Result := PWord(ColBind^.buffer)^;
        FIELD_TYPE_LONG:  if ColBind^.is_unsigned_address^ = 0
                          then Result := PInteger(ColBind^.buffer)^
                          else Result := Integer(PCardinal(ColBind^.buffer)^);
        FIELD_TYPE_FLOAT:     Result := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(PSingle(ColBind^.buffer)^);
        FIELD_TYPE_DOUBLE:    Result := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(PDouble(ColBind^.buffer)^);
        FIELD_TYPE_LONGLONG:  if ColBind^.is_unsigned_address^ = 0
                              then Result := Integer(PInt64(ColBind^.buffer)^)
                              else Result := Integer(PUInt64(ColBind^.buffer)^);
        FIELD_TYPE_YEAR: Result := PWord(ColBind^.buffer)^;
        FIELD_TYPE_STRING,
        FIELD_TYPE_NEWDECIMAL,
        FIELD_TYPE_DECIMAL,
        FIELD_TYPE_ENUM, FIELD_TYPE_SET:
          Result := RawToIntDef(PAnsiChar(ColBind^.buffer), 0);
        FIELD_TYPE_BIT: //http://dev.mysql.com/doc/refman/5.0/en/bit-type.html
          case ColBind^.Length[0]  of
            1: Result := PByte(ColBind^.buffer)^;
            2: Result := ReverseWordBytes(Pointer(ColBind^.buffer));
            3, 4: Result := ReverseLongWordBytes(Pointer(ColBind^.buffer), ColBind^.Length[0] );
            else //5..8: makes compiler happy
              Result := ReverseQuadWordBytes(Pointer(ColBind^.buffer), ColBind^.Length[0] );
            end;
        FIELD_TYPE_TINY_BLOB,
        FIELD_TYPE_MEDIUM_BLOB,
        FIELD_TYPE_LONG_BLOB,
        FIELD_TYPE_BLOB,
        FIELD_TYPE_GEOMETRY:
          if ( ColBind^.Length[0]  > 0 ) and (ColBind^.Length[0]  < 13{Max Int32 Length = 11+#0} ) then begin
            ColBind^.buffer_address^ := @FTinyBuffer[0];
            ColBind^.buffer_Length_address^ := SizeOf(FTinyBuffer)-1;//mysql sets $0 on top of data and corrupts our mem
            FPlainDriver.mysql_stmt_fetch_column(FMYSQL_STMT, ColBind^.mysql_bind, ColumnIndex, 0);
            ColBind^.buffer_address^ := nil;
            ColBind^.buffer_Length_address^ := 0;
            Result := RawToIntDef(@FTinyBuffer[0], @FTinyBuffer[ColBind^.Length[0]], 0);
          end;
        else raise CreateMySQLConvertError(ColumnIndex, ColBind^.buffer_type_address^);
      end
  end else begin
    {$R-}
    Buffer := PMYSQL_ROW(FRowHandle)[ColumnIndex];
    Len := FLengthArray^[ColumnIndex];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    LastWasNull := Buffer = nil;
    if not LastWasNull then
      if ColBind.buffer_type_address^ = FIELD_TYPE_BIT then begin
        case Len of
          1: Result := PByte(Buffer)^;
          2: Result := ReverseWordBytes(Buffer);
          3, 4: Result := ReverseLongWordBytes(Buffer, Len);
          else //5..8: makes compiler happy
            Result := ReverseQuadWordBytes(Buffer, Len);
        end
      end else Result := RawToIntDef(Buffer, 0);
  end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>long</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZAbstractMySQLResultSet.GetLong(ColumnIndex: Integer): Int64;
var
  Buffer: PAnsiChar;
  Len: ULong;
  ColBind: PMYSQL_aligned_BIND;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stLong);
{$ENDIF}
  {$IFNDEF GENERIC_INDEX}Dec(ColumnIndex);{$ENDIF}
  {$R-}
  ColBind := @FMYSQL_aligned_BINDs[ColumnIndex];
  {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
  Result := 0;
  if fBindBufferAllocated then begin
    LastWasNull := ColBind^.is_null =1;
    if not LastWasNull then
      //http://dev.mysql.com/doc/refman/5.1/de/numeric-types.html
      Case ColBind^.buffer_type_address^ of
        FIELD_TYPE_TINY:  if ColBind^.is_unsigned_address^ = 0
                          then Result := PShortInt(ColBind^.buffer)^
                          else Result := PByte(ColBind^.buffer)^;
        FIELD_TYPE_SHORT: if ColBind^.is_unsigned_address^ = 0
                          then Result := PSmallInt(ColBind^.buffer)^
                          else Result := PWord(ColBind^.buffer)^;
        FIELD_TYPE_LONG:  if ColBind^.is_unsigned_address^ = 0
                          then Result := PInteger(ColBind^.buffer)^
                          else Result := PCardinal(ColBind^.buffer)^;
        FIELD_TYPE_FLOAT:     Result := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(PSingle(ColBind^.buffer)^);
        FIELD_TYPE_DOUBLE:    Result := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(PDouble(ColBind^.buffer)^);
        FIELD_TYPE_LONGLONG:  if ColBind^.is_unsigned_address^ = 0
                              then Result := PInt64(ColBind^.buffer)^
                              else Result := PUInt64(ColBind^.buffer)^;
        FIELD_TYPE_YEAR: Result := PWord(ColBind^.buffer)^;
        FIELD_TYPE_STRING,
        FIELD_TYPE_NEWDECIMAL,
        FIELD_TYPE_DECIMAL,
        FIELD_TYPE_ENUM, FIELD_TYPE_SET:
          Result := RawToInt64Def(PAnsiChar(ColBind^.buffer), 0);
        FIELD_TYPE_BIT: //http://dev.mysql.com/doc/refman/5.0/en/bit-type.html
          case ColBind^.Length[0]  of
            1: Result := PByte(ColBind^.buffer)^;
            2: Result := ReverseWordBytes(Pointer(ColBind^.buffer));
            3, 4: Result := ReverseLongWordBytes(Pointer(ColBind^.buffer), ColBind^.Length[0] );
            else //5..8: makes compiler happy
              Result := ReverseQuadWordBytes(Pointer(ColBind^.buffer), ColBind^.Length[0] );
            end;
        FIELD_TYPE_TINY_BLOB, FIELD_TYPE_MEDIUM_BLOB, FIELD_TYPE_LONG_BLOB,
        FIELD_TYPE_BLOB, FIELD_TYPE_GEOMETRY:
          if ( ColBind^.Length[0]  > 0 ) and (ColBind^.Length[0]  < 22{Max Int64 Length = 20+#0}) then
          begin
            ColBind^.buffer_address^ := @FTinyBuffer[0];
            ColBind^.buffer_Length_address^ := SizeOf(FTinyBuffer)-1;//mysql sets $0 on to of data and corrupts our mem
            FPlainDriver.mysql_stmt_fetch_column(FMYSQL_STMT, ColBind^.mysql_bind, ColumnIndex, 0);
            ColBind^.buffer_address^ := nil;
            ColBind^.buffer_Length_address^ := 0;
            Result := RawToInt64Def(@FTinyBuffer[0], @FTinyBuffer[ColBind^.Length[0]], 0);
          end;
        else raise CreateMySQLConvertError(ColumnIndex, ColBind^.buffer_type_address^);
      end
  end else begin
    {$R-}
    Buffer := PMYSQL_ROW(FRowHandle)[ColumnIndex];
    Len := FLengthArray^[ColumnIndex];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    LastWasNull := Buffer = nil;
    if not LastWasNull then
      if ColBind.buffer_type_address^ = FIELD_TYPE_BIT then
        case Len of
          1: Result := PByte(Buffer)^;
          2: Result := ReverseWordBytes(Buffer);
          3, 4: Result := ReverseLongWordBytes(Buffer, Len);
          else //5..8: makes compiler happy
            Result := ReverseQuadWordBytes(Buffer, Len);
        end
      else Result := RawToInt64Def(Buffer, 0);
  end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>long</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZAbstractMySQLResultSet.GetUInt(ColumnIndex: Integer): Cardinal;
var
  Buffer: PAnsiChar;
  Len: ULong;
  ColBind: PMYSQL_aligned_BIND;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stLongWord);
{$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex-1;
  {$ENDIF}
  {$R-}
  ColBind := @FMYSQL_aligned_BINDs[ColumnIndex];
  {$IF defined (RangeCheckEnabled) and not defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}
  Result := 0;
  if fBindBufferAllocated then begin
    LastWasNull := ColBind^.is_null =1;
    if not LastWasNull then
      //http://dev.mysql.com/doc/refman/5.1/de/numeric-types.html
      Case ColBind^.buffer_type_address^ of
        FIELD_TYPE_TINY:  if ColBind^.is_unsigned_address^ = 0
                          then Result := PShortInt(ColBind^.buffer)^
                          else Result := PByte(ColBind^.buffer)^;
        FIELD_TYPE_SHORT: if ColBind^.is_unsigned_address^ = 0
                          then Result := PSmallInt(ColBind^.buffer)^
                          else Result := PWord(ColBind^.buffer)^;
        FIELD_TYPE_LONG:  if ColBind^.is_unsigned_address^ = 0
                          then Result := PInteger(ColBind^.buffer)^
                          else Result := PCardinal(ColBind^.buffer)^;
        FIELD_TYPE_FLOAT:     Result := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(PSingle(ColBind^.buffer)^);
        FIELD_TYPE_DOUBLE:    Result := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(PDouble(ColBind^.buffer)^);
        FIELD_TYPE_LONGLONG:  if ColBind^.is_unsigned_address^ = 0
                              then Result := PInt64(ColBind^.buffer)^
                              else Result := PUInt64(ColBind^.buffer)^;
        FIELD_TYPE_YEAR: Result := PWord(ColBind^.buffer)^;
        FIELD_TYPE_STRING,
        FIELD_TYPE_NEWDECIMAL,
        FIELD_TYPE_DECIMAL,
        FIELD_TYPE_ENUM, FIELD_TYPE_SET:
          Result := RawToUInt64Def(PAnsiChar(ColBind^.buffer), 0);
        FIELD_TYPE_BIT: //http://dev.mysql.com/doc/refman/5.0/en/bit-type.html
          case ColBind^.Length[0]  of
            1: Result := PByte(ColBind^.buffer)^;
            2: Result := ReverseWordBytes(Pointer(ColBind^.buffer));
            3, 4: Result := ReverseLongWordBytes(Pointer(ColBind^.buffer), ColBind^.Length[0] );
            else //5..8: makes compiler happy
              Result := ReverseQuadWordBytes(Pointer(ColBind^.buffer), ColBind^.Length[0] );
            end;
        FIELD_TYPE_TINY_BLOB, FIELD_TYPE_MEDIUM_BLOB, FIELD_TYPE_LONG_BLOB,
        FIELD_TYPE_BLOB, FIELD_TYPE_GEOMETRY:
        if ( ColBind^.Length[0]  > 0 ) and (ColBind^.Length[0]  < 22{Max UInt64 Length = 20+#0} ) then
          begin
            ColBind^.buffer_address^ := @FTinyBuffer[0];
            ColBind^.buffer_Length_address^ := SizeOf(FTinyBuffer)-1;//mysql sets $0 on to of data and corrupts our mem
            FPlainDriver.mysql_stmt_fetch_column(FMYSQL_STMT, ColBind^.mysql_bind, ColumnIndex, 0);
            ColBind^.buffer_address^ := nil;
            ColBind^.buffer_Length_address^ := 0;
            Result := RawToUInt64Def(@FTinyBuffer[0], @FTinyBuffer[ColBind^.Length[0]], 0);
          end;
        else raise CreateMySQLConvertError(ColumnIndex, ColBind^.buffer_type_address^);
      end
  end else begin
    {$R-}
    Buffer := PMYSQL_ROW(FRowHandle)[ColumnIndex];
    Len := FLengthArray^[ColumnIndex];
    {$IF defined (RangeCheckEnabled) and not defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
    LastWasNull := Buffer = nil;
    if not LastWasNull then
      if ColBind.buffer_type_address^ = FIELD_TYPE_BIT then
        case Len of
          1: Result := PByte(Buffer)^;
          2: Result := ReverseWordBytes(Buffer);
          3, 4: Result := ReverseLongWordBytes(Buffer, Len);
          else //5..8: makes compiler happy
            Result := ReverseQuadWordBytes(Buffer, Len);
        end
      else Result := RawToUInt64Def(Buffer, 0);
  end;
end;

{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
function TZAbstractMySQLResultSet.GetULong(ColumnIndex: Integer): UInt64;
var
  Buffer: PAnsiChar;
  Len: ULong;
  ColBind: PMYSQL_aligned_BIND;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stULong);
{$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex-1;
  {$ENDIF}
  {$R-}
  ColBind := @FMYSQL_aligned_BINDs[ColumnIndex];
  {$IF defined (RangeCheckEnabled) and not defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}
  Result := 0;
  if fBindBufferAllocated then begin
    LastWasNull := ColBind^.is_null =1;
    if not LastWasNull then
      //http://dev.mysql.com/doc/refman/5.1/de/numeric-types.html
      Case ColBind^.buffer_type_address^ of
        FIELD_TYPE_LONG:  if ColBind^.is_unsigned_address^ = 0
                          then Result := PInteger(ColBind^.buffer)^
                          else Result := PCardinal(ColBind^.buffer)^;
        FIELD_TYPE_TINY:  if ColBind^.is_unsigned_address^ = 0
                          then Result := PShortInt(ColBind^.buffer)^
                          else Result := PByte(ColBind^.buffer)^;
        FIELD_TYPE_SHORT: if ColBind^.is_unsigned_address^ = 0
                          then Result := PSmallInt(ColBind^.buffer)^
                          else Result := PWord(ColBind^.buffer)^;
        FIELD_TYPE_FLOAT:     Result := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(PSingle(ColBind^.buffer)^);
        FIELD_TYPE_DOUBLE:    Result := {$IFDEF USE_FAST_TRUNC}ZFastCode.{$ENDIF}Trunc(PDouble(ColBind^.buffer)^);
        FIELD_TYPE_LONGLONG:  if ColBind^.is_unsigned_address^ = 0
                              then Result := PInt64(ColBind^.buffer)^
                              else Result := PUInt64(ColBind^.buffer)^;
        FIELD_TYPE_YEAR: Result := PWord(ColBind^.buffer)^;
        FIELD_TYPE_STRING,
        FIELD_TYPE_NEWDECIMAL,
        FIELD_TYPE_DECIMAL,
        FIELD_TYPE_ENUM, FIELD_TYPE_SET:
          Result := RawToUInt64Def(PAnsiChar(ColBind^.buffer), 0);
        FIELD_TYPE_BIT: //http://dev.mysql.com/doc/refman/5.0/en/bit-type.html
          case ColBind^.Length[0]  of
            1: Result := PByte(ColBind^.buffer)^;
            2: Result := ReverseWordBytes(Pointer(ColBind^.buffer));
            3, 4: Result := ReverseLongWordBytes(Pointer(ColBind^.buffer), ColBind^.Length[0] );
            else //5..8: makes compiler happy
              Result := ReverseQuadWordBytes(Pointer(ColBind^.buffer), ColBind^.Length[0] );
            end;
        FIELD_TYPE_TINY_BLOB, FIELD_TYPE_MEDIUM_BLOB, FIELD_TYPE_LONG_BLOB,
        FIELD_TYPE_BLOB, FIELD_TYPE_GEOMETRY:
        if ( ColBind^.Length[0]  > 0 ) and (ColBind^.Length[0]  < 22{Max UInt64 Length = 20+#0} ) then
          begin
            ColBind^.buffer_address^ := @FTinyBuffer[0];
            ColBind^.buffer_Length_address^ := SizeOf(FTinyBuffer)-1;//mysql sets $0 on to of data and corrupts our mem
            FPlainDriver.mysql_stmt_fetch_column(FMYSQL_STMT, ColBind^.mysql_bind, ColumnIndex, 0);
            ColBind^.buffer_address^ := nil;
            ColBind^.buffer_Length_address^ := 0;
            Result := RawToUInt64Def(@FTinyBuffer[0], @FTinyBuffer[ColBind^.Length[0]], 0);
          end;
        else raise CreateMySQLConvertError(ColumnIndex, ColBind^.buffer_type_address^);
      end
  end else begin
    {$R-}
    Buffer := PMYSQL_ROW(FRowHandle)[ColumnIndex];
    Len := FLengthArray^[ColumnIndex];
    {$IF defined (RangeCheckEnabled) and not defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
    LastWasNull := Buffer = nil;
    if not LastWasNull then
      if ColBind.buffer_type_address^ = FIELD_TYPE_BIT then
        case Len of
          1: Result := PByte(Buffer)^;
          2: Result := ReverseWordBytes(Buffer);
          3, 4: Result := ReverseLongWordBytes(Buffer, Len);
          else //5..8: makes compiler happy
            Result := ReverseQuadWordBytes(Buffer, Len);
        end
      else Result := RawToUInt64Def(Buffer, 0);
  end;
end;
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>float</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZAbstractMySQLResultSet.GetFloat(ColumnIndex: Integer): Single;
begin
  Result := GetDouble(ColumnIndex);
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>UUID</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>Zero-UUID</code>
}
procedure TZAbstractMySQLResultSet.GetGUID(ColumnIndex: Integer;
  var Result: TGUID);
var
  ColBind: PMYSQL_aligned_BIND;
  Len: ULong;
  P: PAnsiChar;
label Fail, Fill, DoMove, FromChar;
begin
  {$IFNDEF DISABLE_CHECKING}
  CheckClosed;
  if (fBindBufferAllocated and (FMYSQL_STMT = nil)) or
     (not fBindBufferAllocated and (FRowHandle = nil)) then
    raise EZSQLException.Create(SRowDataIsNotAvailable);
  {$ENDIF}
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stGUID);
{$ENDIF}
  {$R-}
  ColBind := @FMYSQL_aligned_BINDs[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}];
  {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
  if fBindBufferAllocated then begin
    LastWasNull := ColBind^.is_null =1;
    if LastWasNull then
Fill: FillChar(Result, SizeOf(TGUID), #0)
    else case ColBind^.buffer_type_address^ of
        FIELD_TYPE_TINY_BLOB, FIELD_TYPE_MEDIUM_BLOB, FIELD_TYPE_LONG_BLOB,
        FIELD_TYPE_BLOB, FIELD_TYPE_STRING:
          begin
            if ColBind.buffer = nil then
              goto Fail;
            P := ColBind^.buffer;
            if ColBind^.binary and (ColBind^.length[0] = SizeOf(TGUID))
            then goto DoMove
            else if not ColBind^.binary and ((ColBind^.length[0] = 36) or (ColBind^.length[0] = 38))
            then goto FromChar
            else goto Fail;
          end;
        else goto Fail;
    end;
  end else begin
    {$R-}
    P := PMYSQL_ROW(FRowHandle)[ColumnIndex];
    LastWasNull := P = nil;
    if LastWasNull then
      goto Fill
    else begin
      Len := FLengthArray^[ColumnIndex];
      case TZColumnInfo(ColumnsInfo[ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}]).ColumnType of
        stBytes: if Len = SizeOf(TGUID) then
DoMove:          Move(P^, Result.D1, SizeOf(TGUID))
                 else goto Fail;
        stString, stUnicodeString: if (Len = 36) or (Len = 38) then
FromChar:        ValidGUIDToBinary(P, @Result.D1)
                 else goto Fail;
       else
Fail:           raise CreateMySQLConvertError(ColumnIndex{$IFNDEF GENERIC_INDEX}-1{$ENDIF}, ColBind^.buffer_type_address^);
      end;

      end;
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
  end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>java.sql.Date</code> object in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
procedure TZAbstractMySQLResultSet.GetDate(ColumnIndex: Integer;
  var Result: TZDate);
var
  Len: NativeUInt;
  Buffer: PAnsiChar;
  ColBind: PMYSQL_aligned_BIND;
label From_Str, Fill;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckClosed;
  CheckColumnConvertion(ColumnIndex, stDate);
{$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex-1;
  {$ENDIF}
  if fBindBufferAllocated then begin
    {$R-}
    ColBind := @FMYSQL_aligned_BINDs[ColumnIndex];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    LastWasNull := ColBind^.is_null =1;
    if not LastWasNull then
      //http://dev.mysql.com/doc/refman/5.1/de/numeric-types.html
      Case ColBind^.buffer_type_address^ of
        FIELD_TYPE_TIME: goto Fill;
        FIELD_TYPE_TIMESTAMP, FIELD_TYPE_DATE, FIELD_TYPE_DATETIME,
        FIELD_TYPE_NEWDATE: begin
            Result.Year := PMYSQL_TIME(ColBind^.buffer)^.year;
            Result.Month := PMYSQL_TIME(ColBind^.buffer)^.month;
            Result.Day := PMYSQL_TIME(ColBind^.buffer)^.day;
            Result.IsNegative := PMYSQL_TIME(ColBind^.buffer)^.neg <> 0;
          end;
        FIELD_TYPE_YEAR: Result.Year := PWord(ColBind^.buffer)^;
        FIELD_TYPE_STRING: begin
                              Buffer := PAnsiChar(ColBind^.buffer);
                              Len := ColBind^.Length[0];
                              goto From_Str;
                            end;
        else DecodeDate(GetDouble(ColumnIndex{$IFNDEF GENERIC_INDEX}+1{$ENDIF}), Result.Year, Result.Month, Result.Day);
      end else goto Fill;
  end else begin
    {$R-}
    Buffer := PMYSQL_ROW(FRowHandle)[ColumnIndex];
    Len := FLengthArray^[ColumnIndex];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    LastWasNull := Buffer = nil;
    if not LastWasNull then begin
From_Str: LastWasNull := not TryPCharToDate(Buffer, Len, ConSettings^.ReadFormatSettings, Result);
      if LastWasNull then
Fill:   Pint64(@Result.Year)^ := 0;
    end;
  end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>double</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZAbstractMySQLResultSet.GetDouble(ColumnIndex: Integer): Double;
var
  Len: NativeUInt;
  Buffer: PAnsiChar;
  ColBind: PMYSQL_aligned_BIND;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stDouble);
{$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex-1;
  {$ENDIF}
  {$R-}
  ColBind := @FMYSQL_aligned_BINDs[ColumnIndex];
  {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
  Result := 0;
  if fBindBufferAllocated then begin
    LastWasNull := ColBind^.is_null =1;
    if not LastWasNull then
      //http://dev.mysql.com/doc/refman/5.1/de/numeric-types.html
      Case ColBind^.buffer_type_address^ of
        FIELD_TYPE_TINY:  if ColBind^.is_unsigned_address^ = 0
                          then Result := PShortInt(ColBind^.buffer)^
                          else Result := PByte(ColBind^.buffer)^;
        FIELD_TYPE_SHORT: if ColBind^.is_unsigned_address^ = 0
                          then Result := PSmallInt(ColBind^.buffer)^
                          else Result := PWord(ColBind^.buffer)^;
        FIELD_TYPE_LONG:  if ColBind^.is_unsigned_address^ = 0
                          then Result := PInteger(ColBind^.buffer)^
                          else Result := Integer(PCardinal(ColBind^.buffer)^);
        FIELD_TYPE_FLOAT:   if ColBind^.decimals < 20
                            then Result := RoundTo(PSingle(ColBind^.buffer)^, ColBind^.decimals*-1)
                            else Result := PSingle(ColBind^.buffer)^;
        FIELD_TYPE_DOUBLE:  if ColBind^.decimals < 20
                            then Result := RoundTo(PDouble(ColBind^.buffer)^, ColBind^.decimals*-1)
                            else Result := PDouble(ColBind^.buffer)^;
        FIELD_TYPE_LONGLONG:  if ColBind^.is_unsigned_address^ = 0
                              then Result := Integer(PInt64(ColBind^.buffer)^)
                              else Result := Integer(PUInt64(ColBind^.buffer)^);
        FIELD_TYPE_YEAR: Result := PWord(ColBind^.buffer)^;
        FIELD_TYPE_NEWDECIMAL,
        FIELD_TYPE_DECIMAL,
        FIELD_TYPE_STRING,
        FIELD_TYPE_ENUM,
        FIELD_TYPE_SET:
          ZSysUtils.SQLStrToFloatDef(PAnsiChar(ColBind^.buffer), 0, Result, ColBind^.Length[0] );
        FIELD_TYPE_BIT,//http://dev.mysql.com/doc/refman/5.0/en/bit-type.html
        FIELD_TYPE_TINY_BLOB, FIELD_TYPE_MEDIUM_BLOB, FIELD_TYPE_LONG_BLOB,
        FIELD_TYPE_BLOB, FIELD_TYPE_GEOMETRY:
          if ( ColBind^.Length[0]  > 0 ) and (ColBind^.Length[0]  < 30{Max Extended Length = 28 ??} ) then begin
            ColBind^.buffer_address^ := @FTinyBuffer[0];
            ColBind^.buffer_Length_address^ := SizeOf(FTinyBuffer)-1;//mysql sets $0 on to of data and corrupts our mem
            FPlainDriver.mysql_stmt_fetch_column(FMYSQL_STMT, ColBind^.mysql_bind, ColumnIndex, 0);
            ColBind^.buffer_address^ := nil;
            ColBind^.buffer_Length_address^ := 0;
            FTinyBuffer[ColBind^.Length[0]] := 0;
            RawToFloatDef(PAnsichar(@FTinyBuffer[0]), {$IFDEF NO_ANSICHAR}Ord{$ENDIF}('.'), 0, Result);
          end;
        else raise CreateMySQLConvertError(ColumnIndex, ColBind^.buffer_type_address^);
      end
  end else begin
    {$R-}
    Buffer := PMYSQL_ROW(FRowHandle)[ColumnIndex];
    Len := FLengthArray^[ColumnIndex];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    LastWasNull := Buffer = nil;
    if not LastWasNull then
      ZSysUtils.SQLStrToFloatDef(Buffer, 0, Result, Len);
  end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>java.sql.BigDecimal</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @param scale the number of digits to the right of the decimal point
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
procedure TZAbstractMySQLResultSet.GetBigDecimal(ColumnIndex: Integer; var Result: TBCD);
var
  Len: NativeUInt;
  Buffer: PAnsiChar;
  ColBind: PMYSQL_aligned_BIND;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stBigDecimal);
{$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex-1;
  {$ENDIF}
  {$R-}
  ColBind := @FMYSQL_aligned_BINDs[ColumnIndex];
  {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
  if fBindBufferAllocated then begin
    LastWasNull := ColBind^.is_null =1;
    if not LastWasNull then
      //http://dev.mysql.com/doc/refman/5.1/de/numeric-types.html
      //see: setup_one_fetch_function in http://www.iskm.org/mysql56/libmysql_8c_source.html
      //libmysql does always convert the decimal_t to a str-buffer
      Case ColBind^.buffer_type_address^ of
        FIELD_TYPE_TINY:  if ColBind^.is_unsigned_address^ = 0
                          then ScaledOrdinal2BCD(SmallInt(PShortInt(ColBind^.buffer)^), 0, Result)
                          else ScaledOrdinal2BCD(Word(PByte(ColBind^.buffer)^), 0, Result);
        FIELD_TYPE_SHORT: if ColBind^.is_unsigned_address^ = 0
                          then ScaledOrdinal2BCD(PSmallInt(ColBind^.buffer)^, 0, Result)
                          else ScaledOrdinal2BCD(PWord(ColBind^.buffer)^, 0, Result);
        FIELD_TYPE_LONG:  if ColBind^.is_unsigned_address^ = 0
                          then ScaledOrdinal2BCD(PInteger(ColBind^.buffer)^, 0, Result)
                          else ScaledOrdinal2BCD(PCardinal(ColBind^.buffer)^, 0, Result);
        FIELD_TYPE_FLOAT:   Double2BCD(PSingle(ColBind^.buffer)^, Result);
        FIELD_TYPE_DOUBLE:  Double2BCD(PDouble(ColBind^.buffer)^, Result);
        FIELD_TYPE_LONGLONG:  if ColBind^.is_unsigned_address^ = 0
                              then ScaledOrdinal2BCD(PInt64(ColBind^.buffer)^, 0, Result)
                              else ScaledOrdinal2BCD(PUInt64(ColBind^.buffer)^, 0, Result, False);
        FIELD_TYPE_YEAR: ScaledOrdinal2BCD(PWord(ColBind^.buffer)^, 0, Result);
        FIELD_TYPE_STRING,
        FIELD_TYPE_NEWDECIMAL,
        FIELD_TYPE_DECIMAL,
        FIELD_TYPE_ENUM,
        FIELD_TYPE_SET: LastWasNull := not TryRawToBCD(PAnsiChar(ColBind^.buffer), ColBind^.Length[0], Result, '.');
        FIELD_TYPE_BIT,//http://dev.mysql.com/doc/refman/5.0/en/bit-type.html
        FIELD_TYPE_TINY_BLOB, FIELD_TYPE_MEDIUM_BLOB, FIELD_TYPE_LONG_BLOB,
        FIELD_TYPE_BLOB, FIELD_TYPE_GEOMETRY:
          if ( ColBind^.Length[0]  > 0 ) and
             (ColBind^.Length[0]  <= 66{MaxFMTBcdFractionSize + dot + sign} ) then begin
            ColBind^.buffer_address^ := @FTinyBuffer[0];
            ColBind^.buffer_Length_address^ := SizeOf(FTinyBuffer)-1;//mysql sets $0 on to of data and corrupts our mem
            FPlainDriver.mysql_stmt_fetch_column(FMYSQL_STMT, ColBind^.mysql_bind, ColumnIndex, 0);
            ColBind^.buffer_address^ := nil;
            ColBind^.buffer_Length_address^ := 0;
            LastWasNull := not TryRawToBCD(@FTinyBuffer[0], ColBind^.Length[0], Result, '.');
          end else
            Result := nullbcd;
        else raise CreateMySQLConvertError(ColumnIndex, ColBind^.buffer_type_address^);
      end
    else Result := nullbcd;
  end else begin
    {$R-}
    Buffer := PMYSQL_ROW(FRowHandle)[ColumnIndex];
    Len := FLengthArray^[ColumnIndex];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    LastWasNull := (Buffer = nil) or not TryRawToBCD(Buffer, Len, Result, '.');
  end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>byte</code> array in the Java programming language.
  The bytes represent the raw values returned by the driver.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
function TZAbstractMySQLResultSet.GetBytes(ColumnIndex: Integer): TBytes;
var
  Len: NativeUInt;
  Buffer: PAnsiChar;
  ColBind: PMYSQL_aligned_BIND;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stBytes);
{$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex-1;
  {$ENDIF}
  {$R-}
  ColBind := @FMYSQL_aligned_BINDs[ColumnIndex];
  {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
  Result := nil;
  if fBindBufferAllocated then begin
    LastWasNull := ColBind^.is_null =1;
    if not LastWasNull then
      //http://dev.mysql.com/doc/refman/5.1/de/numeric-types.html
      Case ColBind^.buffer_type_address^ of
        FIELD_TYPE_BIT,//http://dev.mysql.com/doc/refman/5.0/en/bit-type.html
        FIELD_TYPE_STRING,
        FIELD_TYPE_ENUM, FIELD_TYPE_SET:
          Result := BufferToBytes(Pointer(ColBind^.buffer), ColBind^.Length[0] );
        FIELD_TYPE_TINY_BLOB, FIELD_TYPE_MEDIUM_BLOB, FIELD_TYPE_LONG_BLOB,
        FIELD_TYPE_BLOB, FIELD_TYPE_GEOMETRY:
          if ColBind^.Length[0] < SizeOf(FTinyBuffer) then begin
            ColBind^.buffer_address^ := @FTinyBuffer[0];
            ColBind^.buffer_Length_address^ := SizeOf(FTinyBuffer)-1;//mysql sets $0 on to of data and corrupts our mem
            FPlainDriver.mysql_stmt_fetch_column(FMYSQL_STMT, ColBind^.mysql_bind, ColumnIndex, 0);
            ColBind^.buffer_address^ := nil;
            ColBind^.buffer_Length_address^ := 0;
            Result := BufferToBytes(@FTinyBuffer[0], ColBind^.Length[0] );
          end else
            Result := GetBlob(ColumnIndex{$IFNDEF GENERIC_INDEX}+1{$ENDIF}).GetBytes;
        else raise CreateMySQLConvertError(ColumnIndex, ColBind^.buffer_type_address^);
      End;
  end else begin
    {$R-}
    Buffer := PMYSQL_ROW(FRowHandle)[ColumnIndex];
    Len := FLengthArray^[ColumnIndex];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    LastWasNull := Buffer = nil;
    if not LastWasNull then
      Result := BufferToBytes(Buffer, Len);
  end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>currency</code> in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>0</code>
}
function TZAbstractMySQLResultSet.GetCurrency(ColumnIndex: Integer): Currency;
var
  Len: NativeUInt;
  Buffer: PAnsiChar;
  ColBind: PMYSQL_aligned_BIND;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckColumnConvertion(ColumnIndex, stFloat);
{$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex-1;
  {$ENDIF}
  {$R-}
  ColBind := @FMYSQL_aligned_BINDs[ColumnIndex];
  {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
  Result := 0;
  if fBindBufferAllocated then begin
    LastWasNull := ColBind^.is_null =1;
    if not LastWasNull then
      //http://dev.mysql.com/doc/refman/5.1/de/numeric-types.html
      Case ColBind^.buffer_type_address^ of
        FIELD_TYPE_TINY:  if ColBind^.is_unsigned_address^ = 0
                          then Result := PShortInt(ColBind^.buffer)^
                          else Result := PByte(ColBind^.buffer)^;
        FIELD_TYPE_SHORT: if ColBind^.is_unsigned_address^ = 0
                          then Result := PSmallInt(ColBind^.buffer)^
                          else Result := PWord(ColBind^.buffer)^;
        FIELD_TYPE_LONG:  if ColBind^.is_unsigned_address^ = 0
                          then Result := PInteger(ColBind^.buffer)^
                          else Result := Integer(PCardinal(ColBind^.buffer)^);
        FIELD_TYPE_FLOAT:   if ColBind^.decimals < 20
                            then Result := RoundTo(PSingle(ColBind^.buffer)^, ColBind^.decimals*-1)
                            else Result := PSingle(ColBind^.buffer)^;
        FIELD_TYPE_DOUBLE:  if ColBind^.decimals < 20
                            then Result := RoundTo(PDouble(ColBind^.buffer)^, ColBind^.decimals*-1)
                            else Result := PDouble(ColBind^.buffer)^;
        FIELD_TYPE_LONGLONG:  if ColBind^.is_unsigned_address^ = 0
                              then Result := Integer(PInt64(ColBind^.buffer)^)
                              else Result := Integer(PUInt64(ColBind^.buffer)^);
        FIELD_TYPE_YEAR: Result := PWord(ColBind^.buffer)^;
        FIELD_TYPE_STRING,
        FIELD_TYPE_ENUM,
        FIELD_TYPE_NEWDECIMAL,
        FIELD_TYPE_DECIMAL,
        FIELD_TYPE_SET:
          ZSysUtils.SQLStrToFloatDef(PAnsiChar(ColBind^.buffer), 0, Result, ColBind^.Length[0] );
        FIELD_TYPE_BIT,//http://dev.mysql.com/doc/refman/5.0/en/bit-type.html
        FIELD_TYPE_TINY_BLOB, FIELD_TYPE_MEDIUM_BLOB, FIELD_TYPE_LONG_BLOB,
        FIELD_TYPE_BLOB, FIELD_TYPE_GEOMETRY:
          if ( ColBind^.Length[0]  > 0 ) and
             (ColBind^.Length[0]  < 30{Max Extended Length = 28 ??} ) then begin
            ColBind^.buffer_address^ := @FTinyBuffer[0];
            ColBind^.buffer_Length_address^ := SizeOf(FTinyBuffer)-1;//mysql sets $0 on to of data and corrupts our mem
            FPlainDriver.mysql_stmt_fetch_column(FMYSQL_STMT, ColBind^.mysql_bind, ColumnIndex, 0);
            ColBind^.buffer_address^ := nil;
            ColBind^.buffer_Length_address^ := 0;
            FTinyBuffer[ColBind^.Length[0]] := 0;
            RawToFloatDef(PAnsichar(@FTinyBuffer[0]), {$IFDEF NO_ANSICHAR}Ord{$ENDIF}('.'), 0, Result);
          end;
        else raise CreateMySQLConvertError(ColumnIndex, ColBind^.buffer_type_address^);
      end
  end else begin
    {$R-}
    Buffer := PMYSQL_ROW(FRowHandle)[ColumnIndex];
    Len := FLengthArray^[ColumnIndex];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    LastWasNull := Buffer = nil;
    if not LastWasNull then
      ZSysUtils.SQLStrToFloatDef(Buffer, 0, Result, Len);
  end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>java.sql.Time</code> object in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>java.sql.Timestamp</code> object in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
  value returned is <code>null</code>
  @exception SQLException if a database access error occurs
}
procedure TZAbstractMySQLResultSet.GetTimeStamp(ColumnIndex: Integer;
  var Result: TZTimeStamp);
var
  Len: NativeUInt;
  Buffer: PAnsiChar;
  ColBind: PMYSQL_aligned_BIND;
Label from_str, Fill;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckClosed;
  CheckColumnConvertion(ColumnIndex, stTimestamp);
{$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex-1;
  {$ENDIF}
  if fBindBufferAllocated then begin
    {$R-}
    ColBind := @FMYSQL_aligned_BINDs[ColumnIndex];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    LastWasNull := ColBind^.is_null =1;
    if not LastWasNull then
      //http://dev.mysql.com/doc/refman/5.1/de/numeric-types.html
      Case ColBind^.buffer_type_address^ of
        FIELD_TYPE_DATE, FIELD_TYPE_NEWDATE: begin
            PInt64(@Result.Hour)^ := 0;
            PInt64(@Result.Fractions)^ := 0;
            Result.Year := PMYSQL_TIME(ColBind^.buffer)^.Year;
            Result.Month := PMYSQL_TIME(ColBind^.buffer)^.month;
            Result.Day := PMYSQL_TIME(ColBind^.buffer)^.day;
            Result.IsNegative := PMYSQL_TIME(ColBind^.buffer)^.neg <> 0;
          end;
        FIELD_TYPE_TIME: begin
            PInt64(@Result.Year)^ := 0;
            Result.Hour := PMYSQL_TIME(ColBind^.buffer)^.hour;
            Result.Minute := PMYSQL_TIME(ColBind^.buffer)^.minute;
            Result.Second := PMYSQL_TIME(ColBind^.buffer)^.second;
            Result.Fractions := PMYSQL_TIME(ColBind^.buffer)^.second_part * FractionLength2NanoSecondMulTable[TZColumnInfo(ColumnsInfo[ColumnIndex]).Scale];
            Result.IsNegative := PMYSQL_TIME(ColBind^.buffer)^.neg <> 0;
            PCardinal(@Result.TimeZoneHour)^ := 0;
          end;
        FIELD_TYPE_TIMESTAMP, FIELD_TYPE_DATETIME: begin
            Result.Year := PMYSQL_TIME(ColBind^.buffer)^.Year;
            Result.Month := PMYSQL_TIME(ColBind^.buffer)^.month;
            Result.Day := PMYSQL_TIME(ColBind^.buffer)^.day;
            Result.Hour := PMYSQL_TIME(ColBind^.buffer)^.hour;
            Result.Minute := PMYSQL_TIME(ColBind^.buffer)^.minute;
            Result.Second := PMYSQL_TIME(ColBind^.buffer)^.second;
            Result.Fractions := PMYSQL_TIME(ColBind^.buffer)^.second_part * FractionLength2NanoSecondMulTable[TZColumnInfo(ColumnsInfo[ColumnIndex]).Scale];
            Result.IsNegative := PMYSQL_TIME(ColBind^.buffer)^.neg <> 0;
            PCardinal(@Result.TimeZoneHour)^ := 0;
          end;
        FIELD_TYPE_YEAR: begin
            FillChar(Result, SizeOf(TZTimeStamp), #0);
            Result.Year := PWord(ColBind^.buffer)^;
          end;
        FIELD_TYPE_STRING: begin
            Buffer := PAnsiChar(ColBind^.buffer);
            Len := ColBind^.Length[0];
            goto from_str;
        end;
        else DecodeDateTimeToTimeStamp(GetDouble(ColumnIndex{$IFNDEF GENERIC_INDEX}+1{$ENDIF}), Result);
      end else goto Fill;
  end else begin
    {$R-}
    Buffer := PMYSQL_ROW(FRowHandle)[ColumnIndex];
    Len := FLengthArray^[ColumnIndex];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    LastWasNull := Buffer = nil;
    if not LastWasNull then begin
from_str:
      LastWasNull := not TryPCharToTimeStamp(Buffer, Len, ConSettings^.ReadFormatSettings, Result);
      if LastWasNull then
Fill:   FillChar(Result, SizeOf(TZTimeStamp), #0);
    end;
  end;
end;

{**
  Gets the value of the designated column in the current row
  of this <code>ResultSet</code> object as
  a <code>java.sql.Time</code> object in the Java programming language.

  @param columnIndex the first column is 1, the second is 2, ...
  @return the column value; if the value is SQL <code>NULL</code>, the
    value returned is <code>null</code>
}
procedure TZAbstractMySQLResultSet.GetTime(ColumnIndex: Integer;
  var Result: TZTime);
var
  Len: NativeUInt;
  Buffer: PAnsiChar;
  ColBind: PMYSQL_aligned_BIND;
label From_Str, Fill;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckClosed;
  CheckColumnConvertion(ColumnIndex, stTime);
{$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex-1;
  {$ENDIF}
  if fBindBufferAllocated then begin
    {$R-}
    ColBind := @FMYSQL_aligned_BINDs[ColumnIndex];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    LastWasNull := ColBind^.is_null =1;
    if not LastWasNull then
      //http://dev.mysql.com/doc/refman/5.1/de/numeric-types.html
      Case ColBind^.buffer_type_address^ of
        FIELD_TYPE_TIMESTAMP, FIELD_TYPE_DATETIME, FIELD_TYPE_TIME: begin
            Result.Hour := PMYSQL_TIME(ColBind^.buffer)^.Hour;
            Result.Minute := PMYSQL_TIME(ColBind^.buffer)^.Minute;
            Result.Second := PMYSQL_TIME(ColBind^.buffer)^.second;
            Result.Fractions := PMYSQL_TIME(ColBind^.buffer)^.second_part*FractionLength2NanoSecondMulTable[TZColumnInfo(ColumnsInfo[ColumnIndex]).Scale];
            Result.IsNegative := PMYSQL_TIME(ColBind^.buffer)^.neg <> 0;
          end;
        FIELD_TYPE_DATE,
        FIELD_TYPE_NEWDATE,
        FIELD_TYPE_YEAR: goto Fill;
        FIELD_TYPE_STRING: begin
            Buffer := ColBind^.buffer;
            Len := ColBind^.Length[0];
            goto From_Str;
          end;
        else DecodeDateTimeToTime(GetDouble(ColumnIndex{$IFNDEF GENERIC_INDEX}+1{$ENDIF}), Result);
      end else
        goto Fill;
  end else begin
    {$R-}
    Buffer := PMYSQL_ROW(FRowHandle)[ColumnIndex];
    Len := FLengthArray^[ColumnIndex];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    LastWasNull := Buffer = nil;
    if not LastWasNull then begin
From_Str:
      LastWasNull := not TryPCharToTime(Buffer, Len, ConSettings^.ReadFormatSettings, Result);
      if LastWasNull then begin
Fill:   PCardinal(@Result.Hour)^ := 0;
        PInt64(@Result.Second)^ := 0;
      end;
    end;
  end;
end;

{**
  Returns the value of the designated column in the current row
  of this <code>ResultSet</code> object as a <code>Blob</code> object
  in the Java programming language.

  @param ColumnIndex the first column is 1, the second is 2, ...
  @return a <code>Blob</code> object representing the SQL <code>BLOB</code> value in
    the specified column
}
function TZAbstractMySQLResultSet.GetBlob(ColumnIndex: Integer): IZBlob;
var
  Buffer: PAnsiChar;
  Len: NativeUInt;
  ColBind: PMYSQL_aligned_BIND;
begin
{$IFNDEF DISABLE_CHECKING}
  CheckBlobColumn(ColumnIndex);
{$ENDIF}
  {$IFNDEF GENERIC_INDEX}
  ColumnIndex := ColumnIndex - 1;
  {$ENDIF}
  {$R-}
  ColBind := @FMYSQL_aligned_BINDs[ColumnIndex];
  {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
  Result := nil;
  if fBindBufferAllocated then begin
    LastWasNull := ColBind^.is_null = 1;
    if not LastWasNull then
      if ColBind^.buffer_address^ = nil then
        if ColBind^.binary
        then Result := TZMySQLPreparedBlob.Create(FplainDriver,
            ColBind, FMYSQL_STMT, ColumnIndex, Self)
        else Result := TZMySQLPreparedClob.Create(FplainDriver,
            ColBind, FMYSQL_STMT, ColumnIndex, Self)
      else begin
          Buffer := GetPAnsiChar(ColumnIndex{$IFNDEF GENERIC_INDEX}+1{$ENDIF}, Len);
          Result := TZAbstractClob.CreateWithData(Buffer, Len,
            ConSettings^.ClientCodePage^.CP, ConSettings);
        end;
  end else begin
    {$R-}
    Buffer := PMYSQL_ROW(FRowHandle)[ColumnIndex];
    Len := FLengthArray^[ColumnIndex];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
    LastWasNull := Buffer = nil;
    if not LastWasNull then
      if ColBind^.binary
      then Result := TZAbstractBlob.CreateWithData(Buffer, Len)
      else Result := TZAbstractClob.CreateWithData(Buffer, Len,
            ConSettings^.ClientCodePage^.CP, ConSettings)
  end;
end;

{ TZMySQL_Store_ResultSet }

{**
  Moves the cursor to the given row number in
  this <code>ResultSet</code> object.

  <p>If the row number is positive, the cursor moves to
  the given row number with respect to the
  beginning of the result set.  The first row is row 1, the second
  is row 2, and so on.

  <p>If the given row number is negative, the cursor moves to
  an absolute row position with respect to
  the end of the result set.  For example, calling the method
  <code>absolute(-1)</code> positions the
  cursor on the last row; calling the method <code>absolute(-2)</code>
  moves the cursor to the next-to-last row, and so on.

  <p>An attempt to position the cursor beyond the first/last row in
  the result set leaves the cursor before the first row or after
  the last row.

  <p><B>Note:</B> Calling <code>absolute(1)</code> is the same
  as calling <code>first()</code>. Calling <code>absolute(-1)</code>
  is the same as calling <code>last()</code>.

  @return <code>true</code> if the cursor is on the result set;
    <code>false</code> otherwise
}
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
function TZMySQL_Store_ResultSet.MoveAbsolute(Row: Integer): Boolean;
  function Seek(const RowIndex: ULongLong): Boolean;
  begin
    if fBindBufferAllocated then begin
      FPlainDriver.mysql_stmt_data_seek(FMYSQL_STMT, RowIndex);
      Result := FPlainDriver.mysql_stmt_fetch(FMYSQL_STMT) = 0;
    end else begin
      FPlainDriver.mysql_data_seek(FQueryHandle, RowIndex);
      FRowHandle := FPlainDriver.mysql_fetch_row(FQueryHandle);
      Result := FRowHandle <> nil;
      if Result
      then FLengthArray := FPlainDriver.mysql_fetch_lengths(FQueryHandle)
      else FLengthArray := nil;
    end;
  end;
begin
  { Checks for maximum row. }
  Result := False;
  if Closed or ((MaxRows > 0) and (Row > MaxRows)) then
    Exit;

  if not fBindBufferAllocated and (FQueryHandle = nil) then begin
    FQueryHandle := FPlainDriver.mysql_store_result(FPMYSQL^);
    if Assigned(FQueryHandle) then
      LastRowNo := FPlainDriver.mysql_num_rows(FQueryHandle);
  end;

  { Process negative rows. }
  if Row < 0 then begin
    Row := LastRowNo - Row + 1;
    if Row < 0 then
       Row := 0;
  end;

  if (Row >= 0) and (Row <= LastRowNo + 1) then begin
    if (Row = 0) and (Row < LastRowNo) then begin//handle beforefirst state
      if RowNo > 1
      then Result := Seek(0) //seek back to first position
      else Result := True;   //we're on first pos already
      FFirstRowFetched := RowNo > 0; //indicate the FirstRow is obtained already
      RowNo := 0; //set BeforeFirst state
    end else begin
      RowNo := Row;
      if (Row >= 1) and (Row <= LastRowNo) then
        Result := Seek(RowNo - 1)
      else begin
        if not fBindBufferAllocated then begin
          FRowHandle := nil;
          FLengthArray := nil;
        end;
        Result := False;
      end;
    end;
  end;
end;
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}

procedure TZMySQL_Store_ResultSet.OpenCursor;
begin
  inherited OpenCursor;
  if FPMYSQL_STMT^ <> nil then begin
    if not FIsOutParamResult then begin //else we'll get a "Commands out of Sync..." error
      FMYSQL_STMT := FPMYSQL_STMT^;
      if FPlainDriver.mysql_stmt_store_result(FMYSQL_STMT)=0
      then LastRowNo := FPlainDriver.mysql_stmt_num_rows(FMYSQL_STMT)
      else checkMySQLError(FPlainDriver, FPMYSQL^, FMYSQL_STMT, lcOther, 'mysql_stmt_store_result', Self)
    end;
  end else begin
    FQueryHandle := FPlainDriver.mysql_store_result(FPMYSQL^);
    if Assigned(FQueryHandle)
    then LastRowNo := FPlainDriver.mysql_num_rows(FQueryHandle)
    else CheckMySQLError(FPlainDriver, FPMYSQL^, FMYSQL_STMT, lcOther, 'mysql_store_result', Self)
  end;
end;

procedure TZMySQL_Store_ResultSet.ResetCursor;
begin
  if not Closed then begin
    if fBindBufferAllocated then begin
      if Assigned(FMYSQL_STMT) then
        if FPlainDriver.mysql_stmt_free_result(FMYSQL_STMT) <> 0 then
          checkMySQLError(FPlainDriver,FPMYSQL^, FMYSQL_STMT, lcOther, '', Self);
    end else if FQueryHandle <> nil then begin
      FPlainDriver.mysql_free_result(FQueryHandle);
      FQueryHandle := nil;
    end;
    inherited ResetCursor;
  end;
end;

{ TZMySQLCachedResolver }

{**
  Creates a MySQL specific cached resolver object.
  @param PlainDriver a native MySQL plain driver.
  @param Handle a MySQL specific query handle.
  @param Statement a related SQL statement object.
  @param Metadata a resultset metadata reference.
}
constructor TZMySQLCachedResolver.Create(const PlainDriver: TZMySQLPlainDriver;
  MySQL: PPMySQL; MYSQL_STMT: PPMYSQL_STMT; const Statement: IZStatement;
  const Metadata: IZResultSetMetadata);
var
  I: Integer;
begin
  inherited Create(Statement, Metadata);
  FPlainDriver := PlainDriver;
  FPMYSQL := MySQL;
  FMYSQL_STMT := MYSQL_STMT;
  { Defines an index of autoincrement field. }
  FAutoColumnIndex := InvalidDbcIndex;
  for I := FirstDbcIndex to Metadata.GetColumnCount{$IFDEF GENERIC_INDEX}-1{$ENDIF} do
    if Metadata.IsAutoIncrement(I) and
      (Metadata.GetColumnType(I) in [stByte, stShort, stWord, stSmall, stLongWord, stInteger, stULong, stLong]) then begin
      FAutoColumnIndex := I;
      Break;
    end;
end;

{**
  Forms a where clause for UPDATE or DELETE DML statements.
  @param Columns a collection of key columns.
  @param OldRowAccessor an accessor object to old column values.
}
procedure TZMySQLCachedResolver.FormWhereClause({$IFDEF AUTOREFCOUNT}const {$ENDIF}Columns: TObjectList;
  {$IFDEF AUTOREFCOUNT}const {$ENDIF}SQLWriter: TZSQLStringWriter;
  {$IFDEF AUTOREFCOUNT}const {$ENDIF}OldRowAccessor: TZRowAccessor; var Result: SQLString);
var
  I: Integer;
  Current: TZResolverParameter;
  Tmp: SQLString;
begin
  if WhereColumns.Count > 0 then
    SQLWriter.AddText(' WHERE ', Result);
  for I := 0 to WhereColumns.Count - 1 do begin
    Current := TZResolverParameter(WhereColumns[I]);
    if I > 0 then
      SQLWriter.AddText(' AND ', Result);
    if (Metadata.IsNullable(Current.ColumnIndex) = ntNullable) then begin
      Tmp := IdentifierConvertor.Quote(Current.ColumnName);
      SQLWriter.AddText(Tmp, Result);
      SQLWriter.AddText('<=>?', Result); //"null safe equals" operator
    end else begin
      Tmp := IdentifierConvertor.Quote(Current.ColumnName);
      SQLWriter.AddText(Tmp, Result);
      SQLWriter.AddText('=?', Result);
    end;
  end;
end;
{**
  Posts updates to database.
  @param Sender a cached result set object.
  @param UpdateType a type of updates.
  @param OldRowAccessor an accessor object to old column values.
  @param NewRowAccessor an accessor object to new column values.
}
procedure TZMySQLCachedResolver.PostUpdates(const Sender: IZCachedResultSet;
  UpdateType: TZRowUpdateType; OldRowAccessor, NewRowAccessor: TZRowAccessor);
begin
  inherited PostUpdates(Sender, UpdateType, OldRowAccessor, NewRowAccessor);
  if (UpdateType = utInserted) then
    UpdateAutoIncrementFields(Sender, UpdateType, OldRowAccessor, NewRowAccessor, Self);
end;

{**
 Do Tasks after Post updates to database.
  @param Sender a cached result set object.
  @param UpdateType a type of updates.
  @param OldRowAccessor an accessor object to old column values.
  @param NewRowAccessor an accessor object to new column values.
}
{$IFDEF FPC} {$PUSH} {$WARN 5024 off : Parameter "$1" not used} {$ENDIF} // readonly dataset - parameter not used intentionally
procedure TZMySQLCachedResolver.UpdateAutoIncrementFields(
  const Sender: IZCachedResultSet; UpdateType: TZRowUpdateType; OldRowAccessor,
  NewRowAccessor: TZRowAccessor; const Resolver: IZCachedResolver);
var LastWasNull: Boolean;
begin
  if ((FAutoColumnIndex {$IFDEF GENERIC_INDEX}>={$ELSE}>{$ENDIF} 0) and
          (OldRowAccessor.IsNull(FAutoColumnIndex) or
          (OldRowAccessor.GetULong(FAutoColumnIndex, LastWasNull)=0)))
  then {if FMYSQL_STMT <> nil
    then NewRowAccessor.SetULong(FAutoColumnIndex, FPlainDriver.mysql_stmt_insert_id(FMYSQL_STMT^))  //EH: why does it not work!?
    else }NewRowAccessor.SetULong(FAutoColumnIndex, FPlainDriver.mysql_insert_id(FPMYSQL^)); //and this also works with the prepareds??!
end;
{$IFDEF FPC} {$POP} {$ENDIF}

{ TZMySQLPreparedClob }
constructor TZMySQLPreparedClob.Create(const PlainDriver: TZMySQLPlainDriver;
  Bind: PMYSQL_aligned_BIND; StmtHandle: PPMYSQL_STMT;
  ColumnIndex: Cardinal; const Sender: IImmediatelyReleasable);
var
  offset: ULong;
  Status: Integer;
begin
  inherited Create;
  FConSettings := Sender.GetConSettings;
  FCurrentCodePage := FConSettings^.ClientCodePage^.CP;
  FBlobSize := Bind^.Length[0]+1; //MySQL sets a trailing #0 on top of data
  GetMem(FBlobData, FBlobSize);
  offset := 0;
  Bind^.buffer_Length_address^ := Bind^.Length[0]; //indicate size of Buffer
  Bind^.buffer_address^ := FBlobData;
  Status := PlainDriver.mysql_stmt_fetch_column(StmtHandle, bind^.mysql_bind, ColumnIndex, offset); //move data to buffer
  Bind^.buffer_address^ := nil; //set nil again
  Bind^.buffer_Length_address^ := 0;
  if Status = 1 then
    checkMySQLError(PlainDriver, nil, StmtHandle^, lcOther, '', Sender);
  PByte(PAnsiChar(FBlobData)+FBlobSize-1)^ := Ord(#0);
End;

{ TZMySQLPreparedBlob }
constructor TZMySQLPreparedBlob.Create(const PlainDriver: TZMySQLPlainDriver;
  Bind: PMYSQL_aligned_BIND; StmtHandle: PMySql_Stmt;
  ColumnIndex: Cardinal; const Sender: IImmediatelyReleasable);
var
  offset: ULong;
  Status: Integer;
begin
  inherited Create;
  FBlobSize := Bind^.Length[0];
  GetMem(FBlobData, FBlobSize);
  offset := 0;
  Bind^.buffer_Length_address^ := Bind^.Length[0]; //indicate size of Buffer
  Bind^.buffer_address^ := FBlobData;
  Status := PlainDriver.mysql_stmt_fetch_column(StmtHandle, bind^.mysql_bind, ColumnIndex, offset); //move data to buffer
  Bind^.buffer_address^ := nil; //set nil again
  Bind^.buffer_Length_address^ := 0;
  if Status = 1 then
    checkMySQLError(PlainDriver, nil, StmtHandle, lcOther, '', Sender);
End;

{ TZMySQL_Use_ResultSet }

procedure TZMySQL_Use_ResultSet.AfterConstruction;
begin
  inherited;
  SetType(rtForwardOnly);
end;

procedure TZMySQL_Use_ResultSet.OpenCursor;
begin
  inherited OpenCursor;
  if FMYSQL_STMT = nil then
    FQueryHandle := FPlainDriver.mysql_use_result(FPMYSQL^)
end;

procedure TZMySQL_Use_ResultSet.ResetCursor;
begin
  if not Closed then begin
    if fBindBufferAllocated then begin
      if FMYSQL_STMT <> nil then
        while FPlainDriver.mysql_stmt_fetch(FMYSQL_STMT) in [0, MYSQL_DATA_TRUNCATED] do;
    end else if FQueryHandle <> nil then
      {need to fetch all temporary until handle = nil else all other queries are out of sync
       see: http://dev.mysql.com/doc/refman/5.0/en/mysql-use-result.html}
      while FPlainDriver.mysql_fetch_row(FQueryHandle) <> nil do;
    inherited ResetCursor;
  end;
end;

{$ENDIF ZEOS_DISABLE_MYSQL} //if set we have an empty unit
end.
