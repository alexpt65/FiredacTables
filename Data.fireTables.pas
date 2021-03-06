{ *************************************************************************** }
{ }
{ }
{ Copyright (C) Amarildo Lacerda }
{ }
{ https://github.com/amarildolacerda }
{ Blog:  www.tireideletra.com.br
  { }
{ }
{ *************************************************************************** }
{ }
{ Licensed under the Apache License, Version 2.0 (the "License"); }
{ you may not use this file except in compliance with the License. }
{ You may obtain a copy of the License at }
{ }
{ http://www.apache.org/licenses/LICENSE-2.0 }
{ }
{ Unless required by applicable law or agreed to in writing, software }
{ distributed under the License is distributed on an "AS IS" BASIS, }
{ WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. }
{ See the License for the specific language governing permissions and }
{ limitations under the License. }
{ }
{ *************************************************************************** }

unit Data.fireTables;

{ AL - 22/05/15
  Codigo passou a ser distribuido no GIT como c�digo aberto.

  Objetivo: criar uma interface entre BDE e FIREDAC, para reutilizar
  o c�digo legado.

  TODO
  Para distribuir em codigo aberto, n�o pode incluir acesso a
  biblioteca local. As bibliotecas devem ser de uso p�blico.

  N�o extender USES para c�digos adicionais, visando facilitar a
  distribui��o como c�digo aberto.

  Concentrar o c�digo ao m�nimo de UNITs para facilitar o uso.

  Fazer testes de validade para uso aplicativos ANDROID/IOS;
  Fazer testes de validade para uso WIN64;

  AL - 28/12/2015
  * Corre��o do UpdateSql parar propagar erros a query principal;
  refletindo em ErrorCount e ErrorMessages
  AL - 21/10/2016
  + incluido metodos novos para ex:  SetConnectionString
  - retirado componentes de TRACE que estavam travando nas DLL de plugin
  se precisar ainda destes componentes, incluir manualmente na aplica��o
}

interface

{$DEFINE TRACE } // quando usa DLL nao pode ter trace no APP nem na DLL
{ .$DEFINE NOTRACE }
{$IF DEFINED(BPL) or DEFINED(DLL) or NOT DEFINED(MSWINDOWS) }
{$DEFINE NOTRACE}
{$IFEND}
{$I firedac.inc}
{$DEFINE USACUSTOMDLG}
{$IFDEF WINDBU }
{$DEFINE LOCALSQL}
{$ENDIF }
{$DEFINE LOG}
{$IFNDEF MSWINDOWS}
{$UNDEF USACUSTOMDLG}
{$UNDEF LOG}
{$ENDIF}
{$IFDEF CPUX64}
{$DEFINE BDE2FIREDAC}
{$ENDIF}
{$IFDEF BPL}
{$UNDEF USACUSTOMDLG}
{$UNDEF LOG}
{$UNDEF VCL}
{$UNDEF FMX}
{$ENDIF}
{$IF CompilerVersion>= 29.0}
{$UNDEF USACUSTOMDLG}
{$ENDIF}
{$IF CompilerVersion>=26.0}
{$DEFINE BDE2FIREDAC}
{$ENDIF}
{$IFDEF ANDROID}
{$UNDEF BDE2FIREDAC}
{$DEFINE FIREDAC}
{$ENDIF}
{$IFNDEF BPL}
{$DEFINE INTF_ON}
{$ENDIF}
{$IFDEF EXTERNAL}
{$UNDEF INTF_ON}
{$ENDIF}
{$IFDEF NOTRACE}
{$UNDEF INTF_ON}
{$ENDIF}
{$IFDEF UNIGUI}
{$DEFINE NOGUI}
{$ENDIF}

uses
{$IFDEF MSWINDOWS}
  Windows,
  Winapi.Messages,
{$ENDIF}
  System.SyncObjs, System.Diagnostics,
  Data.DB, FireDAC.Stan.Param, FireDAC.Stan.Intf, FireDAC.Comp.Client,
  FireDAC.Comp.DataSet, FireDAC.Stan.Error, FireDAC.DatS, FireDAC.Stan.Option,
  FireDAC.DApt.Intf, System.Generics.Collections,
{$IFNDEF BPL}
  Data.QueryIntf,
{$ENDIF}
{$IFDEF MSWINDOWS}
{$ENDIF}
  FireDAC.Comp.ScriptCommands,
{$IFDEF DELPHI25gt}
  FireDAC.Comp.BatchMove,
  FireDAC.Comp.BatchMove.DataSet,
{$ELSE}
  FireDAC.Comp.DataMove,
{$ENDIF}
  FireDAC.Comp.Script,
  System.SysUtils, System.Variants,
  System.Classes,
{$IFDEF FMX}
  FMX.Graphics,
{$ELSE}
  // Vcl.Graphics,
{$ENDIF}
  System.IniFiles
{$IF CompilerVersion>= 31.0}{,Data.fireTables.GuiXDialogs}{$ENDIF};

const // AL - nao pode mudar este codigo de lugar
  c_alias_Local_SQLite = 'LOCAL_SQLITE'; // nao alterar
  firedac_rowSetSize = 250;

type

  TDebugAttrib = record
    active: boolean;
    Params_in: boolean;
    Data_out: boolean;
    Fields_out: boolean;
    execute: boolean;
    prepare, unprepare: boolean;
    transaction: boolean;
    Detalhed: boolean;
  end;

  TFireTransIsolation = (tiDirtyRead, tiReadCommitted, tiRepeatableRead);

  TFireDatabase = class;

  TFireTableType = (ttDefault, ttParadox, ttDBase, ttFoxPro, ttASCII);
{$IFDEF FIREDAC}
  TTableType = TFireTableType;
  TTransIsolation = TFireTransIsolation;
{$ENDIF}
  TFireDatabaseEvent = (dbOpen, dbClose, dbAdd, dbRemove, dbAddAlias,
    dbDeleteAlias, dbAddDriver, dbDeleteDriver);

  TFireDatabaseNotifyEvent = procedure(DBEvent: TFireDatabaseEvent; const Param)
    of object;

  TFireSession = class;

  TFireManager = class(TFDManager)
  public
    PoolDatabasename: string;
    Connection: TFireDatabase;
  end;

  TFireDatabase = class(TFDConnection)
  private
    FStopwatch: TStopwatch;
    FSession: TFireSession;
{$IFNDEF DLL}
    FLock: TMultiReadExclusiveWriteSynchronizer;
{$ENDIF}
    FAliasName: string;
    FKeepConnection: boolean;
    FSessionName: String;
    FTransIsolation: TFireTransIsolation;
    FDriverType: string;
    FmanualConfig: boolean;
    procedure SetDatabasename(const Value: string);
    function GetDatabasename: string;
    procedure SetAliasName(const Value: string);
    procedure SetKeepConnection(const Value: boolean);
    procedure SetSessionName(const Value: String);
    procedure SetTransIsolation(const Value: TFireTransIsolation);
{$IFDEF USACUSTOMDLG}
{$IFDEF VER290}
    procedure DoLoginDialogEvent(AConnection: TFDCustomConnection;
      const AParams: TFDConnectionDefParams);
{$ELSE}
    procedure DoLoginDialogEvent(AConnection: TFDCustomConnection;
      const AConnectionDef: IFDStanConnectionDef);
{$ENDIF}
{$ENDIF}
    procedure SetmanualConfig(const Value: boolean);
    procedure DoBeforeConnectEvent(sender: TObject);
    procedure SetTimeout(const Value: integer);
    function GetTimeout: integer;
    procedure SetPassword(const Value: string);
    procedure SetUserName(const Value: string);
    function GetPassword: string;
    function GetUserName: string;
    // procedure SetSession(const Value: TFireSession);
    // function GetSession: TFireSession;
  protected
    class var FPoolManager: TFireManager;
    procedure DoAfterConnectEvent(sender: TObject); virtual;
    procedure DoConnect; override;
    procedure init;
    procedure CheckTrace;
{$IFNDEF BPL}
  public
{$ENDIF}
    procedure GetPrimaryKeyFields(ATableName: String; AListFields: TStrings);
    procedure GetIndexes(ATableName: string; AListFields: TStrings);
  public

{$IFNDEF BPL}
    class function NewQuery(ADatabaseName: string): IQuery; overload;
{$ENDIF}
    class function New(AAlias, ADatabase, AUser, ASenha: string)
      : TFireDatabase; overload;
    Constructor Create(ow: TComponent); override;
    Destructor Destroy; override;
    class procedure Release;
    function GetFireConnectionString: string;
    procedure SetFireConnectionString(const AConn: String);
    procedure CloseDataSets;
    function CreatePoolManager: string;
    property KeepConnection: boolean read FKeepConnection
      write SetKeepConnection;

    property Session: TFireSession read FSession;
    // write FSession; //read GetSession write SetSession;
    procedure GetColumnNames(ATable: string; aTmp: string; ALst: TStrings);
    procedure GetFieldNames(tabela: string; lst: TStrings); overload;
    procedure GetTableNames(lst: TStrings; sysObjs: boolean); overload;
    procedure GetStoredProcNames(lst: TStrings; APattern: string); overload;

    property manualConfig: boolean read FmanualConfig write SetmanualConfig;
    property Timeout: integer read GetTimeout write SetTimeout;

    property UserName: string read GetUserName write SetUserName;
    property Password: string read GetPassword write SetPassword;
    procedure BeginWrite;
    procedure EndWrite;
    procedure BeginRead;
    procedure EndRead;
    class procedure InitParams(ADB: TFDConnection; AAliasName: string);
  published

    Property AliasName: string read FAliasName write SetAliasName;
    Property Databasename: string read GetDatabasename write SetDatabasename;
    property SessionName: String read FSessionName write SetSessionName;
    property TransIsolation: TFireTransIsolation read FTransIsolation
      write SetTransIsolation;
    property LoginPrompt;
    procedure FillParams(ADB: TFireDatabase);
    function Clone(ADbaseName: string; AOwner: TComponent = nil): TFireDatabase;
  end;

  TDatabaseObjectList = TList<TFireDatabase>;

  TFireUpdateSql = class;

  TFireQuery = class({$IFNDEF BPL} TFDQuery {$ELSE}   {$IFDEF INTF_ON}TFDQuery{$ELSE} {$IFDEF NOTRACE} TFDQuery{$ELSE} TFDCustomQuery{$ENDIF} {$ENDIF}{$ENDIF})
  private
    FLock: TMultiReadExclusiveWriteSynchronizer;
    FSQL: TStrings;
    FDatabasename: string;
    FSessionName: String;
    FAutoRefresh: boolean;
    FOnUpdateError: TFDUpdateErrorEvent;
    FOnReconcileError: TFDReconcileErrorEvent;
    FMacroCheck: boolean;
    FExecAsync: boolean;

    function GetDatabase: TFireDatabase;
    procedure SetDatabase(const Value: TFireDatabase);
    procedure SetDatabasename(const Value: string);
    function GetRequestLive: boolean;
    procedure SetRequestLive(const Value: boolean);
    procedure SetUniDirectional(const Value: boolean);
    procedure SetUpdateMode(const Value: TUpdateMode);
    function GetUpdateMode: TUpdateMode;
    procedure SetSessionName(const Value: String);
    procedure SetParamCheck(const Value: boolean);
    function GetUpdateObject: TFireUpdateSql;
    procedure SetUpdateObject(const Value: TFireUpdateSql);
    procedure SetAutoRefresh(const Value: boolean);
    procedure SetDatasource(const Value: TDataSource);
    procedure InitNullParams;
    function GetSQL: TStrings;
    procedure SetSQL(const Value: TStrings);
    function GetUniDirectional: boolean;
    function GetChacedUpdates: boolean;
    procedure SetCachedUpdates(const Value: boolean);
    procedure SetOnUpdateError(const Value: TFDUpdateErrorEvent);
    function GetParamCheck: boolean;
    procedure DoUpdateRecord(ASender: TDataSet; ARequest: TFDUpdateRequest;
      var AAction: TFDErrorAction; AOptions: TFDUpdateRowOptions);
    procedure DoUpdateError(ASender: TDataSet; AException: EFDException;
      ARow: TFDDatSRow; ARequest: TFDUpdateRequest;
      var AAction: TFDErrorAction);
    procedure DoReconcileError(DataSet: TFDDataSet; E: EFDException;
      UpdateKind: TFDDatSRowState; var Action: TFDDAptReconcileAction);
    function GetCmdExecModeEx: TFDStanAsyncMode;
    procedure SetCmdExecModeEx(const Value: TFDStanAsyncMode);
    procedure SetMacroCheck(const Value: boolean);
    procedure SetExecAsync(const Value: boolean);
{$IFNDEF BPL}
    function GetRowSetSize: integer;
    procedure SetRowSetSize(const Value: integer);
{$ENDIF}
  protected
    FInSqlChanging: boolean;
    FErrorMessage: string;
    FErrorCount: integer;
    FRowsAffectedLocal: integer;
    procedure SqlChanged(sender: TObject); virtual;
    procedure InternalClose; override;
    procedure InternalPost; override;
    procedure SetActive(AValue: boolean); override;
    function GetDataSource: TDataSource; override;

  public
    useLocalSql: boolean;
{$IFNDEF BPL}
    function Intf: IQuery;
    // function ConnectName(ADatabasename: string): IQuery; override;
    class function New(ADatabaseName: string): IQuery; overload; virtual;
{$ENDIF}
    procedure Open(ARowSetSize: integer); overload; virtual;
    procedure Open(AAsync: boolean;
      ARowSetSize: integer = firedac_rowSetSize); overload;
    procedure FreeBookmark(book: TBookMark); override;
    function GetBookmark: TBookMark; override;
    procedure GotoBookmark(book: TBookMark); reintroduce; virtual;
    function GetAfterInsert: TDataSetNotifyEvent;
    procedure SetAfterInsert(Value: TDataSetNotifyEvent);

    function BookmarkValid(Bookmark: TBookMark): boolean; override;
    property FieldOptions;
  public
{$IFNDEF BPL}
    class function New(FConn: TFDConnection): IQuery; overload;
{$ENDIF}
    property CmdExecMode: TFDStanAsyncMode read GetCmdExecModeEx
      write SetCmdExecModeEx;
    property CmdExecAsync: boolean read FExecAsync write SetExecAsync;
    procedure CmdNonBloking;
{$IFNDEF BPL}
    property RowSetSize: integer read GetRowSetSize write SetRowSetSize;
{$ENDIF}
    constructor Create(owner: TComponent); override;
    destructor Destroy; override;
    property Database: TFireDatabase read GetDatabase write SetDatabase;
    function RowsAffected: integer;
    procedure prepare;
    procedure InternalOpen; override;
    Procedure ExecDirect;
    procedure execute(ATimes: integer = 0; AOffset: integer = 0); override;
    procedure DebugBefore(const AIdent:string);
    procedure DebugAfter;
    procedure ExecSql;
    procedure ExecAsyncSql(AExecDirect: boolean = false);
    procedure ParamNullIF(sParam: string; Value: variant);
  published
    property active;
    Property AutoCalcFields;
    property OnUpdateError: TFDUpdateErrorEvent read FOnUpdateError
      write SetOnUpdateError;
    property OnReconcileError: TFDReconcileErrorEvent read FOnReconcileError
      write FOnReconcileError;
    property CachedUpdates: boolean read GetChacedUpdates write SetCachedUpdates
      default false;
    property AutoRefresh: boolean read FAutoRefresh write SetAutoRefresh
      default false;
    property Databasename: string read FDatabasename write SetDatabasename;
    property DataSource: TDataSource read GetDataSource write SetDatasource;
    property RequestLive: boolean read GetRequestLive Write SetRequestLive
      default true;

    property SQL: TStrings read GetSQL write SetSQL;
    property UniDirectional: boolean read GetUniDirectional
      write SetUniDirectional default false;
    property UpdateMode: TUpdateMode read GetUpdateMode write SetUpdateMode;

    Property Params;

    property UpdateObject: TFireUpdateSql read GetUpdateObject
      write SetUpdateObject;
    property SessionName: String read FSessionName write SetSessionName;
    property ParamCheck: boolean read GetParamCheck write SetParamCheck
      default true;
    property MacroCheck: boolean read FMacroCheck write SetMacroCheck;
    // : boolean read FCachedUpdated write SetCachedUpdated;
    property BeforeEdit;
    property AfterEdit;
    property AfterCancel;
    property AfterScroll;
    property AfterPost;
    property AfterInsert: TDataSetNotifyEvent read GetAfterInsert
      write SetAfterInsert;
    property AfterDelete;
    property BeforeCancel;
    property BeforePost;
    property BeforeDelete;
    property BeforeInsert;
    property OnCalcFields;
    property OnPostError;
    // property OnUpdateError;
    property OnDeleteError;
    property BeforeScroll;
    property Filtered;
    property Filter;
    property OnFilterRecord;
  end;

  TFireScripts = class(TFDScript)
  private
    // FLock: TObject;
    FDatabasename: String;
  protected
    function GetDatabasename: string;
    procedure SetDatabasename(const Value: string);
    function GetDatabase: TFireDatabase;
    procedure SetDatabase(const Value: TFireDatabase);
    function GetSQL: TStrings;
    procedure SetSQL(const Value: TStrings);
  public
    Constructor Create(ow: TComponent); override;
    Destructor Destroy; override;
    property Database: TFireDatabase read GetDatabase write SetDatabase;
    Property Databasename: string read GetDatabasename Write SetDatabasename;
    function ExecuteAll: boolean; overload;
    function ExecSql: boolean; virtual;
    property SQL: TStrings read GetSQL write SetSQL;
    procedure Clear;

  end;

  TFireScript = class(TFireScripts)
  private
    function GetSQL: TStrings;
    procedure SetSQL(const Value: TStrings);
  public
    procedure ExecSql; overload; virtual;
    procedure Clear;
  published
    property SQL: TStrings read GetSQL write SetSQL;
  end;

  TFireParam = TFDParam;

  { TFireParamHelper = class helper for TFireParam
    private
    function GetValue: Variant;
    procedure SetValue(const AValue: Variant);
    public
    property Value:Variant read GetValue write SetValue;
    end;
  }

  TFireParams = TFDParams;

  TFireStoredProc = class(TFDCustomStoredProc)
  private
    FDatabasename: String;
    FSessionName: string;
    procedure SetDatabasename(const Value: String);
    function GetDatabase: TFireDatabase;
    procedure SetDatabase(const Value: TFireDatabase);
    procedure SetSessionName(const Value: string);
  protected
  public
    function ExecSql: integer;
    procedure ExecProc;
    property Database: TFireDatabase read GetDatabase Write SetDatabase;
    procedure InternalOpen; override;

  published
    property Params;
    property Databasename: String read FDatabasename write SetDatabasename;
    property SessionName: string read FSessionName write SetSessionName;

    property CatalogName; // : String read GetCatalogName write SetCatalogName;
    property SchemaName; // : String read GetSchemaName write SetSchemaName;
    property PackageName; // : String read GetPackageName write SetPackageName;
    property StoredProcName; // : string read GetProcName write SetProcName;

    property active;
    property AutoCalcFields;
    property FilterOptions;
    property Filter;
    property OnFilterRecord;
    property UpdateObject;
  end;

  TFireTable = class(TFDTable)
  private
    FDatabasename: String;
    FSessionName: string;
    FReadOnly: boolean;
    FTableType: TFireTableType;
    FUpdateMode: TUpdateMode;
    FDefaultIndex: boolean;
    procedure SetDatabasename(const Value: String);
    function GetDatabase: TFireDatabase;
    procedure SetDatabase(const Value: TFireDatabase);
    procedure SetSessionName(const Value: string);
    function GetReadOnly: boolean;
    procedure SetReadOnly(const Value: boolean);
    procedure SetTableType(const Value: TFireTableType);
    function GetTableName: string;
    procedure SetTableName(const Value: string);
    procedure SetUpdateMode(const Value: TUpdateMode);
    procedure SetDefaultIndex(const Value: boolean);
  protected
    procedure SetActive(AValue: boolean); override;

  public
    property Database: TFireDatabase read GetDatabase write SetDatabase;
    procedure CreateTable;
    procedure EmptyTable;
    procedure DeleteTable;
  published
    property ReadOnly: boolean read GetReadOnly write SetReadOnly default false;
    property Databasename: String read FDatabasename write SetDatabasename;
    property DefaultIndex: boolean read FDefaultIndex write SetDefaultIndex;
    property SessionName: string read FSessionName write SetSessionName;
    property TableType: TFireTableType read FTableType write SetTableType
      default ttDefault;
    property TableName: string read GetTableName write SetTableName;
    property UpdateMode: TUpdateMode read FUpdateMode write SetUpdateMode
      default upWhereAll;

  end;

  TFireSession = class(TComponent)
  private
    FLock: TMultiReadExclusiveWriteSynchronizer;
    FConfigFile: TMemIniFile;
    FOnDbNotify: TFireDatabaseNotifyEvent;
    FSessionName: String;
    FActive: boolean;
    FnetFileDir: String;
    procedure SetOnDbNotify(const Value: TFireDatabaseNotifyEvent);
    function GetDatabases(i: integer): TFireDatabase;
    procedure SetDatabases(i: integer; const Value: TFireDatabase);
    procedure SetSessionName(const Value: String);
    procedure SetActive(const Value: boolean);
    procedure SetnetFileDir(const Value: String);
  public
    // procedure Lock;
    // procedure UnLock;
    constructor Create(ow: TComponent); override;
    destructor Destroy; override;
    function IsAlias(sAlias: String): boolean;
    procedure DeleteDatabasename(ADB: string);
    procedure AddDriver(const Name: string; List: TStrings);
    function GetAliasDriverName(sAlias: String): String;
    procedure GetAliasParams(sAlias: String; str: TStrings);
    procedure AddStandardAlias(alias, path, driver: string);
    procedure SaveConfigFile;
    property netFileDir: String read FnetFileDir write SetnetFileDir;
    procedure ModifyAlias(alias: String; ts: TStrings);
    function FindDataBase(alias: String): TFireDatabase;
    class function NewDatabase(const AConnectionString: string): TFireDatabase;
    property OnDbNotify: TFireDatabaseNotifyEvent read FOnDbNotify
      write SetOnDbNotify;
    function DatabaseCount: integer;
    procedure Close;
    procedure Open;
    property Databases[i: integer]: TFireDatabase read GetDatabases
      write SetDatabases;
    procedure CloseDatabases;
    function LockList: TDatabaseObjectList;
    procedure UnlockList;
    function OpenDatabase(dBase: string): TFireDatabase;
    procedure CloseDatabase(lDb: TFireDatabase);
    procedure DeleteAlias(sAlias: string);
    procedure AddAlias(sAlias: string; driver: string; List: TStrings);
    procedure GetTableNames(DBName, msk: String; a, b: boolean; Dest: TStrings);
    procedure GetAliasNames(items: TStrings);
    procedure GetDatabaseNames(L: TStrings);
  published
    property SessionName: String read FSessionName write SetSessionName;
    property active: boolean read FActive write SetActive;
  end;

  TFireSessions = class(TComponent)
  private
    FLock: TMultiReadExclusiveWriteSynchronizer;
    FAliases: TStringList;
    function GetItems(idx: integer): TFireSession;
    procedure SetItems(idx: integer; const Value: TFireSession);
    function GetList(sSession: string): TFireSession;
    procedure SetList(sSession: string; const Value: TFireSession);
    procedure SetCurrentSession(const Value: TFireSession);
    function GetCurrentSession: TFireSession;
  public
    procedure LoadConfig;
    function IsAlias(sAlias: String): boolean;
    constructor Create(own: TComponent); override;
    destructor Destroy; override;
    function count: integer;
    function FindSession(sSession: String): TFireSession;
    procedure OpenSession(sSession: String);
    property Sessions[idx: integer]: TFireSession read GetItems
      write SetItems; default;
    property List[sSession: string]: TFireSession read GetList write SetList;
    property CurrentSession: TFireSession read GetCurrentSession
      write SetCurrentSession;
  end;

  TFireUpdateSql = class(TFDUpdateSql)
  private
    FQuery: array [ukModify .. ukDelete] of TFireQuery;
    procedure SetDatabasename(const Value: String);
    function GetQuery(kd: TUpdatekind): TDataSet;
    // procedure SetQuery(kd: TUpdatekind; const Value: TDataset);
    function GetDatabasename: String;
    function GetDataset: TDataSet;
    procedure SetDataset(const Value: TDataSet);
    function GetDeleteSQL: TStrings;
    procedure SetDeleteSQL(const Value: TStrings);
    function GetInsertSQL: TStrings;
    procedure SetInsertSQL(const Value: TStrings);
    function GetModifySQL: TStrings;
    procedure SetModifySQL(const Value: TStrings);

  protected
    function GetSQL(UpdateKind: TUpdatekind): TStrings; virtual;
  public
    procedure SetParams(ADataset: TDataSet; UpdateKind: TUpdatekind);
      overload; virtual;
    procedure SetParams(UpdateKind: TUpdatekind); overload; virtual;
  public
    constructor Create(ow: TComponent); override;
    destructor Destroy; override;
    property DataSet: TDataSet read GetDataset write SetDataset;
    property Query[kd: TUpdatekind]: TDataSet read GetQuery; // write SetQuery;
    procedure ExecSql(UpdateKind: TUpdatekind); virtual;
    procedure Apply(UpdateKind: TUpdatekind); virtual;
    property Databasename: String read GetDatabasename write SetDatabasename;
  published
    property DeleteSQL: TStrings read GetDeleteSQL write SetDeleteSQL;
    property InsertSQL: TStrings read GetInsertSQL write SetInsertSQL;
    property ModifySQL: TStrings read GetModifySQL write SetModifySQL;
  end;

{$IFDEF MSWINDOWS}

  TFireBatchMode = (batAppend, batUpdate, batAppendUpdate, batDelete, batCopy);

  TFireBatchMove = class({$IFDEF DELPHI25gt}TFDBatchMove{$ELSE} TFDDataMove{$ENDIF})
  private
{$IFDEF DELPHI25gt}
    FDBatchMoveDataSetReader1: TFDBatchMoveDataSetReader;
    FDBatchMoveDataSetWriter1: TFDBatchMoveDataSetWriter;
{$ENDIF}
    FMode: TFireBatchMode;
    FRecordCount: integer;
    FTableType: TFireTableType;
    procedure SetMode(const Value: TFireBatchMode);
    function GetDestination: TFireTable;
    function GetSource: TDataSet;
    procedure SetDestination(const Value: TFireTable);
    procedure SetSource(const Value: TDataSet);
    procedure SetRecordCount(const Value: integer);
    procedure SetTableType(const Value: TFireTableType);
  public
    constructor Create(AOwner: TComponent); override;
    property RecordCount: integer read FRecordCount write SetRecordCount;
    procedure execute;
    property TableType: TFireTableType read FTableType write SetTableType;
  published
    property Source: TDataSet read GetSource write SetSource;
    property Destination: TFireTable read GetDestination write SetDestination;
    property Mode: TFireBatchMode read FMode write SetMode;

  end;
{$ENDIF}

function FireSession: TFireSession;
function FireSessions: TFireSessions;
procedure SetFireDacConfig(arq: string);
procedure LoadConnectionsConfig;

procedure ExchangeFieldType(qry: TFireQuery; fld: string; ftClass: TFieldClass);

function FireTable_GetErrorMessage(E: EFDDBEngineException): string;

var
  FireDebugAttrib: TDebugAttrib;

implementation

{$IFDEF BPL}
{$DEFINE EXTERNAL}
{$ENDIF}

uses
  FireDAC.Phys.Intf, System.Threading,

  FireDAC.Phys.SQLiteVDataSet,

{$IFNDEF EXTERNAL}
  System.uDebug, // DONE -oAL : refatorar, para n�o ter dependencia da uDebug
{$ENDIF}
{$IFDEF MSWINDOWS}
{$IFNDEF EXTERNAL}
  System.IniFilesEx, // DONE -oAL : remover codigo de uso interno - reavaliar
  // DONE -oAL : reavaliar - n�o deveria ter referencia para codigo interno
  FireDacLoginDialogBase,
{$IFNDEF NOTRACE}
  FireDAC.Moni.Custom,
  FireDAC.Moni.Base, // TFDMoniOutputEvent,
  FireDAC.Moni.RemoteClient,
{$ENDIF}
{$ENDIF}
  FireDAC.Stan.Util,
  FireDAC.Stan.ExprFuncs,
  Registry,
  FireDAC.Phys.ODBCBase, FireDAC.Phys.ODBC,
  FireDAC.Phys.Oracle, FireDAC.Phys.MySQL,
  FireDAC.UI.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys,
  FireDAC.DApt, // FireDAC.Phys.IBBase,
  FireDAC.Phys.FB, FireDAC.Phys.MSSQL,

{$IF CompilerVersion>27} // >XE6
  FireDAC.Phys.MySQLDef,
  FireDAC.Phys.ODBCDef, FireDAC.Phys.OracleDef,
{$IFEND}
{$ENDIF}
{$IFDEF FMX}
  FMX.Controls, FMX.Forms, FMX.Dialogs,
  FireDAC.FMXUI.Wait, FireDAC.Comp.UI,
  FireDAC.FMXUI.Login, FireDAC.FMXUI.Error,
{$ELSE}
  Vcl.Controls, {Vcl.Forms,} {Vcl.Dialogs,}
  FireDAC.VCLUI.Wait, FireDAC.Comp.UI,
  FireDAC.VCLUI.Login, FireDAC.VCLUI.Error,
{$ENDIF}
{$IFDEF CONSOLE}
  FireDAC.ConsoleUI.Wait,
{$ENDIF}
{$IF defined(ANDROID) or defined(IOS)}
  System.IOUtils,
{$IFEND}
  FireDAC.Phys.SQLite;

{ TFireDatabase }

var
  LArqConfigINI: String;

type

  TFireDacDataModule = class(TComponent)
{$IFDEF MSWINDOWS}
{$IFDEF NOGUI}
{$IFDEF CONSOLE}
    FDGUIxLoginDialog1: TFDGUIxLoginDialog;
    FDGUIxErrorDialog1: TFDGUIxErrorDialog;
{$ENDIF}
{$ELSE}
    FDGUIxLoginDialog1: TFDGUIxLoginDialog;
    FDGUIxErrorDialog1: TFDGUIxErrorDialog;
{$ENDIF}
    FDPhysODBCDriverLink1: TFDPhysODBCDriverLink;
    FDPhysOracleDriverLink1: TFDPhysOracleDriverLink;
    FDPhysMySQLDriverLink1: TFDPhysMySQLDriverLink;
    FDPhysFBDriverLink1: TFDPhysFBDriverLink;
{$IFNDEF NOTRACE}
    FDMonRemoteLink1: TFDMoniRemoteClientLink;
{$ENDIF}
    Script: TFDScript;
  private
{$IFDEF VCL}
{$IFNDEF EXTERNAL}
    procedure FDGUIxLoginDialog1Login(ASender: TObject; var AResult: boolean);
{$ENDIF}
{$ENDIF}
{$ENDIF}
  private
    FDGUIxWaitCursor1: TFDGUIxWaitCursor;
    FDPhysSQLiteDriverLink1: TFDPhysSQLiteDriverLink;
  public
    constructor Create(ow: TComponent);
    destructor Destroy; override;
{$IFDEF MSWINDOWS}
    function OraDriver: TFDPhysOracleDriverLink;
{$ENDIF}
  end;

Var

  LSessions: TFireSessions;
  LSession: TFireSession;
  LFireDacDataModule: TFireDacDataModule;
  LLocalConnection: TFireDatabase;
  LLocalSQL: TFDLocalSQL;
  LOnFinalization: boolean;
  LOnFinalizationED: boolean;

type

  TDatabasesList = class(TComponent)
  private
    FItems: TDatabaseObjectList;
    FLock: TMultiReadExclusiveWriteSynchronizer;
    function GetItems(idx: integer): TFireDatabase;
  public
    function count: integer;
    constructor Create(AOwner: TComponent);
    function Lock: TDatabaseObjectList;
    procedure Release;
    procedure Remove(DB: TFireDatabase);
    destructor Destroy; override;
    procedure add(ADB: TFireDatabase);
    procedure Delete(i: integer);
    property items[idx: integer]: TFireDatabase read GetItems;
    function FindDataBase(alias: String): TFireDatabase;
  end;

var
  LDatabases: TDatabasesList;

function FireSession: TFireSession;
begin
  result := LSession;
end;

function FireSessions: TFireSessions;
begin
  result := LSessions;
end;

procedure TFireDatabase.BeginRead;
begin
{$IFNDEF DLL}
  FLock.BeginRead;
{$ENDIF}
end;

procedure TFireDatabase.BeginWrite;
begin
{$IFNDEF DLL}
  FLock.BeginWrite;
{$ENDIF}
end;

procedure TFireDatabase.CheckTrace;
var
  i: integer;
begin
{$IFNDEF NOTRACE}
  i := Params.IndexOfName('MonitorBy');
  if i >= 0 then
    Params.Delete(i);
{$IFEND}
end;

function TFireDatabase.Clone(ADbaseName: string; AOwner: TComponent = nil)
  : TFireDatabase;
begin
  if AOwner = nil then
    AOwner := LFireDacDataModule;
  result := TFireDatabase.Create(AOwner);
  result.FillParams(self);
  result.Databasename := ADbaseName;
end;

procedure TFireDatabase.CloseDataSets;
var
  i: integer;
begin
  BeginWrite;
  try
    for i := DataSetCount - 1 downto 0 do
      DataSets[i].Close;
  finally

    EndWrite;
  end;
end;

constructor TFireDatabase.Create(ow: TComponent);
begin
  inherited;
  if not assigned(LDatabases) then
    exit;
  LDatabases.add(self);
{$IFNDEF DLL}
  FLock := TMultiReadExclusiveWriteSynchronizer.Create;
{$ENDIF}
  try
{$IFDEF MSWINDOWS}
{$IFDEF NOGUI}
{$ELSE}
{$IFDEF USACUSTOMDLG}
    OnLogin := DoLoginDialogEvent;
{$ELSE}
{$IFNDEF DLL}
    LoginDialog := LFireDacDataModule.FDGUIxLoginDialog1;
{$ENDIF}
{$ENDIF}
{$ENDIF}
{$ENDIF}
{$IFNDEF DLL}
    FSession := LSession;
{$ENDIF}
    BeforeConnect := DoBeforeConnectEvent;
    AfterConnect := DoAfterConnectEvent;
    FormatOptions.InlineDataSize := 255;
    FetchOptions.RowSetSize := firedac_rowSetSize;
    // menos de 50 repete muitas buscas... mais de 500 - fica pesado
    FetchOptions.Mode := fmOnDemand;
    FetchOptions.CursorKind := ckDynamic;
    FetchOptions.AutoClose := true; // teste
    ResourceOptions.AutoReconnect := true;
    ResourceOptions.AutoConnect := true;
{$IFDEF MULTI_THREADED}
    ResourceOptions.SilentMode := true;
{$ENDIF}
    with UpdateOptions do
    begin
      CheckUpdatable := false;
      CheckReadOnly := false;
    end;

  finally
  end;
end;

function TFireDatabase.CreatePoolManager: string;
var
  oList: TStringList;
begin
  if not assigned(FPoolManager) then
  begin
    oList := TStringList.Create;
    try
      oList.text := Params.text;
      if not assigned(FPoolManager) then
        FPoolManager := TFireManager.Create(nil);
      FPoolManager.PoolDatabasename := Databasename + '_pool';
      FPoolManager.Connection := self.Clone(FPoolManager.PoolDatabasename,
        FPoolManager);
      result := FPoolManager.PoolDatabasename;
      FPoolManager.AddConnectionDef(result, DriverName, oList);
      FPoolManager.Connection.ConnectionDefName := result;
    finally
      oList.free;
    end;
  end;
  result := FPoolManager.PoolDatabasename;
end;

type
  TFireDataType = (fdtComum, fdtFirebird, fdtOracle, fdtMSSQL,
    fdtSQLITE, fdtODBC);

procedure TFireDatabase.init;
var
  fdt: TFireDataType;
begin
  fdt := fdtComum;
  if SameText(Params.Values['DriverID'], 'FB') then
    fdt := fdtFirebird
  else if SameText(Params.Values['DriverID'], 'Ora') then
    fdt := fdtOracle
  else if SameText(Params.Values['DriverID'], 'SQLITE') then
    fdt := fdtSQLITE
  else if SameText(Params.Values['DriverID'], 'mssql') then
    fdt := fdtMSSQL
  else if SameText(Params.Values['DriverID'], 'odbc') then
    fdt := fdtODBC;

{$IFDEF MSWINDOWS}
  // All BDs
  with FormatOptions do
  begin
    MapRules.Clear;
  end;

  case fdt of
    fdtODBC:
      begin
        // nao fazer nada
        FormatOptions.OwnMapRules := false;
        FormatOptions.strsTrim := true;
      end;
    fdtFirebird:
      begin
        if (Params.Values['VendorLib'] <> '') and
          (LFireDacDataModule.FDPhysFBDriverLink1.VendorLib <> Params.Values
          ['VendorLib']) then
        begin
          LFireDacDataModule.FDPhysFBDriverLink1.Release;
          LFireDacDataModule.FDPhysFBDriverLink1.VendorLib :=
            Params.Values['VendorLib'];
        end;

        with FormatOptions do
        begin
          MaxStringSize := 255;
          OwnMapRules := true;
          strsTrim := true;
          with MapRules.add do
          begin
            SourceDataType := dtBCD;
            TargetDataType := dtDouble;
          end;
          with MapRules.add do
          begin
            SourceDataType := dtSingle;
            TargetDataType := dtDouble;
          end;
          with MapRules.add do
          begin
            SourceDataType := dtDateTimeStamp;
            TargetDataType := dtDateTime;
          end;
          with MapRules.add do
          begin
            SourceDataType := dtWideMemo;
            TargetDataType := dtMemo;
          end;
          with MapRules.add do
          begin
            SourceDataType := dtDate;
            TargetDataType := dtDateTime;
          end;
        end;
      end;
    fdtMSSQL:
      with FormatOptions do
      begin
        Round2Scale := true; // teste
{$IF CompilerVersion>=29.0}
        CheckPrecision := true; // teste
{$ENDIF}
        MaxStringSize := 255;
        OwnMapRules := true;
        strsTrim := true;
        with MapRules.add do
        begin
          ScaleMin := 2;
          ScaleMax := 4;
          PrecMin := 15;
          PrecMax := 19;
          SourceDataType := dtBCD;
          TargetDataType := dtCurrency;
          // se usar dtDouble.. muda o resultado da coluna.
        end;
        with MapRules.add do
        begin
          SourceDataType := dtBCD;
          TargetDataType := dtDouble;
        end;
        with MapRules.add do
        begin
          SourceDataType := dtDateTimeStamp;
          TargetDataType := dtDateTime;
        end;
        with MapRules.add do
        begin
          SourceDataType := dtDate;
          TargetDataType := dtDateTime;
        end;
        with MapRules.add do
        begin
          SourceDataType := dtSingle;
          TargetDataType := dtDouble;
        end;
        with MapRules.add do
        begin
          SourceDataType := dtFmtBCD;
          TargetDataType := dtCurrency;
        end;
        with MapRules.add do
        begin
          SourceDataType := dtWideMemo;
          TargetDataType := dtMemo;
        end;
        { with MapRules.add do
          begin
          SourceDataType := dt;
          TargetDataType := dtMemo;
          end;
        }

      end;
    fdtSQLITE:
      with FormatOptions do
      begin
        // Round2Scale := true; // teste
        // CheckPrecision := false; // teste
      end;
    fdtOracle:
      begin // valido para Oracle
        if (Params.Values['VendorLib'] <> '') and
          (LFireDacDataModule.OraDriver.VendorLib <> Params.Values['VendorLib'])
        then
        begin
          LFireDacDataModule.OraDriver.Release;
          LFireDacDataModule.OraDriver.VendorLib := Params.Values['VendorLib'];
        end;
        with FormatOptions do
        begin
          Round2Scale := true; // teste
{$IF CompilerVersion>=29.0}
          CheckPrecision := true; // teste
{$ENDIF}
          MaxStringSize := 255;
          OwnMapRules := true;
          with MapRules.add do
          begin
            SourceDataType := dtSingle;
            TargetDataType := dtDouble;
          end;
          with MapRules.add do
          begin
            ScaleMin := 4;
            ScaleMax := 4;
            PrecMin := 18;
            PrecMax := 18;
            SourceDataType := dtBCD;
            TargetDataType := dtCurrency;
          end;
          with MapRules.add do
          begin // ID_PESSOA Precisao: 7  -  AL 15/04/2015
            ScaleMin := 1;
            ScaleMax := 4;
            PrecMin := 1;
            PrecMax := 8;
            SourceDataType := dtBCD;
            TargetDataType := dtDouble;
          end;
          (* with MapRules.Add do
            begin // ID_CPF Precisao: 11  -  AL 08/09/2015 (JANELA DE CADASTRO DE CLIENTE)
            ScaleMin := 0;
            ScaleMax := 1;
            PrecMin := 11;
            PrecMax := 11;
            SourceDataType := dtBCD;
            TargetDataType := dtCurrency;
            end; *)
          with MapRules.add do
          begin
            SourceDataType := dtBCD;
            TargetDataType := dtExtended;
          end;
          with MapRules.add do
          begin
            SourceDataType := dtFmtBCD;
            TargetDataType := dtCurrency;
          end;
          with MapRules.add do
          begin
            SourceDataType := dtWideMemo;
            TargetDataType := dtMemo;
          end;
          with MapRules.add do
          begin
            SourceDataType := dtDateTimeStamp;
            TargetDataType := dtDateTime;
          end;
          with MapRules.add do
          begin
            SourceDataType := dtDate;
            TargetDataType := dtDateTime;
          end;
        end;
      end
  else
    with FormatOptions do
    begin
      MaxStringSize := 255;
      OwnMapRules := true;
      with MapRules.add do
      begin
        SourceDataType := dtDateTimeStamp;
        TargetDataType := dtDateTime;
      end;
      with MapRules.add do
      begin
        SourceDataType := dtWideMemo;
        TargetDataType := dtMemo;
      end;
    end;
  end;
{$ENDIF}
end;

class function TFireDatabase.New(AAlias, ADatabase, AUser, ASenha: string)
  : TFireDatabase;
begin
  result := FireSession.FindDataBase(ADatabase);
  if not assigned(result) then
  begin
    result := TFireDatabase.Create(LFireDacDataModule);
    result.AliasName := AAlias;
    result.Databasename := ADatabase;
    result.ResourceOptions.SilentMode := true;
    if AUser <> '' then
      result.UserName := AUser;
    if ASenha <> '' then
      result.Password := ASenha;

    if result.Password <> '' then
      result.LoginPrompt := false;

  end;
end;

procedure TFireDatabase.FillParams(ADB: TFireDatabase);
begin
  AliasName := ADB.AliasName;
  Params.Assign(ADB.Params);
  ResourceOptions.Assign(ADB.ResourceOptions);
  FetchOptions.Assign(ADB.FetchOptions);
end;

{$IFNDEF BPL}

class function TFireDatabase.NewQuery(ADatabaseName: string): IQuery;
var
  qry: TFireQuery;
  Intf: TQueryIntf<TFDQuery>;
begin
  qry := TFireQuery.Create(LFireDacDataModule);
  qry.Databasename := ADatabaseName;
  Intf := TQueryIntf<TFDQuery>.Create(qry);
  Intf.FreeOnDestroy := true;
  result := Intf as IQuery;
end;

{$ENDIF}

class procedure TFireDatabase.Release;
begin
  if assigned(FPoolManager) then
  begin
    FPoolManager.free;
    FPoolManager := nil;
  end;
end;

var
  LLastDatabase: TFireDatabase;

destructor TFireDatabase.Destroy;
begin
  LLastDatabase := nil;
  CloseDataSets;
  if assigned(LDatabases) then
  begin
    LDatabases.Remove(self);
  end;

{$IFDEF MSWINDOWS}
{$IFDEF USACUSTOMDLG}
  OnLogin := nil;
{$ELSE}
  LoginDialog := nil;
{$ENDIF}
{$ENDIF}
  BeforeConnect := nil;
  AfterConnect := nil;
{$IFNDEF DLL}
  FSession := nil;
  freeAndNil(FLock);
{$ENDIF}
  inherited;
end;

procedure TFireDatabase.DoBeforeConnectEvent(sender: TObject);
begin
  FStopwatch := TStopwatch.StartNew;
end;

procedure TFireDatabase.DoAfterConnectEvent(sender: TObject);
begin

{$IFNDEF EXTERNAL}
  FStopwatch.Stop;
  if FireDebugAttrib.active and FireDebugAttrib.execute then
    DebugLog('Conex�o: ' + AliasName + '  Tempo: ' + FormatFloat('0.000',
      FStopwatch.ElapsedMilliseconds / 1000));

  if not(csDesigning in ComponentState) then
    LoginPrompt := false;

  if SameText(Params.Values['DriverID'], 'mssql') then
  begin
    ExecSql('set dateformat mdy;');
  end;
{$ENDIF}
end;

{$IFDEF EXTERNAL}

function GetProgramFilesDir: String;
begin
  with TRegistry.Create(KEY_QUERY_VALUE) do
  begin
    RootKey := HKEY_LOCAL_MACHINE;
    OpenKey('\SOFTWARE\Microsoft\Windows\CurrentVersion', true);
    result := ReadString('ProgramFilesDir');
    free;
  end;
end;
{$ENDIF}

procedure SetFireDacConfig(arq: string);
begin
  LArqConfigINI := arq;
  LoadConnectionsConfig;
end;

function GetConfigIni: string;
begin
  if LArqConfigINI = '' then
{$IFDEF MSWINDOWS}
{$IFDEF BPL}
    LArqConfigINI := GetProgramFilesDir + '\store\config\zConnections.ini';
{$ELSE}
{$IFDEF EXTERNAL}
    LArqConfigINI := GetProgramFilesDir + '\store\config\zConnections.ini';
{$ELSE}
    LArqConfigINI := GetIniFilesDir + 'zConnections.ini';
{$ENDIF}
{$ENDIF}
{$ELSE}
    LArqConfigINI := TPath.Combine(TPath.GetSharedDocumentsPath,
      'zConnections.ini');
{$ENDIF}
  result := LArqConfigINI;

end;

procedure TFireDatabase.DoConnect;
var
  oDef: IFDStanConnectionDef;
  oldLoginPrompt: boolean;
begin
  oldLoginPrompt := LoginPrompt;
  try
    BeginWrite;
    try
      if Params.Values['DriverID'] = '' then
        Params.Values['DriverID'] := DriverName;

      if Params.Values['DriverID'] = '' then
        raise exception.Create('Falta definir o protocolo em ' + LArqConfigINI +
          ' para a conex�o: ' + Databasename + ' Alias: ' + AliasName);
      if (Params.Values['DriverID'] = 'SQLITE') and (FDriverType = '') then
        FDriverType := 'SQLITE';

      if (Params.Values['DriverID'] <> '') and (UserName <> '') and
        (Password <> '') then
        LoginPrompt := false;

      inherited;
    finally
      EndWrite;
    end;
  finally
    LoginPrompt := oldLoginPrompt;
  end;
end;

{$IFDEF USACUSTOMDLG}
{$IFDEF VER290}

procedure TFireDatabase.DoLoginDialogEvent(AConnection: TFDCustomConnection;
  const AParams: TFDConnectionDefParams);
{$ELSE}

procedure TFireDatabase.DoLoginDialogEvent(AConnection: TFDCustomConnection;
  const AConnectionDef: IFDStanConnectionDef);
{$ENDIF}
var
  dlg: TFireDacLoginDlgBase;
begin
  dlg := TFireDacLoginDlgBase.Create(LSessions);
  try
    dlg.Connection := AConnection;
    dlg.Caption := 'Login: ' + Databasename;
    dlg.User_Name.text := AConnection.Params.Values['USER_NAME'];
    dlg.ShowModal;
    if dlg.Canceled = false then
    begin
{$IFDEF VER280}
      AConnectionDef.Params.UserName := dlg.User_Name.text;
      AConnectionDef.Params.Password := dlg.Password.text;
{$ELSE}
      AConnectionDef.UserName := dlg.User_Name.text;
      AConnectionDef.Password := dlg.Password.text;
{$ENDIF}
    end;
  finally
    dlg.free;
  end;
end;

{$ENDIF}

procedure TFireDatabase.EndRead;
begin
{$IFNDEF DLL}
  FLock.EndRead;
{$ENDIF}
end;

procedure TFireDatabase.EndWrite;
begin
{$IFNDEF DLL}
  FLock.EndWrite;
{$ENDIF}
end;

procedure TFireDatabase.GetColumnNames(ATable, aTmp: string; ALst: TStrings);
begin
  GetFieldNames('', '', ATable, '', ALst);
end;

function TFireDatabase.GetFireConnectionString: string;
var
  str: TStringList;
  i: integer;
begin
  str := TStringList.Create;
  try
    str.Assign(Params);
    str.Delimiter := ';';
    str.Values['Databasename'] := Databasename;
    str.Values['AliasName'] := AliasName;
    i := str.IndexOfName('MonitorBy');
    if i >= 0 then
      str.Delete(i);
    result := str.DelimitedText;
  finally
    str.free;
  end;
end;

procedure TFireDatabase.GetIndexes(ATableName: string; AListFields: TStrings);
begin
  self.GetIndexNames('', '', ATableName, '', AListFields);
end;

function TFireDatabase.GetDatabasename: string;
begin
  result := ConnectionName;
end;

procedure TFireDatabase.GetFieldNames(tabela: string; lst: TStrings);
begin
  GetColumnNames(tabela, '', lst);
end;

function TFireDatabase.GetPassword: string;
begin
  result := Params.Values['PASSWORD'];
end;

procedure TFireDatabase.GetPrimaryKeyFields(ATableName: String;
  AListFields: TStrings);
begin
  self.GetKeyFieldNames('', '', ATableName, '', AListFields);
end;

procedure TFireDatabase.GetStoredProcNames(lst: TStrings; APattern: string);
var
  AScopes: TFDPhysObjectScopes;
begin
  inherited GetStoredProcNames('', '', '', APattern, lst, AScopes, true);
end;

procedure TFireDatabase.GetTableNames(lst: TStrings; sysObjs: boolean);
var
  LScopes: TFDPhysObjectScopes;
begin
  LScopes := [osMy, osOther];
  if sysObjs then
    LScopes := LScopes + [osSystem];
  if SameText(DriverName, 'SQLITE') then
    inherited GetTableNames('', '', '', lst)
  else
    inherited GetTableNames('', '', '', lst, LScopes, [tkTable, tkView]);
end;

function TFireDatabase.GetTimeout: integer;
begin
  result := ResourceOptions.CmdExecTimeout;
end;

function TFireDatabase.GetUserName: string;
begin
  result := Params.Values['USER_NAME'];
end;

{$IFDEF MSWINDOWS}

function GetComputerName: String;
var
  LBuffer: array [0 .. 255] of Char;
  LSize: dWord;
  LComputerName: string;
begin
  with TRegistry.Create(KEY_READ) do
    try
      RootKey := HKEY_LOCAL_MACHINE;
      OpenKey('\System\CurrentControlSet\Control\ComputerName\ComputerName',
        false);
      result := ReadString('ComputerName');
    finally
      free;
    end;

  { Quando a fun��o acima n�o retornar o nome do computador, e executada nova
    fun��o para ler o nome do computador - Acessibilidade do Usu�rio do Windows
    ou Windows Service }
  if Trim(result) = '' then
  begin
    LSize := MAX_COMPUTERNAME_LENGTH + 1;
    Windows.GetComputerName(LBuffer, LSize);
    LComputerName := LBuffer;
    result := StrPas(PChar(LComputerName));
  end;
end;
{$ENDIF}

procedure FillLocalSQLConnectionParams(ADB: TFireDatabase);
begin
  ADB.DriverName := 'SQLite';
  ADB.Params.Values['Database'] := ':memory:';
  ADB.Params.Values['DriverID'] := 'SQLite';
  ADB.ConnectionName := c_alias_Local_SQLite;
  ADB.FDriverType := 'SQLITE';
  ADB.LoginPrompt := false;
end;

function Protocol2DriverID(AProtocol: string): string;
begin
  if pos('firebird', AProtocol) > 0 then
    result := 'FB'
  else if pos('oracle', AProtocol) > 0 then
    result := 'Ora'
  else if (pos('ado', AProtocol) > 0) or (pos('odbc', AProtocol) > 0) then
    result := 'ODBC'
  else if pos('mssql', AProtocol) > 0 then
    result := 'MSSQL'
  else if SameText(AProtocol, 'mysql') then
    result := 'MySQL'
  else if SameText(AProtocol, 'sqlite') then
    result := 'SQLITE'

  else
    result := AProtocol;
end;

const
  ReTablebase64 = #$40 + #$40 + #$40 + #$40 + #$40 + #$40 + #$40 + #$40 + #$40 +
    #$40 + #$3E + #$40 + #$40 + #$40 + #$3F + #$34 + #$35 + #$36 + #$37 + #$38 +
    #$39 + #$3A + #$3B + #$3C + #$3D + #$40 + #$40 + #$40 + #$40 + #$40 + #$40 +
    #$40 + #$00 + #$01 + #$02 + #$03 + #$04 + #$05 + #$06 + #$07 + #$08 + #$09 +
    #$0A + #$0B + #$0C + #$0D + #$0E + #$0F + #$10 + #$11 + #$12 + #$13 + #$14 +
    #$15 + #$16 + #$17 + #$18 + #$19 + #$40 + #$40 + #$40 + #$40 + #$40 + #$40 +
    #$1A + #$1B + #$1C + #$1D + #$1E + #$1F + #$20 + #$21 + #$22 + #$23 + #$24 +
    #$25 + #$26 + #$27 + #$28 + #$29 + #$2A + #$2B + #$2C + #$2D + #$2E + #$2F +
    #$30 + #$31 + #$32 + #$33 + #$40 + #$40 + #$40 + #$40 + #$40 + #$40;

function Decode4to3Ex(const Value, Table: AnsiString): AnsiString;
var
  x, y, lv: integer;
  d: integer;
  dl: integer;
  c: byte;
  p: integer;
begin
  lv := Length(Value);
  SetLength(result, lv);
  x := 1;
  dl := 4;
  d := 0;
  p := 1;
  while x <= lv do
  begin
    y := Ord(Value[x]);
    if y in [33 .. 127] then
      c := Ord(Table[y - 32])
    else
      c := 64;
    Inc(x);
    if c > 63 then
      continue;
    d := (d shl 6) or c;
    dec(dl);
    if dl <> 0 then
      continue;
    result[p] := AnsiChar((d shr 16) and $FF);
    Inc(p);
    result[p] := AnsiChar((d shr 8) and $FF);
    Inc(p);
    result[p] := AnsiChar(d and $FF);
    Inc(p);
    d := 0;
    dl := 4;
  end;
  case dl of
    1:
      begin
        d := d shr 2;
        result[p] := AnsiChar((d shr 8) and $FF);
        Inc(p);
        result[p] := AnsiChar(d and $FF);
        Inc(p);
      end;
    2:
      begin
        d := d shr 4;
        result[p] := AnsiChar(d and $FF);
        Inc(p);
      end;
  end;
  SetLength(result, p - 1);
end;

function DecodeBase64(const Value: AnsiString): AnsiString;
begin
  result := Decode4to3Ex(Value, ReTablebase64);
end;

var
  LConnectionsINI: TMemIniFile;

procedure LoadConnectionsConfig;
begin
  if assigned(LConnectionsINI) then
    LConnectionsINI.free;
  LConnectionsINI := TMemIniFile.Create(LArqConfigINI);
end;

procedure InitDataBaseParams(ADB: TFireDatabase; AinMemory: boolean = false);
var
  LStr: TStringList;
  LOSAuthent, LProtocol, LPort, LHostname, LDatabase, LUsername, LPassword,
    LDialect, { cSet, } LCharacterSet, LVendorLib: string;
  LRowsetsize: integer;
  LAutoClose: boolean;
  AConn: String;
  // oDef: IFDStanConnectionDef;
  procedure FireFillParams(ADriveName: string; AParams: TStrings);
    procedure add(ANome: string; AValor: string);
    begin
      AParams.Values[ANome] := AValor;
    end;
    function appRoleName: string;
    begin
      result := StringReplace(uppercase(ExtractFileName(ParamStr(0))),
        'XE.EXE', '.', []);
      result := copy(result, 1, pos('.', result) - 1);
    end;

  begin
{$IFDEF MSWINDOWS}
    add('DriverID', ADriveName);

    if SameText(ADriveName, 'FB') then
    begin
      add('Server', LHostname);
      add('Database', LDatabase);
      add('OSAuthent', LOSAuthent);
      if LVendorLib <> '' then
      begin
        LFireDacDataModule.FDPhysFBDriverLink1.VendorLib := LVendorLib;
        add('VendorLib', LVendorLib);
      end;
      add('RoleName', appRoleName);
      if LPort <> '' then
        add('Port', LPort);
      if LDialect <> '' then
        add('SQLDialect', LDialect);
      if LCharacterSet <> '' then
        add('CharacterSet', LCharacterSet);
      // Compatibilidade com os campos Nome no banco WIN1252 - Calixto
      ADB.FDriverType := 'INTRBASE';
    end
    else if SameText(ADriveName, 'Ora') then
    begin
      if LVendorLib <> '' then
      begin
        // LFireDacDataModule.FDPhysOracleDriverLink1.VendorLib := LVendorLib;
        add('VendorLib', LVendorLib);
      end;
      add('Database', LDatabase);
      add('OSAuthent', LOSAuthent);
      add('AuthMode', 'Normal');
      if LCharacterSet <> '' then
        add('CharacterSet', LCharacterSet); // UTF-8  ou  <NLS_LANG>
      ADB.FDriverType := 'ORACLE';
    end
    else if SameText(ADriveName, 'ODBC') then
    begin
      add('Datasource', LDatabase);
      add('ODBCAdvanced', 'DSN=' + LDatabase);
      ADB.FDriverType := 'ODBC';
    end
    else if SameText(ADriveName, 'MSSQL') then
    begin
      add('Server', LHostname);
      add('Database', LDatabase);
      add('RoleName', appRoleName);
      ADB.FDriverType := 'MSSQL';
    end
    else if SameText(ADriveName, 'SQLITE') then
    begin
      add('Database', LDatabase);
      add('Server', LHostname);
      add('LockingMode', 'Normal');
      if LPort = '' then
        add('Port', LPort);
      ADB.FDriverType := 'SQLITE';
    end
    else if SameText(ADriveName, 'MySQL') then
    begin
      add('Database', LDatabase);
      add('Server', LHostname);
      if LPort = '' then
        LPort := '3306';
      add('Port', LPort);
      ADB.FDriverType := 'MYSQL';
      if LStr.Values['UseSSL'] <> '' then
      begin
        add('UseSSL', LStr.Values['UseSSL']);
        add('SSL_ca', LStr.Values['SSL_ca']);
        add('SSL_cert', LStr.Values['SSL_cert']);
        add('SSL_key', LStr.Values['SSL_key']);
        add('SSL_capath', LStr.Values['SSL_capath']);
        add('SSL_cipher', LStr.Values['SSL_cipher']);
      end;
    end;
{$ENDIF}
    add('ApplicationName', ExtractFileName(ParamStr(0)));
{$IFDEF MSWINDOWS}
    add('Workstation', GetComputerName());
{$ENDIF}
    if LUsername <> '' then
      add('User_Name', LUsername);
    if LPassword <> '' then
      add('Password', LPassword);

{$IFNDEF NOTRACE}
    if (AinMemory and (not SameText(ADriveName, 'SQLITE'))) or FireDebugAttrib.active
    then
      add('MonitorBy', 'Remote');
{$IFEND}
  end;

var
  LAuth: string;
  LUser: TArray<string>;
begin
  ADB.BeginWrite;
  try
    if (SameText(ADB.AliasName, c_alias_Local_SQLite)) and
      assigned(LLocalConnection) then
    begin
      FillLocalSQLConnectionParams(ADB);
      exit;
    end;

    if not fileExists(LArqConfigINI) then
    begin
      ForceDirectories(ExtractFilePath(LArqConfigINI));
      with TIniFile.Create(LArqConfigINI) do
        try
          WriteString('SQLITE', 'Protocol', 'SQLITE');
          WriteString('SQLITE', 'Database', ExtractFilePath(LArqConfigINI) +
            'sqliteFiredac.sqlite3');
        finally
          free;
        end;
      exit;
    end;

    if not assigned(LConnectionsINI) then
      LoadConnectionsConfig;
    System.TMonitor.Enter(LConnectionsINI);
    try
      LStr := TStringList.Create;
      try

        LConnectionsINI.ReadSectionValues(ADB.AliasName, LStr);
        if (LStr.count = 0) then
          raise exception.Create('N�o leu informa��es de configura��o: ' +
            LArqConfigINI + ' Alias: ' + ADB.AliasName);

        if not LConnectionsINI.ValueExists(ADB.AliasName, 'AutoClose') then
        begin
          LConnectionsINI.WriteBool(ADB.AliasName, 'AutoClose', true);
          LConnectionsINI.WriteInteger(ADB.AliasName, 'RowSetSize', 250);
        end;

        LAutoClose := LConnectionsINI.ReadBool(ADB.AliasName,
          'AutoClose', true);
        LRowsetsize := LConnectionsINI.ReadInteger(ADB.AliasName,
          'RowSetSize', 250);
        LProtocol := lowercase(LStr.Values['Protocol']);
        LPort := LStr.Values['Port'];
        LHostname := LStr.Values['Hostname'];
        LDatabase := LStr.Values['Database'];
        LAuth := DecodeBase64(LStr.Values['Auth']);
        if LAuth = '' then
          LAuth := '==';
        LUser := LAuth.split(['='], 2);
        LUsername := LUser[0]; // LStr.Values['User'];
        LPassword := LUser[1]; // LStr.Values['Password'];
        LDialect := LStr.Values['Dialect'];
        LCharacterSet := LStr.Values['CharacterSet'];
        LVendorLib := LStr.Values['VendorLib'];
        LOSAuthent := LStr.Values['OSAuthent'];

        if LOSAuthent = '' then
          LOSAuthent := 'no';

        if LProtocol = '' then
          exit;

        FireFillParams(Protocol2DriverID(LProtocol), ADB.Params);

        ADB.FetchOptions.AutoClose := LAutoClose;
        if LRowsetsize <= 0 then
        begin
          ADB.FetchOptions.Mode := fmAll;
          // carrega todos os registros da tabela - indicado para ambientes inst�veis
        end
        else
        begin
          ADB.FetchOptions.RowSetSize := LRowsetsize;
          ADB.FetchOptions.Mode := fmOnDemand;
          // carrega somente o numero de registro necess�rio.  Indicado para tabelas grandes
        end;

      finally
        System.TMonitor.exit(LConnectionsINI);
      end;
    finally
      LStr.free;
    end;
  finally
    ADB.EndWrite;
  end;
end;

class procedure TFireDatabase.InitParams(ADB: TFDConnection;
  AAliasName: string);
var
  DB: TFireDatabase;
begin
  DB := FireSession.FindDataBase(AAliasName);
  if assigned(DB) then
  begin
    ADB.Params.Assign(DB.Params);
    ADB.LoginPrompt := DB.LoginPrompt;
  end;
end;

procedure TFireDatabase.SetAliasName(const Value: string);
var
  DB: TFireDatabase;
  s: string;
  i: integer;
begin
  FAliasName := Value;
  if not FmanualConfig then
    InitDataBaseParams(self);
  init;
  if Databasename = '' then
  begin
    i := 1;
    repeat
      s := Value + intToStr(i);
      DB := FireSession.FindDataBase(s);
      Inc(i);
    until DB = nil;
    Databasename := s;
  end;
{$IFNDEF BPL}
  if assigned(Params) then
    if not(csDesigning in ComponentState) then
      try
        Params.Values['ConnectionName'] := Value;
        Params.Values['AliasName'] := Value;
      Except
      end;
  CheckTrace;
{$ENDIF}
end;

procedure TFireDatabase.SetFireConnectionString(const AConn: String);
var
  str: TStringList;
  i: integer;
begin
  str := TStringList.Create;
  try
    str.Delimiter := ';';
    str.DelimitedText := AConn;
{$IFDEF NOTRACE}
    i := str.IndexOfName('MonitorBy');
    if i >= 0 then
      str.Delete(i);
{$ENDIF}
    Params.CommaText := str.CommaText;
    LoginPrompt := Params.Values['password'] = '';
  finally
    str.free;
  end;
  CheckTrace;
end;

procedure TFireDatabase.SetDatabasename(const Value: string);
var
  DB: TFireDatabase;
begin
  if not FmanualConfig then
  begin
    DB := Session.FindDataBase(Value);
    if assigned(DB) and (DB <> self) then
      raise exception.Create('J� existe um database com o mesmo identificador <'
        + Value + '>');
  end;

  if FDriverType = '' then
    FDriverType := Params.Values['DriverID'];
  ConnectionName := Value;
{$IFNDEF BPL}
  try
    if assigned(Params) then
      if not(csDesigning in ComponentState) then
        Params.Values['Databasename'] := Value;
  except
  end;
{$ENDIF}
end;

procedure TFireDatabase.SetKeepConnection(const Value: boolean);
begin
  FKeepConnection := Value;
end;

procedure TFireDatabase.SetmanualConfig(const Value: boolean);
begin
  FmanualConfig := Value;
end;

procedure TFireDatabase.SetPassword(const Value: string);
begin
  Params.Values['PASSWORD'] := Value;
end;

{
  procedure TFireDatabase.SetSession(const Value: TFireSession);
  begin
  FSession := Value;
  end;
}
procedure TFireDatabase.SetSessionName(const Value: String);
begin
  FSessionName := Value;
end;

procedure TFireDatabase.SetTimeout(const Value: integer);
begin
  ResourceOptions.CmdExecTimeout := Value;
end;

procedure TFireDatabase.SetTransIsolation(const Value: TFireTransIsolation);
begin
  FTransIsolation := Value;
end;

procedure TFireDatabase.SetUserName(const Value: string);
begin
  Params.Values['USER_NAME'] := Value;
end;

{ procedure TFireDatabase.UnLock;
  begin
  FLock.EndRead;
  end; }

{ TFireDatabases }

{ TFireUpdateSql }

procedure TFireUpdateSql.Apply(UpdateKind: TUpdatekind);
var
  uk: TFDUpdateRequest;
  err: TFDErrorAction;
  opt: TFDUpdateRowOptions;
begin
  case UpdateKind of
    ukModify:
      uk := arUpdate;
    ukInsert:
      uk := arInsert;
    ukDelete:
      uk := arDelete;
  end;
  inherited Apply(uk, err, opt);
end;

constructor TFireUpdateSql.Create(ow: TComponent);
begin
  inherited Create(ow);
end;

destructor TFireUpdateSql.Destroy;
begin

  inherited;
end;

procedure DebugLogFields(qry: TFireQuery);
var
  s: string;
  i: integer;
  dt: string;
begin
  s := '';
  if qry.eof then
    exit;
  try

    for i := 0 to qry.Fields.count - 1 do
    begin
      dt := FieldTypeNames[qry.Fields[i].DataType];
      s := s + 'Field: ' + qry.Fields[i].FieldName + ' Type: ' + dt + ' Value: '
        + qry.Fields[i].asString + #13#10;
    end;
  except
  end;
{$IFDEF MSWINDOWS}
{$IFNDEF EXTERNAL}
  if s <> '' then
    DebugLog(s);
{$ENDIF}
{$ENDIF}
end;

procedure DebugLogParams(qry: TFireQuery);
var
  s: string;
  i: integer;
  dt: string;
begin
  s := '';
  try
    for i := 0 to qry.Params.count - 1 do
    begin
      dt := FieldTypeNames[qry.Params[i].DataType];
      s := s + #13#10 + '  Param: ' + qry.Params[i].Name + ' Type: ' + dt +
        ' Value: ' + qry.Params[i].asString;
    end;
  except
  end;
{$IFDEF MSWINDOWS}
{$IFNDEF EXTERNAL}
  if s <> '' then
    DebugLog(s);
{$ENDIF}
{$ENDIF}
end;

procedure TFireUpdateSql.ExecSql(UpdateKind: TUpdatekind);
var
  q: TFireQuery;
  LWatchr: TStopwatch;
begin
{$IFDEF LOG}
  q := TFireQuery(Query[UpdateKind]);
{$ENDIF}
  if FireDebugAttrib.active then
    LWatchr := TStopwatch.StartNew;
  with TFireQuery(Query[UpdateKind]) do
  begin
    CmdExecMode := TFireQuery(DataSet).CmdExecMode;
    ExecSql;
  end;
end;

function TFireUpdateSql.GetDatabasename: String;
begin
  result := inherited ConnectionName;
end;

function TFireUpdateSql.GetDataset: TDataSet;
begin
  result := inherited DataSet;
end;

function TFireUpdateSql.GetDeleteSQL: TStrings;
begin
  result := inherited DeleteSQL;
end;

function TFireUpdateSql.GetInsertSQL: TStrings;
begin
  result := inherited InsertSQL;
end;

function TFireUpdateSql.GetModifySQL: TStrings;
begin
  result := inherited ModifySQL;
end;

function TFireUpdateSql.GetQuery(kd: TUpdatekind): TDataSet;
begin
  if not assigned(FQuery[kd]) then
  begin
    FQuery[kd] := TFireQuery.Create(self);
    FQuery[kd].ResourceOptions.SilentMode := true;
  end;
  result := FQuery[kd];
end;

function TFireUpdateSql.GetSQL(UpdateKind: TUpdatekind): TStrings;
begin
  result := TFireQuery(GetQuery(UpdateKind)).SQL;
end;

procedure TFireUpdateSql.SetDatabasename(const Value: String);
begin
  inherited ConnectionName := Value;
end;

procedure TFireUpdateSql.SetDataset(const Value: TDataSet);
begin
  inherited DataSet := TFDAdaptedDataSet(Value);
end;

procedure TFireUpdateSql.SetDeleteSQL(const Value: TStrings);
begin
  inherited DeleteSQL.Assign(Value);
end;

procedure TFireUpdateSql.SetInsertSQL(const Value: TStrings);
begin
  inherited InsertSQL.Assign(Value);
end;

procedure TFireUpdateSql.SetModifySQL(const Value: TStrings);
begin
  inherited InsertSQL.Assign(Value);
end;

procedure TFireUpdateSql.SetParams(UpdateKind: TUpdatekind);
begin
  // TFireQuery(Query[UpdateKind]).Params.AssignValues(TFireQuery(DataSet).Params);
  SetParams(DataSet, UpdateKind);
end;

procedure TFireUpdateSql.SetParams(ADataset: TDataSet; UpdateKind: TUpdatekind);
var
  q: TFireQuery;
  qOrig: TFireQuery;
  i: integer;
  b: boolean;
  fld: TField;
  sFld: string;
begin
  q := TFireQuery(Query[UpdateKind]);
  q.SQL.Clear;
  qOrig := TFireQuery(ADataset);
  with q do
  begin
    case UpdateKind of
      ukModify:
        SQL.AddStrings(ModifySQL);
      ukInsert:
        SQL.AddStrings(InsertSQL);
      ukDelete:
        SQL.AddStrings(DeleteSQL);
    end;
    Params.AssignValues(TFireQuery(ADataset).Params);
  end;

  for i := 0 to q.Params.count - 1 do
  begin
    b := copy(q.Params[i].Name, 1, 4) = 'OLD_';
    if b then
    begin
      sFld := copy(q.Params[i].Name, 5, 255);
      fld := qOrig.FindField(sFld);
      if fld <> nil then
      begin
        q.Params[i].DataType := fld.DataType;
        q.Params[i].Value := fld.OldValue;
      end;
    end
    else
    begin
      b := copy(q.Params[i].Name, 1, 4) = 'NEW_';
      if b then
      begin
        sFld := copy(q.Params[i].Name, 5, 255);
        fld := qOrig.FindField(sFld);
        if fld <> nil then
        begin
          q.Params[i].DataType := fld.DataType;
          q.Params[i].Value := fld.OldValue;
        end;
      end
      else
      begin
        sFld := q.Params[i].Name;
        fld := qOrig.FindField(sFld);
        if fld <> nil then
        begin
          q.Params[i].DataType := fld.DataType;
          q.Params[i].Value := fld.Value;
        end;
      end;
    end;
  end;

end;

{ TFireQuery }

function TFireQuery.BookmarkValid(Bookmark: TBookMark): boolean;
begin
  result := Bookmark <> nil;
  if UniDirectional then
    result := false;
end;

procedure TFireQuery.CmdNonBloking;
begin
  CmdExecMode := amNonBlocking;
end;

{$IFNDEF BPL}

{ function TFireQuery.ConnectName(ADatabasename: string): IQuery;
  begin
  result := self;
  SetDatabasename(ADatabasename);
  end;
}
function TFireQuery.Intf: IQuery;
begin
  result := TQueryIntf<TFireQuery>.Create(self);
end;

class function TFireQuery.New(FConn: TFDConnection): IQuery;
var
  cmp: TQueryIntf<TFireQuery>;
begin
  cmp := TQueryIntf<TFireQuery>.Create;
  if assigned(FConn) then
    cmp.GetQuery.Connection := FConn;
  result := cmp;
end;

class function TFireQuery.New(ADatabaseName: string): IQuery;
var
  conn: TFireDatabase;
  cmp: TQueryIntf<TFireQuery>;
begin
  cmp := TQueryIntf<TFireQuery>.Create;
  conn := FireSession.FindDataBase(ADatabaseName);
  if assigned(conn) then
    cmp.GetQuery.Database := conn;
  result := cmp;
end;
{$ENDIF}

constructor TFireQuery.Create(owner: TComponent);
begin
  inherited;
  if assigned(owner) and owner.InheritsFrom(TFDConnection) then
    Connection := TFDConnection(owner);
  FLock := TMultiReadExclusiveWriteSynchronizer.Create;
  FSQL := TStringList.Create;
  TStringList(FSQL).OnChange := SqlChanged;
  CachedUpdates := true;
  ParamCheck := true;
  RequestLive := false;
  FMacroCheck := true;
  inherited OnUpdateError := DoUpdateError;
  inherited OnReconcileError := DoReconcileError;

{$IFDEF LOCALSQL}
  // usaLocalSql := true; // ativado por diretiva
{$ENDIF}
end;

procedure TFireQuery.DoUpdateRecord(ASender: TDataSet;
  ARequest: TFDUpdateRequest; var AAction: TFDErrorAction;
  AOptions: TFDUpdateRowOptions);
begin
  try
    if assigned(UpdateObject) then
    begin
      case ARequest of
        arInsert:
          UpdateObject.Apply(ukInsert);
        arUpdate:
          UpdateObject.Apply(ukModify);
        arDelete:
          UpdateObject.Apply(ukDelete);
      else
        AAction := eaDefault;
        exit;
      end;
      AAction := eaApplied;
    end
    else
      AAction := eaDefault;
  except
    on E: EFDException do
    begin
      AAction := eaFail;
      FErrorMessage := E.Message;
      FErrorCount := 1;
    end;

  end;
end;

procedure TFireQuery.DebugAfter;
begin
{$IFNDEF EXTERNAL}
  if (FireDebugAttrib.execute and FireDebugAttrib.active) or
    (FireDebugAttrib.Detalhed) then
    DebugLog('RA:' + intToStr(RowsAffected) + ' RC:' + intToStr(RecordCount) +
      ' Stm: ' + copy(SQL.text, 1, 20) + '...' + #13#10 +
      '---------------------');
{$ENDIF}
end;

procedure TFireQuery.DebugBefore(const AIdent:string);
begin
{$IFNDEF EXTERNAL}
  if FireDebugAttrib.Params_in or FireDebugAttrib.Detalhed then
    DebugLogParams(self);
  if (FireDebugAttrib.execute and FireDebugAttrib.active) or
    (FireDebugAttrib.Detalhed) then
    DebugLog(AIdent+'->'+Databasename + ': ' + SQL.text);
{$ENDIF}
end;

destructor TFireQuery.Destroy;
begin
  LocalSQL := nil;
  freeAndNil(FSQL);
  freeAndNil(FLock);
  inherited;
end;

procedure TFireQuery.ExecAsyncSql(AExecDirect: boolean);
begin
  FRowsAffectedLocal := -1;
  ResourceOptions.CmdExecMode := amAsync;
{$IF CompilerVersion>=29.0}
  inherited ExecSql(AExecDirect);
{$ELSE}
  ExecSql;
{$ENDIF}

end;

procedure TFireQuery.ExecDirect;
begin
{$IF CompilerVersion>=29.0}
  FRowsAffectedLocal := inherited ExecSql(true);
{$ELSE}
  ExecSql;
{$ENDIF}
end;

procedure TFireQuery.ExecSql;
begin
  FRowsAffectedLocal := -1;
  DebugBefore('ExecSql');
  FRowsAffectedLocal := inherited ExecSql(false);
  DebugAfter;
end;

procedure TFireQuery.execute(ATimes, AOffset: integer);
begin
  FRowsAffectedLocal := -1;
  DebugBefore('Execute');
  inherited;
  DebugAfter;
end;

procedure TFireQuery.FreeBookmark(book: TBookMark);
begin
  if not UniDirectional then
    inherited FreeBookmark(book);
end;

function TFireQuery.GetBookmark: TBookMark;
begin
  result := nil;
  if not UniDirectional then
    result := inherited GetBookmark;
end;

function TFireQuery.GetChacedUpdates: boolean;
begin
  result := inherited CachedUpdates;
end;

function TFireQuery.GetCmdExecModeEx: TFDStanAsyncMode;
begin
  result := ResourceOptions.CmdExecMode;
end;

function TFireQuery.GetDatabase: TFireDatabase;
begin
  result := TFireDatabase(inherited Connection);
end;

function TFireQuery.GetDataSource: TDataSource;
begin
  result := MasterLink.DataSource;
end;

function TFireQuery.GetParamCheck: boolean;
begin
  result := ResourceOptions.ParamCreate;
end;

function TFireQuery.GetRequestLive: boolean;
begin
  result := UpdateOptions.RequestLive;
end;

{$IFNDEF BPL}

function TFireQuery.GetRowSetSize: integer;
begin
  result := FetchOptions.RowSetSize;
end;
{$ENDIF}

function TFireQuery.GetSQL: TStrings;
begin
  result := FSQL;
end;

function TFireQuery.GetUniDirectional: boolean;
begin
  { .$ifndef WBAREPORT }
  result := FetchOptions.UniDirectional;
  { .$ELSE }
  // Result := False;
  { .$ENDIF }
end;

function TFireQuery.GetUpdateMode: TUpdateMode;
begin
  result := UpdateOptions.UpdateMode;
end;

function TFireQuery.GetUpdateObject: TFireUpdateSql;
begin
  result := TFireUpdateSql(inherited UpdateObject);
end;

procedure TFireQuery.GotoBookmark(book: TBookMark);
begin
  if (not UniDirectional) and active then
    inherited GotoBookmark(book);
end;

function TFireQuery.GetAfterInsert: TDataSetNotifyEvent;
begin
  result := inherited AfterInsert;
end;

procedure TFireQuery.SetAfterInsert(Value: TDataSetNotifyEvent);
begin
  inherited AfterInsert := Value;
end;

procedure TFireQuery.InitNullParams;
var
  x: integer;
begin
  for x := 0 to ParamCount - 1 do
    if Params[x].DataType = ftUnknown then
    begin
      Params[x].DataType := ftString;
      Params[x].Clear;
    end;
end;

procedure TFireQuery.InternalClose;
begin
  LocalSQL := nil;
  if CachedUpdates and UpdatesPending then
    ApplyUpdates();
  inherited;
{$IFDEF MSWINDOWS}
{$IFNDEF EXTERNAL}
  if FireDebugAttrib.execute and FireDebugAttrib.Data_out and FireDebugAttrib.active
  then
    DebugLog('Close dataset: ' + Databasename);
{$ENDIF}
{$ENDIF}
end;

function FireTable_GetErrorMessage(E: EFDDBEngineException): string;
var
  i: integer;
begin
  result := '';
  case E.Kind of
    ekNoDataFound:
      result := 'Dados n�o encontrado. Uma solicita��o para uma quantidade espec�fica de dados foi solicitado, mas n�o foi encontrado.';
    ekTooManyRows:
      result := 'H� multiplas linhas para a opera��o, sendo o esperado uma �nica linha, rever o comando.';
    ekRecordLocked:
      result := 'Registro em uso bloqueado por outra conex�o, tente novamente.';
    ekUKViolated:
      result := 'J� existe uma registro com a mesma chave �nica na tabela, tente outra combina��o.';
    ekFKViolated:
      result := 'Tentativa de inserir um dado que n�o esta presente na tabela externa de relacionamento, tente um registro v�lido.';
    ekObjNotExists:
      result := 'Tentativa de opera��o com um objeto do banco de dados que n�o existe.';
    ekUserPwdInvalid, ekUserPwdExpired, ekUserPwdWillExpire:
      result := 'Login com usu�rio n�o autorizado.';
    ekCmdAborted:
      result := 'Comando encerrado inesperadamente, tente novamente ou chame o administrador.';
    ekServerGone:
      result := 'Servidor desconectado, n�o � poss�vel executar a opera��o.';
    ekServerOutput:
      result := E.Message;
    ekArrExecMalfunc:
      result := E.Message;
    ekInvalidParams:
      result := 'Parametros inv�lidos, tente nova combina��o de parametros.';
    ekOther:
      result := 'Erro gen�rico. ' + E.Message;
  else
    result := E.Message;
  end;

  result := result + ' */ Objeto: ' + E.FDObjName;
  // result := result + ' ErrorCode: ' + E.ErrorCode.ToString;
  if E.SQL <> '' then
    result := result + ' SQL: ' + E.SQL;
  if E.Params.count > 0 then
    result := result + ' Params: ' + E.Params.text;

  for i := 0 to E.ErrorCount - 1 do
    result := result + #13 + '(' + E.Errors[i].ObjName + ')' +
      E.Errors[i].Message;

  if E.StackTrace <> '' then
    result := result + #13 + E.StackTrace;

end;

procedure TFireQuery.InternalOpen;
begin
  try
    inherited;
  except
    on E: EFDDBEngineException do
    begin
      raise exception.Create(FireTable_GetErrorMessage(E));
    end
    else
      raise;
  end;
end;

procedure TFireQuery.InternalPost;
begin
  try
    inherited;
  except
    on E: EFDDBEngineException do
    begin
      raise exception.Create(FireTable_GetErrorMessage(E));
    end
    else
      raise;
  end;
end;

procedure TFireQuery.Open(AAsync: boolean;
  ARowSetSize: integer = firedac_rowSetSize);
begin
  FRowsAffectedLocal := -1;
  if AAsync then
    ResourceOptions.CmdExecMode := amAsync
  else
    ResourceOptions.CmdExecMode := amBlocking;
  Open(ARowSetSize);
end;

procedure TFireQuery.ParamNullIF(sParam: string; Value: variant);
var
  prm: TFDParam;
begin
  prm := FindParam(sParam);
  if (prm <> nil) and (prm.IsNull) then
    prm.Value := Value;
end;

{ function TFireQuery.IOpen: IQuery;
  begin
  result  := inherited Open;
  end;
}

procedure TFireQuery.Open(ARowSetSize: integer);
begin
  FRowsAffectedLocal := -1;
  if ARowSetSize < 0 then
    ARowSetSize := firedac_rowSetSize;
  FetchOptions.RowSetSize := ARowSetSize;
  if ARowSetSize = 0 then
    FetchOptions.Mode := fmAll
  else
  begin
    FetchOptions.Mode := fmOnDemand;
  end;
  Open;
end;

procedure TFireQuery.prepare;
begin
{$IFNDEF BPL}
  if FireDebugAttrib.active and FireDebugAttrib.prepare then
    DebugLog('Prepare: ' + Databasename);
{$ENDIF}
  InitNullParams;
  inherited prepare;
end;

function TFireQuery.RowsAffected: integer;
begin
  if FRowsAffectedLocal >= 0 then
    result := FRowsAffectedLocal
  else
    result := inherited RowsAffected;
end;

procedure TFireQuery.DoUpdateError(ASender: TDataSet; AException: EFDException;
  ARow: TFDDatSRow; ARequest: TFDUpdateRequest; var AAction: TFDErrorAction);
begin
  FErrorMessage := AException.Message;
  Inc(FErrorCount);
  AAction := eaFail;
  if assigned(FOnUpdateError) then
    FOnUpdateError(ASender, AException, ARow, ARequest, AAction);
{$IFNDEF EXTERNAL}
  if FireDebugAttrib.active then
    ErrorLog(FErrorMessage);
{$ENDIF}
end;

procedure TFireQuery.DoReconcileError(DataSet: TFDDataSet; E: EFDException;
  UpdateKind: TFDDatSRowState; var Action: TFDDAptReconcileAction);
begin
  FRowsAffectedLocal := -1;
  FErrorMessage := FErrorMessage + #13 + E.Message;
  Inc(FErrorCount);
  Action := raAbort;
  if assigned(FOnReconcileError) then
    FOnReconcileError(DataSet, E, UpdateKind, Action);
  // no alquery, o undo � executado se estiver em ManualUpdate = false
  // se estiver com ManualUpdate = true, n�o � feito automatico.
  // UndoLastChange(True);  // movido para o TAlQuery
{$IFNDEF EXTERNAL}
  if FireDebugAttrib.active then
    ErrorLog(FErrorMessage);
{$ENDIF}
end;

procedure TFireQuery.SetActive(AValue: boolean);
var
  LWatchr: TStopwatch;

begin
  if AValue then
  begin
    FRowsAffectedLocal := -1;
    if SameText(Databasename, c_alias_Local_SQLite) then
      LocalSQL := nil
    else // if useLocalSql then
    begin
      if assigned(LLocalSQL) then
      begin
        if LLocalSQL.active = false then
          LLocalSQL.active := true;
        LocalSQL := LLocalSQL; // usado nos relatorios
      end;
    end;

    if (FDatabasename = '') and (not assigned(Connection)) then
      Databasename := c_alias_Local_SQLite; // usa SQLITE memory
    if csDesigning in ComponentState then
      command.CommandText.Assign(SQL);
  end;

{$IFNDEF EXTERNAL}
  if AValue then
  begin
    if FireDebugAttrib.active then
    begin
      if FireDebugAttrib.Params_in or FireDebugAttrib.Detalhed then
      begin
        DebugLogParams(self);
        //if assigned(Connection) then
        //  DebugLog('Driver ID: ' + Connection.DriverName);
        DebugLog('Alias: ' + Databasename + ' SQL: ' + SQL.text);
      end;
      LWatchr := TStopwatch.StartNew;
    end;
  end;
{$ENDIF}
  if AValue and assigned(Connection) and (Connection.Connected = false) then
    Connection.Open;

  inherited SetActive(AValue);
{$IFNDEF EXTERNAL}
  if FireDebugAttrib.active then
  begin
    if AValue then
    begin
      LWatchr.Stop;
      if FireDebugAttrib.Data_out then
        DebugLogFields(self);
      if FireDebugAttrib.execute  then
      begin
        DebugLog('Tempo(2): ' + FormatFloat('0.000', LWatchr.ElapsedMilliseconds
          / 1000) + ' Hr: ' + TimeToStr(now) + ' RA:' + intToStr(RowsAffected)
          { + ' RC:' + IntToStr(RecordCount) }
          + ' Stm: ' + copy(SQL.text, 1, 20) + '...' + #13#10 +
          '---------------------');
      end;
    end;
  end;
{$ENDIF}
end;

procedure TFireQuery.SetAutoRefresh(const Value: boolean);
begin
  FAutoRefresh := Value;
end;

procedure TFireQuery.SetCachedUpdates(const Value: boolean);
begin
  inherited CachedUpdates := Value;
end;

procedure TFireQuery.SetCmdExecModeEx(const Value: TFDStanAsyncMode);
begin
  ResourceOptions.CmdExecMode := Value;
end;

procedure TFireQuery.SetDatabase(const Value: TFireDatabase);
begin
  inherited Connection := Value;
  if assigned(Value) then
    FDatabasename := Value.Databasename;

end;

procedure TFireQuery.SetDatabasename(const Value: string);
var
  ss: TFireSession;
begin
  // Lock;
  try
    FDatabasename := Value;
    if FDatabasename <> '' then
    begin
      ss := FireSessions.FindSession(SessionName);
      if not assigned(ss) then
        ss := FireSession;
      Database := ss.FindDataBase(Value);

      if assigned(Database) and (not Database.manualConfig) and
        (Database.FDriverType = '') then
        InitDataBaseParams(Database);
      ConnectionName := Value;
{$IFDEF LOCALSQL}
      if SameText(Value, c_alias_Local_SQLite) then
        LocalSQL := nil;
{$ENDIF}
    end;
  finally
    // UnLock;
  end;
end;

procedure TFireQuery.SetDatasource(const Value: TDataSource);
begin
  if IsLinkedTo(Value) then
    DatabaseError('Circular Data Link', self);
  MasterLink.DataSource := Value;
end;

procedure TFireQuery.SetExecAsync(const Value: boolean);
begin
  FExecAsync := Value;
  if Value then
    CmdExecMode := amAsync
  else
    CmdExecMode := amBlocking;
end;

procedure TFireQuery.SetMacroCheck(const Value: boolean);
begin
  FMacroCheck := Value;
end;

procedure TFireQuery.SetOnUpdateError(const Value: TFDUpdateErrorEvent);
begin
  FOnUpdateError := Value;
end;

procedure TFireQuery.SetParamCheck(const Value: boolean);
begin
  // FParamCheck := Value;
  if ResourceOptions.ParamCreate <> Value then
  begin
    ResourceOptions.ParamCreate := Value;
  end;
end;

procedure TFireQuery.SetRequestLive(const Value: boolean);
begin
  UpdateOptions.RequestLive := Value;
  // -- testar ReadOnly, quando executa como false
  UpdateOptions.EnableDelete := true;
  UpdateOptions.EnableInsert := true;
  UpdateOptions.EnableUpdate := true;
  // if value then
  // FetchOptions.Items := FetchOptions.Items + [fiMeta]

end;

{$IFNDEF BPL}

procedure TFireQuery.SetRowSetSize(const Value: integer);
begin
  FetchOptions.RowSetSize := Value;
end;
{$ENDIF}

procedure TFireQuery.SetSessionName(const Value: String);
begin
  FSessionName := Value;
end;

procedure TFireQuery.SetSQL(const Value: TStrings);
begin
  FSQL.Assign(Value);
end;

procedure TFireQuery.SetUniDirectional(const Value: boolean);
begin
  if assigned(Connection) and SameText(Connection.DriverName, 'Ora') then
    exit; // oracle nao pode ter unidirectional...
  FetchOptions.UniDirectional := Value;
end;

procedure TFireQuery.SetUpdateMode(const Value: TUpdateMode);
begin
  UpdateOptions.UpdateMode := Value;
end;

procedure TFireQuery.SetUpdateObject(const Value: TFireUpdateSql);
begin
  inherited UpdateObject := Value;
  if assigned(Value) then
  begin
    Value.Connection := self.Connection;
    Value.DataSet := self;
    self.OnUpdateRecord := DoUpdateRecord;
  end
  else
    self.OnUpdateRecord := nil;
end;

procedure TFireQuery.SqlChanged(sender: TObject);
var
  s: String;
  r: string;
  i, f: integer;
begin
{$IFNDEF BPL}
  if FInSqlChanging then
    exit;
  try
    FInSqlChanging := true;
    // troca o modelo de filtro para o modelo de macros permitidos no Firedac
    s := TStringList(sender).text;
    if MacroCheck then
    begin
      repeat
        i := pos('{', s);
        if i > 0 then
        begin // � um filtro
          r := copy(s, i, Length(s));
          f := pos('}', r);
          if f > 0 then
          begin // finalizou o filtro
            r := copy(r, 1, f); // troca o filtro para macro do firedac
            s := StringReplace(s, r, '!' + copy(r, 2, Length(r) - 2), []);
          end
          else
            i := 0;
        end;
      until i = 0;
    end;
    inherited SQL.text := s;
  finally
    FInSqlChanging := false;
  end;
{$ENDIF}
end;

{ TFireSessions }

function TFireSessions.count: integer;
begin
  result := 1;
end;

constructor TFireSessions.Create(own: TComponent);
begin
  inherited;
  FLock := TMultiReadExclusiveWriteSynchronizer.Create;
  FAliases := TStringList.Create;
end;

procedure TFireSessions.LoadConfig;
var
  ini: TIniFile;
  oDef: IFDStanConnectionDef;
  i: integer;
  prm: TStringList;
begin
  FLock.BeginWrite;
  try
    GetConfigIni;

    FAliases.Clear;

    if not fileExists(LArqConfigINI) then
    begin
      ForceDirectories(ExtractFilePath(LArqConfigINI));
      // raise exception.Create('N�o encontrei o arquivo de configura��o: ' +
      // LArqConfigINI);
    end;

    ini := TIniFile.Create(LArqConfigINI);
    prm := TStringList.Create;
    try
      ini.ReadSections(FAliases);

      for i := 0 to FAliases.count - 1 do
      begin
        prm.Values['Name'] := FAliases[i];
        prm.Values['DriverID'] :=
          Protocol2DriverID(ini.ReadString(FAliases[i], 'Protocol', ''));
        prm.Values['Server'] := ini.ReadString(FAliases[i], 'Hostname', '');
        prm.Values['Database'] := ini.ReadString(FAliases[i], 'Database', '');
        prm.Values['OSAuthent'] := ini.ReadString(FAliases[i],
          'OSAuthent', 'no');
        prm.Values['Pooled'] := 'False';
      end;

    finally
      prm.free;
      ini.free;
    end;

  finally
    FLock.EndWrite;
  end;
end;

destructor TFireSessions.Destroy;
begin
  FAliases.free;
  FLock.free;
  inherited;
end;

function TFireSessions.FindSession(sSession: String): TFireSession;
begin
  result := LSession;
end;

function TFireSessions.GetCurrentSession: TFireSession;
begin
  result := LSession;
end;

function TFireSessions.GetItems(idx: integer): TFireSession;
begin
  result := LSession;
end;

function TFireSessions.GetList(sSession: string): TFireSession;
begin
  result := FindSession(sSession);
end;

function TFireSessions.IsAlias(sAlias: String): boolean;
var
  i: integer;
begin
  result := false;
  FLock.BeginRead;
  try
    for i := 0 to FAliases.count - 1 do
      if SameText(FAliases[i], sAlias) then
      begin
        result := true;
        exit;
      end;
  finally
    FLock.EndRead;
  end;
end;

procedure TFireSessions.OpenSession(sSession: String);
begin

end;

procedure TFireSessions.SetCurrentSession(const Value: TFireSession);
begin
  LSession := Value;
end;

procedure TFireSessions.SetItems(idx: integer; const Value: TFireSession);
begin

end;

procedure TFireSessions.SetList(sSession: string; const Value: TFireSession);
begin
  LSession := Value;
end;

{ TFireSession }

procedure TFireSession.AddAlias(sAlias: string; driver: string; List: TStrings);
var
  i: integer;
begin
  FLock.BeginWrite;
  try
    FConfigFile.WriteString(sAlias, 'Protocol', driver);
    for i := 0 to List.count - 1 do
      FConfigFile.WriteString(sAlias, List.Names[i], List.ValueFromIndex[i]);
  finally
    FLock.EndWrite;
  end;
end;

procedure TFireSession.AddDriver(const Name: string; List: TStrings);
begin

end;

procedure TFireSession.AddStandardAlias(alias, path, driver: string);
var
  h, d: string;
  i: integer;
begin
  FLock.BeginWrite;
  try
    FConfigFile.WriteString(alias, 'Protocol', driver);
    i := pos(':', path);
    if i > 2 then
    begin
      h := copy(path, 1, i - 2);
      d := copy(path, i + 1, 255);
      FConfigFile.WriteString(alias, 'Hostname', h);
      FConfigFile.WriteString(alias, 'Database', d);
    end
    else
      FConfigFile.WriteString(alias, 'SERVER NAME', path);
  finally
    FLock.EndWrite;
  end;
end;

procedure TFireSession.Close;
var
  i: integer;
begin
  for i := DatabaseCount - 1 downto 0 do
    with Databases[i] do
    begin
      { .$IFDEF LOCALSQL }
      if not SameText(Databasename, c_alias_Local_SQLite) then { .$ENDIF }
        Offline;
      if LOnFinalization then
        Close;
    end;
end;

procedure TFireSession.CloseDatabase(lDb: TFireDatabase);
begin
  { .$IFDEF LOCALSQL }
  lDb.BeginWrite;
  try
    if not SameText(lDb.Databasename, c_alias_Local_SQLite) then { .$ENDIF }
      lDb.Offline;
    if LOnFinalization then
      lDb.Close;
  finally
    lDb.EndWrite;
  end;
end;

procedure TFireSession.CloseDatabases;
var
  i: integer;
begin
  LDatabases.FLock.BeginRead;
  try
    for i := DatabaseCount - 1 downto 0 do
      with Databases[i] do
      begin
        { .$IFDEF LOCALSQL }
        if not SameText(Databasename, c_alias_Local_SQLite) then { .$ENDIF }
          Offline;
        if LOnFinalization then
          Close;
      end;
  finally
    LDatabases.FLock.EndRead;
  end;
end;

constructor TFireSession.Create(ow: TComponent);
begin
  inherited;
  FLock := TMultiReadExclusiveWriteSynchronizer.Create;
  GetConfigIni;
  FConfigFile := TMemIniFile.Create(LArqConfigINI);
  FnetFileDir := ExtractFilePath(LArqConfigINI);
end;

function TFireSession.DatabaseCount: integer;
begin
  result := LDatabases.count;
end;

procedure TFireSession.DeleteDatabasename(ADB: string);
var
  lDb: TFireDatabase;
begin
  lDb := FindDataBase(ADB);
  if assigned(lDb) then
    LDatabases.Remove(lDb);
end;

procedure TFireSession.DeleteAlias(sAlias: string);
begin
  FLock.BeginWrite;
  try
    FConfigFile.EraseSection(sAlias);
  finally
    FLock.EndWrite;
  end;
end;

destructor TFireSession.Destroy;
begin
  freeAndNil(FConfigFile);
  freeAndNil(FLock);
  inherited;
end;

function TFireSession.FindDataBase(alias: String): TFireDatabase;
begin
  result := nil;
  result := LDatabases.FindDataBase(alias);
end;

function TFireSession.GetAliasDriverName(sAlias: String): String;
var
  ini: TIniFile;
  DB: TFireDatabase;
  Prot: String;
begin
  DB := FindDataBase(sAlias);
  result := '';
  FLock.BeginRead;
  try
    if assigned(DB) then
    begin
      DB.BeginRead;
      try
        Prot := DB.FDriverType;
      finally
        DB.EndRead;
      end;
      if SameText('FB', Prot) then
        result := 'INTRBASE'
      else if SameText('ORA', Prot) then
        result := 'ORACLE'
      else if SameText('MSSQL', Prot) then
        result := 'MSSQL'
      else if SameText('SQLITE', Prot) then
        result := 'SQLITE'
      else
        result := Prot
    end
    else
    begin
      Prot := lowercase(FConfigFile.ReadString(sAlias, 'Protocol', ''));
      if pos('firebird', Prot) > 0 then
        result := 'INTRBASE'
      else if pos('oracle', Prot) > 0 then
        result := 'ORACLE'
      else if pos('SQLITE', Prot) > 0 then
        result := 'SQLITE'
      else if pos('mssql', Prot) > 0 then
        result := 'MSSQL'
      else
        result := Prot;
    end;
  finally
    FLock.EndRead;
  end;
end;

procedure TFireSession.GetAliasNames(items: TStrings);
begin
  FLock.BeginRead;
  try
    items.Assign(FireSessions.FAliases);
  finally
    FLock.EndRead;
  end;
end;

procedure TFireSession.GetAliasParams(sAlias: String; str: TStrings);
var
  DB: TFireDatabase;
  i: integer;
  s: string;
  // oDef: IFDStanConnectionDef;
begin
  DB := FindDataBase(sAlias);
  str.Clear;
  FLock.BeginRead;
  try
    if DB = nil then
    begin
      if assigned(str) then
        try
          FConfigFile.ReadSection(sAlias, str);
          for i := 0 to str.count - 1 do
          begin
            s := str[i];
            s := s + '=' + FConfigFile.ReadString(sAlias, s, '');
            str[i] := s;
          end;
          str.Values['SERVER NAME'] := str.Values['Server'] + ':' +
            str.Values['Database'];
        finally
        end;
    end
    else if assigned(str) then
    begin
{$IFDEF MSWINDOWS}
      { oDef := FDManager.ConnectionDefs.FindConnectionDef(sAlias);
        if assigned(oDef) then
        str.AddStrings(oDef.Params)
        else
      } str.AddStrings(DB.Params);
      str.Values['SERVER NAME'] := str.Values['Server'] + ':' + str.Values
        ['Database'];
{$ENDIF}
    end;
  finally
    FLock.EndRead;
  end;
end;

procedure TFireSession.GetDatabaseNames(L: TStrings);
var
  i: integer;
begin
  FLock.BeginRead;
  try
    if assigned(L) then
      L.Assign(FireSessions.FAliases);

    // if assigned(LDatabases) then
    begin
      try
        for i := 0 to LDatabases.count - 1 do
        begin
          if LDatabases.items[i].Databasename <> '' then
            if L.IndexOf(LDatabases.items[i].Databasename) < 0 then
              L.add(LDatabases.items[i].Databasename);
        end;
      finally
      end;
    end;

  finally
    FLock.EndRead;
  end;
end;

function TFireSession.GetDatabases(i: integer): TFireDatabase;
begin
  result := nil;
  result := LDatabases.items[i];
end;

procedure TFireSession.GetTableNames(DBName, msk: String; a, b: boolean;
  Dest: TStrings);
var
  DB: TFireDatabase;
begin
  DB := FindDataBase(DBName);
  if assigned(DB) then
    DB.GetTableNames(Dest, false);
end;

function TFireSession.IsAlias(sAlias: String): boolean;
begin
  result := LSessions.IsAlias(sAlias);
end;

function TFireSession.LockList: TDatabaseObjectList;
begin
  result := LDatabases.Lock;

end;

{ procedure TFireSession.Lock;
  begin
  FLock.Acquire;
  end;
}
procedure TFireSession.ModifyAlias(alias: String; ts: TStrings);
var
  i: integer;
begin
  FLock.BeginWrite;
  try
    for i := 0 to ts.count - 1 do
      FConfigFile.WriteString(alias, ts.Names[i], ts.ValueFromIndex[i]);
  finally
    FLock.EndWrite;
  end;
end;

var
  LConnectionID: integer = 0;

class function TFireSession.NewDatabase(const AConnectionString: string)
  : TFireDatabase;
var
  prms: TStringList;
  alias: string;
  dBase: string;
  user: string;
  pass: string;
  driver: string;
{$IFDEF NOTRACE}
  i: integer;
{$ENDIF}
begin
  result := nil;
  prms := TStringList.Create;
  try
    prms.Delimiter := ';';
    prms.DelimitedText := AConnectionString;

    alias := prms.Values['Aliasname'];
    if alias = '' then
      alias := prms.Values['ConnectionName'];

    dBase := prms.Values['Databasename'];
    if dBase = '' then
    begin
      Inc(LConnectionID);
      dBase := alias + '_' + LConnectionID.ToString;
    end;
    user := prms.Values['User_Name'];
    pass := prms.Values['password'];
    driver := prms.Values['DriveID'];
    result := FireSession.FindDataBase(dBase);
    if not assigned(result) then
    begin
      result := TFireDatabase.New(alias, dBase, user, pass);
      result.SetFireConnectionString(AConnectionString);
      if driver <> '' then
        result.DriverName := driver;

{$IFDEF NOTRACE}
      // result.Params.Values['RemoteBy']:='Xxx';
      i := result.Params.IndexOfName('MonitorBy');
      if i >= 0 then
        result.Params.Delete(i);
{$ENDIF}
    end;
  finally
    prms.free;
  end;
end;

procedure TFireSession.Open;
begin
  if not active then
    active := true;
end;

function TFireSession.OpenDatabase(dBase: string): TFireDatabase;
var
  DB: TFireDatabase;
begin
  DB := FindDataBase(dBase);
  DB.BeginWrite;
  try
    if not DB.Connected then
      DB.Connected := true;
    result := DB;
  finally
    DB.EndWrite;
  end;
end;

procedure TFireSession.SaveConfigFile;
begin
  FLock.BeginWrite;
  try
    FConfigFile.UpdateFile;
  finally
    FLock.EndWrite;
  end;
end;

procedure TFireSession.SetActive(const Value: boolean);
begin
  FActive := Value;
end;

procedure TFireSession.SetDatabases(i: integer; const Value: TFireDatabase);
begin
end;

procedure TFireSession.SetnetFileDir(const Value: String);
begin
  FnetFileDir := Value;
end;

procedure TFireSession.SetOnDbNotify(const Value: TFireDatabaseNotifyEvent);
begin
  FOnDbNotify := Value;
end;

procedure TFireSession.SetSessionName(const Value: String);
begin
  FSessionName := Value;
end;

procedure TFireSession.UnlockList;
begin
  LDatabases.Release;
end;

{ TFireStoredProc }

procedure TFireStoredProc.ExecProc;
  procedure DebugLogParamsP;
  var
    s, dt: string;
    i: integer;
  begin
    s := '';
    try
      for i := 0 to Params.count - 1 do
      begin
        dt := FieldTypeNames[Params[i].DataType];
        s := s + 'Param: ' + Params[i].Name + ' Type: ' + dt + ' Value: ' +
          Params[i].asString + #13#10;
      end;
    except
    end;
{$IFNDEF EXTERNAL}
    DebugLog(s);
{$ENDIF}
  end;

var
  LUpdateWatchr: TStopwatch;
begin
{$IFNDEF EXTERNAL}
  if (FireDebugAttrib.Params_in and FireDebugAttrib.active) or FireDebugAttrib.Detalhed then
    DebugLogParamsP;
  if FireDebugAttrib.active and FireDebugAttrib.execute then
  begin
    DebugLog('Execute: ' + StoredProcName + ' Hr: ' + TimeToStr(now));
    LUpdateWatchr := TStopwatch.StartNew;
  end;
{$ENDIF}
  try
    inherited ExecProc;
  except
    on E: EFDDBEngineException do
    begin
      raise exception.Create(FireTable_GetErrorMessage(E));
    end
    else
      raise;
  end;
{$IFNDEF EXTERNAL}
  if FireDebugAttrib.active or FireDebugAttrib.Detalhed then
  begin
    LUpdateWatchr.Stop;
    try
      DebugLog('Tempo(3): ' + FormatFloat('0.000',
        LUpdateWatchr.ElapsedMilliseconds / 1000) + ' Hr: ' + TimeToStr(now));
      DebugLog('RA:' + intToStr(RowsAffected) + #13#10 +
        '---------------------');
    except
    end;
  end;
{$ENDIF}
end;

function TFireStoredProc.ExecSql: integer;
begin
  ExecProc;
  result := RowsAffected;
end;

function TFireStoredProc.GetDatabase: TFireDatabase;
begin
  result := TFireDatabase(inherited Connection);
end;

procedure TFireStoredProc.InternalOpen;
  procedure DebugLogParamsP;
  var
    s, dt: string;
    i: integer;
  begin
    s := '';
    try
      for i := 0 to Params.count - 1 do
      begin
        dt := FieldTypeNames[Params[i].DataType];
        s := s + 'Param: ' + Params[i].Name + ' Type: ' + dt + ' Value: ' +
          Params[i].asString + #13#10;
      end;
    except
    end;
{$IFNDEF EXTERNAL}
    DebugLog(s);
{$ENDIF}
  end;

var
  LUpdateWatchr: TStopwatch;
begin
  if (FireDebugAttrib.Params_in and FireDebugAttrib.active) or FireDebugAttrib.Detalhed then
    DebugLogParamsP;
{$IFNDEF EXTERNAL}
  if FireDebugAttrib.active or FireDebugAttrib.Detalhed then
  begin
    DebugLog('Open StoredProc: ' + StoredProcName + ' Hr: ' + TimeToStr(now));
    LUpdateWatchr := TStopwatch.StartNew;
  end;
{$ENDIF}
  try
    inherited;
  except
    on E: EFDDBEngineException do
    begin
      raise exception.Create(FireTable_GetErrorMessage(E));
    end
    else
      raise;
  end;
{$IFNDEF EXTERNAL}
  if FireDebugAttrib.active or FireDebugAttrib.Detalhed then
  begin
    LUpdateWatchr.Stop;
    try
      DebugLog('Tempo(3): ' + FormatFloat('0.000',
        LUpdateWatchr.ElapsedMilliseconds / 1000) + ' Hr: ' + TimeToStr(now));
      DebugLog('RA:' + intToStr(RowsAffected) + #13#10 +
        '---------------------');
    except
    end;
  end;
{$ENDIF}
end;

procedure TFireStoredProc.SetDatabase(const Value: TFireDatabase);
begin
  inherited Connection := Value;
end;

procedure TFireStoredProc.SetDatabasename(const Value: String);
var
  ss: TFireSession;
begin
  FDatabasename := Value;
  ss := FireSessions.FindSession(SessionName);
  if not assigned(ss) then
    ss := FireSession;
  Database := ss.FindDataBase(Value);
  ConnectionName := Value;

end;

procedure TFireStoredProc.SetSessionName(const Value: string);
begin
  FSessionName := Value;
end;

const
  dbUnknow = 0;
  dbIntrBase = 1;
  dbSQLServer = 2;
  dbOracle = 3;
  dbAccess = 4;
  dbSQLite = 5;

function FireGetDataBaseType(alias: String): integer;
var
  sDriveName: string;
begin
  result := -1;
  sDriveName := FireSession.GetAliasDriverName(alias);
  if sDriveName = 'INTRBASE' then
    result := dbIntrBase
  else if sDriveName = 'MSSQL' then
    result := dbSQLServer
  else if sDriveName = 'ORACLE' then
    result := dbOracle
  else if sDriveName = 'SQLITE' then
    result := dbSQLite;
end;

{ TFireTable }
function GetDefCampo(alias, campo, tipo: string; tam, dec: integer;
  isDBF: boolean = false; notNull: boolean = false; valorBase: string = '';
  mx: integer = 0): string;
var
  r, s: string;
  databasetype: integer;
  function iff(b: boolean; v: variant; f: variant): variant;
  begin
    result := v;
    if not b then
      result := f;
  end;

begin
  databasetype := FireGetDataBaseType(alias);
  if (tipo[1] = 'N') and (tam <= 0) then
  begin
    tam := 15;
    dec := 6;
  end;
  s := campo + ' ';
  if isDBF then
    case tipo[1] of
      '@':
        begin
          tipo[1] := 'D';
          tam := 8;
        end;
      'T':
        begin
          tipo[1] := 'C';
          tam := 8;
        end;
      '$':
        begin
          tipo[1] := 'N';
          tam := 15;
          dec := 4;
        end;
      'S', 'I', '+':
        begin
          tipo[1] := 'N';
          tam := 10;
          dec := 0;
        end;
    end;
  case tipo[1] of
    'A', 'C':
      case databasetype of
        dbOracle:
          r := 'VarChar2(' + intToStr(iff(tam <= 0, 1, tam)) + ')';
        // dbSQLite:
        // r := 'TEXT';
      else
        r := 'VarChar(' + intToStr(iff(tam <= 0, 1, tam)) + ')';
      end;
    'G':
      begin
        case databasetype of
          dbOracle:
            r := 'VarChar2(36)';
          // dbSQLite:
          // r := 'TEXT';
        else
          r := 'VarChar(36)';
        end;
        case databasetype of
          dbOracle:
            valorBase := ' Sys_Guid() ';
        end;
      end;
    'D':
      case databasetype of
        dbAccess, dbSQLServer, dbSQLite:
          r := 'DateTime ';
        dbOracle:
          r := 'TimeStamp ';
      else
        r := 'Date';
      end;

    'T':
      r := 'Time';
    '@':
      r := 'TimeStamp';
    'I':
      case databasetype of
        dbAccess:
          r := 'Integer ';
      else
        r := 'Integer ';
      end;
    'S':
      r := 'SmallInt';
    'M', 'B':
      case databasetype of
        dbOracle:
          r := 'NCHAR';
        dbIntrBase:
          r := 'blob SUB_TYPE 1 SEGMENT SIZE ' +
            intToStr(iff(tam <= 0, 80, tam));
        dbSQLServer:
          r := 'text';
      else
        r := 'Memo';
      end;
    '$':
      r := 'Money ';
    'N':
      case databasetype of
        dbAccess, dbSQLServer:
          r := 'Float ';
        dbSQLite:
          r := 'REAL ';
        dbIntrBase:
          r := 'Float ';
      else
        r := 'Numeric(' + intToStr(tam) + ',' + intToStr(dec) + ') ';
      end;
    'L':
      r := 'Boolean';
    '+':
      r := 'AutoInc';
  end;

  if (uppercase(campo) = 'IDBASE') and (databasetype = dbSQLServer) then
  begin
    if mx = 0 then
      mx := 1;
    r := ' Int identity(' + intToStr(mx) + ',1) ';
    notNull := true;
    valorBase := '';
  end;

  if SameText(Trim(valorBase), '''now''') then
    // corrige default firebird para outro tipo de banco
    case databasetype of
      dbSQLServer, dbAccess:
        valorBase := ' GetDate() ';
      dbIntrBase:
        valorBase := ' ''now'' ';
      dbOracle:
        valorBase := ' SysDate ';
    end;

  if pos('SYSDATE', uppercase(valorBase)) > 0 then
    case databasetype of
      dbSQLServer, dbAccess:
        valorBase := ' GetDate() ';
      dbIntrBase:
        valorBase := ' ''now'' ';
      dbOracle:
        valorBase := ' SysDate ';
    end;

  result := s + r;

  case databasetype of
    dbOracle, dbIntrBase:
      if valorBase <> '' then
        result := result + ' default ' + valorBase;
  end;

  if notNull then
    result := result + ' not null '
  else
  begin
    case databasetype of
      dbIntrBase:
        ; // nao faz nada quando for interbase
      dbOracle, dbAccess, dbSQLServer:
        result := result + ' null ';
    end;
  end;

  case databasetype of
    dbOracle, dbIntrBase:
      ;
  else
    if valorBase <> '' then
      result := result + ' default ' + valorBase;
  end;

end;

procedure ShowTables(conn: TFireDatabase);
var
  lst: TStringList;
begin
  if conn = nil then
    exit;

  lst := TStringList.Create;
  try
    conn.GetTableNames('', '', '', lst);
    raise exception.Create(lst.text);
  finally
    lst.free;
  end;
end;

procedure TFireTable.CreateTable;
var
  s, ss, tipo, sTableName: string;
  i: integer;
  tam, dec: integer;
  conn: TFireDatabase;
  criaTmp: boolean;
begin

  criaTmp := false;

  sTableName := TableName;

  s := 'Create Table ' + sTableName + ' ( ';
  if criaTmp then
    s := 'Create Global Temporary Table ' + sTableName + ' ( ';

  ss := '';
  for i := 0 to FieldDefs.count - 1 do
  begin
    tipo := 'C';
    tam := FieldDefs[i].Size;
    dec := FieldDefs[i].Precision;
    case FieldDefs[i].DataType of
      ftBoolean:
        begin
          tipo := 'C';
          tam := 4;
          dec := 0;
        end;
      ftInteger, ftSmallint, ftWord, ftLargeint:
        begin
          tipo := 'N';
          tam := 10;
          dec := 0;
        end;
      ftFloat, ftBCD:
        tipo := 'N';
      ftCurrency, ftFMTBcd:
        begin
          tipo := '$';
          tam := 18;
          dec := 4;
        end;
      ftDate, ftDateTime, ftTime:
        begin
          tipo := 'D';
        end;
      ftAutoInc:
        tipo := '+';
    end;

    if ss <> '' then
      ss := ss + ', ';
    ss := ss + GetDefCampo(Databasename, FieldDefs[i].Name, tipo, tam, dec);
  end;
  s := s + ss + ' )';

  if criaTmp then
    s := s + ' on Commit Preserve rows';

  if Databasename = '' then
    Databasename := c_alias_Local_SQLite;

  conn := FireSession.FindDataBase(Databasename);

  TableName := StringReplace(sTableName, '"', '', [rfReplaceAll]);
  // retira as aspas para fazer a compara��o se a tabela ja existe.
  try
    // if inherited exists then
    try
      conn.ExecSql('Drop table ' + sTableName);
    except
    end;
    conn.ExecSql(s);
  finally
    TableName := sTableName; // restaura o dado original;
  end;
end;

procedure TFireTable.DeleteTable;
begin
  Connection.ExecSql('drop table ' + TableName);
end;

procedure TFireTable.EmptyTable;
begin
  while not eof do
    Delete;
end;

function TFireTable.GetDatabase: TFireDatabase;
begin
  result := TFireDatabase(inherited Connection);
end;

function TFireTable.GetReadOnly: boolean;
begin
  result := FReadOnly;
end;

function TFireTable.GetTableName: string;
begin
  result := inherited TableName;
end;

procedure TFireTable.SetActive(AValue: boolean);
begin
  if (AValue) then
  begin
    if FDatabasename = '' then
    begin
      Databasename := c_alias_Local_SQLite;
      inherited TableName := QuotedStr(TableName);
    end;
{$IFNDEF EXTERNAL}
    if SameText(FDatabasename, c_alias_Local_SQLite) and
      (UpdateOptions.KeyFields = '') then
      UpdateOptions.KeyFields := 'ROWID';
{$ENDIF}
  end;
  inherited;
end;

procedure TFireTable.SetDatabase(const Value: TFireDatabase);
begin
  inherited Connection := Value;
end;

procedure TFireTable.SetDatabasename(const Value: String);
var
  ss: TFireSession;
begin
  FDatabasename := Value;
  if FDatabasename <> '' then
  begin
    ss := FireSessions.FindSession(SessionName);
    if not assigned(ss) then
    begin
      ss := FireSession;
    end;
    Database := ss.FindDataBase(FDatabasename);
  end;
end;

procedure TFireTable.SetDefaultIndex(const Value: boolean);
begin
  FDefaultIndex := Value;
end;

procedure TFireTable.SetReadOnly(const Value: boolean);
begin
  FReadOnly := Value;
end;

procedure TFireTable.SetSessionName(const Value: string);
begin
  FSessionName := Value;
end;

procedure TFireTable.SetTableName(const Value: string);
var
  sOld: string;
begin
  sOld := UpdateOptions.UpdateTableName;
  inherited TableName := Value;
  if csDesigning in ComponentState then
  begin
    if sOld = '' then
      UpdateOptions.UpdateTableName := '';
  end;

end;

procedure TFireTable.SetTableType(const Value: TFireTableType);
begin
  FTableType := Value;
end;

procedure TFireTable.SetUpdateMode(const Value: TUpdateMode);
begin
  FUpdateMode := Value;
end;

{ TFireBatchMove }
{$IFDEF MSWINDOWS}

constructor TFireBatchMove.Create(AOwner: TComponent);
begin
  inherited;
{$IFDEF DELPHI25gt}
  FDBatchMoveDataSetReader1 := TFDBatchMoveDataSetReader.Create(self);
  FDBatchMoveDataSetWriter1 := TFDBatchMoveDataSetWriter.Create(self);
  self.Reader := FDBatchMoveDataSetReader1;
  self.Writer := FDBatchMoveDataSetWriter1;
{$ENDIF}
end;

procedure TFireBatchMove.execute;
begin
  RecordCount := inherited execute;
end;

function TFireBatchMove.GetDestination: TFireTable;
begin
{$IFDEF DELPHI25gt}
  result := TFireTable(FDBatchMoveDataSetWriter1.DataSet);
{$ELSE}
  result := TFireTable(inherited Destination);
{$ENDIF}
end;

function TFireBatchMove.GetSource: TDataSet;
begin
{$IFDEF DELPHI25gt}
  result := FDBatchMoveDataSetReader1.DataSet;
{$ELSE}
  result := inherited Source;
{$ENDIF}
end;

procedure TFireBatchMove.SetDestination(const Value: TFireTable);
begin
{$IFDEF DELPHI25gt}
  FDBatchMoveDataSetWriter1.DataSet := Value;
{$ELSE}
  inherited Destination := Value;
{$ENDIF}
end;

procedure TFireBatchMove.SetMode(const Value: TFireBatchMode);
begin
  FMode := Value;
  case Value of
    batAppend:
      inherited Mode := dmAppend;
    batUpdate:
      inherited Mode := dmUpdate;
    batAppendUpdate:
      inherited Mode := dmAppendUpdate;
    batDelete:
      inherited Mode := dmDelete;
    batCopy:
      inherited Mode := dmAlwaysInsert;
  end;
end;

procedure TFireBatchMove.SetRecordCount(const Value: integer);
begin
  FRecordCount := Value;
end;

procedure TFireBatchMove.SetSource(const Value: TDataSet);
begin
{$IFDEF DELPHI25gt}
  FDBatchMoveDataSetReader1.DataSet := Value;
{$ELSE}
  inherited Source := Value;
{$ENDIF}
end;

procedure TFireBatchMove.SetTableType(const Value: TFireTableType);
begin
  FTableType := Value;
end;
{$ENDIF}
{ TDatabasesList }

procedure TDatabasesList.add(ADB: TFireDatabase);
begin
  FLock.BeginWrite;
  try
    FItems.add(ADB);
  finally
    FLock.EndWrite;
  end;
end;

function TDatabasesList.count: integer;
begin
  FLock.BeginRead;
  try
    result := FItems.count;
  finally
    FLock.EndRead;
  end;
end;

constructor TDatabasesList.Create;
begin
  inherited;
  FItems := TDatabaseObjectList.Create;
  FLock := TMultiReadExclusiveWriteSynchronizer.Create;
end;

procedure TDatabasesList.Delete(i: integer);
begin
  FLock.BeginWrite;
  try
    FItems.Delete(i);
  finally
    FLock.EndWrite;
  end;
end;

destructor TDatabasesList.Destroy;
var
  tmp: TObject;
begin
  while FItems.count > 0 do
  begin
    tmp := FItems.items[0];
    freeAndNil(tmp);
  end;
  freeAndNil(FItems);
  freeAndNil(FLock);
  inherited;
end;

function TDatabasesList.FindDataBase(alias: String): TFireDatabase;
var
  i: integer;
begin
  result := nil;
  FLock.BeginRead;
  try

    if assigned(LLastDatabase) and (LLastDatabase.Databasename.equals(alias))
    then
    begin
      result := LLastDatabase;
      exit;
    end;

    result := nil;
    if alias = '' then
      exit;
    // raise exception.Create('N�o informou o DB Alias para a conex�o');
    if SameText(alias, c_alias_Local_SQLite) and assigned(LLocalConnection) then
    begin
      result := LLocalConnection;
      exit;
    end;
    for i := 0 to count - 1 do
      if SameText(items[i].Databasename, alias) then
      begin
        result := items[i];
        if result.DriverName = '' then
        begin
          InitDataBaseParams(result, false);
          result.init;
        end;
        LLastDatabase := result;
        exit;
      end;
    if not assigned(result) then
      if FireSessions.FAliases.IndexOf(alias) >= 0 then
      begin
        // � um alias que n�o foi iniado como Databasename
        result := TFireDatabase.Create(LSessions);
        result.BeginWrite;
        try
          result.AliasName := alias;
          result.ConnectionName := alias; // trick para quebrar loop;

{$IFDEF MSWINDOWS}
          // InitDataBaseParams(result);  -- a chamada � feita ao atribuir o aliasname
{$IFDEF NOGUI}
{$ELSE}
          result.LoginDialog := LFireDacDataModule.FDGUIxLoginDialog1;
{$ENDIF}
          result.LoginPrompt := true;
{$ENDIF}
          LLastDatabase := result;
        finally
          result.EndWrite;
        end;
      end;

  finally
    FLock.EndRead;
  end;
end;

function TDatabasesList.GetItems(idx: integer): TFireDatabase;
begin
  FLock.BeginRead;
  try
    result := TFireDatabase(FItems[idx]);
  finally
    FLock.EndRead;
  end;
end;

function TDatabasesList.Lock: TDatabaseObjectList;
begin
  FLock.BeginWrite;
  result := FItems;
end;

procedure TDatabasesList.Release;
begin
  FLock.EndWrite;
end;

procedure TDatabasesList.Remove(DB: TFireDatabase);
begin
  FLock.BeginWrite;
  try
    FItems.Remove(DB);
  finally
    FLock.EndWrite;
  end;
end;

procedure ExchangeFieldType(qry: TFireQuery; fld: string; ftClass: TFieldClass);
var
  i: integer;
  f, tmp: TField;
  n: string;
begin
  qry.FLock.BeginWrite;
  try
    for i := qry.FieldCount - 1 downto 0 do
    begin
      if SameText(qry.Fields[i].FullName, fld) then
      begin
        f := qry.Fields[i];
        n := f.Name;
        tmp := ftClass.Create(qry);
        tmp.FieldName := f.FieldName;
        f.free;
        tmp.DataSet := qry;
        exit;
      end;
    end;
  finally
    qry.FLock.EndWrite;
  end;
end;

{$IFNDEF NOTRACE}
{$IFNDEF EXTERNAL}
{$IF CompilerVersion>= 29.0}

Type
  TFireTFDMoniCustomClientLink = class(TFDMoniRemoteClientLink)
  public
    constructor Create(ow: TComponent); override;
    procedure DoTraceMsgEvent(ASender: TFDMoniClientLinkBase;
      const AClassName, AObjName, AMessage: String);
  end;

procedure TFireTFDMoniCustomClientLink.DoTraceMsgEvent
  (ASender: TFDMoniClientLinkBase; const AClassName, AObjName,
  AMessage: String);
begin
{$IFNDEF NOTRACE}
  DebugLog(AClassName + '/' + AObjName + ': ' + AMessage);
{$ENDIF}
end;

constructor TFireTFDMoniCustomClientLink.Create(ow: TComponent);
begin
  inherited;
  onOutPut := DoTraceMsgEvent;
end;

var
  LTrace: TFireTFDMoniCustomClientLink;
{$IFEND}
{$IFEND}
{$ENDIF}

constructor TFireDacDataModule.Create(ow: TComponent);
begin
  inherited Create(ow);

{$IFDEF MSWINDOWS}
{$IFDEF NOGUI}
{$ELSE}
  FDGUIxLoginDialog1 := TFDGUIxLoginDialog.Create(self);
  FDGUIxErrorDialog1 := TFDGUIxErrorDialog.Create(self);
{$ENDIF}
  FDPhysFBDriverLink1 := TFDPhysFBDriverLink.Create(self);
  FDGUIxWaitCursor1 := TFDGUIxWaitCursor.Create(self);
  FDPhysSQLiteDriverLink1 := TFDPhysSQLiteDriverLink.Create(self);
  FDPhysMySQLDriverLink1 := TFDPhysMySQLDriverLink.Create(self);
  Script := TFDScript.Create(self);
  FDPhysODBCDriverLink1 := TFDPhysODBCDriverLink.Create(self);
  FDPhysOracleDriverLink1 := TFDPhysOracleDriverLink.Create(self);
{$IFNDEF NOTRACE}
  FDMonRemoteLink1 := TFDMoniRemoteClientLink.Create(self);
  FDMonRemoteLink1.Tracing := false;
{$ENDIF}
{$ENDIF}
end;

{$IFDEF VCL}
{$IFNDEF EXTERNAL}

procedure TFireDacDataModule.FDGUIxLoginDialog1Login(ASender: TObject;
  var AResult: boolean);
var
  dlg: TFireDacLoginDlgBase;
begin
  dlg := TFireDacLoginDlgBase.Create(self);
  try
    dlg.ShowModal;
    if dlg.ModalResult = mrOk then
    begin
      AResult := true;
{$IF CompilerVersion>=28}
      FDGUIxLoginDialog1.ConnectionDef.Params.UserName := dlg.User_Name.text;
      FDGUIxLoginDialog1.ConnectionDef.Params.Password := dlg.Password.text;
{$ELSE}
      FDGUIxLoginDialog1.ConnectionDef.UserName := dlg.User_Name.text;
      FDGUIxLoginDialog1.ConnectionDef.Password := dlg.Password.text;
{$ENDIF}
    end;
  finally
    dlg.free;
  end;
end;
{$ENDIF}
{$ENDIF}

function FireDacModule: TFireDacDataModule;
begin
  result := LFireDacDataModule;
end;

{ TFireScript }

procedure TFireScript.Clear;
begin
  SQLScripts.Clear;
end;

procedure TFireScript.ExecSql;
begin
  ExecuteScript(SQL);
end;

Constructor TFireScripts.Create(ow: TComponent);
begin
  inherited;
  // FLock := TObject.Create;
end;

Destructor TFireScripts.Destroy;
begin
  // FreeAndNil(FLock);
  inherited;
end;

procedure TFireScripts.Clear;
begin
  inherited SQLScripts.Clear;
end;

function TFireScripts.ExecSql: boolean;
begin
  result := ExecuteAll;
end;

function TFireScripts.ExecuteAll: boolean;
var
  canExecAll: boolean;
  i: integer;
  sErro: string;
begin
  result := false;
  canExecAll := true;
  if (SQLScripts.count = 0) and (SQLScriptFileName = '') then
    exit;

  if SameText(Connection.DriverName, 'SQLITE') then
    canExecAll := false;

  if canExecAll then
    result := inherited ExecuteAll
  else
  begin
    result := true;
    sErro := '';
    for i := 0 to SQLScripts.count - 1 do
      try
        Connection.ExecSql(SQLScripts[i].SQL.text);
      except
        on E: EFDDBEngineException do
        begin
          sErro := FireTable_GetErrorMessage(E);
          result := false;
        end;
        on E: exception do
        begin
          sErro := E.Message;
          result := false;
        end;
      end;
  end;
  if sErro <> '' then
    raise exception.Create(sErro);
end;

function TFireScripts.GetDatabase: TFireDatabase;
begin
  result := TFireDatabase(inherited Connection);
end;

function TFireScripts.GetDatabasename: string;
begin
  result := FDatabasename;
end;

function TFireScripts.GetSQL: TStrings;
begin
  if SQLScripts.count = 0 then
    SQLScripts.add;
  result := SQLScripts.items[0].SQL;
end;

function TFireScript.GetSQL: TStrings;
begin
  if inherited SQLScripts.count = 0 then
    inherited SQLScripts.add;
  result := inherited SQLScripts[0].SQL;
end;

procedure TFireScripts.SetDatabase(const Value: TFireDatabase);
begin
  inherited Connection := Value;
  if assigned(Value) then
    FDatabasename := Value.Databasename;
end;

procedure TFireScripts.SetDatabasename(const Value: string);
var
  ss: TFireSession;
begin
  // System.TMonitor.enter(FLock);
  try
    FDatabasename := Value;
    if FDatabasename <> '' then
    begin
      ss := FireSession;
      Database := ss.FindDataBase(Value);
    end;
  finally
    // System.TMonitor.exit(FLock);
  end;
end;

procedure TFireScripts.SetSQL(const Value: TStrings);
begin
  if SQLScripts.count = 0 then
    SQLScripts.add;
  SQLScripts.items[0].SQL.Assign(Value);
end;

procedure TFireScript.SetSQL(const Value: TStrings);
begin
  if inherited SQLScripts.count = 0 then
    inherited SQLScripts.add;
  inherited SQLScripts[0].Assign(Value);
end;

var
  ArqZConnections: string;

destructor TFireDacDataModule.Destroy;
begin
{$IFDEF MSWINDOWS}
  FDPhysFBDriverLink1.free;
{$IFNDEF NOTRACE}
  FDMonRemoteLink1.Tracing := false;
  FDMonRemoteLink1.free;
{$ENDIF}
{$ENDIF}
  inherited;
end;

{$IFDEF MSWINDOWS}

function TFireDacDataModule.OraDriver: TFDPhysOracleDriverLink;
begin
  if not assigned(FDPhysOracleDriverLink1) then
    FDPhysOracleDriverLink1 := TFDPhysOracleDriverLink.Create(self);
  result := FDPhysOracleDriverLink1;
end;
{$ENDIF}

initialization

try
  FireDebugAttrib.active := false;
  FireDebugAttrib.execute := false;
  ShowTables(nil); // dummy;
{$IFDEF MSWINDOWS}
  if (fileExists(ExtractFilePath(ParamStr(0)) + 'debug.on')) or
    FindCmdLineSwitch('D', ['+', '-', '\', '/'], true) then

  begin
    FireDebugAttrib.Detalhed := FindCmdLineSwitch('+D', ['/', '\'], true);
{$IFNDEF EXTERNAL}
    DebugLog('Iniciando monitor do FireDac');
{$ENDIF}
    FireDebugAttrib.active := true;

{$IFNDEF BPL}
{$IFNDEF NOTRACE}
{$IFNDEF EXTERNAL}
{$IF CompilerVersion>= 29.0}
    if FireDebugAttrib.active then
    begin
      LTrace := TFireTFDMoniCustomClientLink.Create(LSessions);
      with TIniFile.Create(ExtractFilePath(ParamStr(0)) + 'debug.on') do
        try
          LTrace.Host := ReadString('Server', 'Host', 'localhost');
          LTrace.Port := ReadInteger('Server', 'Port', 8050);
          LTrace.Tracing := LTrace.Port > 0;

          FireDebugAttrib.transaction :=
            ReadBool('Database', 'Transaction', false);
          FireDebugAttrib.execute := ReadBool('Database', 'Execute', false);
          FireDebugAttrib.Params_in := ReadBool('Database', 'ParamsIN', false)
            or ReadBool('Database', 'dbPARAMS', false);
          FireDebugAttrib.Data_out := ReadBool('Database', 'ParamsOUT', false);
          FireDebugAttrib.prepare := ReadBool('Database', 'Prepare', false);
          FireDebugAttrib.unprepare := ReadBool('Database', 'Unprepare', false);
          FireDebugAttrib.transaction :=
            ReadBool('Database', 'Transaction', false);

          if FindCmdLineSwitch('-D', ['-', '\', '/'], true) then
            FireDebugAttrib.Params_in := false;

          LTrace.EventKinds := [ekLiveCycle, ekError, ekAdaptUpdate,
            ekConnConnect, ekCmdExecute];
          if FireDebugAttrib.Params_in then
            LTrace.EventKinds := LTrace.EventKinds + [ekCmdDataIn];
          if FireDebugAttrib.Data_out then
            LTrace.EventKinds := LTrace.EventKinds + [ekCmdDataOut];
          if FireDebugAttrib.transaction then
            LTrace.EventKinds := LTrace.EventKinds +
              [ekConnTransact, ekConnService, ekCmdPrepare];
          LTrace.Tracing := true;
        finally
          free;
        end;
    end;
{$IFEND}
{$ENDIF}
{$IFEND}
{$ENDIF}
  end;
{$ENDIF}
  LSessions := TFireSessions.Create(nil);
  LFireDacDataModule := TFireDacDataModule.Create(LSessions);
  LDatabases := TDatabasesList.Create(LSessions);
  LSession := TFireSession.Create(LSessions);

{$IFDEF MSWINDOWS}
  FindCmdLineSwitch('Z=', ArqZConnections, true);
  if ArqZConnections <> '' then
  begin
    if ExtractFilePath(ArqZConnections) = '' then
      ArqZConnections := ExtractFilePath(LArqConfigINI) + ArqZConnections;
    SetFireDacConfig(ArqZConnections);
  end;
  LSessions.LoadConfig;

{$IFNDEF UNIGUI}
  if FireSessions.FAliases.IndexOf(c_alias_Local_SQLite) < 0 then
  begin
    LLocalConnection := TFireDatabase.Create(LSessions);
    LLocalConnection.Temporary := true;
    FillLocalSQLConnectionParams(LLocalConnection);
    // LLocalSQL := TFDLocalSQL.Create(LSessions);
    // LLocalSQL.Connection := LLocalConnection;
  end
  else
  begin
    { LLocalConnection := TFireDatabase.Create(LSessions);
      LLocalConnection.AliasName := c_alias_Local_SQLite;
      LLocalSQL := TFDLocalSQL.Create(LSessions);
      LLocalSQL.Connection := LLocalConnection;
    }
  end;
{$ENDIF}
{$ENDIF}
except
  on E: exception do
{$IFDEF SERVICE}
    DebugLog(E.Message);
{$ELSE}
    raise;
{$ENDIF}
end;

finalization

LOnFinalization := true;

{$IFDEF MSWINDOWS}
{$ENDIF}
{$IFNDEF BPL}
{$IF DEFINED(TRACE)}
{$IFNDEF EXTERNAL}
{$IF CompilerVersion>= 29.0}
{$IFNDEF NOTRACE}
if assigned(LTrace) then
begin
  LTrace.Tracing := false;
  freeAndNil(LTrace);
end;
{$ENDIF}
{$ENDIF}
{$IFEND}
{$ENDIF}
{$ENDIF}
LOnFinalizationED := true;
freeAndNil(LConnectionsINI);
freeAndNil(LSessions);

TFireDatabase.Release;

end.
