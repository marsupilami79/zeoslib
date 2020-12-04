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
{   https://zeoslib.sourceforge.io/ (FORUM)               }
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

{$IFNDEF ZEOS_DISABLE_MYSQL} //if set we have an empty unit
uses
  Classes, {$IFDEF MSEgui}mclasses,{$ENDIF} SysUtils,
  ZSysUtils, ZDbcIntfs, ZPlainMySqlDriver, ZDbcLogging, ZCompatibility,
  ZDbcResultSetMetadata, ZVariant;

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
  FieldOffsets: PMYSQL_FIELDOFFSETS; MySQL_FieldType_Bit_1_IsBoolean: Boolean): TZSQLType;

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

{**
  Returns a valid TZColumnInfo from a FieldHandle
  @param PlainDriver the MySQL PlainDriver interface
  @param FieldHandle the handle of the fetched field
  @returns a new TZColumnInfo
}
function GetMySQLColumnInfoFromFieldHandle(MYSQL_FIELD: PMYSQL_FIELD; FieldOffsets: PMYSQL_FIELDOFFSETS;
  ConSettings: PZConSettings; MySQL_FieldType_Bit_1_IsBoolean: boolean): TZColumnInfo;

procedure ConvertMySQLColumnInfoFromString(var TypeName: RawByteString;
  out TypeInfoSecond: RawByteString;
  out FieldType: TZSQLType; out ColumnSize: Integer; out Scale: Integer;
  MySQL_FieldType_Bit_1_IsBoolean: Boolean);

function GetMySQLOptionValue(Option: TMySQLOption): string;

function ReverseWordBytes(Src: Pointer): Word;
function ReverseLongWordBytes(Src: Pointer; Len: Byte): LongWord;
function ReverseQuadWordBytes(Src: Pointer; Len: Byte): UInt64;

type
  // offsets to used MYSQL_BINDxx members. Filled by GetBindOffsets
  PMYSQL_BINDOFFSETS = ^TMYSQL_BINDOFFSETS;
  TMYSQL_BINDOFFSETS = record
    buffer_type   :NativeUint;
    buffer_length :NativeUint;
    is_unsigned   :NativeUint;
    buffer        :NativeUint;
    length        :NativeUint;
    is_null       :NativeUint;
    Indicator     :NativeUint;
    size          :word;    //size of MYSQL_BINDxx
  end;

  PMYSQL_aligned_BIND = ^TMYSQL_aligned_BIND;
  TMYSQL_aligned_BIND = record
    buffer:                 Pointer; //data place holder
    buffer_address:         PPointer; //we don't need reserved mem at all, but we need to set the address
    buffer_type_address:    PMysqlFieldType;
    buffer_length_address:  PULong; //address of result buffer length
    length_address:         PPointer;
    length:                 PULongArray; //current length of our or bound data
    is_null_address:        Pmy_bool; //adress of is_null -> the field should be used
    is_null:                my_bool; //null indicator -> do not attach directly -> out params are referenced to stmt bindings
    is_unsigned_address:    Pmy_bool; //signed ordinals or not?
    //https://mariadb.com/kb/en/library/bulk-insert-column-wise-binding/
    indicators:             Pmysql_indicator_types; //stmt indicators for bulk bulk ops -> mariadb addresses to "u" and does not use the C-enum
    indicator_address:      PPointer;
    decimals:               Integer; //count of decimal digits for rounding the doubles
    binary:                 Boolean; //binary field or not? Just for reading!
    mysql_bind:             Pointer; //Save exact address of bind for lob reading /is used also on writting 4 the lob-buffer-address
    Iterations:             ULong; //save count of array-Bindings to prevent reallocs for Length and Is_Null-Arrays
  end;
  PMYSQL_aligned_BINDs = ^TMYSQL_aligned_BINDs;
  TMYSQL_aligned_BINDs = array[0..High(Byte)] of TMYSQL_aligned_BIND; //just 4 debugging

  {** implements a struct to hold the mysql column bindings
  EH: LibMySql is scribling in ColumnBindings even if mysql_stmt_free_result() was called
    LibMariaDB doesn't show this terrible behavior
    so i localize the column buffers in stmt and not in the ResultSet
    findings did happen with old d7 on TZTestCompMySQLBugReport.Test727373
    the newer delphi's have fastmm4 which deallocates the memory a bit later
    so this behavior was invisible
  }
  PMYSQL_ColumnsBinding = ^TMYSQL_ColumnsBinding;
  TMYSQL_ColumnsBinding = record
    FieldCount: NativeUInt;
    MYSQL_Col_BINDs: Pointer;
    MYSQL_aligned_BINDs: PMYSQL_aligned_BINDs;
  end;
  PMYSQL_ColumnsBindingArray = ^TMYSQL_ColumnsBindingArray;
  TMYSQL_ColumnsBindingArray = array[0..0] of TMYSQL_ColumnsBinding;//just a debug range usually we obtain just one result

procedure ReallocBindBuffer(var BindBuffer: Pointer;
  var MYSQL_aligned_BINDs: PMYSQL_aligned_BINDs; BindOffsets: PMYSQL_BINDOFFSETS;
  OldCount, NewCount: Integer; Iterations: ULong);

procedure ReAllocMySQLColumnBuffer(OldRSCount, NewRSCount: Integer;
  var ColumnsBindingArray: PMYSQL_ColumnsBindingArray; BindOffset: PMYSQL_BINDOFFSETS);

function GetBindOffsets(IsMariaDB: Boolean; Version: Integer): PMYSQL_BINDOFFSETS;
function GetFieldOffsets(Version: Integer): PMYSQL_FIELDOFFSETS;
function GetServerStatusOffset(Version: Integer): NativeUInt;

{$ENDIF ZEOS_DISABLE_MYSQL} //if set we have an empty unit
implementation
{$IFNDEF ZEOS_DISABLE_MYSQL} //if set we have an empty unit

uses {$IFDEF WITH_UNITANSISTRINGS}AnsiStrings,{$ENDIF}
  Math, TypInfo,
  ZMessages, ZDbcUtils, ZFastCode, ZEncoding;

{**
  Converts a MySQL native types into ZDBC SQL types.
  @param PlainDriver a native MySQL plain driver.
  @param FieldHandle a handler to field description structure.
  @param FieldFlags a field flags.
  @return a SQL undepended type.
}
{$IFDEF FPC} {$PUSH}
  {$WARN 4055 off : Conversion between ordinals and pointers is not portable}
  {$WARN 4079 off : Convering the operants to "Int64" before doing the add could prevent overflow errors}
{$ENDIF} // uses pointer maths
function ConvertMySQLHandleToSQLType(MYSQL_FIELD: PMYSQL_FIELD;
  FieldOffsets: PMYSQL_FIELDOFFSETS; MySQL_FieldType_Bit_1_IsBoolean: Boolean): TZSQLType;
var PrecOrLen: ULong;
begin
  case PMysqlFieldType(NativeUInt(MYSQL_FIELD)+FieldOffsets._type)^ of
    FIELD_TYPE_TINY:
      if PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.flags)^ and UNSIGNED_FLAG = 0
      then Result := stShort
      else Result := stByte;
    FIELD_TYPE_YEAR:
      Result := stWord;
    FIELD_TYPE_SHORT:
      if PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.flags)^ and UNSIGNED_FLAG = 0
      then Result := stSmall
      else Result := stWord;
    FIELD_TYPE_INT24, FIELD_TYPE_LONG:
      if PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.flags)^ and UNSIGNED_FLAG = 0
      then Result := stInteger
      else Result := stLongWord;
    FIELD_TYPE_LONGLONG:
      if PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.flags)^ and UNSIGNED_FLAG = 0
      then Result := stLong
      else Result := stULong;
    FIELD_TYPE_FLOAT, FIELD_TYPE_DOUBLE:
      Result := stDouble;
    FIELD_TYPE_DECIMAL, FIELD_TYPE_NEWDECIMAL: {ADDED FIELD_TYPE_NEWDECIMAL by fduenas 20-06-2006}
      if (FieldOffsets.decimals > 0) then begin
        PrecOrLen := PULong(NativeUInt(MYSQL_FIELD)+FieldOffsets.length)^;
        if (PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.decimals)^ = 0) then
          if PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.flags)^ and UNSIGNED_FLAG = 0 then begin
            if PrecOrLen <= 2 then
              Result := stShort
            else if PrecOrLen <= 4 then
              Result := stSmall
            else if PrecOrLen <= 9 then
              Result := stInteger
            else if PrecOrLen <= 18 then
              Result := stLong
            else Result := stBigDecimal;
          end else begin
            if PrecOrLen <= 3 then
              Result := stByte
            else if PrecOrLen <= 5 then
              Result := stWord
            else if PrecOrLen <= 10 then
              Result := stLongWord
            else if PrecOrLen <= 19 then
              Result := stULong
            else Result := stBigDecimal;
          end
        else begin
          Dec(PrecOrLen, 1+Byte(PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.flags)^ and UNSIGNED_FLAG = 0)); //one digit for the decimal sep and one for the sign
          if (PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.decimals)^ <= 4) and
             (PrecOrLen < ULong(sAlignCurrencyScale2Precision[PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.decimals)^]))
            then Result := stCurrency
            else Result := stBigDecimal
          end;
      end else
        Result := stDouble;
    FIELD_TYPE_DATE, FIELD_TYPE_NEWDATE:
      Result := stDate;
    FIELD_TYPE_TIME:
      Result := stTime;
    FIELD_TYPE_DATETIME, FIELD_TYPE_TIMESTAMP:
      Result := stTimestamp;
    MYSQL_TYPE_JSON: Result := stAsciiStream;
    FIELD_TYPE_TINY_BLOB:
      if ((FieldOffsets.charsetnr > 0) and ((PUInt(NativeUInt(MYSQL_FIELD)+NativeUInt(FieldOffsets.charsetnr))^ <> 63{binary}) or (PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.flags)^ and BINARY_FLAG = 0))) or
         ((FieldOffsets.charsetnr < 0) and (PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.flags)^ and BINARY_FLAG = 0))
        then Result := stString
        else Result := stBytes;
    FIELD_TYPE_MEDIUM_BLOB,
    FIELD_TYPE_LONG_BLOB, FIELD_TYPE_BLOB:
      if ((FieldOffsets.charsetnr > 0) and ((PUInt(NativeUInt(MYSQL_FIELD)+NativeUInt(FieldOffsets.charsetnr))^ <> 63{binary}) or (PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.flags)^ and BINARY_FLAG = 0))) or
         ((FieldOffsets.charsetnr < 0) and (PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.flags)^ and BINARY_FLAG = 0))
        then Result := stAsciiStream
        else Result := stBinaryStream;
    FIELD_TYPE_BIT: //http://dev.mysql.com/doc/refman/5.1/en/bit-type.html
      case PULong(NativeUInt(MYSQL_FIELD)+FieldOffsets.length)^ of
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
      if (PULong(NativeUInt(MYSQL_FIELD)+FieldOffsets.length)^ = 0) or //handle null columns: select null union null
        ((FieldOffsets.charsetnr > 0) and ((PUInt(NativeUInt(MYSQL_FIELD)+NativeUInt(FieldOffsets.charsetnr))^ <> 63{binary}) or (PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.flags)^ and BINARY_FLAG = 0))) or
          ((FieldOffsets.charsetnr < 0) and (PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.flags)^ and BINARY_FLAG = 0))
        then Result := stString
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
{$IFDEF FPC} {$POP} {$ENDIF}

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

{**
  Returns a valid TZColumnInfo from a FieldHandle
  @param PlainDriver the MySQL PlainDriver interface
  @param FieldHandle the handle of the fetched field
  @returns a new TZColumnInfo
}
{$IFDEF FPC} {$PUSH} {$WARN 4055 off : Conversion between ordinals and pointers is not portable} {$ENDIF} // uses pointer maths
function GetMySQLColumnInfoFromFieldHandle(MYSQL_FIELD: PMYSQL_Field;
  FieldOffsets: PMYSQL_FIELDOFFSETS; ConSettings: PZConSettings;
  MySQL_FieldType_Bit_1_IsBoolean:boolean): TZColumnInfo;
var
  FieldLength: ULong;
  CS: Word;
  function ValueToString(Buf: PAnsiChar; Len: Cardinal): String;
  begin
    if (Buf = nil) or (AnsiChar(Buf^) = AnsiChar(#0)) then
      Result := ''
    else begin
      {$IFDEF UNICODE}
      Result := PRawToUnicode(Buf, Len, ConSettings^.ClientCodePage^.CP);
      {$ELSE}
      Result := '';
      System.SetString(Result, Buf, Len)
      {$ENDIF}
    end;
  end;
begin
  if Assigned(MYSQL_FIELD) then
  begin
    Result := TZColumnInfo.Create;
    //note calling a SP with multiple results -> mySQL&mariaDB returning wrong lengthes!
    //see test bugreport.TZTestCompMySQLBugReport.TestTicket186_MultipleResults
    //so we're calling strlen in all cases to have a common behavior!
    {if FieldOffsets.name > 0
    then Result.ColumnLabel := ValueToString(PPAnsichar(NativeUInt(MYSQL_FIELD)+FieldOffsets.name)^, PUint(NativeUInt(MYSQL_FIELD)+NativeUInt(FieldOffsets.name_length))^)
    else} Result.ColumnLabel := ValueToString(PPAnsichar(NativeUInt(MYSQL_FIELD)+FieldOffsets.name)^, StrLen(PPAnsichar(NativeUInt(MYSQL_FIELD)+FieldOffsets.name)^));
    if (FieldOffsets.org_table > 0)
    then {Result.TableName := ValueToString(PPAnsichar(NativeUInt(MYSQL_FIELD)+NativeUInt(FieldOffsets.org_table))^, PUint(NativeUInt(MYSQL_FIELD)+NativeUInt(FieldOffsets.org_table_length))^)
    else }Result.TableName := ValueToString(PPAnsichar(NativeUInt(MYSQL_FIELD)+NativeUInt(FieldOffsets.org_table))^, StrLen(PPAnsichar(NativeUInt(MYSQL_FIELD)+NativeUInt(FieldOffsets.org_table))^));
    if (Result.TableName <> '') then begin
      if FieldOffsets.org_name > 0
      then {Result.ColumnName := ValueToString(PPAnsichar(NativeUInt(MYSQL_FIELD)+NativeUInt(FieldOffsets.org_name))^, PUint(NativeUInt(MYSQL_FIELD)+NativeUInt(FieldOffsets.org_name_length))^)
      else} Result.ColumnName := ValueToString(PPAnsichar(NativeUInt(MYSQL_FIELD)+NativeUInt(FieldOffsets.org_name))^, StrLen(PPAnsichar(NativeUInt(MYSQL_FIELD)+NativeUInt(FieldOffsets.org_name))^));
      {JDBC maps the MySQL MYSQK_FIELD.db to Catalog:
       see: https://stackoverflow.com/questions/7942520/relationship-between-catalog-schema-user-and-database-instance}
      if FieldOffsets.db_length > 0
      then {Result.CatalogName := ValueToString(PPAnsichar(NativeUInt(PAnsichar(MYSQL_FIELD)+FieldOffsets.db))^, PUint(NativeUInt(MYSQL_FIELD)+NativeUInt(FieldOffsets.db_length))^)
      else }Result.CatalogName := ValueToString(PPAnsichar(NativeUInt(PAnsichar(MYSQL_FIELD)+FieldOffsets.db))^, StrLen(PPAnsichar(NativeUInt(PAnsichar(MYSQL_FIELD)+FieldOffsets.db))^));
    end;
    Result.ReadOnly := (FieldOffsets.org_table <0) or (Result.TableName = '') or (Result.ColumnName = '');
    Result.Writable := not Result.ReadOnly;
    Result.ColumnType := ConvertMySQLHandleToSQLType(MYSQL_FIELD, FieldOffsets, MySQL_FieldType_Bit_1_IsBoolean);
    if PMysqlFieldType(NativeUInt(MYSQL_FIELD)+FieldOffsets._type)^ = FIELD_TYPE_TINY_BLOB
    then FieldLength := 255
    else FieldLength := PULong(NativeUInt(MYSQL_FIELD)+FieldOffsets.length)^;
    //EgonHugeist: arrange the MBCS field DisplayWidth to a proper count of Chars

    if Result.ColumnType in [stString, stUnicodeString, stAsciiStream, stUnicodeStream]
    then Result.ColumnCodePage := ConSettings^.ClientCodePage^.CP
    else Result.ColumnCodePage := High(Word);

    Result.Signed := (PMysqlFieldType(NativeUInt(MYSQL_FIELD)+FieldOffsets._type)^ <> FIELD_TYPE_VAR_STRING) and
       ((UNSIGNED_FLAG and PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.flags)^) = 0);
    if Result.ColumnType in [stString, stUnicodeString] then begin
       Result.CharOctedLength := FieldLength;
       if FieldOffsets.charsetnr > 0
       then CS := PUInt(NativeUInt(MYSQL_FIELD)+NativeUInt(FieldOffsets.charsetnr))^
       else CS := ConSettings^.ClientCodePage^.ID;
       case CS of
        1, 84, {Big5}
        95, 96, {cp932 japanese}
        19, 85, {euckr}
        24, 86, {gb2312}
        38, 87, {gbk}
        13, 88, {sjis}
        35, 90, 128..151:  {ucs2}
          begin
            Result.Precision := (FieldLength shr 2);
            if Result.ColumnType = stString
            then Result.CharOctedLength := FieldLength
            else Result.CharOctedLength := FieldLength shr 1;
          end;
        33, 83, 192..215, { utf8 }
        97, 98, { eucjpms}
        12, 91: {ujis}
          begin
            Result.Precision := (FieldLength div 3);
            if Result.ColumnType = stString
            then Result.CharOctedLength := FieldLength
            else Result.CharOctedLength := Result.Precision shl 1;
          end;
        54, 55, 101..124, {utf16}
        56, 62, {utf16le}
        60, 61, 160..183, {utf32}
        45, 46, 224..247, 255: {utf8mb4}
          begin
            Result.Precision := (FieldLength shr 2);
            if Result.ColumnType = stString
            then Result.CharOctedLength := FieldLength
            else Result.CharOctedLength := FieldLength shr 1;
          end;
        else begin //1-Byte charsets
          Result.Precision := FieldLength;
          if Result.ColumnType = stString
          then Result.CharOctedLength := FieldLength
          else Result.CharOctedLength := FieldLength shl 1;
        end;
      end
    end else if Result.ColumnType in [stCurrency, stBigDecimal]
    then Result.Precision := Integer(FieldLength) - 1 - Ord(Result.Signed)
    else Result.Precision := Integer(FieldLength)*Ord(not (PMysqlFieldType(NativeUInt(MYSQL_FIELD)+FieldOffsets._type)^ in
        [FIELD_TYPE_BLOB, FIELD_TYPE_TINY_BLOB, FIELD_TYPE_MEDIUM_BLOB, FIELD_TYPE_LONG_BLOB, FIELD_TYPE_GEOMETRY]));
    Result.Scale := PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.decimals)^;
    Result.AutoIncrement := (AUTO_INCREMENT_FLAG and PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.flags)^ <> 0);// or
      //(TIMESTAMP_FLAG and MYSQL_FIELD.flags <> 0);
    if NOT_NULL_FLAG and PUInt(NativeUInt(MYSQL_FIELD)+FieldOffsets.flags)^ <> 0
    then Result.Nullable := ntNoNulls
    else Result.Nullable := ntNullable;
    // Properties not set via query results here will be fetched from table metadata.
  end
  else
    Result := nil;
end;
{$IFDEF FPC} {$POP} {$ENDIF} // uses pointer maths

procedure ConvertMySQLColumnInfoFromString(var TypeName: RawByteString;
  out TypeInfoSecond: RawByteString;
  out FieldType: TZSQLType; out ColumnSize: Integer; out Scale: Integer;
  MySQL_FieldType_Bit_1_IsBoolean: Boolean);
const
  GeoTypes: array[0..7] of RawByteString = (
   'point','linestring','polygon','geometry',
   'multipoint','multilinestring','multipolygon','geometrycollection'
  );
var
  Len: Integer;
  pB, pC: Integer;
  Signed: Boolean;
  P: PAnsiChar;
  function CreateFailException: EZSQLException;
  begin
    Result := EZSQLException.Create('Unknown MySQL data type! '+String(TypeName))
  end;
label SetLobSize, lByte, lWord, lLong, lLongLong, SetTimeScale, SetVarScale;
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
      P := Pointer(TypeInfoSecond);
      Len := Length(TypeInfoSecond);
      while PByte(P)^ <> 0 do begin
        pc := PosEx({$IFDEF UNICODE}RawByteString{$ENDIF}(','), P, Len, 1);
        if pc = 0 then begin
          ColumnSize := Max(ColumnSize, ZFastCode.StrLen(P)-2);
          Break;
        end else
          ColumnSize := Max(ColumnSize, (pc-3));
        Inc(P, pc);
      end;
    end
  end else if TypeName = 'set' then begin
    ColumnSize := 255;
    FieldType := stString;
  end else if not StartsWith(TypeName, {$IFDEF UNICODE}RawByteString{$ENDIF}('po')) and  //exclude "point" type
    (ZFastCode.Pos({$IFDEF UNICODE}RawByteString{$ENDIF}('int'), TypeName) > 0) then begin
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
        P := Pointer(TypeInfoSecond);
        ColumnSize := RawToIntDef(P, P+pC-1, 0);
        Scale := RawToIntDef(P+pC, 0);
      end;
      if Scale = 0 then
        if ColumnSize < 10
        then goto lLong
        else goto lLongLong
      else if (Scale <= 4) and (ColumnSize < sAlignCurrencyScale2Precision[Scale])
        then FieldType := stCurrency
        else FieldType := stBigDecimal
    end
  end else if (TypeName = 'float') or StartsWith(TypeName, RawByteString('double')) then begin
    FieldType := stDouble;
    ColumnSize := 22;
  end else if EndsWith(TypeName, RawByteString('char')) then begin //includes 'VARCHAR'
    FieldType := stString;
    goto SetVarScale;
  end else if EndsWith(TypeName, RawByteString('binary')) then begin //includes 'VARBINARY'
    FieldType := stBytes;
SetVarScale:
    ColumnSize := RawToIntDef(TypeInfoSecond, 0);
    if not StartsWith(TypeName, RawByteString('var')) then
      Scale := ColumnSize; //tag fixed size
  end else if TypeName = 'date' then begin
    FieldType := stDate;
    ColumnSize := 10;
  end else if TypeName = 'time' then begin
    FieldType := stTime;
    ColumnSize := 10; //MySQL hour range is from -838 to 838 so we add two digits (one for sign and 1 to hour)
    goto SetTimeScale;
  end else if (TypeName = 'timestamp') or (TypeName = 'datetime') then begin
    FieldType := stTimestamp;
    ColumnSize := 19;
SetTimeScale:
    Scale := RawToIntDef(TypeInfoSecond, 0);
    if Scale > 0 then
      ColumnSize := ColumnSize + 1{Dot}+Scale;
  end else if EndsWith(TypeName, RawByteString('blob')) then begin //includes 'TINYBLOB', 'MEDIUMBLOB', 'LONGBLOB'
    FieldType := stBinaryStream;
SetLobSize:
    if StartsWith(TypeName, RawByteString('tiny')) then begin
      FieldType := TZSQLType(Byte(FieldType)-3); //move down to string by default
      ColumnSize := 255
    end else if StartsWith(TypeName, RawByteString('medium')) then
      ColumnSize := 16277215
    else if StartsWith(TypeName, RawByteString('long')) then
      ColumnSize := High(Integer)//usually high cardinal ->4294967295
    else ColumnSize := 65535; //no suffix found use default high Word size
  end else if EndsWith(TypeName, RawByteString('text')) then begin//includes 'TINYTEXT', 'MEDIUMTEXT', 'LONGTEXT'
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
  end else if TypeName = 'json' then  { test it ..}
    FieldType := stAsciiStream
  else
    for pC := 0 to High(GeoTypes) do
       if GeoTypes[pC] = TypeName then begin
          FieldType := stBinaryStream;
          Break;
       end;

  if FieldType = stUnknown then
    raise CreateFailException;
end;

function GetMySQLOptionValue(Option: TMySQLOption): string;
begin
  Result := GetEnumName(TypeInfo(TMySQLOption), Integer(Option));
end;

procedure ReverseBytes(const Src, Dest: Pointer; Len: Byte);
var b: Byte;
  P: PAnsiChar;
begin
  P := PAnsiChar(Src)+Len-1;
  for b := Len-1 downto 0 do
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

{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R-}{$IFEND}
function ReverseQuadWordBytes(Src: Pointer; Len: Byte): UInt64;
begin
  Result := 0;
  ReverseBytes(Src, @Result, Len);
end;
{$IF defined (RangeCheckEnabled) and defined(WITH_UINT64_C1118_ERROR)}{$R+}{$IFEND}

var
  MARIADB_BIND1027_Offset: TMYSQL_BINDOFFSETS;
  MYSQL_BIND51_Offset: TMYSQL_BINDOFFSETS;
  MYSQL_BIND506_Offset: TMYSQL_BINDOFFSETS;
  MYSQL_BIND411_Offset: TMYSQL_BINDOFFSETS;

  MYSQL_FIELD51_Offset: TMYSQL_FIELDOFFSETS;
  MYSQL_FIELD41_Offset: TMYSQL_FIELDOFFSETS;
  MYSQL_FIELD401_Offset: TMYSQL_FIELDOFFSETS;
  MYSQL_FIELD4_Offset: TMYSQL_FIELDOFFSETS;
  MYSQL_FIELD32_Offset: TMYSQL_FIELDOFFSETS;

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

function GetFieldOffsets(Version: Integer): PMYSQL_FIELDOFFSETS;
begin
  if (Version >= 50100) then
    result := @MYSQL_FIELD51_Offset
  else if (Version >= 40100) then
    Result := @MYSQL_FIELD41_Offset
  else if (Version >= 40001) then
    Result := @MYSQL_FIELD401_Offset
  else if (Version >= 40000) then
    Result := @MYSQL_FIELD4_Offset
  else Result := @MYSQL_FIELD32_Offset
end;

function GetServerStatusOffset(Version: Integer): NativeUInt;
begin
  if (Version >= 50000) then
    result := MYSQL5up_server_status_offset
  else if (Version >= 40100) then
    Result := MYSQL41_server_status_offset
  else
    Result := MYSQL323_server_status_offset
end;

{$IFDEF FPC} {$PUSH} {$WARN 4055 off : Conversion between ordinals and pointers is not portable} {$ENDIF} // uses pointer maths
procedure ReallocBindBuffer(var BindBuffer: Pointer;
  var MYSQL_aligned_BINDs: PMYSQL_aligned_BINDs; BindOffsets: PMYSQL_BINDOFFSETS;
  OldCount, NewCount: Integer; Iterations: ULong);
var
  I: Integer;
  Bind: PMYSQL_aligned_BIND;
  ColOffset: NativeUInt;
begin
  {first clean mem of binds we don't need any more}
  if MYSQL_aligned_BINDs <> nil then
    for i := OldCount-1 downto NewCount do begin
      {$R-}
      Bind := @MYSQL_aligned_BINDs[I];
      {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
      if Bind^.buffer <> nil then
        FreeMem(Bind^.buffer);
      if Bind^.Length <> nil then
        FreeMem(Bind^.length);
      if Bind^.Indicators <> nil then
        FreeMem(Bind^.Indicators);
    end;
  ReallocMem(BindBuffer, NewCount*BindOffsets.Size);
  ReallocMem(MYSQL_aligned_BINDs, NewCount*SizeOf(TMYSQL_aligned_BIND));
  if MYSQL_aligned_BINDs <> nil then begin
    FillChar((PAnsichar(BindBuffer)+(OldCount*BindOffsets.Size))^,
      ((NewCount-OldCount)*BindOffsets.Size), {$IFDEF Use_FastCodeFillChar}#0{$ELSE}0{$ENDIF});
    FillChar((PAnsiChar(MYSQL_aligned_BINDs)+(OldCount*SizeOf(TMYSQL_aligned_BIND)))^,
      (NewCount-OldCount)*SizeOf(TMYSQL_aligned_BIND), {$IFDEF Use_FastCodeFillChar}#0{$ELSE}0{$ENDIF});
    for i := OldCount to NewCount-1 do begin
      {$R-}
      Bind := @MYSQL_aligned_BINDs[I];
      {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
      ColOffset := NativeUInt(I*BindOffsets.size);
      { save mysql bind offset fo mysql_stmt_fetch_column }
      Bind^.mysql_bind := Pointer(NativeUInt(BindBuffer)+ColOffset);
      { save aligned addresses }
      bind^.buffer_address := Pointer(NativeUInt(BindBuffer)+ColOffset+BindOffsets.buffer);
      Bind^.buffer_type_address := Pointer(NativeUInt(BindBuffer)+ColOffset+BindOffsets.buffer_type);
      Bind^.is_unsigned_address := Pointer(NativeUInt(BindBuffer)+ColOffset+BindOffsets.is_unsigned);
      Bind^.buffer_length_address := Pointer(NativeUInt(BindBuffer)+ColOffset+BindOffsets.buffer_length);
      Bind^.length_address := Pointer(NativeUInt(BindBuffer)+ColOffset+BindOffsets.length);
      GetMem(Bind^.length, Iterations*SizeOf(ULong));
      FillChar(Bind^.length^, Iterations*SizeOf(ULong), {$IFDEF Use_FastCodeFillChar}#0{$ELSE}0{$ENDIF});
      Bind^.length_address^ := Bind^.length;
      Bind^.is_null_address := @Bind^.is_null;
      PPointer(NativeUInt(BindBuffer)+ColOffset+BindOffsets.is_null)^ := Bind^.is_null_address;
      if (BindOffsets.Indicator > 0)
      then Bind^.indicator_address := Pointer(NativeUInt(BindBuffer)+ColOffset+BindOffsets.Indicator)
      else if Iterations > 1 then
        raise EZSQLException.Create('Array bindings are not supported!');
    end;
  end;
end;
{$IFDEF FPC} {$POP} {$ENDIF} // uses pointer maths


procedure ReAllocMySQLColumnBuffer(OldRSCount, NewRSCount: Integer;
  var ColumnsBindingArray: PMYSQL_ColumnsBindingArray; BindOffset: PMYSQL_BINDOFFSETS);
var i: Integer;
  ColBinding: PMYSQL_ColumnsBinding;
begin
  if ColumnsBindingArray <> nil then
    for i := OldRSCount-1 downto NewRSCount do begin
      {$R-}
      ColBinding := @ColumnsBindingArray[I];
      {$IFDEF RangeCheckEnabled}{$R+}{$ENDIF}
      ReallocBindBuffer(ColBinding.MYSQL_Col_BINDs, ColBinding.MYSQL_aligned_BINDs, BindOffset,
        ColBinding.FieldCount, 0, 1);
    end;
  ReallocMem(ColumnsBindingArray, NewRSCount*SizeOf(TMYSQL_ColumnsBinding));
  if ColumnsBindingArray <> nil then
    FillChar((PAnsichar(ColumnsBindingArray)+(OldRSCount*SizeOf(TMYSQL_ColumnsBinding)))^,
      ((NewRSCount-OldRSCount)*SizeOf(TMYSQL_ColumnsBinding)), {$IFDEF Use_FastCodeFillChar}#0{$ELSE}0{$ENDIF});
end;

initialization
{$IFDEF FPC} {$PUSH} {$WARN 4055 off : Conversion between ordinals and pointers is not portable} {$ENDIF} // uses pointer maths
  with MARIADB_BIND1027_Offset do begin
    buffer_type   := NativeUint(@(PMARIADB_BIND1027(nil).buffer_type));
    buffer_length := NativeUint(@(PMARIADB_BIND1027(nil).buffer_length));
    is_unsigned   := NativeUint(@(PMARIADB_BIND1027(nil).is_unsigned));
    buffer        := NativeUint(@(PMARIADB_BIND1027(nil).buffer));
    length        := NativeUint(@(PMARIADB_BIND1027(nil).length));
    is_null       := NativeUint(@(PMARIADB_BIND1027(nil).is_null));
    Indicator     := NativeUint(@(PMARIADB_BIND1027(nil).u.indicator));
    size          := Sizeof(TMARIADB_BIND1027);
  end;
  with MYSQL_BIND51_Offset do begin
    buffer_type   := NativeUint(@(PMYSQL_BIND51(nil).buffer_type));
    buffer_length := NativeUint(@(PMYSQL_BIND51(nil).buffer_length));
    is_unsigned   := NativeUint(@(PMYSQL_BIND51(nil).is_unsigned));
    buffer        := NativeUint(@(PMYSQL_BIND51(nil).buffer));
    length        := NativeUint(@(PMYSQL_BIND51(nil).length));
    is_null       := NativeUint(@(PMYSQL_BIND51(nil).is_null));
    Indicator     := 0;
    size          := Sizeof(TMYSQL_BIND51);
  end;
  with MYSQL_BIND506_Offset do begin
    buffer_type   := NativeUint(@(PMYSQL_BIND506(nil).buffer_type));
    buffer_length := NativeUint(@(PMYSQL_BIND506(nil).buffer_length));
    is_unsigned   := NativeUint(@(PMYSQL_BIND506(nil).is_unsigned));
    buffer        := NativeUint(@(PMYSQL_BIND506(nil).buffer));
    length        := NativeUint(@(PMYSQL_BIND506(nil).length));
    is_null       := NativeUint(@(PMYSQL_BIND506(nil).is_null));
    Indicator     := 0;
    size          := Sizeof(TMYSQL_BIND506);
  end;
  with MYSQL_BIND411_Offset do begin
    buffer_type   := NativeUInt(@(PMYSQL_BIND411(nil).buffer_type));
    buffer_length := NativeUInt(@(PMYSQL_BIND411(nil).buffer_length));
    is_unsigned   := NativeUInt(@(PMYSQL_BIND411(nil).is_unsigned));
    buffer        := NativeUInt(@(PMYSQL_BIND411(nil).buffer));
    length        := NativeUInt(@(PMYSQL_BIND411(nil).length));
    is_null       := NativeUInt(@(PMYSQL_BIND411(nil).is_null));
    Indicator     := 0;
    size          := Sizeof(TMYSQL_BIND411);
  end;

  with MYSQL_FIELD51_Offset do begin
    name            := NativeUInt(@(PMYSQL_FIELD51(nil).name));
    name_length     := NativeUInt(@(PMYSQL_FIELD51(nil).name_length));
    org_table       := NativeUInt(@(PMYSQL_FIELD51(nil).org_table));
    org_table_length:= NativeUInt(@(PMYSQL_FIELD51(nil).org_table_length));
    org_name        := NativeUInt(@(PMYSQL_FIELD51(nil).org_name));
    org_name_length := NativeUInt(@(PMYSQL_FIELD51(nil).org_name_length));
    db              := NativeUInt(@(PMYSQL_FIELD51(nil).db));
    db_length       := NativeUInt(@(PMYSQL_FIELD51(nil).db_length));
    charsetnr       := NativeUInt(@(PMYSQL_FIELD51(nil).charsetnr));
    _type           := NativeUInt(@(PMYSQL_FIELD51(nil)._type));
    flags           := NativeUInt(@(PMYSQL_FIELD51(nil).flags));
    length          := NativeUInt(@(PMYSQL_FIELD51(nil).length));
    decimals        := NativeUInt(@(PMYSQL_FIELD51(nil).decimals));
    max_length      := NativeUInt(@(PMYSQL_FIELD51(nil).max_length));
  end;
  with MYSQL_FIELD41_Offset do begin
    name            := NativeUInt(@(PMYSQL_FIELD41(nil).name));
    name_length     := NativeUInt(@(PMYSQL_FIELD41(nil).name_length));
    org_table       := NativeUInt(@(PMYSQL_FIELD41(nil).org_table));
    org_table_length:= NativeUInt(@(PMYSQL_FIELD41(nil).org_table_length));
    org_name        := NativeUInt(@(PMYSQL_FIELD41(nil).org_name));
    org_name_length := NativeUInt(@(PMYSQL_FIELD41(nil).org_name_length));
    db              := NativeUInt(@(PMYSQL_FIELD41(nil).db));
    db_length       := NativeUInt(@(PMYSQL_FIELD41(nil).db_length));
    charsetnr       := NativeUInt(@(PMYSQL_FIELD41(nil).charsetnr));
    _type           := NativeUInt(@(PMYSQL_FIELD41(nil)._type));
    flags           := NativeUInt(@(PMYSQL_FIELD41(nil).flags));
    length          := NativeUInt(@(PMYSQL_FIELD41(nil).length));
    decimals        := NativeUInt(@(PMYSQL_FIELD41(nil).decimals));
    max_length      := NativeUInt(@(PMYSQL_FIELD41(nil).max_length));
  end;
  with MYSQL_FIELD401_Offset do begin
    name            := NativeUInt(@(PMYSQL_FIELD401(nil).name));
    name_length     := NativeUInt(@(PMYSQL_FIELD401(nil).name_length));
    org_table       := NativeUInt(@(PMYSQL_FIELD401(nil).org_table));
    org_table_length:= NativeUInt(@(PMYSQL_FIELD401(nil).org_table_length));
    org_name        := NativeUInt(@(PMYSQL_FIELD401(nil).org_name));
    org_name_length := NativeUInt(@(PMYSQL_FIELD401(nil).org_name_length));
    db              := NativeUInt(@(PMYSQL_FIELD401(nil).db));
    db_length       := NativeUInt(@(PMYSQL_FIELD401(nil).db_length));
    charsetnr       := NativeUInt(@(PMYSQL_FIELD401(nil).charsetnr));
    _type           := NativeUInt(@(PMYSQL_FIELD401(nil)._type));
    flags           := NativeUInt(@(PMYSQL_FIELD401(nil).flags));
    length          := NativeUInt(@(PMYSQL_FIELD401(nil).length));
    decimals        := NativeUInt(@(PMYSQL_FIELD401(nil).decimals));
    max_length      := NativeUInt(@(PMYSQL_FIELD401(nil).max_length));
  end;
  with MYSQL_FIELD4_Offset do begin
    name            := NativeUInt(@(PMYSQL_FIELD40(nil).name));
    name_length     := -1;
    org_table       := NativeUInt(@(PMYSQL_FIELD40(nil).org_table));
    org_table_length:= -1;
    org_name        := -1;
    org_name_length := -1;
    db              := NativeUInt(@(PMYSQL_FIELD40(nil).db));
    db_length       := -1;
    charsetnr       := -1;
    _type           := NativeUInt(@(PMYSQL_FIELD40(nil)._type));
    flags           := NativeUInt(@(PMYSQL_FIELD40(nil).flags));
    length          := NativeUInt(@(PMYSQL_FIELD40(nil).length));
    decimals        := NativeUInt(@(PMYSQL_FIELD40(nil).decimals));
    max_length      := NativeUInt(@(PMYSQL_FIELD40(nil).max_length));
  end;
  with MYSQL_FIELD32_Offset do begin
    name            := NativeUInt(@(PMYSQL_FIELD32(nil).name));
    name_length     := -1;
    org_table       := -1;
    org_table_length:= -1;
    org_name        := -1;
    org_name_length := -1;
    db              := -1;
    db_length       := -1;
    charsetnr       := -1;
    _type           := NativeUInt(@(PMYSQL_FIELD32(nil)._type));
    flags           := NativeUInt(@(PMYSQL_FIELD32(nil).flags));
    length          := NativeUInt(@(PMYSQL_FIELD32(nil).length));
    decimals        := NativeUInt(@(PMYSQL_FIELD32(nil).decimals));
    max_length      := NativeUInt(@(PMYSQL_FIELD32(nil).max_length));
  end;
{$IFDEF FPC} {$POP} {$ENDIF}

{$ENDIF ZEOS_DISABLE_MYSQL} //if set we have an empty unit
end.
