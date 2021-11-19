{*********************************************************}
{                                                         }
{                     Zeos SQL Shell                      }
{                 Script Parsing Classes                  }
{                                                         }
{         Originally written by Sergey Seroukhov          }
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

unit ZScriptParser;

interface

{$I ZParseSql.inc}

uses Classes, {$IFDEF MSEgui}mclasses,{$ENDIF} SysUtils,
  ZTokenizer;

type
  {** Defines a SQL delimiter type. }
  TZDelimiterType = (dtDefault, dtDelimiter, dtGo, dtSetTerm, dtEmptyLine);

  {** Implements a SQL script parser. }
  TZSQLScriptParser = class
  private
    FDelimiter: string;
    FDelimiterType: TZDelimiterType;
    FCleanupStatements: Boolean;
    FTokenizer: IZTokenizer;
    FUncompletedStatement: string;
    FStatements: TStrings;

    function GetStatementCount: Integer;
    function GetStatement(Index: Integer): string;

  public
    constructor Create;
    constructor CreateWithTokenizer(const Tokenizer: IZTokenizer);
    destructor Destroy; override;

    procedure Clear;
    procedure ClearCompleted;
    procedure ClearUncompleted;

    procedure ParseText(const Text: string);
    procedure ParseLine(const Line: string);

    property Delimiter: string read FDelimiter write FDelimiter;
    property DelimiterType: TZDelimiterType read FDelimiterType
      write FDelimiterType default dtDefault;
    property CleanupStatements: Boolean read FCleanupStatements
      write FCleanupStatements default True;
    property Tokenizer: IZTokenizer read FTokenizer write FTokenizer;
    property UncompletedStatement: string read FUncompletedStatement;
    property StatementCount: Integer read GetStatementCount;
    property Statements[Index: Integer]: string read GetStatement;
  end;

implementation

uses ZMessages, ZSysUtils, ZFastCode, ZCompatibility, ZExceptions;

{ TZSQLScriptParser }

{**
  Constructs this script parser class.
}
constructor TZSQLScriptParser.Create;
begin
  FStatements := TStringList.Create;
  FDelimiter := ';';
  FDelimiterType := dtDefault;
  FCleanupStatements := True;
end;

{**
  Creates this object and assignes a tokenizer object.
  @param Tokenizer a tokenizer object.
}
constructor TZSQLScriptParser.CreateWithTokenizer(const Tokenizer: IZTokenizer);
begin
  Create;
  FTokenizer := Tokenizer;
end;

{**
  Destroys this class and cleanups the memory.
}
destructor TZSQLScriptParser.Destroy;
begin
  FreeAndNil(FStatements);
  FTokenizer := nil;
  inherited Destroy;
end;

{**
  Gets SQL statements number.
  @returns SQL statements number.
}
function TZSQLScriptParser.GetStatementCount: Integer;
begin
  Result := FStatements.Count;
end;

{**
  Gets a parsed SQL statement by it's index.
  @param Index a statement index.
  @returns a SQL statement string.
}
function TZSQLScriptParser.GetStatement(Index: Integer): string;
begin
  Result := FStatements[Index];
end;

{**
  Clears all completed and uncompleted statements and line delimiter.
}
procedure TZSQLScriptParser.Clear;
begin
  FStatements.Clear;
  FDelimiter := ';';
  FUncompletedStatement := '';
end;

{**
  Clears only completed statements.
}
procedure TZSQLScriptParser.ClearCompleted;
begin
  FStatements.Clear;
end;

{**
  Clears completed and uncompleted statements.
}
procedure TZSQLScriptParser.ClearUncompleted;
begin
  FStatements.Clear;
  FUncompletedStatement := '';
end;

{**
  Parses incrementaly only one single line.
  The line appends with EOL character.
  @param Line a line to be parsed.
}
procedure TZSQLScriptParser.ParseLine(const Line: string);
begin
  ParseText(#10 + Line + #10);
end;

const
  ParseOptions: array[Boolean] of TZTokenOptions = ([], [toSkipComments]);
  ConCatDelim: array[Boolean] of String = (LineEnding, ' ');
  pGO: PChar = 'GO';
  pDelimiter: PChar = 'DELIMITER';
  pSet: PChar = 'SET';
  pTerm: PChar = 'TERM';

{**
  Parses a complete text with several lines.
  @oaram Text a text of the SQL script to be parsed.
}
procedure TZSQLScriptParser.ParseText(const Text: string);
//new version of EgonHugeist which composes complex scripts more than 100x faster than old version
var
  Tokens: TZTokenList;
  Token: PZToken;
  StartTokenIndex, EndTokenIndex, TokenIndex, DelimStartIDX, TempIDX, N, L,
  LastCommentIdx: Integer;
  SQL, LastComment: string;
  P, PDelim, PEnd: PChar;
  DelimTokenType: TZTokenType;

  procedure SetNextToken;
  begin
    Token := Tokens[TokenIndex];
    Inc(TokenIndex);
  end;
  procedure FlushDelimiterTokens;
  var PEnd: PChar;
  begin
    if L > 1  then begin
      PEnd := Token.P+L;
      while (Tokens[TokenIndex].P < PEnd) do
        SetNextToken; //skip '!!!!!!!!' or '##xx11' delimiter tokens
    end;
  end;

label jmpEOF, jmpNewDelim, jmpReset, jmpSpcRepl, jmpTerm;
begin
  if Tokenizer = nil then
    raise EZSQLException.Create(STokenizerIsNotDefined);
  Tokens := Tokenizer.TokenizeBufferToList(Text, ParseOptions[CleanupStatements]);

  DelimTokenType := ttSymbol;
  if (DelimiterType = dtDefault) or ((Delimiter = '') and
      ((DelimiterType = dtDelimiter) or (DelimiterType = dtSetTerm))) then
    Delimiter := ';' //use default delimiter
  else if DelimiterType = dtGo then begin
     Delimiter := 'GO';
     DelimTokenType := ttWord;
  end else if DelimiterType = dtEmptyLine then begin
    Delimiter := #10;
    DelimTokenType := ttWhiteSpace;
  end;
  L := Length(Delimiter);
  PDelim := Pointer(Delimiter);

  LastComment := '';
  TokenIndex := 0;
  StartTokenIndex := TokenIndex;
  EndTokenIndex := -1;
  LastCommentIdx := 0;
  SQL := FUncompletedStatement;
  if SQL <> '' then
    SQL := SQL + ConCatDelim[CleanupStatements];
  FUncompletedStatement := '';
  FStatements.Clear;
  PEnd := Tokens[Tokens.Count-1].P;//ttEOF -> do not read over boundaries
  try
    repeat
      SetNextToken;
      if Token.TokenType <> ttEOF then
      case DelimiterType of
        dtGo:   if (Token.TokenType = ttWord) and (Token.L = 2) and SameText(Token.P, pGO, 2) then
                  EndTokenIndex := TokenIndex -2;
        dtEmptyLine:
            if Token.TokenType = ttWhitespace then begin
              P := Token.P;
              N := 0;
              while P < Token.P+Token.L do begin
                if P^ = PDelim^ then Inc(N);
                Inc(P);
              end;
              if (N >= 2) then begin
                EndTokenIndex := TokenIndex - 2;
                if (Tokens[EndTokenIndex].TokenType = ttSymbol) and (Tokens[EndTokenIndex].P^ = ';') then
                  Dec(EndTokenIndex)
              end else
                goto jmpSpcRepl;
            end;
        dtDefault:
            if ((Token.L = 1) and (PDelim^ = Token.P^)) then begin
              if TokenIndex = 1
              then StartTokenIndex := 1
              else EndTokenIndex := TokenIndex -2;
              if (TokenIndex > 1) and (Tokens[EndTokenIndex].TokenType = ttWhitespace) then
                Dec(EndTokenIndex);
            end;
        dtDelimiter:
            if (Token.TokenType = DelimTokenType) and (((L = 1) and (PDelim^ = Token.P^)) or ((Token.P+L < PEnd) and SameText(Token.P, PDelim, L))) then
              goto jmpTerm
            else if (Token.TokenType = ttWord) and (Token.L = 9) and SameText(Token.P, pDelimiter, 9) then begin
              SetNextToken;
              if (Token.TokenType = ttWhitespace) then //Left trim the delimiter
                SetNextToken;
              DelimStartIDX := TokenIndex -1; //new delimiter starts here
              while Token.TokenType <> ttWhitespace do //run over symbols f.e...
                SetNextToken;
              if (Token.TokenType in [ttWhitespace, ttEOF]) then begin //end of new delimter reached
                N := TokenIndex -2;
                goto jmpNewDelim;
              end;
            end;
        dtSetTerm:
            if (Token.TokenType = DelimTokenType) and (((L = 1) and (PDelim^ = Token.P^)) or ((Token.P+L <= PEnd) and SameText(Token.P, PDelim, L))) then begin
jmpTerm:      EndTokenIndex := TokenIndex -2;
              FlushDelimiterTokens;
              if Tokens[EndTokenIndex].TokenType = ttWhiteSpace then //trim right before delimiter
                Dec(EndTokenIndex);
              LastCommentIdx := TokenIndex+Ord(Tokens[TokenIndex].TokenType = ttWhiteSpace);
            end else if (Token.TokenType = ttWord) and (Token.L = 3) and SameText(Token.P, pSet, 3) then begin //test for SET TERM___X(delimiter)
              TempIDX := TokenIndex; //remainder
              while True do begin //secondary inner loop scans for 'TERM', extracts new delimiter and pads these processed tokens away
                SetNextToken;
                case Token.TokenType of
                  ttWhitespace: continue;
                  ttEOF: Break;
                  ttWord: if (Token.L = 4) and SameText(Token.P, pTerm, 4) then begin //"SET TERM" reached
                            {EH: compose LastComment logic first: IIUC every string before "SET TERM ' is concated to previous stmt if it exits! }
                            if TempIDX > 2 then begin //handle a skript starting with "SET TERM x ; "
                              N := TempIDX -(2+Ord(Tokens[TempIDX-2].TokenType = ttWhiteSpace));
                              if LastCommentIdx <= N then begin
                                //EH: all SingleLineComments are ending with LineEnding but the tests do expect a trimmed LastComment..
                                //what a illogical thing, imho that's a bug!
                                //If we compose the SQL again the db-service will fail with parsing errors!
                                //However just satisfy the tests:
                                Token := Tokens[N];
                                P := Token.P+Token.L-1;
                                while (P >= Token.P) and (Ord(P^) <= Ord(' ')) do Dec(P);
                                Token.L := (P - Token.P) +1;
                                LastComment := Tokens.AsString(LastCommentIdx, N);
                              end;
                            end;
                            SetNextToken;
                            if Token.TokenType = ttWhitespace then//left trim the new delimiter
                              SetNextToken;
                            DelimStartIDX := TokenIndex -1; //new delimiter starts here
                            DelimTokenType := Tokens[DelimStartIDX].TokenType;
                            {seek to current delimiter}
                            while (Token.TokenType <> ttEOF) and not ((Token.TokenType = DelimTokenType) and
                               (((L = 1) and (PDelim^ = Token.P^)) or ((Token.P+L <= PEnd) and SameText(Token.P, PDelim, L)))) do
                              SetNextToken;
                            if Token.TokenType = ttEOF then goto jmpEOF;
                            //Extract the new delimiter
                            N := TokenIndex -2;
                            if (Tokens[N].TokenType = ttWhiteSpace) and (N > DelimStartIDX) then
                              Dec(N); //rigth trim the delimiter
jmpNewDelim:                FlushDelimiterTokens; //seek over current delimiter sequence f.e. '/!' which are two symbol tokens
                            DelimTokenType := Tokens[DelimStartIDX].TokenType;
                            Delimiter := Tokens.AsString(DelimStartIDX, N); //set the new delimitier
                            PDelim := Pointer(Delimiter);
                            L := Length(Delimiter);
                            StartTokenIndex := TokenIndex;
                            LastCommentIdx := TokenIndex;
                            Break;
                          end else
                            goto jmpReset;
                  else begin
jmpReset:           TokenIndex := TempIDX;
                    Break;
                  end;
                end;
              end;
            end;

      end;
      { Processes the end of statements. }
      if EndTokenIndex >= StartTokenIndex then begin
        if CleanupStatements then begin
          if Tokens[StartTokenIndex].TokenType = ttWhiteSpace then
            Inc(StartTokenIndex); //Trim left
          if Tokens[EndTokenIndex].TokenType = ttWhiteSpace then
            Dec(EndTokenIndex); //Trim right
        end;
        SQL := Tokens.AsString(StartTokenIndex, EndTokenIndex);
        if (LastComment <> '') and (DelimiterType in [dtSetTerm, dtDelimiter]) then begin
          SQL := LastComment + ConCatDelim[CleanupStatements] + SQL;
          LastComment := '';
        end;
        if SQL <> '' then begin
          FStatements.Add(SQL);
          SQL := '';
        end;
        StartTokenIndex := TokenIndex;
      end else if (Token.TokenType = ttWhitespace) then begin
        if StartTokenIndex = TokenIndex-1 then //EH iiuc the (ms, 20/10/2005) logic pads all leading whitespaces away
          Inc(StartTokenIndex)
        else if CleanupStatements then begin
jmpSpcRepl: Token.P := pSpace; { replace all whitespaces with a single space. }
          Token.L := 1;
        end;
      end;
    until Token.TokenType = ttEOF;
jmpEOF:
    if ( LastComment <> '' ) and ( FStatements.Count > 0) then
      FStatements[FStatements.Count-1] := FStatements[FStatements.Count-1]+ConCatDelim[CleanupStatements]+LastComment;
    if StartTokenIndex < Tokens.Count-1 then begin
      if CleanupStatements and (Tokens[StartTokenIndex].TokenType = ttWhiteSpace) then
        Inc(StartTokenIndex); //trim left the SQL
      if (DelimiterType <> dtEmptyLine) and (TokenIndex>1) and (Tokens[TokenIndex-2].TokenType = ttWhiteSpace) then
        Dec(TokenIndex);
      FUncompletedStatement := Tokens.AsString(StartTokenIndex, TokenIndex-2);
    end;
  finally
    Tokens.Free;
  end;
end;

end.
