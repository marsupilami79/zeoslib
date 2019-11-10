{*********************************************************}
{                                                         }
{                 Zeos Database Objects                   }
{           Database Connectivity Interfaces              }
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

unit ZDbcIntfs;

interface

{$I ZDbc.inc}
{$Z-}

uses
  {$IFDEF USE_SYNCOMMONS}
  SynCommons, SynTable,
  {$ENDIF USE_SYNCOMMONS}
  FmtBcd, Types, Classes, SysUtils,
  {$IFDEF FPC}syncobjs{$ELSE}SyncObjs{$ENDIF},
  ZClasses, ZCollections, ZCompatibility, ZTokenizer, ZSelectSchema,
  ZGenericSqlAnalyser, ZDbcLogging, ZVariant, ZPlainDriver, ZURL;

const
  { generic constant for first column/parameter index }
  FirstDbcIndex = {$IFDEF GENERIC_INDEX}0{$ELSE}1{$ENDIF};
  { generic constant for invalid column/parameter index }
  InvalidDbcIndex = {$IFDEF GENERIC_INDEX}-1{$ELSE}0{$ENDIF};
const
  { Constants from JDBC DatabaseMetadata }
  TypeSearchable           = 3;
  ProcedureReturnsResult   = 2;

// Data types
type
  /// <summary>
  ///  Defines supported SQL types.
  /// </summary>
  TZSQLType = (stUnknown,
    //fixed size DataTypes first
    stBoolean,
    stByte, stShort, stWord, stSmall, stLongWord, stInteger, stULong, stLong,  //ordinals
    stFloat, stDouble, stCurrency, stBigDecimal, //floats
    stDate, stTime, stTimestamp,
    stGUID,
    //now varying size types in equal order
    stString, stUnicodeString, stBytes,
    stAsciiStream, stUnicodeStream, stBinaryStream,
    //finally the object types
    stArray, stDataSet);

  TZSQLTypeArray = array of TZSQLType;

  /// <summary>
  ///  Defines a transaction isolation level.
  /// </summary>
  TZTransactIsolationLevel = (tiNone, tiReadUncommitted, tiReadCommitted,
    tiRepeatableRead, tiSerializable);

  TZSupportedTransactIsolationLevels = set of TZTransactIsolationLevel;

  /// <summary>
  ///  Defines a resultset fetch direction.
  /// </summary>
  TZFetchDirection = (fdForward, fdReverse, fdUnknown);

  /// <summary>
  ///  Defines a type of result set.
  /// </summary>
  TZResultSetType = (rtForwardOnly, rtScrollInsensitive, rtScrollSensitive);

  /// <summary>
  ///  Defines a result set concurrency type.
  /// </summary>
  TZResultSetConcurrency = (rcReadOnly, rcUpdatable);

  /// <summary>
  ///  Defines a nullable type for the column.
  /// </summary>
  TZColumnNullableType = (ntNoNulls, ntNullable, ntNullableUnknown);

  /// <summary>
  ///  Defines a nullable type for the column.
  /// </summary>
  TZProcedureResultType = (prtUnknown, prtNoResult, prtReturnsResult);

  /// <summary>
  ///  Defines a column type for the procedures.
  /// </summary>
  TZProcedureColumnType = (pctUnknown, pctIn, pctInOut, pctOut, pctReturn,
    pctResultSet);

  /// <summary>
  ///  Defines a dynamic array of column types for the procedures.
  /// </summary>
  TZProcedureColumnTypeDynArray = array of TZProcedureColumnType;

  /// <summary>
  ///  Defines a best row identifier.
  /// </summary>
  TZBestRowIdentifier = (brUnknown, brNotPseudo, brPseudo);

  /// <summary>
  ///  Defines a scope best row identifier.
  /// </summary>
  TZScopeBestRowIdentifier = (sbrTemporary, sbrTransaction, sbrSession);

  /// <summary>
  ///  Defines a version column.
  /// </summary>
  TZVersionColumn = (vcUnknown, vcNotPseudo, vcPseudo);

  TZImportedKey = (ikCascade, ikRestrict, ikSetNull, ikNoAction, ikSetDefault,
    ikInitiallyDeferred, ikInitiallyImmediate, ikNotDeferrable);

  TZTableIndex = (tiStatistic, tiClustered, tiHashed, tiOther);

  /// <summary>
  ///   Defines a post update mode.
  /// </summary>
  TZPostUpdatesMode = (poColumnsAll, poColumnsChanged);

  /// <summary>
  ///   Defines a locate mode.
  /// </summary>
  TZLocateUpdatesMode = (loWhereAll, loWhereChanged, loWhereKeyOnly);

  /// <summary>
  ///   Defines a MoreResults state.
  /// </summary>
  TZMoreResultsIndicator = (mriUnknown, mriHasNoMoreResults, mriHasMoreResults);

  /// <summary>
  ///  Defines the server type.
  /// </summary>
  TZServerProvider = (spUnknown, spMSSQL, spMSJet, spOracle, spSybase,
    spPostgreSQL, spIB_FB, spMySQL, spNexusDB, spSQLite, spDB2, spAS400,
    spInformix, spCUBRID, spFoxPro);

  /// <summary>
  ///   Generic connection lost exception.
  /// </summary>
  EZSQLConnectionLost = class(EZSQLException);

  TOnConnectionLostError = procedure(var AError: EZSQLConnectionLost) of Object;

  //TZTimeType = (ttTime, ttDate, ttDateTime, ttInterval);

// Interfaces
type

  // Forward declarations
  IZDriverManager = interface;
  IZDriver = interface;
  IZConnection = interface;
  IZDatabaseMetadata = interface;
  IZDatabaseInfo = interface;
  IZStatement = interface;
  IZPreparedStatement = interface;
  IZCallableStatement = interface;
  IZResultSet = interface;
  IZResultSetMetadata = interface;
  IZBlob = interface;
  IZClob = interface;
  IZNotification = interface;
  IZSequence = interface;
  IZDataSet = interface;

  /// <summary>
  ///   Driver Manager interface.
  /// </summary>
  IZDriverManager = interface(IZInterface)
    ['{8874B9AA-068A-4C0C-AE75-9DB1EA9E3720}']
    /// <summary>
    ///  Locates a required driver and opens a connection to the specified database.
    /// </summary>
    /// <param name="Url">
    ///   a database connection Url.
    /// </param>
    /// <returns>
    ///   an opened connection.
    /// </returns>
    function GetConnection(const Url: string): IZConnection;
    /// <summary>
    ///  Locates a required driver and opens a connection to the specified database.
    /// </summary>
    /// <param name="Url">
    ///   a database connection Url.
    /// </param>
    /// <param name="Info">
    ///   a list of extra connection parameters.
    /// </param>
    /// <returns>
    ///   an opened connection.
    /// </returns>
    function GetConnectionWithParams(const Url: string; Info: TStrings): IZConnection;
    /// <summary>
    ///  Locates a required driver and opens a connection to the specified database.
    /// </summary>
    /// <param name="User">
    ///   a user's name.
    /// </param>
    /// <param name="Password">
    ///   a user's password.
    /// </param>
    /// <returns>
    ///   an opened connection.
    /// </returns>
    function GetConnectionWithLogin(const Url: string; const User: string;
      const Password: string): IZConnection;
    /// <summary>
    ///  Gets a driver which accepts the specified url.
    /// </summary>
    /// <param name="Url">
    ///   a database connection url.
    /// </param>
    /// <returns>
    ///   a found driver or <c>nil</c> otherwise.
    /// </returns>
    function GetDriver(const Url: string): IZDriver;
    /// <summary>
    ///  Locates a required driver and returns the client library version number.
    /// </summary>
    /// <param name="Url">
    ///  a database connection Url.
    /// </param>
    /// <returns>
    ///  client library version number.
    /// </returns>
    function GetClientVersion(const Url: string): Integer;
    /// <summary>
    ///    Registers a driver for specific database.
    /// </summary>
    /// <param name="Driver">
    ///    a driver to be registered.
    /// </param>
    procedure RegisterDriver(const Driver: IZDriver);
    /// <summary>
    ///    Unregisters a driver for specific database.
    /// </summary>
    /// <param name="Driver">
    ///    a driver to be unregistered.
    /// </param>
    procedure DeregisterDriver(const Driver: IZDriver);
    /// <summary>
    ///  Gets a collection of registered drivers.
    /// </summary>
    /// <returns>
    ///   an unmodifiable collection with registered drivers.
    /// </returns>
    function GetDrivers: IZCollection;
    /// <summary>
    ///  Adds a logging listener to log SQL events.
    /// </summary>
    /// <param name="Listener">
    ///  a logging interface to be added.
    /// </param>
    procedure AddLoggingListener(const Listener: IZLoggingListener);
    /// <summary>
    ///  Removes a logging listener from the list.
    /// </summary>
    /// <param name="Listener">
    ///  a logging interface to be removed.
    /// </param>
    procedure RemoveLoggingListener(const Listener: IZLoggingListener);
    function HasLoggingListener: Boolean;
    /// <summary>
    ///  Logs a message about event with normal result code.
    /// </summary>
    /// <param name="Category">
    ///  a category of the message.
    /// </param>
    /// <param name="Protocol">
    ///  a name of the protocol.
    /// </param>
    /// <param name="Msg">
    ///  a description message.
    /// </param>
    procedure LogMessage(Category: TZLoggingCategory; const Protocol: RawByteString;
      const Msg: RawByteString); overload;
    procedure LogMessage(const Category: TZLoggingCategory; const Sender: IZLoggingObject); overload;
    /// <summary>
    ///  Logs a message about event with error result code.
    /// </summary>
    /// <param name="Category">
    ///   the category of the message.
    /// </param>
    /// <param name="Protocol">
    ///   the name of the protocol.
    /// </param>
    /// <param name="Msg">
    ///   a description message.
    /// </param>
    /// <param name="ErrorCode">
    ///   an error code.
    /// </param>
    /// <param name="Error">
    ///   an error message.
    /// </param>
    procedure LogError(Category: TZLoggingCategory; const Protocol: RawByteString;
      const Msg: RawByteString; ErrorCode: Integer; const Error: RawByteString);
    /// <summary>
    ///  Constructs a valid URL
    /// </summary>
    /// <param name="Protocol">
    ///  the Driver-protocol (must be assigned).
    /// </param>
    /// <param name="HostName">
    ///  the hostname (could be empty).
    /// </param>
    /// <param name="Database">
    ///  the connection-database (could be empty).
    /// </param>
    /// <param name="UserName">
    ///  the username (could be empty).
    /// </param>
    /// <param name="Password">
    ///  the password(could be empty).
    /// </param>
    /// <param name="Port">
    ///  the Server-Port (could be 0).
    /// </param>
    /// <param name="Properties">
    ///  the Database-Properties (could be empty).
    /// </param>
    function ConstructURL(const Protocol, HostName, Database,
      UserName, Password: String; const Port: Integer;
      const Properties: TStrings = nil; const LibLocation: String = ''): String;
    procedure AddGarbage(const Value: IZInterface);
    procedure ClearGarbageCollector;
  end;

  /// <summary>
  ///   Database Driver interface.
  /// </summary>
  IZDriver = interface(IZInterface)
    ['{2157710E-FBD8-417C-8541-753B585332E2}']

    function GetSupportedProtocols: TStringDynArray;
    function GetSupportedClientCodePages(const Url: TZURL;
      Const {$IFNDEF UNICODE}AutoEncode,{$ENDIF} SupportedsOnly: Boolean;
      CtrlsCPType: TZControlsCodePage = cCP_UTF16): TStringDynArray;
    function Connect(const Url: string; Info: TStrings): IZConnection; overload;
    function Connect(const Url: TZURL): IZConnection; overload;
    function GetClientVersion(const Url: string): Integer;
    function AcceptsURL(const Url: string): Boolean;
    function GetPlainDriver(const Url: TZURL; const InitDriver: Boolean = True): IZPlainDriver;

    function GetPropertyInfo(const Url: string; Info: TStrings): TStrings;
    function GetMajorVersion: Integer;
    function GetMinorVersion: Integer;
    function GetSubVersion: Integer;
    function GetTokenizer: IZTokenizer;
    function GetStatementAnalyser: IZStatementAnalyser;
  end;

  IImmediatelyReleasable = interface(IZInterface)
    ['{7AA5A5DA-5EC7-442E-85B0-CCCC71C13169}']
    procedure ReleaseImmediat(const Sender: IImmediatelyReleasable; var AError: EZSQLConnectionLost);
    function GetConSettings: PZConSettings;
  end;

  /// <summary>
  ///   Database Connection interface.
  /// </summary>
  IZConnection = interface(IZInterface)
    ['{8EEBBD1A-56D1-4EC0-B3BD-42B60591457F}']
    procedure RegisterOnConnectionLostErrorHandler(Handler: TOnConnectionLostError);
    procedure RegisterStatement(const Value: IZStatement);
    procedure DeregisterStatement(const Statement: IZStatement);

    function CreateStatement: IZStatement;
    function PrepareStatement(const SQL: string): IZPreparedStatement;
    function PrepareCall(const SQL: string): IZCallableStatement;

    function CreateStatementWithParams(Info: TStrings): IZStatement;
    function PrepareStatementWithParams(const SQL: string; Info: TStrings):
      IZPreparedStatement;
    function PrepareCallWithParams(const SQL: string; Info: TStrings):
      IZCallableStatement;

    function CreateNotification(const Event: string): IZNotification;
    function CreateSequence(const Sequence: string; BlockSize: Integer): IZSequence;

    function NativeSQL(const SQL: string): string;

    procedure SetAutoCommit(Value: Boolean);
    function GetAutoCommit: Boolean;

    procedure Commit;
    procedure Rollback;

    //2Phase Commit Support initially for PostgresSQL (firmos) 21022006
    procedure PrepareTransaction(const transactionid: string);
    procedure CommitPrepared(const transactionid: string);
    procedure RollbackPrepared(const transactionid: string);


    //Ping Server Support (firmos) 27032006

    function PingServer: Integer;
    function AbortOperation: Integer;
    function EscapeString(const Value: RawByteString): RawByteString;

    procedure Open;
    procedure Close;
    function IsClosed: Boolean;

    function GetDriver: IZDriver;
    function GetIZPlainDriver: IZPlainDriver;
    function GetMetadata: IZDatabaseMetadata;
    function GetParameters: TStrings;
    function GetClientVersion: Integer;
    function GetHostVersion: Integer;

    procedure SetReadOnly(Value: Boolean);
    function IsReadOnly: Boolean;

    procedure SetCatalog(const Value: string);
    function GetCatalog: string;

    procedure SetTransactionIsolation(Value: TZTransactIsolationLevel);
    function GetTransactionIsolation: TZTransactIsolationLevel;

    function GetWarnings: EZSQLWarning;
    procedure ClearWarnings;

    function UseMetadata: boolean;
    procedure SetUseMetadata(Value: Boolean);

    {$IFNDEF WITH_TBYTES_AS_RAWBYTESTRING}
    function GetBinaryEscapeString(const Value: RawByteString): String; overload;
    {$ENDIF}
    function GetBinaryEscapeString(const Value: TBytes): String; overload;
    procedure GetBinaryEscapeString(Buf: Pointer; Len: LengthInt; out Result: RawByteString); overload;
    procedure GetBinaryEscapeString(Buf: Pointer; Len: LengthInt; out Result: ZWideString); overload;

    function GetEscapeString(const Value: ZWideString): ZWideString; overload;
    function GetEscapeString(const Value: RawByteString): RawByteString; overload;
    procedure GetEscapeString(Buf: PAnsichar; Len: LengthInt; out Result: RawByteString); overload;
    procedure GetEscapeString(Buf: PAnsichar; Len: LengthInt; RawCP: Word; out Result: ZWideString); overload;
    procedure GetEscapeString(Buf: PWideChar; Len: LengthInt; RawCP: Word; out Result: RawByteString); overload;
    procedure GetEscapeString(Buf: PWideChar; Len: LengthInt; out Result: ZWideString); overload;

    function GetClientCodePageInformations: PZCodePage;
    function GetAutoEncodeStrings: Boolean;
    procedure SetAutoEncodeStrings(const Value: Boolean);
    property AutoEncodeStrings: Boolean read GetAutoEncodeStrings write SetAutoEncodeStrings;
    function GetEncoding: TZCharEncoding;
    function GetConSettings: PZConSettings;
    function GetClientVariantManager: IZClientVariantManager;
    function GetURL: String;
    function GetServerProvider: TZServerProvider;
  end;

  /// <summary>
  ///   Database metadata interface.
  /// </summary>
  IZDatabaseMetadata = interface(IZInterface)
    ['{FE331C2D-0664-464E-A981-B4F65B85D1A8}']

    function GetURL: string;
    function GetUserName: string;

    function GetDatabaseInfo: IZDatabaseInfo;
    function GetTriggers(const Catalog: string; const SchemaPattern: string;
      const TableNamePattern: string; const TriggerNamePattern: string): IZResultSet; //EgonHugeist 30.03.2011
    function GetCollationAndCharSet(const Catalog, Schema, TableName, ColumnName: String): IZResultSet; //EgonHugeist 10.01.2012
    function GetCharacterSets: IZResultSet; //EgonHugeist 19.01.2012
    function GetProcedures(const Catalog: string; const SchemaPattern: string;
      const ProcedureNamePattern: string): IZResultSet;
    function GetProcedureColumns(const Catalog: string; const SchemaPattern: string;
      const ProcedureNamePattern: string; const ColumnNamePattern: string): IZResultSet;

    function GetTables(const Catalog: string; const SchemaPattern: string;
      const TableNamePattern: string; const Types: TStringDynArray): IZResultSet;
    function GetSchemas: IZResultSet;
    function GetCatalogs: IZResultSet;
    function GetTableTypes: IZResultSet;
    function GetColumns(const Catalog: string; const SchemaPattern: string;
      const TableNamePattern: string; const ColumnNamePattern: string): IZResultSet;
    function GetColumnPrivileges(const Catalog: string; const Schema: string;
      const Table: string; const ColumnNamePattern: string): IZResultSet;

    function GetTablePrivileges(const Catalog: string; const SchemaPattern: string;
      const TableNamePattern: string): IZResultSet;
    function GetBestRowIdentifier(const Catalog: string; const Schema: string;
      const Table: string; Scope: Integer; Nullable: Boolean): IZResultSet;
    function GetVersionColumns(const Catalog: string; const Schema: string;
      const Table: string): IZResultSet;

    function GetPrimaryKeys(const Catalog: string; const Schema: string;
      const Table: string): IZResultSet;
    function GetImportedKeys(const Catalog: string; const Schema: string;
      const Table: string): IZResultSet;
    function GetExportedKeys(const Catalog: string; const Schema: string;
      const Table: string): IZResultSet;
    function GetCrossReference(const PrimaryCatalog: string; const PrimarySchema: string;
      const PrimaryTable: string; const ForeignCatalog: string; const ForeignSchema: string;
      const ForeignTable: string): IZResultSet;

    function GetTypeInfo: IZResultSet;

    function GetIndexInfo(const Catalog: string; const Schema: string; const Table: string;
      Unique: Boolean; Approximate: Boolean): IZResultSet;

    function GetSequences(const Catalog: string; const SchemaPattern: string;
      const SequenceNamePattern: string): IZResultSet;

    function GetUDTs(const Catalog: string; const SchemaPattern: string;
      const TypeNamePattern: string; const Types: TIntegerDynArray): IZResultSet;

    function GetConnection: IZConnection;
    function GetIdentifierConvertor: IZIdentifierConvertor;

    procedure ClearCache; overload;
    procedure ClearCache(const Key: string); overload;

    function AddEscapeCharToWildcards(const Pattern: string): string;
    function NormalizePatternCase(const Pattern: String): string;
    function CloneCachedResultSet(const ResultSet: IZResultSet): IZResultSet;
  end;

  /// <summary>
  ///  Database information interface. Used to describe the database as a whole
  ///  (version, capabilities, policies, etc).
  /// </summary>
  IZDatabaseInfo = interface(IZInterface)
    ['{107CA354-F594-48F9-8E08-CD797F151EA0}']

    // database/driver/server info:
    function GetDatabaseProductName: string;
    function GetDatabaseProductVersion: string;
    function GetDriverName: string;
    function GetDriverVersion: string;
    function GetDriverMajorVersion: Integer;
    function GetDriverMinorVersion: Integer;
    function GetServerVersion: string;

    // capabilities (what it can/cannot do):
    function AllProceduresAreCallable: Boolean;
    function AllTablesAreSelectable: Boolean;
    function SupportsMixedCaseIdentifiers: Boolean;
    function SupportsMixedCaseQuotedIdentifiers: Boolean;
    function SupportsAlterTableWithAddColumn: Boolean;
    function SupportsAlterTableWithDropColumn: Boolean;
    function SupportsColumnAliasing: Boolean;
    function SupportsConvert: Boolean;
    function SupportsConvertForTypes(FromType: TZSQLType; ToType: TZSQLType):
      Boolean;
    function SupportsTableCorrelationNames: Boolean;
    function SupportsDifferentTableCorrelationNames: Boolean;
    function SupportsExpressionsInOrderBy: Boolean;
    function SupportsOrderByUnrelated: Boolean;
    function SupportsGroupBy: Boolean;
    function SupportsGroupByUnrelated: Boolean;
    function SupportsGroupByBeyondSelect: Boolean;
    function SupportsLikeEscapeClause: Boolean;
    function SupportsMultipleResultSets: Boolean;
    function SupportsMultipleTransactions: Boolean;
    function SupportsNonNullableColumns: Boolean;
    function SupportsMinimumSQLGrammar: Boolean;
    function SupportsCoreSQLGrammar: Boolean;
    function SupportsExtendedSQLGrammar: Boolean;
    function SupportsANSI92EntryLevelSQL: Boolean;
    function SupportsANSI92IntermediateSQL: Boolean;
    function SupportsANSI92FullSQL: Boolean;
    function SupportsIntegrityEnhancementFacility: Boolean;
    function SupportsOuterJoins: Boolean;
    function SupportsFullOuterJoins: Boolean;
    function SupportsLimitedOuterJoins: Boolean;
    function SupportsSchemasInDataManipulation: Boolean;
    function SupportsSchemasInProcedureCalls: Boolean;
    function SupportsSchemasInTableDefinitions: Boolean;
    function SupportsSchemasInIndexDefinitions: Boolean;
    function SupportsSchemasInPrivilegeDefinitions: Boolean;
    function SupportsCatalogsInDataManipulation: Boolean;
    function SupportsCatalogsInProcedureCalls: Boolean;
    function SupportsCatalogsInTableDefinitions: Boolean;
    function SupportsCatalogsInIndexDefinitions: Boolean;
    function SupportsCatalogsInPrivilegeDefinitions: Boolean;
    function SupportsOverloadPrefixInStoredProcedureName: Boolean;
    function SupportsParameterBinding: Boolean;
    function SupportsPositionedDelete: Boolean;
    function SupportsPositionedUpdate: Boolean;
    function SupportsSelectForUpdate: Boolean;
    function SupportsStoredProcedures: Boolean;
    function SupportsSubqueriesInComparisons: Boolean;
    function SupportsSubqueriesInExists: Boolean;
    function SupportsSubqueriesInIns: Boolean;
    function SupportsSubqueriesInQuantifieds: Boolean;
    function SupportsCorrelatedSubqueries: Boolean;
    function SupportsUnion: Boolean;
    function SupportsUnionAll: Boolean;
    function SupportsOpenCursorsAcrossCommit: Boolean;
    function SupportsOpenCursorsAcrossRollback: Boolean;
    function SupportsOpenStatementsAcrossCommit: Boolean;
    function SupportsOpenStatementsAcrossRollback: Boolean;
    function SupportsTransactions: Boolean;
    function SupportsTransactionIsolationLevel(const Level: TZTransactIsolationLevel):
      Boolean;
    function SupportsDataDefinitionAndDataManipulationTransactions: Boolean;
    function SupportsDataManipulationTransactionsOnly: Boolean;
    function SupportsResultSetType(const _Type: TZResultSetType): Boolean;
    function SupportsResultSetConcurrency(const _Type: TZResultSetType;
      const Concurrency: TZResultSetConcurrency): Boolean;
    function SupportsBatchUpdates: Boolean;
    function SupportsNonEscapedSearchStrings: Boolean;
    function SupportsMilliseconds: Boolean;
    function SupportsUpdateAutoIncrementFields: Boolean;
    function SupportsArrayBindings: Boolean;

    // maxima:
    function GetMaxBinaryLiteralLength: Integer;
    function GetMaxCharLiteralLength: Integer;
    function GetMaxColumnNameLength: Integer;
    function GetMaxColumnsInGroupBy: Integer;
    function GetMaxColumnsInIndex: Integer;
    function GetMaxColumnsInOrderBy: Integer;
    function GetMaxColumnsInSelect: Integer;
    function GetMaxColumnsInTable: Integer;
    function GetMaxConnections: Integer;
    function GetMaxCursorNameLength: Integer;
    function GetMaxIndexLength: Integer;
    function GetMaxSchemaNameLength: Integer;
    function GetMaxProcedureNameLength: Integer;
    function GetMaxCatalogNameLength: Integer;
    function GetMaxRowSize: Integer;
    function GetMaxStatementLength: Integer;
    function GetMaxStatements: Integer;
    function GetMaxTableNameLength: Integer;
    function GetMaxTablesInSelect: Integer;
    function GetMaxUserNameLength: Integer;

    // policies (how are various data and operations handled):
    function IsReadOnly: Boolean;
    function IsCatalogAtStart: Boolean;
    function DoesMaxRowSizeIncludeBlobs: Boolean;
    function NullsAreSortedHigh: Boolean;
    function NullsAreSortedLow: Boolean;
    function NullsAreSortedAtStart: Boolean;
    function NullsAreSortedAtEnd: Boolean;
    function NullPlusNonNullIsNull: Boolean;
    function UsesLocalFiles: Boolean;
    function UsesLocalFilePerTable: Boolean;
    function StoresUpperCaseIdentifiers: Boolean;
    function StoresLowerCaseIdentifiers: Boolean;
    function StoresMixedCaseIdentifiers: Boolean;
    function StoresUpperCaseQuotedIdentifiers: Boolean;
    function StoresLowerCaseQuotedIdentifiers: Boolean;
    function StoresMixedCaseQuotedIdentifiers: Boolean;
    function GetDefaultTransactionIsolation: TZTransactIsolationLevel;
    function DataDefinitionCausesTransactionCommit: Boolean;
    function DataDefinitionIgnoredInTransactions: Boolean;

    // interface details (terms, keywords, etc):
    function GetIdentifierQuoteString: string;
    function GetIdentifierQuoteKeywordsSorted: TStringList;
    function GetSchemaTerm: string;
    function GetProcedureTerm: string;
    function GetCatalogTerm: string;
    function GetCatalogSeparator: string;
    function GetSQLKeywords: string;
    function GetNumericFunctions: string;
    function GetStringFunctions: string;
    function GetSystemFunctions: string;
    function GetTimeDateFunctions: string;
    function GetSearchStringEscape: string;
    function GetExtraNameCharacters: string;
  end;

  /// <summary>
  ///  Generic SQL statement interface.
  /// </summary>
  IZStatement = interface(IZInterface)
    ['{22CEFA7E-6A6D-48EC-BB9B-EE66056E90F1}']

    /// <summary>
    ///  Executes an SQL statement that returns a single <c>ResultSet</c> object.
    /// </summary>
    /// <param name="SQL">
    ///  typically this is a static SQL <c>SELECT</c> statement
    /// </param>
    /// <returns>
    ///  a <c>ResultSet</c> object that contains the data produced by the
    ///  given query; never <c>nil</c>
    /// </returns>
    function ExecuteQuery(const SQL: ZWideString): IZResultSet; overload;
    /// <summary>
    ///  Executes an SQL <c>INSERT</c>, <c>UPDATE</c> or
    ///  <c>DELETE</c> statement. In addition,
    ///  SQL statements that return nothing, such as SQL DDL statements,
    ///  can be executed.
    /// </summary>
    /// <param name="SQL">
    ///  an SQL <c>INSERT</c>, <c>UPDATE</c> or
    ///  <c>DELETE</c> statement or an SQL statement that returns nothing
    /// </param>
    /// <returns>
    ///  either the row count for <c>INSERT</c>, <c>UPDATE</c>
    ///  or <c>DELETE</c> statements, or 0 for SQL statements that return nothing
    /// </returns>
    function ExecuteUpdate(const SQL: ZWideString): Integer; overload;
    /// <summary>
    ///  Executes an SQL <code>INSERT</code>, <code>UPDATE</code> or
    ///  <code>DELETE</code> statement. In addition,
    ///  SQL statements that return nothing, such as SQL DDL statements,
    ///  can be executed.
    /// </summary>
    /// <param name="SQL">
    ///  an SQL <code>INSERT</code>, <code>UPDATE</code> or
    ///  <code>DELETE</code> statement or an SQL statement that returns nothing
    /// </param>
    /// <returns>
    ///  either the row count for <code>INSERT</code>, <code>UPDATE</code>
    ///  or <code>DELETE</code> statements, or 0 for SQL statements that return nothing
    /// </returns>
    function Execute(const SQL: ZWideString): Boolean; overload;
    /// <summary>
    ///  Executes an SQL statement that returns a single <c>ResultSet</c> object.
    /// </summary>
    /// <param name="SQL">
    ///  typically this is a static SQL <c>SELECT</c> statement
    /// </param>
    /// <returns>
    ///  a <c>ResultSet</c> object that contains the data produced by the
    ///  given query; never <c>nil</c>
    /// </returns>
    function ExecuteQuery(const SQL: RawByteString): IZResultSet; overload;
    /// <summary>
    ///  Executes an SQL <c>INSERT</c>, <c>UPDATE</c> or
    ///  <c>DELETE</c> statement. In addition,
    ///  SQL statements that return nothing, such as SQL DDL statements,
    ///  can be executed.
    /// </summary>
    /// <param name="SQL">
    ///  an SQL <c>INSERT</c>, <c>UPDATE</c> or
    ///  <c>DELETE</c> statement or an SQL statement that returns nothing
    /// </param>
    /// <returns>
    ///  either the row count for <c>INSERT</c>, <c>UPDATE</c>
    ///  or <c>DELETE</c> statements, or 0 for SQL statements that return nothing
    /// </returns>
    function ExecuteUpdate(const SQL: RawByteString): Integer; overload;
    /// <summary>
    ///  Executes an SQL <code>INSERT</code>, <code>UPDATE</code> or
    ///  <code>DELETE</code> statement. In addition,
    ///  SQL statements that return nothing, such as SQL DDL statements,
    ///  can be executed.
    /// </summary>
    /// <param name="SQL">
    ///  an SQL <code>INSERT</code>, <code>UPDATE</code> or
    ///  <code>DELETE</code> statement or an SQL statement that returns nothing
    /// </param>
    /// <returns>
    ///  either the row count for <code>INSERT</code>, <code>UPDATE</code>
    ///  or <code>DELETE</code> statements, or 0 for SQL statements that return nothing
    /// </returns>
    function Execute(const SQL: RawByteString): Boolean; overload;

    /// <summary>
    ///  get the current SQL string
    /// </summary>
    function GetSQL : String;

    /// <summary>
    ///  Releases this <c>Statement</c> object's database
    ///  resources immediately instead of waiting for
    ///  this to happen when it is automatically closed.
    ///  It is generally good practice to release resources as soon as
    ///  you are finished with them to avoid tying up database
    ///  resources.
    ///  <para><b>Note:</b> A <c>Statement</c> object is automatically closed when its
    ///    reference counter becomes zero. When a <c>Statement</c> object is closed, its current
    ///    <c>ResultSet</c> object, if one exists, is also closed.
    ///  </para>
    /// </summary>
    procedure Close;
    function IsClosed: Boolean;

    /// <summary>
    ///  Returns the maximum number of bytes allowed
    ///  for any column value.
    ///  This limit is the maximum number of bytes that can be
    ///  returned for any column value.
    ///  The limit applies only to <c>BINARY</c>,
    ///  <c>VARBINARY</c>, <c>LONGVARBINARY</c>, <c>CHAR</c>, <c>VARCHAR</c>, and <c>LONGVARCHAR</c>
    ///  columns.  If the limit is exceeded, the excess data is silently
    ///  discarded.
    /// </summary>
    /// <returns>
    ///  the current max column size limit; zero means unlimited
    /// </returns>
    function GetMaxFieldSize: Integer;
    /// <summary>
    ///  Sets the limit for the maximum number of bytes in a column to
    ///  the given number of bytes.  This is the maximum number of bytes
    ///  that can be returned for any column value.  This limit applies
    ///  only to <c>BINARY</c>, <c>VARBINARY</c>,
    ///  <c>LONGVARBINARY</c>, <c>CHAR</c>, <c>VARCHAR</c>, and
    ///  <c>LONGVARCHAR</c> fields.  If the limit is exceeded, the excess data
    ///  is silently discarded. For maximum portability, use values
    ///  greater than 256.
    /// </summary>
    /// <param name="Value">
    ///  the new max column size limit; zero means unlimited
    /// </param>
    procedure SetMaxFieldSize(Value: Integer);
    /// <summary>
    ///  Retrieves the maximum number of rows that a
    ///  <c>ResultSet</c> object can contain.  If the limit is exceeded, the excess
    ///  rows are silently dropped.
    /// </summary>
    /// <returns>
    ///  the current max row limit; zero means unlimited
    /// </returns>
    function GetMaxRows: Integer;
    /// <summary>
    ///  Sets the limit for the maximum number of rows that any
    ///  <c>ResultSet</c> object can contain to the given number.
    ///  If the limit is exceeded, the excess rows are silently dropped.
    /// </summary>
    /// <param name="Value">
    ///  the new max rows limit; zero means unlimited
    /// </param>
    procedure SetMaxRows(Value: Integer);
    /// <summary>
    ///  Retrieves the number of seconds the driver will
    ///  wait for a <c>Statement</c> object to execute. If the limit is exceeded, a
    ///  <c>SQLException</c> is thrown.
    /// </summary>
    /// <returns>
    ///  the current query timeout limit in seconds; zero means unlimited
    /// </returns>
    function GetQueryTimeout: Integer;
    /// <summary>
    ///  Sets the number of seconds the driver will
    ///  wait for a <c>Statement</c> object to execute to the given number of seconds.
    ///  If the limit is exceeded, an <c>SQLException</c> is thrown.
    /// </summary>
    /// <param name="Value">
    ///  the new query timeout limit in seconds; zero means unlimited
    /// </param>
    procedure SetQueryTimeout(Value: Integer);
    /// <summary>
    ///  Cancels this <c>Statement</c> object if both the DBMS and
    ///  driver support aborting an SQL statement.
    ///  This method can be used by one thread to cancel a statement that
    ///  is being executed by another thread.
    /// </summary>
    procedure Cancel;
    /// <summary>
    ///  Defines the SQL cursor name that will be used by
    ///  subsequent <c>Statement</c> object <c>execute</c> methods.
    ///  This name can then be
    ///  used in SQL positioned update / delete statements to identify the
    ///  current row in the <c>ResultSet</c> object generated by this statement.  If
    ///  the database doesn't support positioned update/delete, this
    ///  method is a noop.  To insure that a cursor has the proper isolation
    ///  level to support updates, the cursor's <c>SELECT</c> statement should be
    ///  of the form 'select for update ...'. If the 'for update' phrase is
    ///  omitted, positioned updates may fail.
    ///  <note>
    ///   <para><B>Note:</B> By definition, positioned update/delete
    ///   execution must be done by a different <c>Statement</c> object than the one
    ///   which generated the <c>ResultSet</c> object being used for positioning. Also,
    ///   cursor names must be unique within a connection.</para>
    ///  </note>
    /// </summary>
    /// <param name="Value">
    ///    the new cursor name, which must be unique within a connection
    /// </param>
    procedure SetCursorName(const Value: String);

    /// <summary>
    ///  Returns the current result as a <c>ResultSet</c> object.
    ///  This method should be called only once per result.
    /// </summary>
    /// <returns>
    ///  the current result as a <c>ResultSet</c> object;
    ///  <c>nil</c> if the result is an update count or there are no more results
    /// </returns>
    /// <seealso cref="Execute">Execute</seealso>
    function GetResultSet: IZResultSet;
    /// <summary>
    ///  Returns the current result as an update count;
    ///  if the result is a <c>ResultSet</c> object or there are no more results, -1
    ///  is returned. This method should be called only once per result.
    /// </summary>
    /// <returns>
    ///  the current result as an update count; -1 if the current result is a
    ///  <c>ResultSet</c> object or there are no more results
    /// </returns>
    /// <seealso cref="Execute">Execute</seealso>
    function GetUpdateCount: Integer;
    /// <summary>
    ///  Moves to a <c>Statement</c> object's next result.  It returns
    ///  <c>true</c> if this result is a <c>ResultSet</c> object.
    ///  This method also implicitly closes any current <c>ResultSet</c>
    ///  object obtained with the method <c>getResultSet</c>.
    ///
    ///  <para>There are no more results when the following is true:
    ///  <code>(not getMoreResults and (getUpdateCount = -1)</code>
    ///  </para>
    /// </summary>
    /// <returns>
    ///  <c>true</c> if the next result is a <c>ResultSet</c> object;
    ///  <c>false</c> if it is an update count or there are no more results
    /// </returns>
    /// <seealso cref="Execute">Execute</seealso>
    function GetMoreResults: Boolean;

    /// <summary>
    ///  Gives the driver a hint as to the direction in which
    ///  the rows in a result set
    ///  will be processed. The hint applies only to result sets created
    ///  using this <c>Statement</c> object.  The default value is
    ///  <c>fdForward</c>.
    ///  <para>Note that this method sets the default fetch direction for
    ///  result sets generated by this <c>Statement</c> object.
    ///  Each result set has its own methods for getting and setting
    ///  its own fetch direction.</para>
    /// </summary>
    /// <param name="Value">
    ///  the initial direction for processing rows
    /// </param>
    procedure SetFetchDirection(Value: TZFetchDirection);
    /// <summary>
    ///  Retrieves the direction for fetching rows from
    ///  database tables that is the default for result sets
    ///  generated from this <c>Statement</c> object.
    ///  If this <c>Statement</c> object has not set
    ///  a fetch direction by calling the method <c>setFetchDirection</c>,
    ///  the return value is implementation-specific.
    /// </summary>
    /// <returns>
    ///  the default fetch direction for result sets generated
    ///  from this <c>Statement</c> object
    /// </returns>
    function GetFetchDirection: TZFetchDirection;

    /// <summary>
    ///  Gives the DBC driver a hint as to the number of rows that should
    ///  be fetched from the database when more rows are needed.  The number
    ///  of rows specified affects only result sets created using this
    ///  statement. If the value specified is zero, then the hint is ignored.
    ///  The default value is zero.
    ///  <para><b>Note:</b> Most drivers will ignore this.</para>
    /// </summary>
    /// <param name="Value">
    ///  the number of rows to fetch
    /// </param>
    procedure SetFetchSize(Value: Integer);
    /// <summary>
    ///  Retrieves the number of result set rows that is the default
    ///  fetch size for result sets
    ///  generated from this <c>Statement</c> object.
    ///  If this <c>Statement</c> object has not set
    ///  a fetch size by calling the method <c>setFetchSize</c>,
    ///  the return value is implementation-specific.
    ///  <para><b>Note:</b> Most drivers will ignore this.</para>
    /// </summary>
    /// <returns>
    ///  the default fetch size for result sets generated
    ///  from this <c>Statement</c> object
    /// </returns>
    function GetFetchSize: Integer;
    /// <summary>
    ///  Sets a result set concurrency for <c>ResultSet</c> objects
    ///  generated by this <c>Statement</c> object.
    /// </summary>
    /// <param name="Value">
    ///  either <c>rcReadOnly</code> or
    ///  <code>rcUpdateable</code>
    /// </param>
    procedure SetResultSetConcurrency(Value: TZResultSetConcurrency);
    /// <summary>
    ///  Retrieves the result set concurrency for <c>ResultSet</c> objects
    ///  generated by this <c>Statement</c> object.
    /// </summary>
    /// <returns>
    ///  either <c>rcReadOnly</c> or
    ///  <c>rcUpdateable</c>
    /// </returns>
    function GetResultSetConcurrency: TZResultSetConcurrency;
    /// <summary>
    ///  Sets a result set type for <c>ResultSet</c> objects
    ///  generated by this <c>Statement</c> object.
    /// </summary>
    /// <param name="Value">
    ///  one of <c>rtForwardOnly</c>,
    ///  <c>rtScrollInsensitive</c>, or
    ///  <c>rtScrollSensitive</c>
    /// </param>
    procedure SetResultSetType(Value: TZResultSetType);
    /// <summary>
    ///  Retrieves the result set type for <c>ResultSet</c> objects
    ///  generated by this <c>Statement</c> object.
    /// </summary>
    /// <returns>
    ///  one of <c>rcForwardOnly</c>,
    ///  <c>rcScrollInsensitive</c>, or
    ///  <c>rcScrollSensitive</c>
    /// </returns>
    function GetResultSetType: TZResultSetType;

    /// <summary>
    ///  Sets a new value for post updates.
    /// </summary>
    /// <param name="Value">
    ///  a new value for post updates.
    /// </param>
    procedure SetPostUpdates(Value: TZPostUpdatesMode);
    /// <summary>
    ///  Gets the current value for post updates.
    /// </summary>
    /// <returns>
    ///  the current value for post updates.
    /// </returns>
    function GetPostUpdates: TZPostUpdatesMode;
    /// <summary>
    ///  Sets a new value for locate updates.
    /// </summary>
    /// <param name="Value">
    ///  Value a new value for locate updates.
    /// </param>
    procedure SetLocateUpdates(Value: TZLocateUpdatesMode);
    /// <summary>
    ///  Gets the current value for locate updates.
    /// </summary>
    /// <returns>
    ///  the current value for locate updates.
    /// </returns>
    function GetLocateUpdates: TZLocateUpdatesMode;

    /// <summary>
    ///  Adds an SQL command to the current batch of commmands for this
    ///  <c>Statement</c> object. This method is optional.
    /// </summary>
    /// <param name="SQL">
    ///  typically this is a static SQL <c>INSERT</c> or
    ///  <c>UPDATE</c> statement
    /// </param>
    procedure AddBatch(const SQL: string);
    /// <summary>
    ///  Adds an SQL command to the current batch of commmands for this
    ///  <c>Statement</c> object. This method is optional.
    /// </summary>
    /// <param name="SQL">
    ///  typically this is a static SQL <c>INSERT</c> or
    ///  <c>UPDATE</c> statement
    /// </param>
    procedure AddBatchRequest(const SQL: string);

    /// <summary>
    ///  Makes the set of commands in the current batch empty.
    ///  This method is optional.
    /// </summary>
    procedure ClearBatch;
    function ExecuteBatch: TIntegerDynArray;

    /// <summary>
    ///  Returns the <c>Connection</c> object
    ///  that produced this <c>Statement</c> object.
    /// </summary>
    /// <returns>
    ///  the connection that produced this statement
    /// </returns>
    function GetConnection: IZConnection;

    /// <summary>
    ///  Gets statement parameters.
    /// </summary>
    /// <returns>
    ///  a list with statement parameters.
    /// </returns>
    function GetParameters: TStrings;
    /// <summary>
    ///  Returns the ChunkSize for reading/writing large lobs
    /// </summary>
    /// <returns>
    ///  the chunksize in bytes.
    /// </returns>
    function GetChunkSize: Integer;

    /// <summary>
    ///  Retrieves the first warning reported by calls on this <c>Statement</c> object.
    ///  Subsequent <c>Statement</c> object warnings will be chained to this
    ///  <c>SQLWarning</c> object.
    ///  <para>The warning chain is automatically cleared each time
    ///  a statement is (re)executed.</para>
    ///  <para><b>Note:</b> If you are processing a <c>ResultSet</c> object, any
    ///  warnings associated with reads on that <c>ResultSet</c> object
    ///  will be chained on it.</para>
    /// </summary>
    /// <returns>
    ///  the first <c>SQLWarning</c> object or <c>nil</c>
    /// </returns>
    function GetWarnings: EZSQLWarning;

    /// <summary>
    ///  Clears all the warnings reported on this <c>Statement</c>
    ///  object. After a call to this method,
    ///  the method <c>getWarnings</c> will return
    ///  <c>nil</c> until a new warning is reported for this
    ///  <c>Statement</c> object.
    /// </summary>
    procedure ClearWarnings;
    procedure FreeOpenResultSetReference(const ResultSet: IZResultSet);
  end;

  /// <summary>
  ///   Prepared SQL statement interface.
  /// </summary>
  IZPreparedStatement = interface(IZStatement)
    ['{990B8477-AF11-4090-8821-5B7AFEA9DD70}']

    function ExecuteQueryPrepared: IZResultSet;
    function ExecuteUpdatePrepared: Integer;
    function ExecutePrepared: Boolean;

    procedure SetNull(ParameterIndex: Integer; SQLType: TZSQLType);
    procedure SetBoolean(ParameterIndex: Integer; Value: Boolean);
    procedure SetByte(ParameterIndex: Integer; Value: Byte);
    procedure SetShort(ParameterIndex: Integer; Value: ShortInt);
    procedure SetWord(ParameterIndex: Integer; Value: Word);
    procedure SetSmall(ParameterIndex: Integer; Value: SmallInt);
    procedure SetUInt(ParameterIndex: Integer; Value: Cardinal);
    procedure SetInt(ParameterIndex: Integer; Value: Integer);
    procedure SetULong(ParameterIndex: Integer; const Value: UInt64);
    procedure SetLong(ParameterIndex: Integer; const Value: Int64);
    procedure SetFloat(ParameterIndex: Integer; Value: Single);
    procedure SetDouble(ParameterIndex: Integer; const Value: Double);
    procedure SetCurrency(ParameterIndex: Integer; const Value: Currency);
    procedure SetBigDecimal(ParameterIndex: Integer; const Value: TBCD);
    procedure SetCharRec(ParameterIndex: Integer; const Value: TZCharRec);
    procedure SetString(ParameterIndex: Integer; const Value: String);
    procedure SetUnicodeString(ParameterIndex: Integer; const Value: ZWideString); //AVZ
    procedure SetBytes(ParameterIndex: Integer; const Value: TBytes);
    procedure SetGuid(ParameterIndex: Integer; const Value: TGUID);
    {$IFNDEF NO_ANSISTRING}
    procedure SetAnsiString(ParameterIndex: Integer; const Value: AnsiString);
    {$ENDIF}
    {$IFNDEF NO_UTF8STRING}
    procedure SetUTF8String(ParameterIndex: Integer; const Value: UTF8String);
    {$ENDIF}
    procedure SetRawByteString(ParameterIndex: Integer; const Value: RawByteString);
    procedure SetDate(ParameterIndex: Integer; const Value: TDateTime); overload;
    procedure SetDate(ParameterIndex: Integer; const Value: TZDate); overload;
    procedure SetTime(ParameterIndex: Integer; const Value: TDateTime); overload;
    procedure SetTime(ParameterIndex: Integer; const Value: TZTime); overload;
    procedure SetTimestamp(ParameterIndex: Integer; const Value: TDateTime); overload;
    procedure SetTimestamp(ParameterIndex: Integer; const Value: TZTimeStamp); overload;
    procedure SetAsciiStream(ParameterIndex: Integer; const Value: TStream);
    procedure SetUnicodeStream(ParameterIndex: Integer; const Value: TStream);
    procedure SetBinaryStream(ParameterIndex: Integer; const Value: TStream);
    procedure SetBlob(ParameterIndex: Integer; SQLType: TZSQLType; const Value: IZBlob);
    procedure SetValue(ParameterIndex: Integer; const Value: TZVariant);
    procedure SetNullArray(ParameterIndex: Integer; const SQLType: TZSQLType; const Value; const VariantType: TZVariantType = vtNull);
    procedure SetDataArray(ParameterIndex: Integer; const Value; const SQLType: TZSQLType; const VariantType: TZVariantType = vtNull);

    procedure RegisterParameter(ParameterIndex: Integer; SQLType: TZSQLType;
      ParamType: TZProcedureColumnType; const Name: String = ''; PrecisionOrSize: LengthInt = 0;
      {%H-}Scale: LengthInt = 0);

    //======================================================================
    // Methods for accessing out parameters by index
    //======================================================================
    function IsNull(Index: Integer): Boolean;
    function GetBoolean(ParameterIndex: Integer): Boolean;
    function GetByte(ParameterIndex: Integer): Byte;
    function GetShort(ParameterIndex: Integer): ShortInt;
    function GetWord(ParameterIndex: Integer): Word;
    function GetSmall(ParameterIndex: Integer): SmallInt;
    function GetUInt(ParameterIndex: Integer): Cardinal;
    function GetInt(ParameterIndex: Integer): Integer;
    function GetULong(ParameterIndex: Integer): UInt64;
    function GetLong(ParameterIndex: Integer): Int64;
    function GetFloat(ParameterIndex: Integer): Single;
    function GetDouble(ParameterIndex: Integer): Double;
    function GetCurrency(ParameterIndex: Integer): Currency;
    procedure GetBigDecimal(ParameterIndex: Integer; var Result: TBCD);
    procedure GetGUID(Index: Integer; var Result: TGUID);
    function GetBytes(ParameterIndex: Integer): TBytes; overload;
    function GetDate(ParameterIndex: Integer): TDateTime; overload;
    procedure GetDate(ParameterIndex: Integer; Var Result: TZDate); overload;
    function GetTime(ParameterIndex: Integer): TDateTime; overload;
    procedure GetTime(ParameterIndex: Integer; Var Result: TZTime); overload;
    function GetTimestamp(ParameterIndex: Integer): TDateTime; overload;
    procedure GetTimeStamp(Index: Integer; var Result: TZTimeStamp); overload;
    function GetValue(ParameterIndex: Integer): TZVariant;

    function GetString(ParameterIndex: Integer): String;
    {$IFNDEF NO_ANSISTRING}
    function GetAnsiString(ParameterIndex: Integer): AnsiString;
    {$ENDIF}
    {$IFNDEF NO_UTF8STRING}
    function GetUTF8String(ParameterIndex: Integer): UTF8String;
    {$ENDIF}
    function GetRawByteString(ParameterIndex: Integer): RawByteString;
    function GetUnicodeString(ParameterIndex: Integer): ZWideString;

    function GetBLob(ParameterIndex: Integer): IZBlob;
    //function GetCLob(ParameterIndex: Integer): IZClob;

    procedure ClearParameters;
  end;

  /// <summary>
  ///   Callable SQL statement interface.
  /// </summary>
  IZCallableStatement = interface(IZPreparedStatement)
    ['{E6FA6C18-C764-4C05-8FCB-0582BDD1EF40}']
    { Multiple ResultSet support API }
    function GetFirstResultSet: IZResultSet;
    function GetPreviousResultSet: IZResultSet;
    function GetNextResultSet: IZResultSet;
    function GetLastResultSet: IZResultSet;
    function BOR: Boolean;
    function EOR: Boolean;
    function GetResultSetByIndex(Index: Integer): IZResultSet;
    function GetResultSetCount: Integer;

    procedure RegisterOutParameter(ParameterIndex: Integer; SQLType: Integer); //deprecated;
    procedure RegisterParamType(ParameterIndex:integer;ParamType:Integer); //deprecated;
  end;

  /// <summary>
  ///   EH: sort helper procs.
  /// </summary>
  TCompareFunc = function(const Null1, Null2: Boolean; const V1, V2): Integer;
  TCompareFuncs = Array of TCompareFunc;

  /// <summary>
  ///   Defines Column-Comparison kinds
  /// </summary>
  TComparisonKind = (ckAscending{greater than}, ckDescending{less than}, ckEquals);
  TComparisonKindArray = Array of TComparisonKind;

  {$IFDEF USE_SYNCOMMONS}
  TZJSONComposeOption = (jcoEndJSONObject, jcoDATETIME_MAGIC, jcoMongoISODate,
    jcoMilliseconds, jcsSkipNulls);
  TZJSONComposeOptions = set of TZJSONComposeOption;
  {$ENDIF USE_SYNCOMMONS}

  /// <summary>
  ///   Rows returned by SQL query.
  /// </summary>
  IZResultSet = interface(IZInterface)
    ['{8F4C4D10-2425-409E-96A9-7142007CC1B2}']

    function Next: Boolean;
    procedure Close;
    procedure ResetCursor;
    function WasNull: Boolean;
    function IsClosed: Boolean;

    //======================================================================
    // Methods for accessing results by column index
    //======================================================================

    function IsNull(ColumnIndex: Integer): Boolean;
    function GetPChar(ColumnIndex: Integer): PChar; deprecated;
    function GetPAnsiChar(ColumnIndex: Integer): PAnsiChar; overload; //deprecated;
    function GetPAnsiChar(ColumnIndex: Integer; out Len: NativeUInt): PAnsiChar; overload;
    function GetString(ColumnIndex: Integer): String;
    {$IFNDEF NO_ANSISTRING}
    function GetAnsiString(ColumnIndex: Integer): AnsiString;
    {$ENDIF}
    {$IFNDEF NO_UTF8STRING}
    function GetUTF8String(ColumnIndex: Integer): UTF8String;
    {$ENDIF}
    function GetRawByteString(ColumnIndex: Integer): RawByteString;
    function GetUnicodeString(ColumnIndex: Integer): ZWideString;
    function GetPWideChar(ColumnIndex: Integer): PWideChar; overload; //deprecated;
    function GetPWideChar(ColumnIndex: Integer; out Len: NativeUInt): PWideChar; overload;
    function GetBoolean(ColumnIndex: Integer): Boolean;
    function GetByte(ColumnIndex: Integer): Byte;
    function GetShort(ColumnIndex: Integer): ShortInt;
    function GetWord(ColumnIndex: Integer): Word;
    function GetSmall(ColumnIndex: Integer): SmallInt;
    function GetUInt(ColumnIndex: Integer): Cardinal;
    function GetInt(ColumnIndex: Integer): Integer;
    function GetULong(ColumnIndex: Integer): UInt64;
    function GetLong(ColumnIndex: Integer): Int64;
    function GetFloat(ColumnIndex: Integer): Single;
    function GetDouble(ColumnIndex: Integer): Double;
    function GetCurrency(ColumnIndex: Integer): Currency;
    procedure GetBigDecimal(ColumnIndex: Integer; var Result: TBCD);
    procedure GetGUID(ColumnIndex: Integer; var Result: TGUID);
    function GetBytes(ColumnIndex: Integer): TBytes;
    function GetDate(ColumnIndex: Integer): TDateTime; overload;
    procedure GetDate(ColumnIndex: Integer; var Result: TZDate); overload;
    function GetTime(ColumnIndex: Integer): TDateTime; overload;
    procedure GetTime(ColumnIndex: Integer; Var Result: TZTime); overload;
    function GetTimestamp(ColumnIndex: Integer): TDateTime; overload;
    procedure GetTimestamp(ColumnIndex: Integer; Var Result: TZTimeStamp); overload;
    function GetAsciiStream(ColumnIndex: Integer): TStream;
    function GetUnicodeStream(ColumnIndex: Integer): TStream;
    function GetBinaryStream(ColumnIndex: Integer): TStream;
    function GetBlob(ColumnIndex: Integer): IZBlob;
    function GetDataSet(ColumnIndex: Integer): IZDataSet;
    function GetValue(ColumnIndex: Integer): TZVariant;
    function GetDefaultExpression(ColumnIndex: Integer): string;

    //======================================================================
    // Methods for accessing results by column name
    //======================================================================

    function IsNullByName(const ColumnName: string): Boolean;
    function GetPCharByName(const ColumnName: string): PChar; deprecated;
    function GetPAnsiCharByName(const ColumnName: string): PAnsiChar; overload; deprecated;
    function GetPAnsiCharByName(const ColumnName: string; out Len: NativeUInt): PAnsiChar; overload;
    function GetStringByName(const ColumnName: string): String;
    {$IFNDEF NO_ANSISTRING}
    function GetAnsiStringByName(const ColumnName: string): AnsiString;
    {$ENDIF}
    {$IFNDEF NO_UTF8STRING}
    function GetUTF8StringByName(const ColumnName: string): UTF8String;
    {$ENDIF}
    function GetRawByteStringByName(const ColumnName: string): RawByteString;
    function GetUnicodeStringByName(const ColumnName: string): ZWideString;
    function GetPWideCharByName(const ColumnName: string): PWideChar; overload;
    function GetPWideCharByName(const ColumnName: string; out Len: NativeUInt): PWideChar; overload;
    function GetBooleanByName(const ColumnName: string): Boolean;
    function GetByteByName(const ColumnName: string): Byte;
    function GetShortByName(const ColumnName: string): ShortInt;
    function GetWordByName(const ColumnName: string): Word;
    function GetSmallByName(const ColumnName: string): SmallInt;
    function GetUIntByName(const ColumnName: string): Cardinal;
    function GetIntByName(const ColumnName: string): Integer;
    function GetULongByName(const ColumnName: string): UInt64;
    function GetLongByName(const ColumnName: string): Int64;
    function GetFloatByName(const ColumnName: string): Single;
    function GetDoubleByName(const ColumnName: string): Double;
    function GetCurrencyByName(const ColumnName: string): Currency;
    procedure GetBigDecimalByName(const ColumnName: string; var Result: TBCD);
    procedure GetGUIDByName(const ColumnName: string; var Result: TGUID);
    function GetBytesByName(const ColumnName: string): TBytes;
    function GetDateByName(const ColumnName: string): TDateTime; overload;
    procedure GetDateByName(const ColumnName: string; var Result: TZDate); overload;
    function GetTimeByName(const ColumnName: string): TDateTime; overload;
    procedure GetTimeByName(const ColumnName: string; Var Result: TZTime); overload;
    function GetTimestampByName(const ColumnName: string): TDateTime; overload;
    procedure GetTimeStampByName(const ColumnName: string; var Result: TZTimeStamp); overload;
    function GetAsciiStreamByName(const ColumnName: string): TStream;
    function GetUnicodeStreamByName(const ColumnName: string): TStream;
    function GetBinaryStreamByName(const ColumnName: string): TStream;
    function GetBlobByName(const ColumnName: string): IZBlob;
    function GetDataSetByName(const ColumnName: String): IZDataSet;
    function GetValueByName(const ColumnName: string): TZVariant;

    //=====================================================================
    // Advanced features:
    //=====================================================================

    function GetWarnings: EZSQLWarning;
    procedure ClearWarnings;

    function GetCursorName: String;
    function GetMetadata: IZResultSetMetadata;
    function FindColumn(const ColumnName: string): Integer;

    //---------------------------------------------------------------------
    // Traversal/Positioning
    //---------------------------------------------------------------------

    function IsBeforeFirst: Boolean;
    function IsAfterLast: Boolean;
    function IsFirst: Boolean;
    function IsLast: Boolean;
    procedure BeforeFirst;
    procedure AfterLast;
    function First: Boolean;
    function Last: Boolean;
    function GetRow: NativeInt;
    function MoveAbsolute(Row: Integer): Boolean;
    function MoveRelative(Rows: Integer): Boolean;
    function Previous: Boolean;

    //---------------------------------------------------------------------
    // Properties
    //---------------------------------------------------------------------

    procedure SetFetchDirection(Value: TZFetchDirection);
    function GetFetchDirection: TZFetchDirection;

    procedure SetFetchSize(Value: Integer);
    function GetFetchSize: Integer;

    function GetType: TZResultSetType;
    function GetConcurrency: TZResultSetConcurrency;

    function GetPostUpdates: TZPostUpdatesMode;
    function GetLocateUpdates: TZLocateUpdatesMode;

    //---------------------------------------------------------------------
    // Updates
    //---------------------------------------------------------------------

    function RowUpdated: Boolean;
    function RowInserted: Boolean;
    function RowDeleted: Boolean;

    procedure UpdateNull(ColumnIndex: Integer);
    procedure UpdateBoolean(ColumnIndex: Integer; Value: Boolean);
    procedure UpdateByte(ColumnIndex: Integer; Value: Byte);
    procedure UpdateShort(ColumnIndex: Integer; Value: ShortInt);
    procedure UpdateWord(ColumnIndex: Integer; Value: Word);
    procedure UpdateSmall(ColumnIndex: Integer; Value: SmallInt);
    procedure UpdateUInt(ColumnIndex: Integer; Value: Cardinal);
    procedure UpdateInt(ColumnIndex: Integer; Value: Integer);
    procedure UpdateULong(ColumnIndex: Integer; const Value: UInt64);
    procedure UpdateLong(ColumnIndex: Integer; const Value: Int64);
    procedure UpdateFloat(ColumnIndex: Integer; Value: Single);
    procedure UpdateDouble(ColumnIndex: Integer; const Value: Double);
    procedure UpdateCurrency(ColumnIndex: Integer; const Value: Currency);
    procedure UpdateBigDecimal(ColumnIndex: Integer; const Value: TBCD);
    procedure UpdateGUID(ColumnIndex: Integer; const Value: TGUID);
    procedure UpdatePChar(ColumnIndex: Integer; Value: PChar);
    procedure UpdatePAnsiChar(ColumnIndex: Integer; Value: PAnsiChar); overload;
    procedure UpdatePAnsiChar(ColumnIndex: Integer; Value: PAnsiChar; var Len: NativeUInt); overload;
    procedure UpdatePWideChar(ColumnIndex: Integer; Value: PWideChar); overload;
    procedure UpdatePWideChar(ColumnIndex: Integer; Value: PWideChar; var Len: NativeUInt); overload;
    procedure UpdateString(ColumnIndex: Integer; const Value: String);
    {$IFNDEF NO_ANSISTRING}
    procedure UpdateAnsiString(ColumnIndex: Integer; const Value: AnsiString);
    {$ENDIF}
    {$IFNDEF NO_UTF8STRING}
    procedure UpdateUTF8String(ColumnIndex: Integer; const Value: UTF8String);
    {$ENDIF}
    procedure UpdateRawByteString(ColumnIndex: Integer; const Value: RawByteString);
    procedure UpdateUnicodeString(ColumnIndex: Integer; const Value: ZWideString);
    procedure UpdateBytes(ColumnIndex: Integer; const Value: TBytes);
    procedure UpdateDate(ColumnIndex: Integer; const Value: TDateTime); overload;
    procedure UpdateDate(ColumnIndex: Integer; const Value: TZDate); overload;
    procedure UpdateTime(ColumnIndex: Integer; const Value: TDateTime); overload;
    procedure UpdateTime(ColumnIndex: Integer; const Value: TZTime); overload;
    procedure UpdateTimestamp(ColumnIndex: Integer; const Value: TDateTime); overload;
    procedure UpdateTimestamp(ColumnIndex: Integer; const Value: TZTimeStamp); overload;
    procedure UpdateAsciiStream(ColumnIndex: Integer; const Value: TStream);
    procedure UpdateUnicodeStream(ColumnIndex: Integer; const Value: TStream);
    procedure UpdateBinaryStream(ColumnIndex: Integer; const Value: TStream);
    procedure UpdateValue(ColumnIndex: Integer; const Value: TZVariant);
    procedure UpdateDefaultExpression(ColumnIndex: Integer; const Value: string);
    procedure UpdateLob(ColumnIndex: Integer; const Value: IZBlob);

    //======================================================================
    // Methods for accessing results by column name
    //======================================================================

    procedure UpdateNullByName(const ColumnName: string);
    procedure UpdateBooleanByName(const ColumnName: string; Value: Boolean);
    procedure UpdateByteByName(const ColumnName: string; Value: Byte);
    procedure UpdateShortByName(const ColumnName: string; Value: ShortInt);
    procedure UpdateWordByName(const ColumnName: string; Value: Word);
    procedure UpdateSmallByName(const ColumnName: string; Value: SmallInt);
    procedure UpdateUIntByName(const ColumnName: string; Value: Cardinal);
    procedure UpdateIntByName(const ColumnName: string; Value: Integer);
    procedure UpdateULongByName(const ColumnName: string; const Value: UInt64);
    procedure UpdateLongByName(const ColumnName: string; const Value: Int64);
    procedure UpdateFloatByName(const ColumnName: string; Value: Single);
    procedure UpdateCurrencyByName(const ColumnName: string; const Value: Currency);
    procedure UpdateDoubleByName(const ColumnName: string; const Value: Double);
    procedure UpdateBigDecimalByName(const ColumnName: string; const Value: TBCD);
    procedure UpdateGUIDByName(const ColumnName: string; const Value: TGUID);
    procedure UpdatePAnsiCharByName(const ColumnName: string; Value: PAnsiChar); overload; deprecated;
    procedure UpdatePAnsiCharByName(const ColumnName: string; Value: PAnsiChar; var Len: NativeUInt); overload;
    procedure UpdatePCharByName(const ColumnName: string; const Value: PChar); deprecated;
    procedure UpdatePWideCharByName(const ColumnName: string; Value: PWideChar); overload; deprecated;
    procedure UpdatePWideCharByName(const ColumnName: string; Value: PWideChar; var Len: NativeUInt); overload;
    procedure UpdateStringByName(const ColumnName: string; const Value: String);
    {$IFNDEF NO_ANSISTRING}
    procedure UpdateAnsiStringByName(const ColumnName: string; const Value: AnsiString);
    {$ENDIF}
    {$IFNDEF NO_UTF8STRING}
    procedure UpdateUTF8StringByName(const ColumnName: string; const Value: UTF8String);
    {$ENDIF}
    procedure UpdateRawByteStringByName(const ColumnName: string; const Value: RawByteString);
    procedure UpdateUnicodeStringByName(const ColumnName: string; const Value: ZWideString);
    procedure UpdateBytesByName(const ColumnName: string; const Value: TBytes);
    procedure UpdateDateByName(const ColumnName: string; const Value: TDateTime); overload;
    procedure UpdateDateByName(const ColumnName: string; const Value: TZDate); overload;
    procedure UpdateTimeByName(const ColumnName: string; const Value: TDateTime); overload;
    procedure UpdateTimeByName(const ColumnName: string; const Value: TZTime); overload;
    procedure UpdateTimestampByName(const ColumnName: string; const Value: TDateTime); overload;
    procedure UpdateTimestampByName(const ColumnName: string; const Value: TZTimeStamp); overload;
    procedure UpdateAsciiStreamByName(const ColumnName: string; const Value: TStream);
    procedure UpdateUnicodeStreamByName(const ColumnName: string; const Value: TStream);
    procedure UpdateBinaryStreamByName(const ColumnName: string; const Value: TStream);
    procedure UpdateValueByName(const ColumnName: string; const Value: TZVariant);

    procedure InsertRow;
    procedure UpdateRow;
    procedure DeleteRow;
    procedure RefreshRow;
    procedure CancelRowUpdates;
    procedure MoveToInsertRow;
    procedure MoveToCurrentRow;
//    procedure MoveToSearchRow;

//    function Search(CaseInsensitive, PartialKey: Boolean): Boolean;
//    function Compare(Row: Integer; CaseInsensitive, PartialKey: Boolean):
//      Boolean;

    function CompareRows(Row1, Row2: NativeInt; const ColumnIndices: TIntegerDynArray;
      const CompareFuncs: TCompareFuncs): Integer;
    function GetCompareFuncs(const ColumnIndices: TIntegerDynArray;
      const CompareKinds: TComparisonKindArray): TCompareFuncs;

    function GetStatement: IZStatement;
    function GetConSettings: PZConsettings;

    {$IFDEF USE_SYNCOMMONS}
    procedure ColumnsToJSON(JSONWriter: TJSONWriter; JSONComposeOptions: TZJSONComposeOptions); overload;
    procedure ColumnsToJSON(JSONWriter: TJSONWriter; EndJSONObject: Boolean = True;
      With_DATETIME_MAGIC: Boolean = False; SkipNullFields: Boolean = False); overload; //deprecated;
    {$ENDIF USE_SYNCOMMONS}
  end;

  /// <summary>
  ///   TDataSet interface.
  /// </summary>
  IZDataSet = interface(IZInterface)
    ['{DBC24011-EF26-4FD8-AC8B-C3E01619494A}']
    //function GetDataSet: TDataSet;
    function IsEmpty: Boolean;
  end;

  /// <summary>
  ///   ResultSet metadata interface.
  /// </summary>
  IZResultSetMetadata = interface(IZInterface)
    ['{47CA2144-2EA7-42C4-8444-F5154369B2D7}']

    function FindColumn(const ColumnName: string): Integer;

    function GetColumnCount: Integer;
    function IsAutoIncrement(ColumnIndex: Integer): Boolean;
    function IsCaseSensitive(ColumnIndex: Integer): Boolean;
    function IsSearchable(ColumnIndex: Integer): Boolean;
    function IsCurrency(ColumnIndex: Integer): Boolean;
    function IsNullable(ColumnIndex: Integer): TZColumnNullableType;

    function IsSigned(ColumnIndex: Integer): Boolean;
    function GetColumnLabel(ColumnIndex: Integer): string;
    function GetOrgColumnLabel(ColumnIndex: Integer): string;
    function GetColumnName(ColumnIndex: Integer): string;
    function GetColumnCodePage(ColumnIndex: Integer): Word;
    function GetSchemaName(ColumnIndex: Integer): string;
    function GetPrecision(ColumnIndex: Integer): Integer;
    function GetScale(ColumnIndex: Integer): Integer;
    function GetTableName(ColumnIndex: Integer): string;
    function GetCatalogName(ColumnIndex: Integer): string;
    function GetColumnType(ColumnIndex: Integer): TZSQLType;
    function GetColumnTypeName(ColumnIndex: Integer): string;
    function IsReadOnly(ColumnIndex: Integer): Boolean;
    function IsWritable(ColumnIndex: Integer): Boolean;
    function IsDefinitelyWritable(ColumnIndex: Integer): Boolean;
    function GetDefaultValue(ColumnIndex: Integer): string;
    function HasDefaultValue(ColumnIndex: Integer): Boolean;
  end;

  IZLob = interface(IZInterface)
    ['{DCF816A4-F21C-4FBB-837B-A12DCF886A6F}']
    function IsEmpty: Boolean;
    function IsUpdated: Boolean;
    function IsClob: Boolean;
    function Length: Integer;
    procedure Clear;
    function GetBufferAddress: PPointer;
    function GetLengthAddress: PInteger;
    {$IFDEF WITH_MM_CAN_REALLOC_EXTERNAL_MEM}
    procedure SetBlobData(const Buffer: Pointer; const Len: Cardinal; const CodePage: Word); overload;
    {$ENDIF}
  end;
  /// <summary>
  ///   External or internal blob wrapper object.
  /// </summary>
  IZBlob = interface(IZLob)
    ['{47D209F1-D065-49DD-A156-EFD1E523F6BF}']


    function GetString: RawByteString;
    procedure SetString(const Value: RawByteString);
    function GetBytes: TBytes;
    procedure SetBytes(const Value: TBytes);
    function GetStream: TStream;
    procedure SetStream(const Value: TStream); overload;
    function GetBuffer: Pointer;
    procedure SetBuffer(const Buffer: Pointer; const Length: Integer);
    {$IFDEF WITH_MM_CAN_REALLOC_EXTERNAL_MEM}
    procedure SetBlobData(const Buffer: Pointer; const Len: Cardinal); overload;
    {$ENDIF}

    function Clone(Empty: Boolean = False): IZBlob;

    {Clob operations}
    function GetRawByteString: RawByteString;
    procedure SetRawByteString(Const Value: RawByteString; const CodePage: Word);
    {$IFNDEF NO_ANSISTRING}
    function GetAnsiString: AnsiString;
    procedure SetAnsiString(Const Value: AnsiString);
    {$ENDIF}
    {$IFNDEF NO_UTF8STRING}
    function GetUTF8String: UTF8String;
    procedure SetUTF8String(Const Value: UTF8String);
    {$ENDIF}
    procedure SetUnicodeString(const Value: ZWideString);
    function GetUnicodeString: ZWideString;
    procedure SetStream(const Value: TStream; const CodePage: Word); overload;
    function GetRawByteStream: TStream;
    function GetAnsiStream: TStream;
    function GetUTF8Stream: TStream;
    function GetUnicodeStream: TStream;
    function GetPAnsiChar(const CodePage: Word): PAnsiChar;
    procedure SetPAnsiChar(const Buffer: PAnsiChar; const CodePage: Word; const Len: Cardinal);
    function GetPWideChar: PWideChar;
    procedure SetPWideChar(const Buffer: PWideChar; const Len: Cardinal);
  end;

  IZClob = interface(IZBlob)
    ['{2E0ED2FE-5F9F-4752-ADCB-EFE92E39FF94}']
  end;

  PIZLob = ^IZBlob;
  IZLobDynArray = array of IZBLob;

  IZUnCachedLob = interface(IZBlob)
    ['{194F1179-9FFC-4032-B983-5EB3DD2E8B16}']
    procedure FlushBuffer;
  end;

  /// <summary>
  ///   Database notification interface.
  /// </summary>
  IZNotification = interface(IZInterface)
    ['{BF785C71-EBE9-4145-8DAE-40674E45EF6F}']

    function GetEvent: string;
    procedure Listen;
    procedure Unlisten;
    procedure DoNotify;
    function CheckEvents: string;

    function GetConnection: IZConnection;
  end;

  /// <summary>
  ///   Database sequence generator interface.
  /// </summary>
  IZSequence = interface(IZInterface)
    ['{A9A54FE5-0DBE-492F-8DA6-04AC5FCE779C}']
    function  GetName: string;
    function  GetBlockSize: Integer;
    procedure SetName(const Value: string);
    procedure SetBlockSize(const Value: Integer);
    function  GetCurrentValue: Int64;
    function  GetNextValue: Int64;
    function  GetCurrentValueSQL: string;
    function  GetNextValueSQL: string;
    function  GetConnection: IZConnection;
  end;

var
  /// <summary>
  ///   The common driver manager object.
  /// </summary>
  DriverManager: IZDriverManager;
  GlobalCriticalSection: TCriticalSection;

implementation

uses ZMessages, ZConnProperties;

type

  { TZDriverManager }

  /// <summary>
  ///   Driver Manager interface.
  /// </summary>
  TZDriverManager = class(TInterfacedObject, IZDriverManager)
  private
    FDriversCS: TCriticalSection; // thread-safety for FDrivers collection. Not the drivers themselves!
    FLogCS: TCriticalSection;     // thread-safety for logging listeners
    FDrivers: IZCollection;
    FLoggingListeners: IZCollection;
    FGarbageCollector: IZCollection;
    FHasLoggingListener: Boolean;
    procedure InternalLogEvent(const Event: TZLoggingEvent);
    function InternalGetDriver(const Url: string): IZDriver;
  public
    constructor Create;
    destructor Destroy; override;

    function GetConnection(const Url: string): IZConnection;
    function GetConnectionWithParams(const Url: string; Info: TStrings): IZConnection;
    function GetConnectionWithLogin(const Url: string; const User: string;
      const Password: string): IZConnection;

    function GetDriver(const Url: string): IZDriver;
    procedure RegisterDriver(const Driver: IZDriver);
    procedure DeregisterDriver(const Driver: IZDriver);

    function GetDrivers: IZCollection;

    function GetClientVersion(const Url: string): Integer;

    procedure AddLoggingListener(const Listener: IZLoggingListener);
    procedure RemoveLoggingListener(const Listener: IZLoggingListener);
    function HasLoggingListener: Boolean;

    procedure LogMessage(Category: TZLoggingCategory; const Protocol: RawByteString;
      const Msg: RawByteString); overload;
    procedure LogMessage(const Category: TZLoggingCategory; const Sender: IZLoggingObject); overload;
    procedure LogError(Category: TZLoggingCategory; const Protocol: RawByteString;
      const Msg: RawByteString; ErrorCode: Integer; const Error: RawByteString);

    function ConstructURL(const Protocol, HostName, Database,
      UserName, Password: String; const Port: Integer;
      const Properties: TStrings = nil; const LibLocation: String = ''): String;
    procedure AddGarbage(const Value: IZInterface);
    procedure ClearGarbageCollector;
  end;

{ TZDriverManager }

{**
  Constructs this object with default properties.
}
constructor TZDriverManager.Create;
begin
  FDriversCS := TCriticalSection.Create;
  FLogCS := TCriticalSection.Create;
  FDrivers := TZCollection.Create;
  FLoggingListeners := TZCollection.Create;
  FGarbageCollector := TZCollection.Create;
  FHasLoggingListener := False;
end;

{**
  Destroys this object and cleanups the memory.
}
destructor TZDriverManager.Destroy;
begin
  FDrivers := nil;
  FLoggingListeners := nil;
  FreeAndNil(FDriversCS);
  FreeAndNil(FLogCS);
  inherited Destroy;
end;

function TZDriverManager.GetDrivers: IZCollection;
begin
  FDriversCS.Enter;
  try
    Result := TZUnmodifiableCollection.Create(FDrivers);
  finally
    FDriversCS.Leave;
  end;
end;

procedure TZDriverManager.RegisterDriver(const Driver: IZDriver);
begin
  FDriversCS.Enter;
  try
    if not FDrivers.Contains(Driver) then
      FDrivers.Add(Driver);
  finally
    FDriversCS.Leave;
  end;
end;

procedure TZDriverManager.DeregisterDriver(const Driver: IZDriver);
begin
  FDriversCS.Enter;
  try
    FDrivers.Remove(Driver);
  finally
    FDriversCS.Leave;
  end;
end;

function TZDriverManager.GetDriver(const Url: string): IZDriver;
begin
  FDriversCS.Enter;
  Result := nil;
  try
    Result := InternalGetDriver(URL);
  finally
    FDriversCS.Leave;
  end;
end;

function TZDriverManager.GetConnectionWithParams(const Url: string; Info: TStrings):
  IZConnection;
var
  Driver: IZDriver;
begin
  FDriversCS.Enter;
  Driver := nil;
  try
    Driver := InternalGetDriver(URL);
    if Driver = nil then
      raise EZSQLException.Create(SDriverWasNotFound);
    Result := Driver.Connect(Url, Info);
  finally
    FDriversCS.Leave;
  end;
end;

function TZDriverManager.GetClientVersion(const Url: string): Integer;
var
  Driver: IZDriver;
begin
  FDriversCS.Enter;
  try
    Driver := InternalGetDriver(URL);
    if Driver = nil then
      raise EZSQLException.Create(SDriverWasNotFound);
    Result := GetClientVersion(Url);
  finally
    FDriversCS.Leave;
  end;
end;

function TZDriverManager.GetConnectionWithLogin(const Url: string; const User: string;
  const Password: string): IZConnection;
var
  Info: TStrings;
  Driver: IZDriver;
begin
  FDriversCS.Enter;
  Info := TStringList.Create;
  Result := nil;
  try
    Info.Values[ConnProps_Username] := User;
    Info.Values[ConnProps_Password] := Password;
    Driver := InternalGetDriver(URL);
    if Driver = nil then
      raise EZSQLException.Create(SDriverWasNotFound);
    Result := Driver.Connect(Url, Info);
  finally
    FreeAndNil(Info);
    FDriversCS.Leave;
  end;
end;

function TZDriverManager.GetConnection(const Url: string): IZConnection;
begin
  Result := GetConnectionWithParams(Url, nil);
end;

procedure TZDriverManager.AddGarbage(const Value: IZInterface);
begin
  FDriversCS.Enter;
  try
    FGarbageCollector.Add(Value);
  finally
    FDriversCS.Leave;
  end;
end;

procedure TZDriverManager.AddLoggingListener(const Listener: IZLoggingListener);
begin
  FLogCS.Enter;
  try
    FLoggingListeners.Add(Listener);
    FHasLoggingListener := True;
  finally
    FLogCS.Leave;
  end;
end;

procedure TZDriverManager.RemoveLoggingListener(const Listener: IZLoggingListener);
begin
  FLogCS.Enter;
  try
    FLoggingListeners.Remove(Listener);
    FHasLoggingListener := (FLoggingListeners.Count>0);
  finally
    FLogCS.Leave;
  end;
end;

function TZDriverManager.HasLoggingListener: Boolean;
begin
  Result := FHasLoggingListener;
end;

function TZDriverManager.InternalGetDriver(const Url: string): IZDriver;
var I: Integer;
begin
  Result := nil;
  for I := 0 to FDrivers.Count - 1 do
    if (FDrivers[I].QueryInterface(IZDriver, Result) = S_OK) and Result.AcceptsURL(Url) then
      Exit;
  Result := nil;
end;

{**
  Logs an error message about event with error result code.
  @param Category a category of the message.
  @param Protocol a name of the protocol.
  @param Msg a description message.
  @param ErrorCode an error code.
  @param Error an error message.
}
procedure TZDriverManager.LogError(Category: TZLoggingCategory;
  const Protocol: RawByteString; const Msg: RawByteString; ErrorCode: Integer;
  const Error: RawByteString);
var
  Event: TZLoggingEvent;
begin
  Event := nil;
  FLogCS.Enter;
  try
    if not FHasLoggingListener then
      Exit;
    Event := TZLoggingEvent.Create(Category, Protocol, Msg, ErrorCode, Error);
    InternalLogEvent(Event);
  finally
    FreeAndNil(Event);
    FLogCS.Leave;
  end;
end;

procedure TZDriverManager.InternalLogEvent(const Event: TZLoggingEvent);
var
  I: Integer;
  Listener: IZLoggingListener;
begin
  for I := 0 to FLoggingListeners.Count - 1 do
    if FLoggingListeners[I].QueryInterface(IZLoggingListener, Listener) = S_OK then
      Listener.LogEvent(Event);
end;

{**
  Logs a message about event with error result code.
  @param Category a category of the message.
  @param Protocol a name of the protocol.
  @param Msg a description message.
}
procedure TZDriverManager.LogMessage(Category: TZLoggingCategory;
  const Protocol: RawByteString; const Msg: RawByteString);
var
  Event: TZLoggingEvent;
begin
  Event := nil;
  FLogCS.Enter;
  try
    if not FHasLoggingListener then
      Exit;
    Event := TZLoggingEvent.Create(Category, Protocol, Msg, 0, EmptyRaw);
    InternalLogEvent(Event);
  finally
    FreeAndNil(Event);
    FLogCS.Leave;
  end;
end;

procedure TZDriverManager.LogMessage(const Category: TZLoggingCategory;
  const Sender: IZLoggingObject);
var
  Event: TZLoggingEvent;
begin
  Event := nil;
  FLogCS.Enter;
  try
    if not FHasLoggingListener then
      Exit;
    Event := Sender.CreateLogEvent(Category);
    if Event <> nil then
      InternalLogEvent(Event);
  finally
    FreeAndNil(Event);
    FLogCS.Leave;
  end;
end;

procedure TZDriverManager.ClearGarbageCollector;
begin
  if (FGarbageCollector.Count > 0) {$IFDEF HAVE_CS_TRYENTER}and FDriversCS.TryEnter{$ENDIF} then begin
  {$IFNDEF HAVE_CS_TRYENTER}
    FDriversCS.Enter;
  {$ENDIF}
    try
      FGarbageCollector.Clear;
    finally
      FDriversCS.Leave;
    end;
  end;
end;

function TZDriverManager.ConstructURL(const Protocol, HostName, Database,
  UserName, Password: String; const Port: Integer;
  const Properties: TStrings = nil; const LibLocation: String = ''): String;
var ZURL: TZURL;
begin
  FDriversCS.Enter;
  ZURL := TZURL.Create;
  try
    ZURL.Protocol := Protocol;
    ZURL.HostName := HostName;
    ZURL.Database := DataBase;
    ZURL.UserName := UserName;
    ZURL.Password := Password;
    ZURL.Port := Port;
    if Assigned(Properties) then
      ZURL.Properties.AddStrings(Properties);
    ZURL.LibLocation := LibLocation;
    Result := ZURL.URL;
  finally
    FDriversCS.Leave;
    FreeAndNil(ZURL);
  end;
end;

initialization
  DriverManager := TZDriverManager.Create;
  GlobalCriticalSection := TCriticalSection.Create;
finalization
  DriverManager := nil;
  FreeAndNil(GlobalCriticalSection);
end.
