unit WABaseORM.FireDAC.Query;

interface

uses
  System.SysUtils, System.Variants, Data.DB,
  FireDAC.Comp.Client, FireDAC.Stan.Param,
  WABaseORM.DB.Interfaces;

type
  TWABaseORMFireDACQuery = class(TInterfacedObject, IWABaseORMQuery)
  private
    FQuery: TFDQuery;
  public
    constructor Create(AConnection: TFDConnection);
    destructor Destroy; override;
    procedure SetSQL(const ASQL: string);
    procedure SetParam(const AName: string; const AValue: Variant); overload;
    procedure SetParam(const AName: string; const AValue: Integer); overload;
    procedure SetParam(const AName: string; const AValue: Int64); overload;
    procedure SetParam(const AName: string; const AValue: string); overload;
    procedure SetParam(const AName: string; const AValue: Double); overload;
    procedure SetParam(const AName: string; const AValue: Currency); overload;
    procedure SetParam(const AName: string; const AValue: TDateTime); overload;
    procedure SetParam(const AName: string; const AValue: Boolean); overload;
    procedure SetParam(const AName: string); overload;
    function Open: TDataSet;
    function ExecSQL: Integer;
    function AsDataSet: TDataSet;
  end;

implementation

{ TWABaseORMFireDACQuery }

constructor TWABaseORMFireDACQuery.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FQuery := TFDQuery.Create(nil);
  FQuery.Connection := AConnection;
end;

destructor TWABaseORMFireDACQuery.Destroy;
begin
  FQuery.Free;
  inherited;
end;

procedure TWABaseORMFireDACQuery.SetSQL(const ASQL: string);
begin
  FQuery.Close;
  FQuery.SQL.Text := ASQL;
end;

procedure TWABaseORMFireDACQuery.SetParam(const AName: string; const AValue: Variant);
begin
  FQuery.ParamByName(AName).Value := AValue;
end;

procedure TWABaseORMFireDACQuery.SetParam(const AName: string; const AValue: Integer);
begin
  FQuery.ParamByName(AName).AsInteger := AValue;
end;

procedure TWABaseORMFireDACQuery.SetParam(const AName: string; const AValue: Int64);
begin
  FQuery.ParamByName(AName).AsLargeInt := AValue;
end;

procedure TWABaseORMFireDACQuery.SetParam(const AName: string; const AValue: string);
begin
  FQuery.ParamByName(AName).AsString := AValue;
end;

procedure TWABaseORMFireDACQuery.SetParam(const AName: string; const AValue: Double);
begin
  FQuery.ParamByName(AName).AsFloat := AValue;
end;

procedure TWABaseORMFireDACQuery.SetParam(const AName: string; const AValue: Currency);
begin
  FQuery.ParamByName(AName).AsCurrency := AValue;
end;

procedure TWABaseORMFireDACQuery.SetParam(const AName: string; const AValue: TDateTime);
begin
  FQuery.ParamByName(AName).AsDateTime := AValue;
end;

procedure TWABaseORMFireDACQuery.SetParam(const AName: string; const AValue: Boolean);
begin
  FQuery.ParamByName(AName).AsBoolean := AValue;
end;

procedure TWABaseORMFireDACQuery.SetParam(const AName: string);
begin
  FQuery.ParamByName(AName).Clear;
  FQuery.ParamByName(AName).Value := Null;
end;

function TWABaseORMFireDACQuery.Open: TDataSet;
begin
  FQuery.Open;
  Result := FQuery;
end;

function TWABaseORMFireDACQuery.ExecSQL: Integer;
begin
  FQuery.ExecSQL;
  Result := FQuery.RowsAffected;
end;

function TWABaseORMFireDACQuery.AsDataSet: TDataSet;
begin
  Result := FQuery;
end;

end.
