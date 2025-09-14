unit zeosproxy_cbor_imp;

{$mode Delphi}{$H+}

interface

uses
  Classes, SysUtils, httpdefs;

type
  TZDbcProxyCborImp = class
  protected
    procedure ExecuteCborQuery(ARequest: TRequest; AResponse: TResponse);
  public
    function OnCustomRequest(ARequest  : TRequest;
          AResponse : TResponse;
          APath     : String
    ): Boolean;
  end;

var
  CborImp: TZDbcProxyCborImp;

implementation

uses zeosproxy_imp, dom, XMLRead, ZDbcIntfs, DbcProxyUtils, ZCbor, ZDbcXmlUtils, FmtBCD, ZExceptions;

const
  ZCborChangedRows = 1;
  ZCborResultSet = 2;
  ZCborError = 3;

procedure encodeException(E: Exception; Target: TStream); forward;
procedure encodeResultSet(ResultSet: IZResultSet; Target: TStream); forward;
procedure encodeChangedRows(RowCount: Integer; Target: TStream); forward;
function encodeResultSetMetadata(ResultSet: IZResultSet): TCborItem; forward;
function encodeResultSetData(ResultSet: IZResultSet): TCborItem; forward;

function TZDbcProxyCborImp.OnCustomRequest(ARequest  : TRequest;
      AResponse : TResponse;
      APath     : String
): Boolean;
begin
  Result := false;
  if ARequest.URL.StartsWith('/ZeosProxy/') then begin
    if ARequest.URL = '/ZeosProxy/cborquery' then begin
      ExecuteCborQuery(ARequest, AResponse);
      Result := True;
    end else begin
      AResponse.Code := 404;
      AResponse.CodeText := 'Page not found';
      AResponse.Content:='<html><body><h1>404 Page not found.</h1></body></html>';
      AResponse.ContentType := 'text/html';
      Result := True;
    end;
  end;
end;

procedure TZDbcProxyCborImp.ExecuteCborQuery(ARequest: TRequest; AResponse: TResponse);
var
  ConnectionID: String;
  XMLDoc: TXMLDocument;
  XMLStream: TStringStream;
  DocNode: TDOMNode;
  x: Integer;
  SQLNode: TDOMNode;
  ParamsNode: TDOMNode;
  NodeName: String;
  Statement: IZPreparedStatement;
  ResultSet: IZResultSet;
  SQL, Query: String;
  Res: TMemoryStream;
begin
  ParamsNode := nil;
  SQLNode := nil;
  try
    ConnectionID := ARequest.Authorization; //Trim(ARequest.CustomHeaders.Values['Authorization']);
    if not ConnectionID.StartsWith('bearer ', true) then
      raise Exception.Create('Authentication is not of type BEARER');
    Delete(ConnectionID, 1, 7);

    with ConnectionManager.LockConnection(ConnectionID) do
    try
      Query := ARequest.Content;
      XMLStream := TStringStream.Create(Query);
      XMLRead.ReadXMLFile(XMLDoc, XMLStream);
      DocNode := XMLDoc.GetChildNodes.Item[0];
      for x := 0 to DocNode.ChildNodes.Count - 1 do begin
        NodeName := LowerCase(UTF8Encode(DocNode.ChildNodes[x].NodeName));
        if NodeName = 'sql' then
          SQLNode := DocNode.ChildNodes[x]
        else if NodeName = 'params' then
          ParamsNode := DocNode.ChildNodes[x];
      end;
      if not Assigned(SQLNode) then
        raise Exception.Create('No SQL node found!');
      {if not Assigned(ParamsNode) then
        raise Exception.Create('No PARAMS node found!');}

      SQL := UTF8Encode(SQLNode.TextContent);
      Statement := ZeosConnection.PrepareStatementWithParams(SQL, nil);
      if Assigned(ParamsNode) then
        decodeParameters(ParamsNode, Statement);
      AResponse.ContentType := 'application/cbor';
      Res := TMemoryStream.Create;
      try
        if Statement.ExecutePrepared then begin
          ResultSet := Statement.GetResultSet;
          if Assigned(ResultSet) then begin
            encodeResultSet(ResultSet, Res);
          end else begin
            encodeChangedRows(Statement.GetUpdateCount, Res);
          end;
        end else
          encodeChangedRows(Statement.GetUpdateCount, Res);
      except
        FreeAndNil(Res);
        raise;
      end;
      AResponse.ContentStream := Res;
    finally
      Unlock;

      if Assigned(ResultSet) then
        ResultSet := nil;
      if Assigned(Statement) then
        Statement := nil;
      if Assigned(ParamsNode) then
        ParamsNode := nil;
      if Assigned(SQLNode) then
        SQLNode := nil;
      if Assigned(DocNode) then
        DocNode := nil;
      if Assigned(XMLDoc) then
        FreeAndNil(XMLDoc);
    end;
    AuditLogger.LogLine('ExecuteStatement');
    AuditLogger.LogLine(String(SQL));
  except
    on E: Exception do begin
      Res := TMemoryStream.Create;
      try
        encodeException(E, AResponse.ContentStream);
        AResponse.ContentStream := Res;
        AResponse.ContentType := 'application/cbor';
      except
        FreeAndNil(Res);
        raise;
      end;
    end;
  end;
end;

procedure encodeException(E: Exception; Target: TStream);
var
  EncList: TCborArr;
begin
  EncList := TCborArr.Create;
  try
    EncList.Add(TCborUINTItem.Create(ZCborError));
    EncList.Add(TCborUtf8String.Create(E.Message));
    EncList.CBOREncode(Target);
  finally
    FreeAndNil(EncList);
  end;
end;

procedure encodeResultSet(ResultSet: IZResultSet; Target: TStream);
var
  EncList: TCborArr;

begin
  EncList := TCborArr.Create;
  try
    EncList.Add(TCborUINTItem.Create(ZCborResultSet));
    EncList.Add(encodeResultSetMetadata(ResultSet));
    EncList.Add(encodeResultSetData(ResultSet));
    EncList.CBOREncode(Target);
  finally
    FreeAndNil(EncList);
  end;
end;

procedure encodeChangedRows(RowCount: Integer; Target: TStream);
var
  EncList: TCborArr;
begin
  EncList := TCborArr.Create;
  try
    EncList.Add(TCborUINTItem.Create(ZCborChangedRows));
    EncList.Add(TCborUINTItem.Create(RowCount));
    EncList.CBOREncode(Target);
  finally
    FreeAndNil(EncList);
  end;
end;

function encodeResultSetMetadata(ResultSet: IZResultSet): TCborItem;
var
  EncList: TCborArr;
  ColInfo: TCborArr;
  MD: IZResultSetMetadata;
  x: Integer;
begin
  EncList := TCborArr.Create;
  try
    MD := ResultSet.GetMetadata;
    for x := FirstDbcIndex to MD.GetColumnCount - 1 + FirstDbcIndex do begin
      ColInfo := TCborArr.Create;
      ColInfo.Add(TCborUtf8String.Create(MD.GetCatalogName(x)));
      ColInfo.Add(TCborUINTItem.Create(MD.GetColumnCodePage(x)));
      ColInfo.Add(TCborUtf8String.Create(MD.GetColumnLabel(x)));
      ColInfo.Add(TCborUtf8String.Create(MD.GetColumnName(x)));
      ColInfo.Add(TCborUINTItem.Create(Ord(MD.GetColumnType(x))));
      ColInfo.Add(TCborUtf8String.Create(MD.GetDefaultValue(x)));
      ColInfo.Add(TCborUINTItem.Create(MD.GetPrecision(x)));
      ColInfo.Add(TCborUINTItem.Create(MD.GetScale(x)));
      ColInfo.Add(TCborUtf8String.Create(MD.GetSchemaName(x)));
      ColInfo.Add(TCborUtf8String.Create(MD.GetTableName(x)));
      ColInfo.Add(TCborBoolean.Create(MD.HasDefaultValue(x)));
      ColInfo.Add(TCborBoolean.Create(MD.IsAutoIncrement(x)));
      ColInfo.Add(TCborBoolean.Create(MD.IsCaseSensitive(x)));
      ColInfo.Add(TCborBoolean.Create(MD.IsCurrency(x)));
      ColInfo.Add(TCborBoolean.Create(MD.IsDefinitelyWritable(x)));
      ColInfo.Add(TCborUINTItem.Create(Ord(MD.IsNullable(x))));
      ColInfo.Add(TCborBoolean.Create(MD.IsReadOnly(x)));
      ColInfo.Add(TCborBoolean.Create(MD.IsSearchable(x)));
      ColInfo.Add(TCborBoolean.Create(MD.IsSigned(x)));
      ColInfo.Add(TCborBoolean.Create(MD.IsWritable(x)));
      EncList.Add(ColInfo);
      ColInfo := nil;
    end;
  except
    if Assigned(ColInfo) then
      FreeAndNil(ColInfo);
    FreeAndNil(EncList);
    raise;
  end;
  Result := EncList;
end;

function encodeResultSetData(ResultSet: IZResultSet): TCborItem;
var
  EncList: TCborArr;
  Row: TCborArr;
  x: Integer;
  LongVal: Int64;
  BCD: tBCD;
  Item: TCborItem;
begin
  EncList := TCborArr.Create;
  try
    while ResultSet.Next and not ResultSet.IsAfterLast do begin
      Row := TCborArr.Create;
      for x := 0 to ResultSet.GetColumnCount - 1 do begin
        if ResultSet.IsNull(x) then
          Row.Add(TCborNULL.Create)
        else begin
          case ResultSet.GetMetadata.GetColumnType(x) of
            stBoolean:
              Row.Add(TCborBoolean.Create(ResultSet.GetBoolean(x)));
            stByte, stWord, stLongWord, stULong:
              Row.Add(TCborUINTItem.Create(ResultSet.GetULong(x)));
            stShort, stSmall, stInteger, stLong: begin
              LongVal := ResultSet.GetLong(x);
              if LongVal < 0 then
                Row.Add(TCborNegIntItem.Create(LongVal))
              else
                Row.Add(TCborUINTItem.Create(LongVal));
            end;
            stFloat, stDouble:
              Row.Add(TCborFloat.Create(ResultSet.GetDouble(x)));
            stBigDecimal, stCurrency:
              if ResultSet.GetMetadata.GetPrecision(x) > 15 then begin
                ResultSet.GetBigDecimal(x, BCD);
                Row.Add(TCborUtf8String.Create(BCDToStr(BCD, ZXmlProxyFormatSettings)));
              end else
                Row.Add(TCborFloat.Create(ResultSet.GetDouble(x)));
            stString, stUnicodeString, stAsciiStream, stUnicodeStream: begin
                Item := TCborUtf8String.Create(ResultSet.GetUTF8String(x));
                Row.Add(Item);
              end;
            stDate, stTime, stTimestamp:
              Row.Add(TCborFloat.Create(ResultSet.GetTimestamp(x)));
            stBinaryStream, stBytes:
              Row.Add(TCborByteString.Create(ResultSet.GetRawByteString(x)));
          else
            raise Exception.Create('Encoding of type ' + ResultSet.GetMetadata.GetColumnTypeName(x) + ' is not supported (yet).');
          end;
        end;
      end;
      EncList.Add(Row);
      Row := nil;
    end;
  except
    if Assigned(Row) then
      FreeAndNil(Row);
    FreeAndNil(EncList);
  end;
  Result := EncList;
end;

end.

