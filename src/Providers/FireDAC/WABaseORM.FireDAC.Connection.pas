unit WABaseORM.FireDAC.Connection;

interface

uses
  System.SysUtils,
  FireDAC.Comp.Client,
  FireDAC.Stan.Option,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.Phys,
  FireDAC.Phys.FB,
  FireDAC.Phys.Intf,
  FireDAC.Dapt,
  WABaseORM.DB.Interfaces,
  WABaseORM.FireDAC.Query,
  WABaseORM.FireDAC.Transaction;

type
  TWABaseORMFireDACConnection = class(TInterfacedObject, IWABaseORMConnection)
  private
    FConnection: TFDConnection;
    FOwnsConnection: Boolean;
  public
    constructor Create(const ADriverID, AServer, ADatabase, AUser, APassword: string); overload;
    constructor Create(AExistingConnection: TFDConnection); overload;
    destructor Destroy; override;
    procedure Connect;
    procedure Disconnect;
    function Connected: Boolean;
    function CreateQuery: IWABaseORMQuery;
    function StartTransaction: IWABaseORMTransaction;
    function InTransaction: Boolean;
  end;

implementation

{ TWABaseORMFireDACConnection }

constructor TWABaseORMFireDACConnection.Create(const ADriverID, AServer, ADatabase, AUser, APassword: string);
begin
  inherited Create;
  FOwnsConnection := True;
  FConnection := TFDConnection.Create(nil);
  FConnection.Params.DriverID := ADriverID;
  FConnection.Params.Database := ADatabase;
  FConnection.Params.UserName := AUser;
  FConnection.Params.Password := APassword;
  if AServer <> '' then
    FConnection.Params.Add('Server=' + AServer);
  FConnection.LoginPrompt := False;
end;

constructor TWABaseORMFireDACConnection.Create(AExistingConnection: TFDConnection);
begin
  inherited Create;
  FOwnsConnection := False;
  FConnection := AExistingConnection;
end;

destructor TWABaseORMFireDACConnection.Destroy;
begin
  if FOwnsConnection then
    FConnection.Free;
  inherited;
end;

procedure TWABaseORMFireDACConnection.Connect;
begin
  FConnection.Connected := True;
end;

procedure TWABaseORMFireDACConnection.Disconnect;
begin
  FConnection.Connected := False;
end;

function TWABaseORMFireDACConnection.Connected: Boolean;
begin
  Result := FConnection.Connected;
end;

function TWABaseORMFireDACConnection.CreateQuery: IWABaseORMQuery;
begin
  Result := TWABaseORMFireDACQuery.Create(FConnection);
end;

function TWABaseORMFireDACConnection.StartTransaction: IWABaseORMTransaction;
begin
  Result := TWABaseORMFireDACTransaction.Create(FConnection);
end;

function TWABaseORMFireDACConnection.InTransaction: Boolean;
begin
  Result := FConnection.InTransaction;
end;

end.
