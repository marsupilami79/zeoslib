// ###################################################################
// #### This file is part of the mathematics library project, and is
// #### offered under the licence agreement described on
// #### http://www.mrsoft.org/
// ####
// #### Copyright:(c) 2019, Michael R. . All rights reserved.
// ####
// #### Unless required by applicable law or agreed to in writing, software
// #### distributed under the License is distributed on an "AS IS" BASIS,
// #### WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// #### See the License for the specific language governing permissions and
// #### limitations under the License.
// ###################################################################

unit ZCbor;

// conversion of cbor encoded data to a TCborItem
// note: there is no tagging yet implemented!!

// note: if the items are used as a map only whereas the
// names are all UTF8Strings a conversion "ToString" brings a
// nice valid JSON string conversion of the items.

// the decoding handles unknown "simple" values (maj type 7) as simple
// integer values.

// the library uses some stuff from the indy project namely the base64 encoders/decoders

// a limitation of this little library is that the negivative number actually uses an
// int64 to encode the negative values -> negative values below -2^63 will raise exceptions

// simple value opcode `$f7 is not implemented -> it's undefined in the original RFC

interface

{$IFDEF FPC}
{$MODE DELPHIUNICODE}
{$ENDIF}

uses SysUtils, Classes, Contnrs{$IFDEF FPC}{$IFDEF UNIX}, clocale{$ENDIF}{$ENDIF};

type
  ECBorNotImplmented = class(Exception);
  ECborDecodeError = class(Exception);

const cCborSerializationTag : Array[0..2] of byte = ($D9, $D9, $F7);

// major cbor types. Note major type 7 actually is the "simple" value type with subtype
// floating point, null and boolean
type
  TCBORType = ( majUnsignedInt = 0, majNegInt = 1, majByteStr = 2, majUTFEncStr = 3,
                majArray = 4, majMap = 5, majTag = 6, majFloat = 7 );

type
  // object list for arrays and maps
  TCborItemList = class;

  // base class
  TCborItem = class(TObject)
  private
    fCBORType : TCBORType; // determines which field is valid
  public
    property CBorType : TCBORType read fCBORType;

    procedure CBOREncode( toStream : TStream ); virtual; abstract;
    function ToString : string; {$IFNDEF FPC}override;{$ENDIF}
  end;

  // ############################################
  // #### integral types (pos neg integers)
  TCborUINTItem = class(TCborItem)
  private
    fuIntVal : UInt64;
  public
    procedure CBOREncode( toStream : TStream ); override;
    function ToString : string; {$IFNDEF FPC}override;{$ENDIF}

    property Value : UInt64 read fUIntVal;

    constructor Create( uVal : UInt64 );
  end;
  TCborNegIntItem = class(TCborItem)
  private
    fnegIntVal : Int64;
  public
    procedure CBOREncode( toStream : TStream ); override;
    function ToString : string; {$IFNDEF FPC}override;{$ENDIF}

    property Value : Int64 read fnegIntVal;

    // needs to be negative!!!
    constructor Create( negVal : Int64 );
  end;
  // binary data
  TCborByteString = class(TCborItem)
  private
    fbyteStr : RawByteString;
  public
    function ToString : string; {$IFNDEF FPC}override;{$ENDIF}
    procedure CBOREncode( toStream : TStream ); override;
    function ToBytes : TBytes;

    property Value : RawByteString read fbyteStr;

    constructor Create( str : RawByteString );
  end;
  // utf8 strings
  TCborUtf8String = class(TCborItem)
  private
    futfStr : UTF8String;

    function EscapeJSON( jsonString : string ) : string;
  public
    procedure CBOREncode( toStream : TStream ); override;
    function ToString : string; {$IFNDEF FPC}override;{$ENDIF}

    property Value : UTF8String read futfStr;

    constructor Create( str : UTF8String );
  end;
  // #########################################################
  // #### Arrays and dictionaries (map)
  TCborArr = class(TCborItem)
  private
    farr : TCborItemList;
    function GetCount: integer;
    function GetItem(index: integer): TCborItem;
  public
    procedure Add( item : TCborItem );
    procedure Delete(index: integer);

    procedure CBOREncode( toStream : TStream ); override;
    function ToString : string; {$IFNDEF FPC}override;{$ENDIF}

    property Count : integer read GetCount;
    property Items[ index : integer ] : TCborItem read GetItem; default;

    constructor Create;
    destructor Destroy; override;
  end;
  TCborMap = class(TCborItem)
  private
    // map
    fNames : TCborItemList;
    fvalue : TCborItemList;
    function GetCount: integer;
    function GetName(index: integer): TCborItem;
    function GetValue(index: integer): TCborItem;
    function GetValueByName(name: string): TCborItem;
  public
    procedure Add( name : TCborItem; value : TCborItem );

    procedure CBOREncode( toStream : TStream ); override;
    function ToString : string; {$IFNDEF FPC}override;{$ENDIF}

    function IndexOfName( name : string ) : integer;

    property Count : integer read GetCount;
    property Names[ index : integer ] : TCborItem read GetName;
    property Values[ index : integer ] : TCborItem read GetValue;
    property ValueByName[ name : string ] : TCborItem read GetValueByName;

    constructor Create;
    destructor Destroy; override;
  end;

  // ################################################
  // #### floating point and simple numbers
  TCborFloat = class(TCborItem)
  private
    ffloatVal : double;
  public
    procedure CBOREncode( toStream : TStream ); override;
    function ToString : string; {$IFNDEF FPC}override;{$ENDIF}

    property Value : double read ffloatVal;

    constructor Create( val : Double );
  end;

  // major type 7 (float) simple types
  TCborBoolean = class(TCborItem)
  private
    fBoolVal : boolean;
  public
    procedure CBOREncode( toStream : TStream ); override;
    function ToString : string; {$IFNDEF FPC}override;{$ENDIF}

    property Value : boolean read fBoolVal;

    constructor Create( val : boolean );
  end;
  TCborNULL = class(TCborItem)
  public
    procedure CBOREncode( toStream : TStream ); override;
    function ToString : string; {$IFNDEF FPC}override;{$ENDIF}

    constructor Create;
  end;
  TCborSimpleValue = class(TCborItem)
  private
    fSimpleVal : byte;
  public
    procedure CBOREncode( toStream : TStream ); override;
    function ToString : string; {$IFNDEF FPC}override;{$ENDIF}

    property Value : byte read fSimpleVal;

    constructor Create( aVal : byte );
  end;


  // #########################################################
  // #### Helper list class for maps and arrays
  TCborItemList = class(TObjectList)
  private
    function GetCBORItem(index: integer): TCborItem;
  public
    property Items[ index : integer ] : TCborItem read GetCBORItem; default;

    procedure Encode( toStream : TStream );

    constructor Create;
  end;

// #####################################################################
// #### Encoding/Decoding
// #####################################################################
type
  TCborDecoding = class(TObject)
  private
    type
      TCBORdecodeFunc = function( stream : TStream ) : TCborItem;

  protected
    class var cborDecodeTbl : Array[0..255] of TCBORdecodeFunc;
    class procedure InitDecodeTable;
  public
    // decoding a stream (e.g. file)
    class function Decode( stream : TStream; checkForCeborMagicNr : boolean = False ) : TCborItem;
    // naked pointer based decoding
    class function DecodeData( data : PByte; len : integer ) : TCborItem; overload;
    class function DecodeData( data : RawByteString ) : TCborItem; overload;
    class function DecodeData( data : PByte; len : integer; var bytesDecoded : integer ) : TCborItem; overload;
    class function DecodeData( data : RawByteString; var bytesDecoded : integer ) : TCborItem; overload;


    // base64 data or base634url encoded data
    class function DecodeBase64( data : String ) : TCborItem;
    class function DecodeBase64Url( data : String ) : TCborItem;
    class function DecodeBase64UrlEx( data : string; var restBuffer : TBytes ) : TCborItem;
  end;


function Base64Decode( s : string ) : RawByteString;
function Base64DecodeToBytes( s : string ) : TBytes;
function Base64URLDecode( s : String ) : RawByteString;
function Base64URLDecodeToBytes( s : String ) : TBytes;
function Base64URLEncode( aData : String ) : string; overload;
function Base64URLEncode( aData : RawByteString ) : String; overload;
function Base64URLEncode( aData : TBytes ) : String; overload;
function Base64URLEncode( pData : PByte; len : integer ) : string; overload;
function Base64Encode( aData : RawByteString ) : String; overload;
function Base64Encode( pData : PByte; len : integer ) : string; overload;

function Base64UrlFixup(base64Str: string): string;

implementation

{$IFNDEF FPC}
  {$IF COMPILERVERSION > 21}
    {$DEFINE HAVE_TFORMATSETTINGS_CREATE}
  {$IFEND}
{$ENDIF}

uses Math, {$IFNDEF FPC}idCoderMime,{$ENDIF} StrUtils, ZBase64;


const cCBORTypeMask = $E0;
      cCBORValMask = $1F;
      cCBORBreak = $ff;

// ###############################################################
// #### BASE64 auxilary functions
// ###############################################################

// wrapper around a pointer + length variabl that does not alter the content
// but allows to access the pointer as stream
type
  TWrapMemoryStream = class(TCustomMemoryStream)
  public
    function Write(const Buffer; Count: Longint): Longint; override;
    constructor Create(aData : Pointer; len : integer);
  end;

{ TWrapMemoryStream }

constructor TWrapMemoryStream.Create(aData: Pointer; len: integer);
begin
     inherited Create;

     SetPointer(aData, len);
end;

function TWrapMemoryStream.Write(const Buffer; Count: Longint): Longint;
begin
     raise Exception.Create('Not allowed');
end;

function Base64UrlFixup(base64Str: string): string;
var sFixup : string;
    i : integer;
begin
     // url encoding
     sFixup := stringReplace(base64Str, '+', '-', [rfReplaceAll]);
     sFixup := StringReplace(sfixup, '/', '_', [rfReplaceAll]);

     // strip the '='
     i := Length(sFixup);
     while (i > 0) and (sfixup[i] = '=') do
     begin
          delete(sFixup, i, 1);
          dec(i);
     end;

     Result := sFixup;
end;


// this function uses the standard base64 encoding and basically strips the
// trailing == as well as changes the '+' and '/' elemets (uri compatiblilty)
function Base64URLEncode( aData : RawByteString ) : String;
begin
     Result := Base64URLEncode( PByte( PAnsiChar( aData ) ), Length(aData) );
end;

function Base64URLEncode( aData : TBytes ) : String; overload;
begin
     Result := Base64URLEncode( @aData[0], Length(aData) );
end;

function Base64URLEncode( aData : String ) : string; overload;
var s : UTF8String;
begin
     s := UTF8String(aData);
     Result := '';

     if s <> '' then
        Result := Base64URLEncode( @s[1], Length(s) );
end;

function Base64URLEncode( pData : PByte; len : integer ) : string;
var
  sFixup : string;
  {$IF NOT DECLARED(ZEncodeBase64)}
  wrapMem : TWrapMemoryStream;
  {$ELSE}
  Data: TBytes;
  {$IFEND}
begin
     if len = 0 then
        exit('');

     {$IF NOT DECLARED(ZEncodeBase64)}
     wrapMem := TWrapMemoryStream.Create( pData, len );
     try
        with TIdEncoderMIME.Create(nil) do
        try
           sFixup := Encode( wrapMem );
        finally
               Free;
        end;
     finally
            wrapMem.Free;
     end;
     {$ELSE}
     SetLength(Data, len);
     Move(pData^, Data[0], len);
     sFixup := String(ZEncodeBase64(Data));
     {$IFEND}
     Result := Base64UrlFixup(sFixup);
end;

function Base64Encode( aData : RawByteString ) : String;
begin
     Result := Base64Encode( PByte( PAnsiChar( aData ) ), length(aData) );
end;

function Base64Encode( pData : PByte; len : integer ) : string;
var
  {$IF NOT DECLARED(ZEncodeBase64)}
  wrapMem : TWrapMemoryStream;
  {$ELSE}
  Data: TBytes;
  {$IFEND}
begin
     {$IF NOT DECLARED(ZEncodeBase64)}
     wrapMem := TWrapMemoryStream.Create( pData, len );
     try
        with TIdEncoderMIME.Create(nil) do
        try
           Result := Encode( wrapMem );
        finally
               Free;
        end;
     finally
            wrapMem.Free;
     end;
     {$ELSE}
     if len = 0 then
        exit('');
     SetLength(Data, len);
     Move(pData^, Data[0], len);
     Result := String(ZEncodeBase64(Data));
     {$IFEND}
end;

function Base64Decode( s : string ) : RawByteString;
{$IF NOT DECLARED(ZDecodeBase64)}
var aWrapStream : TWrapMemoryStream;
    sconvStr : UTF8String;
    lStream : TMemoryStream;
begin
     sConvStr := UTF8String( s );
     aWrapStream := TWrapMemoryStream.Create( @sConvStr[1], Length(sConvStr) );
     lStream := TMemoryStream.Create;

     try
        with TIdDecoderMIME.Create(nil) do
        try
           DecodeBegin(lStream);
           Decode( aWrapStream );
           DecodeEnd;

           SetLength(Result, lStream.Size );
           if lStream.Size > 0 then
              Move( PByte(lStream.Memory)^, Result[1], lStream.Size);
        finally
               Free;
        end;
     finally
            lStream.Free;
     end;
     aWrapStream.Free;
end;
{$ELSE}
var
    Bytes: TBytes;
begin
  Bytes := ZDecodeBase64(AnsiString(S));
  SetLength(Result, Length(Bytes));
  if length(Bytes) > 0 then
    Move(Bytes[0], Result[1], Length(Bytes));
end;
{$IFEND}

function Base64DecodeToBytes( s : string ) : TBytes;
{$IF NOT DECLARED(ZDecodeBase64)}
var aWrapStream : TWrapMemoryStream;
    sconvStr : UTF8String;
    lStream : TMemoryStream;
{$IFEND}
begin
     {$IF NOT DECLARED(ZDecodeBase64)}
     sConvStr := UTF8String( s );
     aWrapStream := TWrapMemoryStream.Create( @sConvStr[1], Length(sConvStr) );
     lStream := TMemoryStream.Create;

     try
        with TIdDecoderMIME.Create(nil) do
        try
           DecodeBegin(lStream);
           Decode( aWrapStream );
           DecodeEnd;

           SetLength(Result, lStream.Size );
           if lStream.Size > 0 then
              Move( PByte(lStream.Memory)^, Result[0], lStream.Size);
        finally
               Free;
        end;
     finally
            lStream.Free;
     end;
     aWrapStream.Free;
     {$IFEND}
     Result := ZDecodeBase64(AnsiString(s));
end;


function Base64URLDecode( s : String ) : RawByteString;
var sFixup : UTF8String;
    {$IF NOT DECLARED(ZDecodeBase64)}
    aWrapStream : TWrapMemoryStream;
    lStream : TMemoryStream;
    {$ELSE}
    Data: TBytes;
    {$IFEND}
begin
     if s = '' then
        exit('');

     // fixup
     sfixup := UTF8String(s) + StringOfChar( '=', (4 - Length(s) mod 4) mod 4 );
     sFixup := stringReplace(sfixup, '-', '+', [rfReplaceAll]);
     sFixup := StringReplace(sfixup, '_', '/', [rfReplaceAll]);

     {$IF NOT DECLARED(ZDecodeBase64)}
     sConvStr := sFixup;
     aWrapStream := TWrapMemoryStream.Create( @sConvStr[1], Length(sConvStr) );
     lStream := TMemoryStream.Create;

     try
        with TIdDecoderMIME.Create(nil) do
        try
           DecodeBegin(lStream);
           Decode( aWrapStream );
           DecodeEnd;

           SetLength(Result, lStream.Size );
           if lStream.Size > 0 then
                Move( PByte(lStream.Memory)^, Result[1], lStream.Size);
        finally
               Free;
        end;
     finally
            lStream.Free;
     end;
     aWrapStream.Free;
     {$IFEND}
     Data := ZDecodeBase64(sFixup);
     SetLength(Result, Length(Data));
     Move(Data[0], Result[1], Length(Data));
end;

function Base64URLDecodeToBytes( s : String ) : TBytes;
var res : RawByteString;
begin
     res := Base64URLDecode( s );
     Result := nil;
     if res <> '' then
     begin
          SetLength(Result, Length(res));
          Move( Res[1], Result[0], Length(Res));
     end;
end;

// ##########################################################
// #### float 16 bit conversion from single and back
// ##########################################################

// based on: https://galfar.vevb.net/wp/2011/16bit-half-float-in-pascaldelphi/

function FloatToHalf(Float: Single): Word;
var Src: LongWord;
    Sign, Exp, Mantissa: LongInt;
begin
     Src := PLongWord(@Float)^;
     // Extract sign, exponent, and mantissa from Single number
     Sign := Src shr 31;
     Exp := LongInt((Src and $7F800000) shr 23) - 127 + 15;
     Mantissa := Src and $007FFFFF;

     if (Exp > 0) and (Exp < 30)
     then
         // Simple case - round the significand and combine it with the sign and exponent
         Result := (Sign shl 15) or (Exp shl 10) or ((Mantissa + $00001000) shr 13)
     else if Src = 0
     then
         // Input float is zero - return zero
         Result := 0
     else
     begin
          // Difficult case - lengthy conversion
          if Exp <= 0 then
          begin
               if Exp < -10
               then
                   // Input float's value is less than HalfMin, return zero
                   Result := 0
               else
               begin
                    // Float is a normalized Single whose magnitude is less than HalfNormMin.
                    // We convert it to denormalized half.
                    Mantissa := (Mantissa or $00800000) shr (1 - Exp);
                    // Round to nearest
                    if (Mantissa and $00001000) > 0 then
                      Mantissa := Mantissa + $00002000;
                    // Assemble Sign and Mantissa (Exp is zero to get denormalized number)
                    Result := (Sign shl 15) or (Mantissa shr 13);
               end;
          end
          else if Exp = 255 - 127 + 15 then
          begin
               if Mantissa = 0
               then
                   // Input float is infinity, create infinity half with original sign
                   Result := (Sign shl 15) or $7C00
               else
                   // Input float is NaN, create half NaN with original sign and mantissa
                   Result := (Sign shl 15) or $7C00 or (Mantissa shr 13);
          end
          else
          begin
               // Exp is > 0 so input float is normalized Single

               // Round to nearest
               if (Mantissa and $00001000) > 0 then
               begin
                    Mantissa := Mantissa + $00002000;
                    if (Mantissa and $00800000) > 0 then
                    begin
                         Mantissa := 0;
                         Exp := Exp + 1;
                    end;
               end;

               if Exp > 30 then
               begin
                    // Exponent overflow - return infinity half
                    Result := (Sign shl 15) or $7C00;
               end
               else
                   // Assemble normalized half
                   Result := (Sign shl 15) or (Exp shl 10) or (Mantissa shr 13);
          end;
     end;
end;

function HalfToFloat(Half: word): Single;
var Dst, Sign, Mantissa: LongWord;
    Exp: LongInt;
begin
     // Extract sign, exponent, and mantissa from half number
     Sign := Half shr 15;
     Exp := (Half and $7C00) shr 10;
     Mantissa := Half and 1023;

     if (Exp > 0) and (Exp < 31) then
     begin
          // Common normalized number
          Exp := Exp + (127 - 15);
          Mantissa := Mantissa shl 13;
          Dst := (Sign shl 31) or (LongWord(Exp) shl 23) or Mantissa;
          // Result := Power(-1, Sign) * Power(2, Exp - 15) * (1 + Mantissa / 1024);
     end
     else if (Exp = 0) and (Mantissa = 0) then
     begin
          // Zero - preserve sign
          Dst := Sign shl 31;
     end
     else if (Exp = 0) and (Mantissa <> 0) then
     begin
          // Denormalized number - renormalize it
          while (Mantissa and $00000400) = 0 do
          begin
            Mantissa := Mantissa shl 1;
            Dec(Exp);
          end;
          Inc(Exp);
          Mantissa := Mantissa and not $00000400;
          // Now assemble normalized number
          Exp := Exp + (127 - 15);
          Mantissa := Mantissa shl 13;
          Dst := (Sign shl 31) or (LongWord(Exp) shl 23) or Mantissa;
          // Result := Power(-1, Sign) * Power(2, -14) * (Mantissa / 1024);
     end
     else if (Exp = 31) and (Mantissa = 0) then
     begin
          // +/- infinity
          Dst := (Sign shl 31) or $7F800000;
     end
     else //if (Exp = 31) and (Mantisa <> 0) then
     begin
          // Not a number - preserve sign and mantissa
          Dst := (Sign shl 31) or $7F800000 or (Mantissa shl 13);
     end;

     // Reinterpret LongWord as Single
     Result := PSingle(@Dst)^;
end;

// reads a byte from the stream and reverst the position
function PeekFromStream( stream : TStream; var buf : byte ) : byte;
begin
     stream.ReadBuffer(buf, sizeof(Buf));
     stream.Seek(-sizeof(buf), soCurrent);
     Result := buf;
end;

// cbor uses network byte order which maps to the just inverse byte order for intel machines
procedure RevertByteOrder( stream : PByte; numBytes : integer);
var i: Integer;
    pEnd : PByte;
    tmp : byte;
begin
     pEnd := stream;
     inc(pEnd, numBytes - 1);
     for i := 0 to numBytes div 2 - 1 do
     begin
          tmp := stream^;
          stream^ := pEnd^;
          pEnd^ := tmp;
          inc(stream);
          dec(pEnd);
     end;
end;

// #################################################################
// #### cbor decoder
// #################################################################

class function TCborDecoding.Decode(stream: TStream; checkForCeborMagicNr : boolean = False): TCborItem;
var opCode : Byte;
    hea : Array[0..2] of byte;
begin
     InitDecodeTable;

     Result := nil;
     if (stream = nil) then
        exit;

     if checkForCeborMagicNr then
     begin
          stream.ReadBuffer(hea, sizeof(hea));

          // if no serialization header indicator is found just try the standard decoding
          if not CompareMem( @hea[0], @cCborSerializationTag[0], sizeof(cCborSerializationTag) ) then
             stream.Seek(-sizeof(cCborSerializationTag), soCurrent);
     end;

     PeekFromStream(stream, opCode);
     Result := cborDecodeTbl[ opCode ](stream);
end;

class function TCborDecoding.DecodeData(data: PByte;
  len: integer): TCborItem;
var dummy : integer;
begin
     Result := DecodeData(data, len, dummy);
end;

class function TCborDecoding.DecodeData(data: RawByteString;
  var bytesDecoded: integer): TCborItem;
begin
     Result := DecodeData( PByte( PAnsiChar( data ) ), Length(data), bytesDecoded );
end;

class function TCborDecoding.DecodeData(data: PByte; len: integer;
  var bytesDecoded: integer): TCborItem;
var memStream : TWrapMemoryStream;
begin
     memStream := TWrapMemoryStream.Create(data, len);
     try
        Result := Decode(memStream);
        bytesDecoded := Integer(memStream.Position);
     finally
            memStream.Free;
     end;
end;

class function TCborDecoding.DecodeData(data: RawByteString): TCborItem;
begin
     Result := DecodeData( PByte( PAnsiChar( data ) ), Length(data) );
end;

class function TCborDecoding.DecodeBase64(data: String): TCborItem;
var decoded : RawByteString;
begin
     decoded := Base64Decode(data);
     Result := nil;

     if decoded <> '' then
        Result := DecodeData( PByte(PAnsiChar(decoded)), Length(decoded));
end;

class function TCborDecoding.DecodeBase64Url(data: String): TCborItem;
var decoded : RawByteString;
  i: integer;
begin
     decoded := Base64URLDecode(data);
     Result := nil;

     with TStringStream.Create('') do
     try
        for i := 1 to Length(decoded) do
            WriteString(IntToHex( Byte( decoded[i]), 2 ) + ' ' );

        SaveToFile('d:\cbor_attestObj.txt');
     finally
            Free;
     end;

     if decoded <> '' then
        Result := DecodeData( PByte(PAnsiChar(decoded)), Length(decoded));
end;

class function TCborDecoding.DecodeBase64UrlEx(data: string;
  var restBuffer: TBytes): TCborItem;
var decoded : RawByteString;
    bytesDecoded : integer;
begin
     decoded := Base64URLDecode(data);
     Result := nil;

     bytesDecoded := 0;
     if decoded <> '' then
        Result := DecodeData( PByte(PAnsiChar(decoded)), Length(decoded), bytesDecoded);

     SetLength( restBuffer, length(decoded) - bytesDecoded );
     if Length(restBuffer) > 0 then
        Move( decoded[bytesDecoded], restBuffer[0], Length(restBuffer));
end;


// ##############################################################
// #### cbor objects
// ##############################################################

{ TCborFloat }

constructor TCborFloat.Create(val: Double);
begin
     inherited Create;

     fCBORType := majFloat;
     ffloatVal := val;
end;

function TCborFloat.ToString: string;
var fmt : TFormatSettings;
begin
     {$IFNDEF HAVE_TFORMATSETTINGS_CREATE}
     {$IF DECLARED(GetLocaleFormatSettings)}
     GetLocaleFormatSettings(0, fmt);
     {$ELSE}
     fmt := DefaultFormatSettings;
     {$ENDIF}
     {$ELSE}
     fmt := TFormatSettings.Create;
     {$ENDIF}
     fmt.DecimalSeparator := '.';
     //Result := FormatFloat( '%f', fFloatVal, fmt);
     Result := FloatToStr(ffloatVal, fmt);
end;

procedure TCborFloat.CBOREncode(toStream: TStream);
var opCode : Byte;
    val : Double;
    sVal : single;
    dVal : double;
    wVal : Word;
    wtoSval : single;
begin
     val := ffloatVal;
     sVal := ffloatVal; // simply cast to single and back to double -> if it's the same we use single
     dVal := sVal;

     wVal := FloatToHalf( sVal );
     wtoSVal := HalfToFloat( wVal );

     // needs double encoding?
     if ffloatVal <> dVal then
     begin
          RevertByteOrder(@val, sizeof(val));

          // write double
          opCode := $FB;
          toStream.WriteBuffer(opCode, sizeof(opCode));
          toStream.WriteBuffer(val, sizeof(val));
     end // 16bit float sufficient?
     else if wtoSVal = sVal then
     begin
          RevertByteOrder( @wVal, sizeof(wVal));

          // write half single
          opcode := $F9;
          toStream.WriteBuffer(opCode, sizeof(opcode));
          toStream.WriteBuffer(wval, sizeof(wVal));
     end
     else
     begin

          RevertByteOrder(@sVal, sizeof(sVal));

          // write single
          opCode := $FA;
          toStream.WriteBuffer(opCode, sizeof(opCode));
          toStream.WriteBuffer(sval, sizeof(sval));
     end;
end;

{ TCborMap }

constructor TCborMap.Create;
begin
     inherited Create;

     fCBORType := majMap;
     fNames := TCborItemList.Create;
     fvalue := TCborItemList.Create;
end;

procedure TCborMap.Add(name, value: TCborItem);
begin
     fNames.Add(name);
     fvalue.Add(value);
end;

destructor TCborMap.Destroy;
begin
     fNames.Free;
     fvalue.Free;

     inherited;
end;

function TCborMap.ToString: string;
var i: Integer;
begin
     Result := '{';
     for i := 0 to fNames.Count - 1 do
     begin
          Result := Result + ifthen(fNames[i] is TCborUtf8String, '', '"') +
                             fNames[i].ToString +
                             ifthen(fNames[i] is TCborUtf8String, '', '"') +
                             ':' + fvalue[i].ToString;
          if i <> fNames.Count - 1 then
             Result := Result + ',';
     end;
     Result := Result + '}';
end;


procedure TCborMap.CBOREncode(toStream: TStream);
var len : int64;
    opCode : Byte;
    bLen : Byte;
    wLen : word;
    dwLen : LongWord;
    i : Integer;
begin
     len := fNames.Count;

     if len <= $17 then
     begin
          opCode := Byte($A0 + len);
          toStream.WriteBuffer(opCode, sizeof(opCode));
     end
     else if len <= High(Byte) then
     begin
          opCode := $B8;
          toStream.WriteBuffer(opCode, sizeof(opCode));
          bLen := Byte(len);
          toStream.WriteBuffer(bLen, sizeof(bLen));
     end
     else if len <= High(Word) then
     begin
          opCode := $B9;
          toStream.WriteBuffer(opCode, sizeof(opCode));
          wLen := Word(len);
          RevertByteOrder( @wLen, sizeof(wLen));
          toStream.WriteBuffer(wLen, sizeof(wLen));
     end
     else if len <= High(LongWord) then
     begin
          opCode := $BA;
          toStream.WriteBuffer(opCode, sizeof(opCode));
          dwLen := LongWord(len);
          RevertByteOrder( @dwLen, sizeof(dwLen));
          toStream.WriteBuffer(dwLen, sizeof(dwLen));
     end
     else
         raise Exception.Create('To long list...!');

     for i := 0 to fNames.Count - 1 do
     begin
          fNames[i].CBOREncode(toStream);
          fvalue[i].CBOREncode(toStream);
     end;
end;


function TCborMap.GetCount: integer;
begin
     Result := fNames.Count;
end;

function TCborMap.GetName(index: integer): TCborItem;
begin
     Result := fNames[index];
end;

function TCborMap.GetValue(index: integer): TCborItem;
begin
     Result := fvalue[index];
end;

function TCborMap.GetValueByName(name: string): TCborItem;
var i: Integer;
begin
     // works only for utf names
     Result := nil;

     i := IndexOfName(Name);
     if i >= 0 then
        Result := fValue[i];
end;

function TCborMap.IndexOfName(name: string): integer;
var i : integer;
begin
     Result := -1;
     for i := 0 to GetCount - 1 do
     begin
          if (Names[i] is TCborUtf8String) then
          begin
               if SameStr( String((Names[i] as TCborUtf8String).Value), name) then
               begin
                    Result := i;
                    break;
               end;
          end
          else if (Names[i] is TCborUINTItem) then
          begin
               if name = IntToStr( (Names[i] as TCborUINTItem).Value ) then
               begin
                    Result := i;
                    break;
               end;
          end
          else if (Names[i] is TCborNegIntItem) then
          begin
               if name = IntToStr( (Names[i] as TCborNegIntItem).Value ) then
               begin
                    Result := i;
                    break;
               end;
          end;
     end;
end;

{ TCborArr }

constructor TCborArr.Create;
begin
     inherited Create;

     fCBORType := majArray;
     farr := TCborItemList.Create;
end;

procedure TCborArr.Add(item: TCborItem);
begin
     farr.Add(item);
end;

procedure TCborArr.Delete(index: integer);
begin
     farr.Delete(index);
end;


destructor TCborArr.Destroy;
begin
     farr.Free;

     inherited;
end;

function TCborArr.ToString: string;
var i: Integer;
begin
     Result := '[';
     for i := 0 to farr.Count - 1 do
     begin
          Result := Result + fArr[i].ToString;
          if i <> fArr.Count - 1 then
             Result := Result + ', ';
     end;
     Result := Result + ']';
end;

procedure TCborArr.CBOREncode(toStream: TStream);
var len : int64;
    opCode : Byte;
    bLen : Byte;
    wLen : word;
    dwLen : LongWord;
    i : Integer;
begin
     len := farr.Count;

     if len <= $17 then
     begin
          opCode := Byte($80 + len);
          toStream.WriteBuffer(opCode, sizeof(opCode));
     end
     else if len <= High(Byte) then
     begin
          opCode := $98;
          toStream.WriteBuffer(opCode, sizeof(opCode));
          bLen := Byte(len);
          toStream.WriteBuffer(bLen, sizeof(bLen));
     end
     else if len <= High(Word) then
     begin
          opCode := $99;
          toStream.WriteBuffer(opCode, sizeof(opCode));
          wLen := Word(len);
          RevertByteOrder( @wLen, sizeof(wLen));
          toStream.WriteBuffer(wLen, sizeof(wLen));
     end
     else if len <= High(LongWord) then
     begin
          opCode := $9A;
          toStream.WriteBuffer(opCode, sizeof(opCode));
          dwLen := LongWord(len);
          RevertByteOrder( @dwLen, sizeof(dwLen) );
          toStream.WriteBuffer(dwLen, sizeof(dwLen));
     end
     else
         raise Exception.Create('To long array!');

     for i := 0 to farr.Count - 1 do
         fArr[i].CBOREncode(toStream);
end;


function TCborArr.GetCount: integer;
begin
     Result := farr.Count;
end;

function TCborArr.GetItem(index: integer): TCborItem;
begin
     Result := farr[index];
end;

{ TCborUtf8String }

constructor TCborUtf8String.Create(str: UTF8String);
begin
     inherited Create;

     fCBORType := majUTFEncStr;
     futfStr := str;
end;

function TCborUtf8String.ToString: string;
begin
     Result := '"' + EscapeJSON( String( futfStr ) ) + '"';
end;

function TCborUtf8String.EscapeJSON(jsonString: string): string;
var idx : integer;
    actPos : integer;
procedure WriteJSONStr(const data : String; var s : String);
var i : integer;
begin
     for i := 1 to Length(data) do
     begin
          s[actPos] := data[i];
          inc(actPos);
     end;
end;
begin
     idx := 1;
     actPos := 1;

     setLength(Result, 6*length(jsonString));

     while idx <= Length(jsonString) do
     begin
          case jsonString[idx] of
            '/',
            '\',
            '"': WriteJSONStr('\' + jsonString[idx], Result);
            #8:  WriteJSONStr('\b', Result);
            #9:  WriteJSONStr('\t', Result);
            #10: WriteJSONStr('\n', Result);
            #13: WriteJSONStr('\r', Result);
            #12: WriteJSONStr('\f', Result);
          else
              if (ord(jsonString[idx]) < 32) or (ord(jsonString[idx]) > 127)
              then
                  WriteJSONStr('\u' + inttohex(ord(jsonString[idx]), 4), Result)
              else
              begin
                   Result[actPos] := jsonString[idx];
                   inc(actPos);
              end;
          end;

          inc(idx);
     end;

     Result := Copy(Result, 1, actPos - 1);
end;


procedure TCborUtf8String.CBOREncode(toStream: TStream);
var len : int64;
    opCode : Byte;
    bLen : Byte;
    wLen : word;
    dwLen : LongWord;
begin
     len := length(futfStr);

     if len <= $17 then
     begin
          opCode := Byte($60 + len);
          toStream.WriteBuffer(opCode, sizeof(opCode));
     end
     else if len <= High(Byte) then
     begin
          opCode := $78;
          toStream.WriteBuffer(opCode, sizeof(opCode));
          bLen := Byte(len);
          toStream.WriteBuffer(bLen, sizeof(bLen));
     end
     else if len <= High(Word) then
     begin
          opCode := $79;
          toStream.WriteBuffer(opCode, sizeof(opCode));
          wLen := Word(len);
          RevertByteOrder( @wLen, sizeof(wLen));
          toStream.WriteBuffer(wLen, sizeof(wLen));
     end
     else if len <= High(LongWord) then
     begin
          opCode := $7A;
          toStream.WriteBuffer(opCode, sizeof(opCode));
          dwLen := LongWord(len);
          RevertByteOrder( @dwLen, sizeof(dwLen));
          toStream.WriteBuffer(dwLen, sizeof(dwLen));
     end
     else
         raise Exception.Create('To long string!');

     if len > 0 then
        toStream.WriteBuffer( futfStr[1], len);
end;

{ TCborByteString }

constructor TCborByteString.Create(str: RawByteString);
begin
     inherited Create;

     fCBORType := majByteStr;
     fbyteStr := str;
end;

function TCborByteString.ToString: string;
begin
     Result := '"';
     if Length(fbyteStr) > 0 then
        Result := Result + Base64URLEncode(fbyteStr);
     Result := Result + '"';
end;

procedure TCborByteString.CBOREncode(toStream: TStream);
var len : int64;
    opCode : Byte;
    bLen : Byte;
    wLen : word;
    dwLen : LongWord;
begin
     len := length(fbyteStr);

     if len <= $17 then
     begin
          opCode := Byte($40 + len);
          toStream.WriteBuffer(opCode, sizeof(opCode));
     end
     else if len <= High(Byte) then
     begin
          opCode := $58;
          toStream.WriteBuffer(opCode, sizeof(opCode));
          bLen := Byte(len);
          toStream.WriteBuffer(bLen, sizeof(bLen));
     end
     else if len <= High(Word) then
     begin
          opCode := $59;
          toStream.WriteBuffer(opCode, sizeof(opCode));
          wLen := Word(len);
          RevertByteOrder( @wLen, sizeof(wLen));
          toStream.WriteBuffer(wLen, sizeof(wLen));
     end
     else if len <= High(LongWord) then
     begin
          opCode := $5A;
          toStream.WriteBuffer(opCode, sizeof(opCode));
          dwLen := LongWord(len);
          RevertByteOrder( @dwLen, sizeof(dwLen));
          toStream.WriteBuffer(dwLen, sizeof(dwLen));
     end
     else
         raise Exception.Create('To long string!');

     if len > 0 then
        toStream.WriteBuffer( fByteStr[1], len);
end;

function TCborByteString.ToBytes: TBytes;
begin
     SetLength( Result, Length(fbyteStr));
     if Length(fbyteStr) > 0 then
        Move( fByteStr[1], Result[0], Length(fbyteStr));
end;

{ TCborNegIntItem }

constructor TCborNegIntItem.Create(negVal: Int64);
begin
     inherited Create;

     assert( negval < 0, 'Only negative values allowed');

     fCBORType := majNegInt;
     fnegIntVal := negVal;
end;

function TCborNegIntItem.ToString: string;
begin
     Result := IntToStr(fnegIntVal);
end;

procedure TCborNegIntItem.CBOREncode(toStream: TStream);
var opCode : Byte;
    bData : Byte;
    wData : Word;
    dwData : LongWord;
    uIntVal : UINT64;
begin
     uIntVal := abs( fnegIntVal + 1);

     // determine "opcode"
     if {$IFNDEF FPC}Abs{$ENDIF}(uIntVal) <= $17 then
     begin
          opCode := $20 + Byte(uIntVal);
          toStream.WriteBuffer(opCode, sizeof(opCode));
     end
     else if uIntVal <= High(Byte) then
     begin
          opCode := $38;
          bData := Byte(uIntVal);
          toStream.WriteBuffer(opCode, sizeof(opCode));
          toStream.WriteBuffer(bData, sizeof(bData));
     end
     else if uIntVal <= High(Word) then
     begin
          opCode := $39;
          wData := Word( uIntVal );
          RevertByteOrder(@wData, sizeof(wData));
          toStream.WriteBuffer(opCode, sizeof(opCode));
          toStream.WriteBuffer(wData, sizeof(wData));
     end
     else if uIntVal <= High(LongWord) then
     begin
          opCode := $3A;
          dwData := LongWord( uIntVal );
          RevertByteOrder(@dwData, sizeof(dwData));
          toStream.WriteBuffer(opCode, sizeof(opCode));
          toStream.WriteBuffer(dwData, sizeof(dwData));
     end
     else
     begin
          opCode := $3B;
          toStream.WriteBuffer(opCode, sizeof(opCode));
          RevertByteOrder(@uIntVal, sizeof(uIntVal));
          toStream.WriteBuffer(uIntVal, sizeof(uIntVal));
     end;
end;


{ TCborUINTItem }

constructor TCborUINTItem.Create(uVal: UInt64);
begin
     inherited Create;

     fCBORType := majUnsignedInt;
     fuIntVal := uVal;
end;

function TCborUINTItem.ToString: string;
begin
     Result := IntToStr(fuIntVal);
end;

procedure TCborUINTItem.CBOREncode(toStream: TStream);
var opCode : Byte;
    bData : Byte;
    wData : Word;
    dwData : LongWord;
    u64Data : UInt64;
begin
     // determine "opcode"
     if fuIntVal <= $17 then
     begin
          opCode := Byte(fUIntVal);
          toStream.WriteBuffer(opCode, sizeof(opCode));
     end
     else if fuIntVal <= High(Byte) then
     begin
          opCode := $18;
          bData := Byte(fUIntVal);
          toStream.WriteBuffer(opCode, sizeof(opCode));
          toStream.WriteBuffer(bData, sizeof(bData));
     end
     else if fuIntVal <= High(Word) then
     begin
          opCode := $19;
          wData := Word( fUIntVal );
          toStream.WriteBuffer(opCode, sizeof(opCode));
          RevertByteOrder(@wData, sizeof(wData));
          toStream.WriteBuffer(wData, sizeof(wData));
     end
     else if fUIntVal <= High(LongWord) then
     begin
          opCode := $1A;
          dwData := LongWord( fUIntVal );
          toStream.WriteBuffer(opCode, sizeof(opCode));
          RevertByteOrder(@dwData, sizeof(dwData));
          toStream.WriteBuffer(dwData, sizeof(dwData));
     end
     else
     begin
          opCode := $1B;
          u64Data := fuIntVal;
          toStream.WriteBuffer(opCode, sizeof(opCode));
          RevertByteOrder(@u64Data, sizeof(u64Data));
          toStream.WriteBuffer(u64Data, sizeof(u64Data));
     end;
end;

{ TCborItemList }

function TCborItemList.GetCBORItem(index: integer): TCborItem;
begin
     Result := GetItem(index) as TCborItem;
end;

constructor TCborItemList.Create;
begin
     inherited Create(True);
end;

procedure TCborItemList.Encode(toStream: TStream);
var i : integer;
begin
     for i := 0 to Count - 1 do
         GetCBORItem(i).CBOREncode( toStream );
end;

{ TCborBaseItem }

function TCborItem.ToString: string;
begin
     Result := 'Type: ' + intToStr( integer(fCBORType ) );
end;

{ TCborBoolean }

constructor TCborBoolean.Create(val: boolean);
begin
     inherited Create;

     fBoolVal := val;
     fCBORType := majFloat;
end;

procedure TCborBoolean.CBOREncode(toStream: TStream);
var opCode : byte;
begin
     opCode := ifthen( fBoolVal, $F5, $F4 );
     toStream.WriteBuffer(opCode, sizeof(opCode));
end;

function TCborBoolean.ToString: string;
begin
     Result := ifthen( fBoolVal, 'true', 'false' );
end;

{ TCborNULL }

constructor TCborNULL.Create;
begin
     fCBORType := majFloat;

     inherited Create;
end;

procedure TCborNULL.CBOREncode(toStream: TStream);
var opCode : Byte;
begin
     opCode := $F6;
     toStream.WriteBuffer(opCode, sizeof(opCode));
end;

function TCborNULL.ToString: string;
begin
     Result := 'null';
end;

{ TCborSimpleValue }

constructor TCborSimpleValue.Create(aVal: byte);
begin
     inherited Create;

     fCBORType := majFloat;
     fSimpleVal := aVal;
end;

procedure TCborSimpleValue.CBOREncode(toStream: TStream);
var opCode : byte;
begin
     if fSimpleVal <= 19 then
     begin
          opCode := $E0 + fSimpleVal;
          toStream.WriteBuffer( opCode, sizeof(Byte));
     end
     else
     begin
          if (fSimpleVal >= 20) and (fSimpleVal <= 31) then
             raise ECBorNotImplmented.Create('Simple val type within the defined range of floats and other types');

          opCode := $F8;
          toStream.WriteBuffer(opCode, sizeof(opCode));
          toSTream.WriteBuffer(fSimpleVal, sizeof(fSimpleVal));
     end;
end;

function TCborSimpleValue.ToString: string;
begin
     Result := IntToStr(fSimpleVal);
end;


// ##############################################################
// #### Decoding routines
// ##############################################################

function DecodeTinyUInt( stream : TStream ) : TCborItem;
var opCode : byte;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));

     Result := TCborUINTItem.Create(opCode and cCBORValMask);
end;

function DecodeByte( stream : TStream ) : TCborItem;
var opCode : byte;
    val : byte;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));
     stream.ReadBuffer(val, sizeof(val));

     Result := TCborUINTItem.Create(val);
end;

function DecodeWord( stream : TStream ) : TCborItem;
var opCode : byte;
    val : word;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));
     stream.ReadBuffer(val, sizeof(val));
     RevertByteOrder(@val, sizeof(val));

     Result := TCborUINTItem.Create(val);
end;


function DecodeLongWord( stream : TStream ) : TCborItem;
var opCode : byte;
    val : Longword;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));
     stream.ReadBuffer(val, sizeof(val));
     RevertByteOrder(@val, sizeof(val));

     Result := TCborUINTItem.Create(val);
end;


function DecodeUINT64( stream : TStream ) : TCborItem;
var opCode : byte;
    val : uint64;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));
     stream.ReadBuffer(val, sizeof(val));
     RevertByteOrder(@val, sizeof(val));

     Result := TCborUINTItem.Create(val);
end;

function DecodeTinyNegInt( stream : TStream ) : TCborItem;
var val : byte;
begin
     stream.ReadBuffer(val, sizeof(val));

     Result := TCborNegIntItem.Create(-1 - (val and cCBORValMask));
end;

function DecodeNegByte( stream : TStream ) : TCborItem;
var opCode : byte;
    val : byte;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));
     stream.ReadBuffer(val, sizeof(val));

     Result := TCborNegIntItem.Create(-1 - integer(val));
end;

function DecodeNegWord( stream : TStream ) : TCborItem;
var opCode : byte;
    val : word;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));
     stream.ReadBuffer(val, sizeof(val));
     RevertByteOrder(@val, sizeof(val));

     Result := TCborNegIntItem.Create(-1 - integer(val));
end;

function DecodeNegLongWord( stream : TStream ) : TCborItem;
var opCode : byte;
    val : LongWord;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));
     stream.ReadBuffer(val, sizeof(val));
     RevertByteOrder(@val, sizeof(val));

     Result := TCborNegIntItem.Create(-1 - Int64(val));
end;


function DecodeNegUINT64( stream : TStream ) : TCborItem;
var opCode : byte;
    val : uint64;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));
     stream.ReadBuffer(val, sizeof(val));
     RevertByteOrder(@val, sizeof(val));

     Result := TCborNegIntItem.Create(-1 - Int64(val));
end;


function DecodeShortString( stream : TStream ) : TCborItem;
var len : integer;
    opCode : byte;
    byteSTr : RawByteString;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));

     len := opCode - $40;
     SetLength(byteStr, len);
     if len > 0 then
        stream.ReadBuffer( byteStr[1], len );
     Result := TCborByteString.Create( byteStr );
end;

function DecodeMediumString( stream : TStream ) : TCborItem;
var len : byte;
    opCode : byte;
    byteSTr : RawByteString;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));

     Stream.ReadBuffer(len, sizeof(len));
     SetLength(byteStr, len);
     if len > 0 then
        stream.ReadBuffer( byteStr[1], len );
     Result := TCborByteString.Create( byteStr );
end;

function DecodeLongString( stream : TStream ) : TCborItem;
var len : word;
    opCode : byte;
    byteSTr : RawByteString;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));

     Stream.ReadBuffer(len, sizeof(len));
     RevertByteOrder(@len, sizeof(len));
     SetLength(byteStr, len);
     if len > 0 then
        stream.ReadBuffer( byteStr[1], len );
     Result := TCborByteString.Create( byteStr );
end;

function DecodeLongLongString( stream : TStream ) : TCborItem;
var len : Longword;
    opCode : byte;
    byteSTr : RawByteString;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));

     Stream.ReadBuffer(len, sizeof(len));
     RevertByteOrder(@len, sizeof(len));
     SetLength(byteStr, len);
     if len > 0 then
        stream.ReadBuffer( byteStr[1], len );
     Result := TCborByteString.Create( byteStr );
end;


function DecodeUINT64String( stream : TStream ) : TCborItem;
var len : UINT64;
    opCode : byte;
    byteSTr : RawByteString;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));

     Stream.ReadBuffer(len, sizeof(len));
     RevertByteOrder(@len, sizeof(len));
     SetLength(byteStr, len);
     if len > 0 then
        stream.ReadBuffer( byteStr[1], len );
     Result := TCborByteString.Create( byteStr );
end;


function DecodeChunkedString( stream : TStream ) : TCborItem;
var aItem : TCborByteString;
    opCode : byte;
    resByteStr : RawByteString;
begin
     stream.ReadBuffer( opCode, sizeof(opcode));

     while PeekFromStream( stream, opcode) <> cCborBreak do
     begin
          aItem := TCborDecoding.cborDecodeTbl[ opCode ]( stream ) as TCborByteString;

          resByteStr := resByteStr + aItem.fbyteStr;
          aItem.Free;
     end;

     stream.Seek(sizeof(Byte), soCurrent);
     Result := TCborByteString.Create( resByteStr );
end;

function DecodeUTF8ShortString( stream : TStream ) : TCborItem;
var len : integer;
    opCode : byte;
    byteSTr : UTF8String;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));

     len := opCode - $60;
     SetLength(byteStr, len);
     if len > 0 then
        stream.ReadBuffer( byteStr[1], len );
     Result := TCborUtf8String.Create( byteStr );
end;

function DecodeUTF8MediumString( stream : TStream ) : TCborItem;
var len : byte;
    opCode : byte;
    byteSTr : UTF8String;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));

     Stream.ReadBuffer(len, sizeof(len));
     SetLength(byteStr, len);
     if len > 0 then
        stream.ReadBuffer( byteStr[1], len );
     Result := TCborUtf8String.Create( byteStr );
end;

function DecodeUTF8LongString( stream : TStream ) : TCborItem;
var len : word;
    opCode : byte;
    byteSTr : UTF8String;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));

     Stream.ReadBuffer(len, sizeof(len));
     RevertByteOrder(@len, sizeof(len));
     SetLength(byteStr, len);
     if len > 0 then
        stream.ReadBuffer( byteStr[1], len );
     Result := TCborUtf8String.Create( byteStr );
end;

function DecodeUTF8LongLongString( stream : TStream ) : TCborItem;
var len : LongWord;
    opCode : byte;
    byteSTr : UTF8String;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));

     Stream.ReadBuffer(len, sizeof(len));
     RevertByteOrder(@len, sizeof(len));
     SetLength(byteStr, len);
     if len > 0 then
        stream.ReadBuffer( byteStr[1], len );
     Result := TCborUtf8String.Create( byteStr );
end;


function DecodeUTF8UINT64String( stream : TStream ) : TCborItem;
var len : UINT64;
    opCode : byte;
    byteSTr : UTF8String;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));

     Stream.ReadBuffer(len, sizeof(len));
     RevertByteOrder(@len, sizeof(len));
     SetLength(byteStr, len);
     if len > 0 then
        stream.ReadBuffer( byteStr[1], len );
     Result := TCborUtf8String.Create( byteStr );
end;


function DecodeUTFChunkedString( stream : TStream ) : TCborItem;
var aItem : TCborUtf8String;
    opCode : byte;
    resByteStr : UTF8String;
begin
     stream.ReadBuffer( opCode, sizeof(opcode));

     while PeekFromStream( stream, opcode) <> cCborBreak do
     begin
          aItem := TCborDecoding.cborDecodeTbl[ opCode ]( stream ) as TCborUTF8String;

          resByteStr := resByteStr + aItem.futfStr;
          aItem.Free;
     end;

     stream.Seek(sizeof(Byte), soCurrent);
     Result := TCborUtf8String.Create( resByteStr );
end;

function DecodeShortIntList( stream : TStream ) : TCborItem;
var opcode : byte;
    len : integer;
    i : integer;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));
     len := OpCode - $80;

     Result := TCborArr.Create;
     try
        for i := 0 to len - 1 do
            TCborArr( Result ).Add( TCborDecoding.cborDecodeTbl[ PeekFromStream(stream, opCode) ](stream) );
     except
           Result.Free;
           raise;
     end;
end;

function DecodeSmallIntList( stream : TStream ) : TCborItem;
var len : byte;
    i : integer;
    opCode : Byte;
begin
     stream.ReadBuffer(opCode, sizeof(opCode) );
     stream.ReadBuffer(len, sizeof(len));

     Result := TCborArr.Create;
     try
        for i := 0 to len - 1 do
            TCborArr(Result).Add( TCborDecoding.cborDecodeTbl[ PeekFromStream(stream, opCode) ](stream) );
     except
           Result.Free;
           raise;
     end;
end;

function DecodeMediumIntList( stream : TStream ) : TCborItem;
var len : word;
    i : integer;
    opCode : Byte;
begin
     stream.ReadBuffer(opCode, sizeof(opCode) );
     stream.ReadBuffer(len, sizeof(len));
     RevertByteOrder( @len, sizeof(len) );

     Result := TCborArr.Create;
     try
        for i := 0 to len - 1 do
            TCborArr(Result).Add( TCborDecoding.cborDecodeTbl[ PeekFromStream(stream, opCode) ](stream) );
     except
           Result.Free;
           raise;
     end;
end;

function DecodeLongIntList( stream : TStream ) : TCborItem;
var len : LongWord;
    i : integer;
    opCode : Byte;
begin
     stream.ReadBuffer(opCode, sizeof(opCode) );
     stream.ReadBuffer(len, sizeof(len));
     RevertByteOrder( @len, sizeof(len) );

     Result := TCborArr.Create;
     try
        for i := 0 to len - 1 do
            TCborArr(Result).Add( TCborDecoding.cborDecodeTbl[ PeekFromStream(stream, opCode) ](stream) );
     except
           Result.Free;
           raise;
     end;
end;

function DecodeLongLongIntList( stream : TStream ) : TCborItem;
var len : UInt64;
    opCode : Byte;
begin
     stream.ReadBuffer(opCode, sizeof(opCode) );
     stream.ReadBuffer(len, sizeof(len));
     RevertByteOrder( @len, sizeof(len) );

     Result := TCborArr.Create;
     try
        while len > 0 do
        begin
             TCborArr(Result).Add( TCborDecoding.cborDecodeTbl[ PeekFromStream(stream, opCode) ](stream) );
             dec(len);
        end;
     except
           Result.Free;
           raise;
     end;
end;

function DecodeChunkedIntList( stream : TStream ) : TCborItem;
var item : TCborItem;
    opCode : byte;
    i:Integer;
begin
     stream.ReadBuffer(opCode, sizeof(opCode) );

     Result := TCborArr.Create;
     try
        while PeekFromStream( stream, opCode ) <> cCBORBreak do
        begin
             item := TCborDecoding.cborDecodeTbl[ opCode ]( stream );

             if item.cborType in [majUnsignedInt, majNegInt]
             then
                 TCborArr(Result).Add(item)
             else if item.cborType = majArray then
             begin
                  for i := 0 to TCBorArr(item).farr.Count - 1 do
                      TCborArr(Result).Add( TCBorArr(item).farr[i]);

                  TCBorArr(item).farr.OwnsObjects := False;
                  item.Free;
             end
             else
             begin
                  item.Free;
                  raise ECborDecodeError.Create('Error decoding the array');
             end;
        end;

        // read the final break
        stream.ReadBuffer(opCode, sizeof(opCode));
     except
           Result.Free;
           raise;
     end;
end;

function DecodeShortMap( stream : TStream ) : TCborItem;
var opcode : byte;
    len : integer;
    i : integer;
    name, value : TCborItem;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));
     len := OpCode - $A0;

     Result := TCborMap.Create;
     try
        for i := 0 to len - 1 do
        begin
             name := nil;
             value := nil;
             try
                name := TCborDecoding.cborDecodeTbl[ PeekFromStream(stream, opCode) ](stream);
                value := TCborDecoding.cborDecodeTbl[ PeekFromStream(stream, opCode) ](stream)
             except
                   name.Free;
                   value.Free;

                   raise;
             end;

             TCborMap( Result ).Add( name, value );
        end;
     except
           Result.Free;
           raise;
     end;
end;

function DecodeSmallIntMap( stream : TStream ) : TCborItem;
var opcode : byte;
    len : byte;
    i : integer;
    name, value : TCborItem;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));
     stream.ReadBuffer(len, sizeof(len));

     Result := TCborMap.Create;
     if len > 0 then
     try
        for i := 0 to len - 1 do
        begin
             name := nil;
             value := nil;
             try
                name := TCborDecoding.cborDecodeTbl[ PeekFromStream(stream, opCode) ](stream);
                value := TCborDecoding.cborDecodeTbl[ PeekFromStream(stream, opCode) ](stream)
             except
                   name.Free;
                   value.Free;

                   raise;
             end;

             TCborMap( Result ).Add( name, value );
        end;
     except
           Result.Free;
           raise;
     end;
end;

function DecodeMediumMap( stream : TStream ) : TCborItem;
var opcode : byte;
    len : word;
    i : integer;
    name, value : TCborItem;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));
     stream.ReadBuffer(len, sizeof(len));
     RevertByteOrder(@len, sizeof(len));

     Result := TCborMap.Create;
     if len > 0 then
     try
        for i := 0 to len - 1 do
        begin
             name := nil;
             value := nil;
             try
                name := TCborDecoding.cborDecodeTbl[ PeekFromStream(stream, opCode) ](stream);
                value := TCborDecoding.cborDecodeTbl[ PeekFromStream(stream, opCode) ](stream)
             except
                   name.Free;
                   value.Free;

                   raise;
             end;

             TCborMap( Result ).Add( name, value );
        end;
     except
           Result.Free;
           raise;
     end;
end;

function DecodeLongMap( stream : TStream ) : TCborItem;
var opcode : byte;
    len : Longword;
    i : integer;
    name, value : TCborItem;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));
     stream.ReadBuffer(len, sizeof(len));
     RevertByteOrder(@len, sizeof(len));

     Result := TCborMap.Create;
     if len > 0 then
     try
        for i := 0 to len - 1 do
        begin
             name := nil;
             value := nil;
             try
                name := TCborDecoding.cborDecodeTbl[ PeekFromStream(stream, opCode) ](stream);
                value := TCborDecoding.cborDecodeTbl[ PeekFromStream(stream, opCode) ](stream)
             except
                   name.Free;
                   value.Free;

                   raise;
             end;

             TCborMap( Result ).Add( name, value );
        end;
     except
           Result.Free;
           raise;
     end;
end;

function DecodeLongLongMap( stream : TStream ) : TCborItem;
var opcode : byte;
    len : UInt64;
    i : integer;
    name, value : TCborItem;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));
     stream.ReadBuffer(len, sizeof(len));
     RevertByteOrder(@len, sizeof(len));

     Result := TCborMap.Create;
     if len > 0 then
     try
        for i := 0 to len - 1 do
        begin
             name := nil;
             value := nil;
             try
                name := TCborDecoding.cborDecodeTbl[ PeekFromStream(stream, opCode) ](stream);
                value := TCborDecoding.cborDecodeTbl[ PeekFromStream(stream, opCode) ](stream)
             except
                   name.Free;
                   value.Free;

                   raise;
             end;

             TCborMap( Result ).Add( name, value );
        end;
     except
           Result.Free;
           raise;
     end;
end;

function DecodeChunkedMap( stream : TStream ) : TCborItem;
var opCode : byte;
    name, value : TCborItem;
begin
     stream.ReadBuffer(opCode, sizeof(opcode));

     Result := TCborMap.Create;
     try
        while PeekFromStream(stream, opCode) <> cCBORBreak do
        begin
             name := TCborDecoding.cborDecodeTbl[ opCode ]( stream );
             PeekFromStream(stream, opCode);
             value := TCborDecoding.cborDecodeTbl[ opCode ]( stream );

             TCborMap(Result).Add(name, value);
        end;

        // read final break
        stream.ReadBuffer(opCode, sizeof(opcode));
     except
           Result.Free;
           raise;
     end;
end;

function DecodeTinyFloat( stream : TStream ) : TCborItem;
var opCode : Byte;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));
     Result := TCborFloat.Create( opcode and cCBORValMask);
end;

function DecodeTrueFalse( stream : TStream ) : TCBorItem;
var opCode : Byte;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));
     Result := TCborBoolean.Create( opCode = $F5 );
end;

function DecodeNULL( stream : TStream ) : TCborItem;
var opCode : Byte;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));
     Result := TCborNULL.Create;
end;

function DecodeTinySimpleVal( stream : TStream ) : TCborItem;
var opCode : Byte;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));
     Result := TCborSimpleValue.Create(opCode and cCBORValMask);
end;

function DecodeSimpleValue( stream : TStream ) : TCborItem;
var opCode : byte;
    val : byte;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));
     stream.ReadBuffer(val, sizeof(val) );
     Result := TCborSimpleValue.Create(val);
end;

function Decode16BitFloat( stream : TStream ) : TCborItem;
var opCode : byte;
    val : word;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));
     stream.ReadBuffer(val, sizeof(val) );
     RevertByteOrder(@val, sizeof(val));
     Result := TCborFloat.Create(HalfToFloat( val ) );
end;

function DecodeFloat( stream : TStream ) : TCborItem;
var opCode : byte;
    val : single;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));
     stream.ReadBuffer(val, sizeof(val) );
     RevertByteOrder(@val, sizeof(val));
     Result := TCborFloat.Create( val );
end;

function DecodeDouble( stream : TStream ) : TCborItem;
var opCode : byte;
    val : double;
begin
     stream.ReadBuffer(opCode, sizeof(opCode));
     stream.ReadBuffer(val, sizeof(val) );
     RevertByteOrder(@val, sizeof(val));
     Result := TCborFloat.Create( val );
end;


function NotImplemented( stream : TStream ) : TCborItem;
var buf : Byte;
begin
     raise ECBorNotImplmented.Create('Error code $' + IntToHex(PeekFromStream(stream, buf), 2) + ' + not implemented');
end;

// jump table as defined in the RFC
class procedure TCborDecoding.InitDecodeTable;
var i : integer;
begin
     if Assigned(TCborDecoding.cborDecodeTbl[0]) then
        exit;

     for i := 0 to High(TCborDecoding.cborDecodeTbl) do
         TCborDecoding.cborDecodeTbl[i] := NotImplemented;

     // int
     for i := 0 to $17 do
         TCborDecoding.cborDecodeTbl[i] := DecodeTinyUInt;
     TCborDecoding.cborDecodeTbl[$18] := DecodeByte;
     TCborDecoding.cborDecodeTbl[$19] := DecodeWord;
     TCborDecoding.cborDecodeTbl[$1A] := DecodeLongWord;
     TCborDecoding.cborDecodeTbl[$1B] := DecodeUINT64;

     // neg int
     for i := $20 to $37 do
         TCborDecoding.cborDecodeTbl[i] := DecodeTinyNegInt;
     TCborDecoding.cborDecodeTbl[$38] := DecodeNegByte;
     TCborDecoding.cborDecodeTbl[$39] := DecodeNegWord;
     TCborDecoding.cborDecodeTbl[$3A] := DecodeNegLongWord;
     TCborDecoding.cborDecodeTbl[$3B] := DecodeNegUINT64;

     // strings
     for i := $40 to $57 do
         TCborDecoding.cborDecodeTbl[i] := DecodeShortString;
     TCborDecoding.cborDecodeTbl[$58] := DecodeMediumString;
     TCborDecoding.cborDecodeTbl[$59] := DecodeLongString;
     TCborDecoding.cborDecodeTbl[$5A] := DecodeLongLongString;
     TCborDecoding.cborDecodeTbl[$5B] := DecodeUINT64String;
     TCborDecoding.cborDecodeTbl[$5F] := DecodeChunkedString;

     // utf8
     for i := $60 to $77 do
         TCborDecoding.cborDecodeTbl[i] := DecodeUTF8ShortString;
     TCborDecoding.cborDecodeTbl[$78] := DecodeUTF8MediumString;
     TCborDecoding.cborDecodeTbl[$79] := DecodeUTF8LongString;
     TCborDecoding.cborDecodeTbl[$7A] := DecodeUTF8LongLongString;
     TCborDecoding.cborDecodeTbl[$7B] := DecodeUTF8UINT64String;
     TCborDecoding.cborDecodeTbl[$7F] := DecodeUTFChunkedString;

     // int list
     for i := $80 to $97 do
         TCborDecoding.cborDecodeTbl[i] := DecodeShortIntList;
     TCborDecoding.cborDecodeTbl[$98] := DecodeSmallIntList;
     TCborDecoding.cborDecodeTbl[$99] := DecodeMediumIntList;
     TCborDecoding.cborDecodeTbl[$9A] := DecodeLongIntList;
     TCborDecoding.cborDecodeTbl[$9B] := DecodeLongLongIntList;
     TCborDecoding.cborDecodeTbl[$9F] := DecodeChunkedIntList;

     // maps
     for i := $A0 to $B7 do
         TCborDecoding.cborDecodeTbl[i] := DecodeShortMap;
     TCborDecoding.cborDecodeTbl[$B8] := DecodeSmallIntMap;
     TCborDecoding.cborDecodeTbl[$B9] := DecodeMediumMap;
     TCborDecoding.cborDecodeTbl[$BA] := DecodeLongMap;
     TCborDecoding.cborDecodeTbl[$BB] := DecodeLongLongMap;
     TCborDecoding.cborDecodeTbl[$BF] := DecodeChunkedMap;

     for i := $E0 to $F3 do
         TCborDecoding.cborDecodeTbl[i] := DecodeTinySimpleVal;
     TCborDecoding.cborDecodeTbl[$F4] := DecodeTrueFalse;
     TCborDecoding.cborDecodeTbl[$F5] := DecodeTrueFalse;
     TCborDecoding.cborDecodeTbl[$F6] := DecodeNULL;
     TCborDecoding.cborDecodeTbl[$F8] := DecodeSimpleValue;
     TCborDecoding.cborDecodeTbl[$F9] := Decode16BitFloat;
     TCborDecoding.cborDecodeTbl[$FA] := DecodeFloat;
     TCborDecoding.cborDecodeTbl[$FB] := DecodeDouble;
end;

(*
 +-----------------+-------------------------------------------------+
   | Byte            | Structure/Semantics                             |
   +-----------------+-------------------------------------------------+
   | 0x00..0x17      | Integer 0x00..0x17 (0..23)                      |
   |                 |                                                 |
   | 0x18            | Unsigned integer (one-byte uint8_t follows)     |
   |                 |                                                 |
   | 0x19            | Unsigned integer (two-byte uint16_t follows)    |
   |                 |                                                 |
   | 0x1a            | Unsigned integer (four-byte uint32_t follows)   |
   |                 |                                                 |
   | 0x1b            | Unsigned integer (eight-byte uint64_t follows)  |
   |                 |                                                 |
   | 0x20..0x37      | Negative integer -1-0x00..-1-0x17 (-1..-24)     |
   |                 |                                                 |
   | 0x38            | Negative integer -1-n (one-byte uint8_t for n   |
   |                 | follows)                                        |
   |                 |                                                 |
   | 0x39            | Negative integer -1-n (two-byte uint16_t for n  |
   |                 | follows)                                        |
   |                 |                                                 |
   | 0x3a            | Negative integer -1-n (four-byte uint32_t for n |
   |                 | follows)                                        |
   |                 |                                                 |
   | 0x3b            | Negative integer -1-n (eight-byte uint64_t for  |
   |                 | n follows)                                      |
   |                 |                                                 |
   | 0x40..0x57      | byte string (0x00..0x17 bytes follow)           |
   |                 |                                                 |
   | 0x58            | byte string (one-byte uint8_t for n, and then n |
   |                 | bytes follow)                                   |
   |                 |                                                 |
   | 0x59            | byte string (two-byte uint16_t for n, and then  |
   |                 | n bytes follow)                                 |



Bormann & Hoffman            Standards Track                   [Page 45]


RFC 7049                          CBOR                      October 2013


   |                 |                                                 |
   | 0x5a            | byte string (four-byte uint32_t for n, and then |
   |                 | n bytes follow)                                 |
   |                 |                                                 |
   | 0x5b            | byte string (eight-byte uint64_t for n, and     |
   |                 | then n bytes follow)                            |
   |                 |                                                 |
   | 0x5f            | byte string, byte strings follow, terminated by |
   |                 | "break"                                         |
   |                 |                                                 |
   | 0x60..0x77      | UTF-8 string (0x00..0x17 bytes follow)          |
   |                 |                                                 |
   | 0x78            | UTF-8 string (one-byte uint8_t for n, and then  |
   |                 | n bytes follow)                                 |
   |                 |                                                 |
   | 0x79            | UTF-8 string (two-byte uint16_t for n, and then |
   |                 | n bytes follow)                                 |
   |                 |                                                 |
   | 0x7a            | UTF-8 string (four-byte uint32_t for n, and     |
   |                 | then n bytes follow)                            |
   |                 |                                                 |
   | 0x7b            | UTF-8 string (eight-byte uint64_t for n, and    |
   |                 | then n bytes follow)                            |
   |                 |                                                 |
   | 0x7f            | UTF-8 string, UTF-8 strings follow, terminated  |
   |                 | by "break"                                      |
   |                 |                                                 |
   | 0x80..0x97      | array (0x00..0x17 data items follow)            |
   |                 |                                                 |
   | 0x98            | array (one-byte uint8_t for n, and then n data  |
   |                 | items follow)                                   |
   |                 |                                                 |
   | 0x99            | array (two-byte uint16_t for n, and then n data |
   |                 | items follow)                                   |
   |                 |                                                 |
   | 0x9a            | array (four-byte uint32_t for n, and then n     |
   |                 | data items follow)                              |
   |                 |                                                 |
   | 0x9b            | array (eight-byte uint64_t for n, and then n    |
   |                 | data items follow)                              |
   |                 |                                                 |
   | 0x9f            | array, data items follow, terminated by "break" |
   |                 |                                                 |
   | 0xa0..0xb7      | map (0x00..0x17 pairs of data items follow)     |
   |                 |                                                 |
   | 0xb8            | map (one-byte uint8_t for n, and then n pairs   |
   |                 | of data items follow)                           |
   |                 |                                                 |



Bormann & Hoffman            Standards Track                   [Page 46]


RFC 7049                          CBOR                      October 2013


   | 0xb9            | map (two-byte uint16_t for n, and then n pairs  |
   |                 | of data items follow)                           |
   |                 |                                                 |
   | 0xba            | map (four-byte uint32_t for n, and then n pairs |
   |                 | of data items follow)                           |
   |                 |                                                 |
   | 0xbb            | map (eight-byte uint64_t for n, and then n      |
   |                 | pairs of data items follow)                     |
   |                 |                                                 |
   | 0xbf            | map, pairs of data items follow, terminated by  |
   |                 | "break"                                         |
   |                 |                                                 |
   | 0xc0            | Text-based date/time (data item follows; see    |
   |                 | Section 2.4.1)                                  |
   |                 |                                                 |
   | 0xc1            | Epoch-based date/time (data item follows; see   |
   |                 | Section 2.4.1)                                  |
   |                 |                                                 |
   | 0xc2            | Positive bignum (data item "byte string"        |
   |                 | follows)                                        |
   |                 |                                                 |
   | 0xc3            | Negative bignum (data item "byte string"        |
   |                 | follows)                                        |
   |                 |                                                 |
   | 0xc4            | Decimal Fraction (data item "array" follows;    |
   |                 | see Section 2.4.3)                              |
   |                 |                                                 |
   | 0xc5            | Bigfloat (data item "array" follows; see        |
   |                 | Section 2.4.3)                                  |
   |                 |                                                 |
   | 0xc6..0xd4      | (tagged item)                                   |
   |                 |                                                 |
   | 0xd5..0xd7      | Expected Conversion (data item follows; see     |
   |                 | Section 2.4.4.2)                                |
   |                 |                                                 |
   | 0xd8..0xdb      | (more tagged items, 1/2/4/8 bytes and then a    |
   |                 | data item follow)                               |
   |                 |                                                 |
   | 0xe0..0xf3      | (simple value)                                  |
   |                 |                                                 |
   | 0xf4            | False                                           |
   |                 |                                                 |
   | 0xf5            | True                                            |
   |                 |                                                 |
   | 0xf6            | Null                                            |
   |                 |                                                 |
   | 0xf7            | Undefined                                       |
   |                 |                                                 |



Bormann & Hoffman            Standards Track                   [Page 47]


RFC 7049                          CBOR                      October 2013


   | 0xf8            | (simple value, one byte follows)                |
   |                 |                                                 |
   | 0xf9            | Half-Precision Float (two-byte IEEE 754)        |
   |                 |                                                 |
   | 0xfa            | Single-Precision Float (four-byte IEEE 754)     |
   |                 |                                                 |
   | 0xfb            | Double-Precision Float (eight-byte IEEE 754)    |
   |                 |                                                 |
   | 0xff            | "break" stop code                               |
   +-----------------+-------------------------------------------------+
   *)
end.
