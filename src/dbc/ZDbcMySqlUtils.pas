{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{           MySQL Database Connectivity Classes           }
{                                                         }
{         Originally written by Sergey Seroukhov          }
{                           and Sergey Merkuriev          }
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

unit ZDbcMySqlUtils;

interface

{$I ZDbc.inc}

uses
  Classes, {$IFDEF MSEgui}mclasses,{$ENDIF} SysUtils,
  ZSysUtils, ZDbcIntfs, ZPlainMySqlDriver, ZPlainMySqlConstants, ZDbcLogging,
  ZCompatibility, ZDbcResultSetMetadata, ZVariant, ZDbcMySql;

const
  MAXBUF = 65535;

type
  {** Silent exception }
  EZMySQLSilentException = class(EAbort);

{**
  Converts a MySQL native types into ZDBC SQL types.
  @param PlainDriver a native MySQL plain driver.
  @param FieldHandle a handler to field description structure.
  @param FieldFlags field flags.
  @return a SQL undepended type.
}
function ConvertMySQLHandleToSQLType(MYSQL_FIELD: PMYSQL_FIELD;
  CtrlsCPType: TZControlsCodePage; MySQL_FieldType_Bit_1_IsBoolean: Boolean): TZSQLType;

{**
  Checks for possible sql errors.
  @param PlainDriver a MySQL plain driver.
  @param MYSQL_STMT a MySQL statement handle.
  @param MYSQL a MySQL connection handle.
  @param LogCategory a logging category.
  @param LogMessage a logging message.
}
procedure CheckMySQLError(const PlainDriver: TZMySQLPlainDriver;
  MYSQL: PMYSQL; MYSQL_STMT: PMYSQL_STMT; LogCategory: TZLoggingCategory;
  const LogMessage: RawByteString; const ImmediatelyReleasable: IImmediatelyReleasable);

procedure EnterSilentMySQLError;
procedure LeaveSilentMySQLError;

{**
  Decodes a MySQL Version Value encoded with format:
   (major_version * 10,000) + (minor_version * 100) + sub_version
  into separated major, minor and subversion values
  @param MySQLVersion an integer containing the MySQL Full Version to decode.
  @param MajorVersion an integer containing the Major Version decoded.
  @param MinorVersion an integer containing the Minor Version decoded.
  @param SubVersion an integer contaning the Sub Version (revision) decoded.
}
procedure DecodeMySQLVersioning(const MySQLVersion: Integer;
 out MajorVersion: Integer; out MinorVersion: Integer;
 out SubVersion: Integer);

{**
  Encodes major, minor and subversion (revision) values in MySQL format:
   (major_version * 10,000) + (minor_version * 100) + sub_version
  For example, 4.1.12 is returned as 40112.
  @param MajorVersion an integer containing the Major Version.
  @param MinorVersion an integer containing the Minor Version.
  @param SubVersion an integer containing the Sub Version (revision).
  @return an integer containing the full version.
}
function EncodeMySQLVersioning(const MajorVersion: Integer;
 const MinorVersion: Integer; const SubVersion: Integer): Integer;

{**
  Decodes a MySQL Version Value and Encodes it to a Zeos SQL Version format:
   (major_version * 1,000,000) + (minor_version * 1,000) + sub_version
  into separated major, minor and subversion values
  @param MySQLVersion an integer containing the Full Version to decode.
  @return Encoded Zeos SQL Version Value.
}
function ConvertMySQLVersionToSQLVersion( const MySQLVersion: Integer ): Integer;

function getMySQLFieldSize (field_type: TMysqlFieldType; field_size: LongWord): LongWord;

{**
  Returns a valid TZColumnInfo from a FieldHandle
  @param PlainDriver the MySQL PlainDriver interface
  @param FieldHandle the handle of the fetched field
  @returns a new TZColumnInfo
}
function GetMySQLColumnInfoFromFieldHandle(MYSQL_FIELD: PMYSQL_FIELD;
  ConSettings: PZConSettings; MySQL_FieldType_Bit_1_IsBoolean: boolean): TZColumnInfo;

procedure ConvertMySQLColumnInfoFromString(var TypeName: RawByteString;
  ConSettings: PZConSettings; out TypeInfoSecond: RawByteString;
  out FieldType: TZSQLType; out ColumnSize: Integer; out Scale: Integer;
  MySQL_FieldType_Bit_1_IsBoolean: Boolean);

function MySQLPrepareAnsiSQLParam(const Connection: IZMySQLConnection;
  const Value: TZVariant; const DefaultValue: String;
  const ClientVarManager: IZClientVariantManager;
  InParamType: TZSQLType; UseDefaults: Boolean): RawByteString;

function GetMySQLOptionValue(Option: TMySQLOption): string;

function ReverseWordBytes(Src: Pointer): Word;
function ReverseLongWordBytes(Src: Pointer; Len: Byte): LongWord;
function ReverseQuadWordBytes(Src: Pointer; Len: Byte): UInt64;

function GetBindOffsets(IsMariaDB: Boolean; Version: Integer): PMYSQL_BINDOFFSETS;

procedure AllocMySQLBindBuffer(var BindBuffer: Pointer;
  var MYSQL_aligned_BINDs: PMYSQL_aligned_BINDs; BindOffsets: PMYSQL_BINDOFFSETS;
  BindCount, Iterations: ULong);

procedure FreeMySQLBindBuffer(var BindBuffer: Pointer;
  var MYSQL_aligned_BINDs: PMYSQL_aligned_BINDs; BindOffsets: PMYSQL_BINDOFFSETS;
  BoundCount: ULong);

implementation

uses {$IFDEF WITH_UNITANSISTRINGS}AnsiStrings, {$ENDIF} Math, TypInfo,
  ZMessages, ZDbcUtils, ZFastCode, ZEncoding;

threadvar
  SilentMySQLError: Integer;

procedure EnterSilentMySQLError;
begin
  Inc(SilentMySQLError);
end;

procedure LeaveSilentMySQLError;
begin
  Dec(SilentMySQLError);
end;

{**
  Converts a MySQL native types into ZDBC SQL types.
  @param PlainDriver a native MySQL plain driver.
  @param FieldHandle a handler to field description structure.
  @param FieldFlags a field flags.
  @return a SQL undepended type.
}
function ConvertMySQLHandleToSQLType(MYSQL_FIELD: PMYSQL_FIELD;
  CtrlsCPType: TZControlsCodePage; MySQL_FieldType_Bit_1_IsBoolean: Boolean): TZSQLType;
begin
    case MYSQL_FIELD^._type of
    FIELD_TYPE_TINY:
      if MYSQL_FIELD^.flags and UNSIGNED_FLAG = 0
      then Result := stShort
      else Result := stByte;
    FIELD_TYPE_YEAR:
      Result := stWord;
    FIELD_TYPE_SHORT:
      if MYSQL_FIELD^.flags and UNSIGNED_FLAG = 0
      then Result := stSmall
      else Result := stWord;
    FIELD_TYPE_INT24, FIELD_TYPE_LONG:
      if MYSQL_FIELD^.flags and UNSIGNED_FLAG = 0
      then Result := stInteger
      else Result := stLongWord;
    FIELD_TYPE_LONGLONG:
      if MYSQL_FIELD^.flags and UNSIGNED_FLAG = 0
      then Result := stLong
      else Result := stULong;
    FIELD_TYPE_FLOAT, FIELD_TYPE_DOUBLE:
      Result := stDouble;
    FIELD_TYPE_DECIMAL, FIELD_TYPE_NEWDECIMAL: {ADDED FIELD_TYPE_NEWDECIMAL by fduenas 20-06-2006}
      if MYSQL_FIELD^.decimals = 0 then
        if MYSQL_FIELD^.flags and UNSIGNED_FLAG = 0 then begin
          if MYSQL_FIELD^.length <= 2 then
            Result := stShort
          else if MYSQL_FIELD^.length <= 4 then
            Result := stSmall
          else if MYSQL_FIELD^.length <= 9 then
            Result := stInteger
          else Result := stLong;
        end else begin
          if MYSQL_FIELD^.length <= 3 then
            Result := stByte
          else if MYSQL_FIELD^.length <= 5 then
            Result := stWord
          else if MYSQL_FIELD^.length <= 10 then
            Result := stLongWord
          else Result := stULong;
        end
      else
        Result := stDouble;
    FIELD_TYPE_DATE, FIELD_TYPE_NEWDATE:
      Result := stDate;
    FIELD_TYPE_TIME:
      Result := stTime;
    FIELD_TYPE_DATETIME, FIELD_TYPE_TIMESTAMP:
      Result := stTimestamp;
    FIELD_TYPE_TINY_BLOB, FIELD_TYPE_MEDIUM_BLOB,
    FIELD_TYPE_LONG_BLOB, FIELD_TYPE_BLOB:
      if //((MYSQL_FIELD.flags and BINARY_FLAG) = 0)
         (MYSQL_FIELD^.charsetnr <> 63{binary}) then
        If ( CtrlsCPType = cCP_UTF16) then
          Result := stUnicodeStream
        else
          Result := stAsciiStream
      else
        Result := stBinaryStream;
    FIELD_TYPE_BIT: //http://dev.mysql.com/doc/refman/5.1/en/bit-type.html
      case MYSQL_FIELD^.length of
        1: if MySQL_FieldType_Bit_1_IsBoolean
           then Result := stBoolean
           else result := stByte;
        2..8: Result := stByte;
        9..16: Result := stWord;
        17..32: Result := stLongWord;
        else Result := stULong;
      end;
    FIELD_TYPE_VARCHAR,
    FIELD_TYPE_VAR_STRING,
    FIELD_TYPE_STRING:
      if (MYSQL_FIELD^.Length = 0) or //handle null columns: select null union null
         (MYSQL_FIELD^.charsetnr <> 63{binary}) then
        if ( CtrlsCPType = cCP_UTF16)
        then Result := stUnicodeString
        else Result := stString
      else Result := stBytes;
    FIELD_TYPE_ENUM:
      Result := stString;
    FIELD_TYPE_SET:
      Result := stString;
    FIELD_TYPE_NULL:
      // Example: SELECT NULL FROM DUAL
      Result := stString;
   FIELD_TYPE_GEOMETRY:
      // Todo: Would be nice to show as WKT.
      Result := stBinaryStream;
   else
      raise Exception.Create('Unknown MySQL data type!');
   end;
end;

procedure CheckMySQLError(const PlainDriver: TZMySQLPlainDriver;
  MYSQL: PMYSQL; MYSQL_STMT: PMYSQL_STMT; LogCategory: TZLoggingCategory;
  const LogMessage: RawByteString; const ImmediatelyReleasable: IImmediatelyReleasable);
var
  ErrorMessage: RawByteString;
  ErrorCode: Integer;
  ConSettings: PZConSettings;
begin
  if Assigned(MYSQL_STMT) then begin
    ErrorCode := PlainDriver.mysql_stmt_errno(MYSQL_STMT);
    ErrorMessage := {$IFDEF WITH_UNITANSISTRINGS}AnsiStrings.{$ENDIF}Trim(PlainDriver.mysql_stmt_error(MYSQL_STMT));
  end else begin
    ErrorMessage := {$IFDEF WITH_UNITANSISTRINGS}AnsiStrings.{$ENDIF}Trim(PlainDriver.mysql_error(MYSQL));
    ErrorCode := PlainDriver.mysql_errno(MYSQL);
  end;
  if (ErrorCode <> 0) then
  begin
    if (ErrorMessage = '') then
      ErrorMessage := 'unknown error';
    ConSettings := ImmediatelyReleasable.GetConSettings;
    if (ErrorCode = CR_SERVER_GONE_ERROR) or (ErrorCode = CR_SERVER_LOST) then begin
      ImmediatelyReleasable.ReleaseImmediat(ImmediatelyReleasable);
      EZSQLConnectionLost.CreateWithCode(ErrorCode,
      Format(SSQLError1, [ConSettings^.ConvFuncs.ZRawToString(
        ErrorMessage, ConSettings^.ClientCodePage^.CP, ConSettings^.CTRL_CP)]));
    end else begin
      if SilentMySQLError > 0 then
        raise EZMySQLSilentException.CreateFmt(SSQLError1, [ErrorMessage]);

      DriverManager.LogError(LogCategory, ConSettings^.Protocol, LogMessage,
        ErrorCode, ErrorMessage);
      raise EZSQLException.CreateWithCode(ErrorCode,
        Format(SSQLError1, [ConSettings^.ConvFuncs.ZRawToString(
          ErrorMessage, ConSettings^.ClientCodePage^.CP, ConSettings^.CTRL_CP)]));
    end;
  end;
end;

{**
  Decodes a MySQL Version Value encoded with format:
   (major_version * 10,000) + (minor_version * 100) + sub_version
  into separated major, minor and subversion values
  @param MySQLVersion an integer containing the MySQL Full Version to decode.
  @param MajorVersion an integer containing the Major Version decoded.
  @param MinorVersion an integer containing the Minor Version decoded.
  @param SubVersion an integer contaning the Sub Version (revision) decoded.
}
procedure DecodeMySQLVersioning(const MySQLVersion: Integer;
 out MajorVersion: Integer; out MinorVersion: Integer;
 out SubVersion: Integer);
begin
  MajorVersion := MySQLVersion div 10000;
  MinorVersion := (MySQLVersion - (MajorVersion * 10000)) div 100;
  SubVersion   := MySQLVersion-(MajorVersion*10000)-(MinorVersion*100);
end;

{**
  Encodes major, minor and subversion (revision) values in MySQL format:
   (major_version * 10,000) + (minor_version * 100) + sub_version
  For example, 4.1.12 is returned as 40112.
  @param MajorVersion an integer containing the Major Version.
  @param MinorVersion an integer containing the Minor Version.
  @param SubVersion an integer containing the Sub Version (revision).
  @return an integer containing the full version.
}
function EncodeMySQLVersioning(const MajorVersion: Integer;
 const MinorVersion: Integer; const SubVersion: Integer): Integer;
begin
 Result := (MajorVersion * 10000) + (MinorVersion * 100) + SubVersion;
end;

{**
  Decodes a MySQL Version Value and Encodes it to a Zeos SQL Version format:
   (major_version * 1,000,000) + (minor_version * 1,000) + sub_version
  into separated major, minor and subversion values
  So it transforms a version in format XYYZZ to XYYYZZZ where:
   X = major_version
   Y = minor_version
   Z = sub version
  @param MySQLVersion an integer containing the Full MySQL Version to decode.
  @return Encoded Zeos SQL Version Value.
}
function ConvertMySQLVersionToSQLVersion( const MySQLVersion: Integer ): integer;
var
   MajorVersion, MinorVersion, SubVersion: Integer;
begin
 DecodeMySQLVersioning(MySQLVersion,MajorVersion,MinorVersion,SubVersion);
 Result := EncodeSQLVersioning(MajorVersion,MinorVersion,SubVersion);
end;

function getMySQLFieldSize(field_type: TMysqlFieldType; field_size: LongWord): LongWord;
begin
  case field_type of
    FIELD_TYPE_ENUM:        Result := 1;
    FIELD_TYPE_TINY:        Result := 1;
    FIELD_TYPE_SHORT:       Result := 2;
    FIELD_TYPE_LONG:        Result := 4;
    FIELD_TYPE_LONGLONG:    Result := 8;
    FIELD_TYPE_FLOAT:       Result := 4;
    FIELD_TYPE_DOUBLE:      Result := 8;
    FIELD_TYPE_DATE:        Result := sizeOf(TMYSQL_TIME);
    FIELD_TYPE_TIME:        Result := sizeOf(TMYSQL_TIME);
    FIELD_TYPE_DATETIME:    Result := sizeOf(TMYSQL_TIME);
    FIELD_TYPE_TINY_BLOB:   Result := field_size; //stBytes
    FIELD_TYPE_BLOB:        Result := field_size;
    FIELD_TYPE_STRING:      Result := field_size;
  else
    Result := 255;  {unknown ??}
  end;
end;

{**
  Returns a valid TZColumnInfo from a FieldHandle
  @param PlainDriver the MySQL PlainDriver interface
  @param FieldHandle the handle of the fetched field
  @returns a new TZColumnInfo
}
function GetMySQLColumnInfoFromFieldHandle(MYSQL_FIELD: PMYSQL_Field;
  ConSettings: PZConSettings; MySQL_FieldType_Bit_1_IsBoolean:boolean): TZColumnInfo;
var
  FieldLength: ULong;
  function ValueToString(Buf: PAnsiChar; Len: Cardinal): String;
  {$IFNDEF UNICODE}
  var tmp: ZWideString;
  {$ENDIF}
  begin
    if (Buf = nil) or (Buf^ = #0) then
      Result := ''
    else begin
      //EH: mariadb up to 10.3 and old MySQL versions seems to be buggy here so this workaround was made
      //Note the issues happen only if no gui is used?! What? True so it seems to be a performance issue?
      Len := ZFastCode.StrLen(Buf);
      {$IFDEF UNICODE}
      Result := PRawToUnicode(Buf, Len, ConSettings^.ClientCodePage^.CP);
      {$ELSE}
      if (not ConSettings^.AutoEncode) or ZCompatibleCodePages(ConSettings^.ClientCodePage^.CP, ConSettings^.CTRL_CP)
      then System.SetString(Result, Buf, Len)
      else begin
        tmp := PRawToUnicode(Buf, len, ConSettings^.ClientCodePage^.CP);
        Result := ZUnicodeToString(tmp, ConSettings^.CTRL_CP);
      end;
      {$ENDIF}
    end;
  end;
begin
  if Assigned(MYSQL_FIELD) then
  begin
    Result := TZColumnInfo.Create;
    Result.ColumnLabel := ValueToString(MYSQL_FIELD^.name,
      MYSQL_FIELD^.name_length);
    Result.TableName := ValueToString(MYSQL_FIELD^.org_table,
      MYSQL_FIELD^.org_table_length);
    if Result.TableName <> '' then begin
      Result.ColumnName := ValueToString(MYSQL_FIELD^.org_name,
        MYSQL_FIELD^.org_name_length);
      {JDBC maps the MySQL MYSQK_FIELD.db to Catalog:
       see: https://stackoverflow.com/questions/7942520/relationship-between-catalog-schema-user-and-database-instance}
      Result.CatalogName := ValueToString(MYSQL_FIELD^.db,
        MYSQL_FIELD^.db_length);
    end;
    Result.ReadOnly := (MYSQL_FIELD^.org_table = nil) or (MYSQL_FIELD^.org_name = nil);
    Result.Writable := not Result.ReadOnly;
    Result.ColumnType := ConvertMySQLHandleToSQLType(MYSQL_FIELD, ConSettings.CPType, MySQL_FieldType_Bit_1_IsBoolean);
    FieldLength := MYSQL_FIELD^.length;
    //EgonHugeist: arrange the MBCS field DisplayWidth to a proper count of Chars

    if Result.ColumnType in [stString, stUnicodeString, stAsciiStream, stUnicodeStream] then
      Result.ColumnCodePage := ConSettings^.ClientCodePage^.CP
    else
      Result.ColumnCodePage := High(Word);

    if Result.ColumnType in [stString, stUnicodeString] then begin
       Result.CharOctedLength := FieldLength;
       case MYSQL_FIELD^.charsetnr of
        1, 84, {Big5}
        95, 96, {cp932 japanese}
        19, 85, {euckr}
        24, 86, {gb2312}
        38, 87, {gbk}
        13, 88, {sjis}
        35, 90, 128..151:  {ucs2}
          begin
            Result.ColumnDisplaySize := (FieldLength div 4);
            Result.Precision := Result.ColumnDisplaySize;
            if Result.ColumnType = stString then
              Result.CharOctedLength := FieldLength
            else
              Result.CharOctedLength := FieldLength shr 1;
          end;
        33, 83, 192..215, { utf8 }
        97, 98, { eucjpms}
        12, 91: {ujis}
          begin
            Result.ColumnDisplaySize := (FieldLength div 3);
            Result.Precision := Result.ColumnDisplaySize;
            if Result.ColumnType = stString then
              Result.CharOctedLength := FieldLength
            else
              Result.CharOctedLength := Result.ColumnDisplaySize shl 1;
          end;
        54, 55, 101..124, {utf16}
        56, 62, {utf16le}
        60, 61, 160..183, {utf32}
        45, 46, 224..247: {utf8mb4}
          begin
            Result.ColumnDisplaySize := (FieldLength div 4);
            Result.Precision := Result.ColumnDisplaySize;
            if Result.ColumnType = stString then
              Result.CharOctedLength := FieldLength
            else
              Result.CharOctedLength := FieldLength shr 1;
          end;
        else //1-Byte charsets
        begin
          Result.ColumnDisplaySize := FieldLength;
          Result.Precision := FieldLength;
          if Result.ColumnType = stString then
            Result.CharOctedLength := FieldLength
          else
            Result.CharOctedLength := FieldLength shl 1;
        end;
      end
    end else
      Result.Precision := Integer(FieldLength)*Ord(not (MYSQL_FIELD^._type in
        [FIELD_TYPE_BLOB, FIELD_TYPE_TINY_BLOB, FIELD_TYPE_MEDIUM_BLOB, FIELD_TYPE_LONG_BLOB]));
    Result.Scale := MYSQL_FIELD^.decimals;
    Result.AutoIncrement := (AUTO_INCREMENT_FLAG and MYSQL_FIELD^.flags <> 0);// or
      //(TIMESTAMP_FLAG and MYSQL_FIELD^.flags <> 0);
    Result.Signed := (UNSIGNED_FLAG and MYSQL_FIELD^.flags) = 0;
    if NOT_NULL_FLAG and MYSQL_FIELD^.flags <> 0 then
      Result.Nullable := ntNoNulls
    else
      Result.Nullable := ntNullable;
    // Properties not set via query results here will be fetched from table metadata.
  end
  else
    Result := nil;
end;

procedure ConvertMySQLColumnInfoFromString(var TypeName: RawByteString;
  ConSettings: PZConSettings; out TypeInfoSecond: RawByteString;
  out FieldType: TZSQLType; out ColumnSize: Integer; out Scale: Integer;
  MySQL_FieldType_Bit_1_IsBoolean: Boolean);
const
  GeoTypes: array[0..7] of RawByteString = (
   'point','linestring','polygon','geometry',
   'multipoint','multilinestring','multipolygon','geometrycollection'
  );
var
  TempPos: Integer;
  pB, pC: Integer;
  Signed: Boolean;
label SetLobSize, lByte, lWord, lLong, lLongLong;
begin
  TypeInfoSecond := '';
  Scale := 0;
  ColumnSize := 0;

  TypeName := {$IFDEF WITH_UNITANSISTRINGS}AnsiStrings.{$ENDIF}LowerCase(TypeName);
  Signed := (not (ZFastCode.Pos({$IFDEF UNICODE}RawByteString{$ENDIF}('unsigned'), TypeName) > 0));
  pB := ZFastCode.Pos({$IFDEF UNICODE}RawByteString{$ENDIF}('('), TypeName);
  if pB > 0 then begin
    pC := ZFastCode.PosEx({$IFDEF UNICODE}RawByteString{$ENDIF}(')'), TypeName, pB);
    TypeInfoSecond := {$IFDEF WITH_UNITANSISTRINGS}AnsiStrings.{$ENDIF}UpperCase(Copy(TypeName, pB+1, pc-pB-1));
    TypeName := Copy(TypeName, 1, pB-1);
  end;

  { the column type is ENUM}
  if TypeName = 'enum' then begin
    FieldType := stString;
    if not MySQL_FieldType_Bit_1_IsBoolean and ((TypeInfoSecond = '''Y'',''N''') or (TypeInfoSecond = '''N'',''Y''')) then
      FieldType := stBoolean
    else begin
      TempPos := 1;
      while true do begin
        pC := PosEx({$IFDEF UNICODE}RawByteString{$ENDIF}(','), TypeInfoSecond, TempPos);
        if pC > 0 then begin
          TypeInfoSecond[pc] := #0;
          ColumnSize := Max(ColumnSize, ZFastCode.StrLen(@TypeInfoSecond[TempPos])-2);
          //TypeInfoSecond[pc] := ',';
          TempPos := pc+1;
        end else begin
          ColumnSize := Max(ColumnSize, ZFastCode.StrLen(@TypeInfoSecond[TempPos])-2);
          Break;
        end;
      end;
    end
  end else if TypeName = 'set' then begin
    ColumnSize := 255;
    FieldType := stString;
  end else if ZFastCode.Pos({$IFDEF UNICODE}RawByteString{$ENDIF}('int'), TypeName) > 0 then begin
    if StartsWith(TypeName, {$IFDEF UNICODE}RawByteString{$ENDIF}('tiny')) then begin
lByte:
      FieldType := TZSQLType(Ord(stByte)+Ord(Signed));  //0 - 255 or -128 - 127
      ColumnSize := 3+Ord(Signed);
    end else if StartsWith(TypeName, {$IFDEF UNICODE}RawByteString{$ENDIF}('small')) then begin
lWord:
      FieldType := TZSQLType(Ord(stWord)+Ord(Signed));  //0 - 65535 or -32768 - 32767
      ColumnSize := 5+Ord(Signed);
    end else if StartsWith(TypeName, {$IFDEF UNICODE}RawByteString{$ENDIF}('medium')) or
                EndsWith(TypeName, {$IFDEF UNICODE}RawByteString{$ENDIF}('24')) then begin
      FieldType := TZSQLType(Ord(stLongWord)+Ord(Signed)); //0 - 16777215 or -8388608 - 8388607
      ColumnSize := 8;
    end else if StartsWith(TypeName, {$IFDEF UNICODE}RawByteString{$ENDIF}('big')) then begin
lLongLong:
      FieldType := TZSQLType(Ord(stULong)+Ord(Signed)); //0 - 18446744073709551615 or -9223372036854775808 - 922337203685477580
      ColumnSize := 20;
    end else begin//includes INTEGER
lLong:
      FieldType := TZSQLType(Ord(stLongWord)+Ord(Signed));  //0 - 4294967295 or -2147483648 - 2147483647
      ColumnSize := 10+Ord(Signed);
    end;
  end else if TypeName = 'year' then begin
    FieldType := stWord;  //1901 to 2155, and 0000 in the 4 year format and 1970-2069 if you use the 2 digit format (70-69).
    ColumnSize := 4;
  end else if TypeName = 'real' then begin
    FieldType := stFloat
  end else if {(TypeName = 'float') or }(TypeName = 'decimal') {or StartsWith(TypeName, RawByteString('double'))} then begin
    //read careful! http://dev.mysql.com/doc/refman/5.7/en/floating-point-types.html
    if TypeInfoSecond = '' then begin
      FieldType := stDouble;
      ColumnSize := 12;
    end else begin
      pC := ZFastCode.Pos({$IFDEF UNICODE}RawByteString{$ENDIF}(','), TypeInfoSecond);
      if pC > 0 then begin
        TypeInfoSecond[pC] := #0;
        ColumnSize := RawToIntDef(@TypeInfoSecond[1], 0);
        Scale := RawToIntDef(@TypeInfoSecond[pC+1], 0);
        TypeInfoSecond[pC] := ',';
      end;
      if Scale = 0 then
        if ColumnSize < 10 then
          goto lLong
        else
          goto lLongLong
      else {if ColumnSize < 25 then begin
        FieldType := stFloat;
        ColumnSize := 12;
      end else} begin
        FieldType := stDouble;
        ColumnSize := 22;
      end;
    end
  end else if (TypeName = 'float') or StartsWith(TypeName, RawByteString('double')) then begin
    FieldType := stDouble;
    ColumnSize := 22;
  end else if EndsWith(TypeName, RawByteString('char')) then begin //includes 'VARCHAR'
    FieldType := stString;
    ColumnSize := RawToIntDef(TypeInfoSecond, 0);
  end else if EndsWith(TypeName, RawByteString('binary')) then begin //includes 'VARBINARY'
    FieldType := stBytes;
    ColumnSize := RawToIntDef(TypeInfoSecond, 0);
  end else if TypeName = 'date' then begin
    FieldType := stDate;
    ColumnSize := 10;
  end else if TypeName = 'time' then begin
    FieldType := stTime;
    ColumnSize := 8;
  end else if (TypeName = 'timestamp') or (TypeName = 'datetime') then begin
    FieldType := stTimestamp;
    ColumnSize := 19;
  end else if EndsWith(TypeName, RawByteString('blob')) then begin //includes 'TINYBLOB', 'MEDIUMBLOB', 'LONGBLOB'
    FieldType := stBinaryStream;
SetLobSize:
    if StartsWith(TypeName, RawByteString('tiny')) then
      ColumnSize := 255
    else if StartsWith(TypeName, RawByteString('medium')) then
      ColumnSize := 16277215//may be 65535
    else if StartsWith(TypeName, RawByteString('long')) then
      ColumnSize := High(Integer)//2147483657//may be 65535
    else ColumnSize := MAXBUF;
  end else if EndsWith(TypeName, RawByteString('text')) then begin //includes 'TINYTEXT', 'MEDIUMTEXT', 'LONGTEXT'
    FieldType := stAsciiStream;
    goto SetLobSize;
  end else if TypeName = 'bit' then begin //see: http://dev.mysql.com/doc/refman/5.1/en/bit-type.html
    ColumnSize := RawToIntDef(TypeInfoSecond, 1);
    Signed := False;
    case ColumnSize of
      1: if MySQL_FieldType_Bit_1_IsBoolean
         then FieldType := stBoolean
         else goto lByte;
      2..8: goto lByte;
      9..16: goto lWord;
      17..32: goto lLong;
      else goto lLongLong;
    end;
  end else if TypeName = 'json' then
    FieldType := stAsciiStream
  else
    for pC := 0 to High(GeoTypes) do
       if GeoTypes[pC] = TypeName then begin
          FieldType := stBinaryStream;
          Break;
       end;

  case FieldType of
    stString: if ( ConSettings^.CPType = cCP_UTF16) then FieldType := stUnicodeString;
    stAsciiStream: if ( ConSettings^.CPType = cCP_UTF16) then FieldType := stUnicodeStream;
    stUnknown: raise Exception.Create('Unknown MySQL data type!'+String(TypeName));
  end;
end;

function MySQLPrepareAnsiSQLParam(const Connection: IZMySQLConnection;
  const Value: TZVariant; const DefaultValue: String;
  const ClientVarManager: IZClientVariantManager;
  InParamType: TZSQLType; UseDefaults: Boolean): RawByteString;
var
  TempBytes: TBytes;
  TempBlob: IZBlob;
  CharRec: TZCharRec;
  ConSettings: PZConSettings;
  TempVar: TZVariant;
label SetDefaultVal;
begin
  ConSettings := Connection.GetConSettings;
  if ClientVarManager.IsNull(Value) then
SetDefaultVal:
    if UseDefaults and (DefaultValue <> '') then
      Result := ConSettings^.ConvFuncs.ZStringToRaw(DefaultValue,
        ConSettings^.CTRL_CP, ConSettings^.ClientCodePage^.CP)
    else
      Result := 'NULL'
  else
  begin
    case InParamType of
      stBoolean:
        if Connection.MySQL_FieldType_Bit_1_IsBoolean
        then Result := ZSysUtils.BoolStrIntsRaw[ClientVarManager.GetAsBoolean(Value)]
        else if ClientVarManager.GetAsBoolean(Value)
          then Result := '''Y'''
          else Result := '''N''';
      stByte, stShort, stWord, stSmall, stLongWord, stInteger, stULong, stLong,
      stFloat, stDouble, stCurrency, stBigDecimal:
        Result := ClientVarManager.GetAsRawByteString(Value);
      stBytes:
        begin
          TempBytes := ClientVarManager.GetAsBytes(Value);
          Result := GetSQLHexAnsiString(PAnsiChar(TempBytes), Length(TempBytes));
        end;
      stString, stUnicodeString: begin
          ClientVarManager.Assign(Value, TempVar);
          CharRec := ClientVarManager.GetAsCharRec(TempVar, Connection.GetConSettings^.ClientCodePage^.CP);
          Connection.GetEscapeString(CharRec.P, CharRec.Len, Result);
        end;
      stDate:
        Result := DateTimeToRawSQLDate(ClientVarManager.GetAsDateTime(Value),
          ConSettings^.WriteFormatSettings, True);
      stTime:
        Result := DateTimeToRawSQLTime(ClientVarManager.GetAsDateTime(Value),
          ConSettings^.WriteFormatSettings, True);
      stTimestamp:
        Result := DateTimeToRawSQLTimeStamp(ClientVarManager.GetAsDateTime(Value),
          ConSettings^.WriteFormatSettings, True);
      stAsciiStream, stUnicodeStream, stBinaryStream:
        begin
          TempBlob := ClientVarManager.GetAsInterface(Value) as IZBlob;
          if not TempBlob.IsEmpty then
            if InParamType  = stBinaryStream
            then Result := GetSQLHexAnsiString(PAnsichar(TempBlob.GetBuffer), TempBlob.Length)
            else if TempBlob.IsClob then begin
              CharRec.P := TempBlob.GetPAnsiChar(ConSettings^.ClientCodePage^.CP);
              Connection.GetEscapeString(CharRec.P, TempBlob.Length, Result);
            end else
              Result := Connection.EscapeString(GetValidatedAnsiStringFromBuffer(TempBlob.GetBuffer,
                TempBlob.Length, ConSettings))
          else
            goto SetDefaultVal;
        end;
      else
        RaiseUnsupportedParameterTypeException(InParamType);
    end;
  end;
end;

function GetMySQLOptionValue(Option: TMySQLOption): string;
begin
  Result := GetEnumName(TypeInfo(TMySQLOption), Integer(Option));
end;

procedure ReverseBytes(const Src, Dest: Pointer; Len: Byte);
var b: Byte;
  P: PAnsiChar;
begin
  Len := Len -1;
  P := PAnsiChar(Src)+Len;
  for b := Len downto 0 do
    (PAnsiChar(Dest)+B)^ := (P-B)^;
end;

function ReverseWordBytes(Src: Pointer): Word;
begin
  (PAnsiChar(@Result)+1)^ := PAnsiChar(Src)^;
  PAnsiChar(@Result)^ := (PAnsiChar(Src)+1)^;
end;

function ReverseLongWordBytes(Src: Pointer; Len: Byte): LongWord;
begin
  Result := 0;
  ReverseBytes(Src, @Result, Len);
end;

function ReverseQuadWordBytes(Src: Pointer; Len: Byte): UInt64;
begin
  Result := 0;
  ReverseBytes(Src, @Result, Len);
end;

var
  MARIADB_BIND1027_Offset: TMYSQL_BINDOFFSETS;
  MYSQL_BIND51_Offset: TMYSQL_BINDOFFSETS;
  MYSQL_BIND506_Offset: TMYSQL_BINDOFFSETS;
  MYSQL_BIND411_Offset: TMYSQL_BINDOFFSETS;

function GetBindOffsets(IsMariaDB: Boolean; Version: Integer): PMYSQL_BINDOFFSETS;
begin
  if IsMariaDB and (Version >= 100207) then
    result := @MARIADB_BIND1027_Offset
  else if (Version >= 50100) or IsMariaDB {they start with 100000} then
    result := @MYSQL_BIND51_Offset
  else if (Version >= 50006) then
    Result := @MYSQL_BIND506_Offset
  else if (Version >= 40101) then
    Result := @MYSQL_BIND411_Offset
  else Result := nil
end;

procedure AllocMySQLBindBuffer(var BindBuffer: Pointer;
  var MYSQL_aligned_BINDs: PMYSQL_aligned_BINDs; BindOffsets: PMYSQL_BINDOFFSETS;
  BindCount, Iterations: ULong);
var
  ColOffset: NativeUInt;
  Bind: PMYSQL_aligned_BIND;
  I: Integer;
begin
  if BindCount = 0 then
    Exit;
  GetMem(BindBuffer, BindCount*BindOffsets.Size);
  FillChar(BindBuffer^, BindCount*BindOffsets.Size, {$IFDEF Use_FastCodeFillChar}#0{$ELSE}0{$ENDIF});
  GetMem(MYSQL_aligned_BINDs, BindCount*SizeOf(TMYSQL_aligned_BIND));
  FillChar(MYSQL_aligned_BINDs^, BindCount*SizeOf(TMYSQL_aligned_BIND), {$IFDEF Use_FastCodeFillChar}#0{$ELSE}0{$ENDIF});
  for i := 0 to BindCount-1 do begin
    {$R-}
    Bind := @MYSQL_aligned_BINDs[I];
    {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
//    FillChar(Bind^, SizeOf(TMYSQL_aligned_BIND), {$IFDEF Use_FastCodeFillChar}#0{$ELSE}0{$ENDIF});
    ColOffset := NativeUInt(I*BindOffsets.size);
    { save mysql bind offset fo mysql_stmt_fetch_column }
    Bind^.mysql_bind := {%H-}Pointer(NativeUInt(BindBuffer)+ColOffset);
    { save aligned addresses }
    bind^.buffer_address := {%H-}Pointer(NativeUInt(BindBuffer)+ColOffset+BindOffsets.buffer);
    Bind^.buffer_type_address := {%H-}Pointer(NativeUInt(BindBuffer)+ColOffset+BindOffsets.buffer_type);
    Bind^.is_unsigned_address := {%H-}Pointer(NativeUInt(BindBuffer)+ColOffset+BindOffsets.is_unsigned);
    Bind^.buffer_length_address := {%H-}Pointer(NativeUInt(BindBuffer)+ColOffset+BindOffsets.buffer_length);
    Bind^.length_address := {%H-}Pointer(NativeUInt(BindBuffer)+ColOffset+BindOffsets.length);
    GetMem(Bind^.length, Iterations*SizeOf(ULong));
    FillChar(Bind^.length^, Iterations*SizeOf(ULong), {$IFDEF Use_FastCodeFillChar}#0{$ELSE}0{$ENDIF});
    Bind^.length_address^ := Pointer(Bind^.length);
    GetMem(Bind^.is_null, Iterations*SizeOf(my_bool));
    FillChar(Bind^.is_null^, Iterations*SizeOf(my_bool), {$IFDEF Use_FastCodeFillChar}#0{$ELSE}0{$ENDIF});
    {%H-}PPointer(NativeUInt(BindBuffer)+ColOffset+BindOffsets.is_null)^ := Pointer(Bind^.is_null);
    if (BindOffsets.Indicator > 0) then begin
      Bind^.indicator_address := {%H-}Pointer(NativeUInt(BindBuffer)+ColOffset+BindOffsets.Indicator);
      if Iterations > 0 then begin
        GetMem(Bind^.indicators, Iterations*SizeOf(TIndicator));
        FillChar(Bind^.indicators^, Iterations*SizeOf(TIndicator), {$IFDEF Use_FastCodeFillChar}#0{$ELSE}0{$ENDIF});
        Bind^.indicator_address^ := Pointer(Bind^.indicators);
      end;
    end else if Iterations > 1 then
      raise EZSQLException.Create('Array bindings are not supported!');
  end;
end;

procedure FreeMySQLBindBuffer(var BindBuffer: Pointer;
  var MYSQL_aligned_BINDs: PMYSQL_aligned_BINDs; BindOffsets: PMYSQL_BINDOFFSETS;
  BoundCount: ULong);
var
  Bind: PMYSQL_aligned_BIND;
  I: Integer;
begin
  FreeMem(BindBuffer);
  BindBuffer := nil;
  if (MYSQL_aligned_BINDs <> nil) and (BoundCount > 0) then begin
    for i := BoundCount-1 downto 0 do begin
      {$R-}
      Bind := @MYSQL_aligned_BINDs[I];
      {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
      FreeMem(Bind^.buffer);
      FreeMem(Bind^.length);
      FreeMem(Bind^.indicators);
      FreeMem(Bind^.is_null);
    end;
    FreeMem(MYSQL_aligned_BINDs);
    MYSQL_aligned_BINDs := nil;
  end;
end;

initialization
  with MARIADB_BIND1027_Offset do begin
    buffer_type   := {%H-}NativeUint(@(PMARIADB_BIND1027(nil).buffer_type));
    buffer_length := {%H-}NativeUint(@(PMARIADB_BIND1027(nil).buffer_length));
    is_unsigned   := {%H-}NativeUint(@(PMARIADB_BIND1027(nil).is_unsigned));
    buffer        := {%H-}NativeUint(@(PMARIADB_BIND1027(nil).buffer));
    length        := {%H-}NativeUint(@(PMARIADB_BIND1027(nil).length));
    is_null       := {%H-}NativeUint(@(PMARIADB_BIND1027(nil).is_null));
    Indicator     := {%H-}NativeUint(@(PMARIADB_BIND1027(nil).u.indicator));
    size          := Sizeof(TMARIADB_BIND1027);
  end;
  with MYSQL_BIND51_Offset do begin
    buffer_type   := {%H-}NativeUint(@(PMYSQL_BIND51(nil).buffer_type));
    buffer_length := {%H-}NativeUint(@(PMYSQL_BIND51(nil).buffer_length));
    is_unsigned   := {%H-}NativeUint(@(PMYSQL_BIND51(nil).is_unsigned));
    buffer        := {%H-}NativeUint(@(PMYSQL_BIND51(nil).buffer));
    length        := {%H-}NativeUint(@(PMYSQL_BIND51(nil).length));
    is_null       := {%H-}NativeUint(@(PMYSQL_BIND51(nil).is_null));
    Indicator     := 0;
    size          := Sizeof(TMYSQL_BIND51);
  end;
  with MYSQL_BIND506_Offset do begin
    buffer_type   := {%H-}NativeUint(@(PMYSQL_BIND506(nil).buffer_type));
    buffer_length := {%H-}NativeUint(@(PMYSQL_BIND506(nil).buffer_length));
    is_unsigned   := {%H-}NativeUint(@(PMYSQL_BIND506(nil).is_unsigned));
    buffer        := {%H-}NativeUint(@(PMYSQL_BIND506(nil).buffer));
    length        := {%H-}NativeUint(@(PMYSQL_BIND506(nil).length));
    is_null       := {%H-}NativeUint(@(PMYSQL_BIND506(nil).is_null));
    Indicator     := 0;
    size          := Sizeof(PMYSQL_BIND506);
  end;
  with MYSQL_BIND411_Offset do begin
    buffer_type   := {%H-}NativeUint(@(PMYSQL_BIND411(nil).buffer_type));
    buffer_length := {%H-}NativeUint(@(PMYSQL_BIND411(nil).buffer_length));
    is_unsigned   := {%H-}NativeUint(@(PMYSQL_BIND411(nil).is_unsigned));
    buffer        := {%H-}NativeUint(@(PMYSQL_BIND411(nil).buffer));
    length        := {%H-}NativeUint(@(PMYSQL_BIND411(nil).length));
    is_null       := {%H-}NativeUint(@(PMYSQL_BIND411(nil).is_null));
    Indicator     := 0;
    size          := Sizeof(TMYSQL_BIND411);
  end;

end.
