unit WABaseORM.QueryBuilder;

interface

uses
  System.SysUtils, System.Generics.Collections;

type
  TWABaseORMQueryBuilder = class
  private
    FTableName: string;
    FColumns: TList<string>;
    FConditions: TList<string>;
    FOrderBy: string;
  public
    constructor Create(const ATableName: string);
    destructor Destroy; override;
    function Select(const AColumns: array of string): TWABaseORMQueryBuilder;
    function SelectAll: TWABaseORMQueryBuilder;
    function Where(const ACondition: string): TWABaseORMQueryBuilder;
    function OrderBy(const AColumns: string): TWABaseORMQueryBuilder;
    function BuildSelect: string;
    function BuildInsert(const AColumns: array of string): string;
    function BuildUpdate(const AColumns: array of string; const APKColumn: string): string;
    function BuildDelete(const APKColumn: string): string;
  end;

implementation

{ TWABaseORMQueryBuilder }

constructor TWABaseORMQueryBuilder.Create(const ATableName: string);
begin
  inherited Create;
  FTableName := ATableName;
  FColumns := TList<string>.Create;
  FConditions := TList<string>.Create;
  FOrderBy := '';
end;

destructor TWABaseORMQueryBuilder.Destroy;
begin
  FColumns.Free;
  FConditions.Free;
  inherited;
end;

function TWABaseORMQueryBuilder.Select(const AColumns: array of string): TWABaseORMQueryBuilder;
var
  Col: string;
begin
  FColumns.Clear;
  for Col in AColumns do
    FColumns.Add(Col);
  Result := Self;
end;

function TWABaseORMQueryBuilder.SelectAll: TWABaseORMQueryBuilder;
begin
  FColumns.Clear;
  FColumns.Add('*');
  Result := Self;
end;

function TWABaseORMQueryBuilder.Where(const ACondition: string): TWABaseORMQueryBuilder;
begin
  FConditions.Add(ACondition);
  Result := Self;
end;

function TWABaseORMQueryBuilder.OrderBy(const AColumns: string): TWABaseORMQueryBuilder;
begin
  FOrderBy := AColumns;
  Result := Self;
end;

function TWABaseORMQueryBuilder.BuildSelect: string;
var
  Cols: string;
begin
  if FColumns.Count = 0 then
    Cols := '*'
  else
    Cols := String.Join(', ', FColumns.ToArray);

  Result := Format('SELECT %s FROM %s', [Cols, FTableName]);

  if FConditions.Count > 0 then
    Result := Result + ' WHERE ' + String.Join(' AND ', FConditions.ToArray);

  if FOrderBy <> '' then
    Result := Result + ' ORDER BY ' + FOrderBy;
end;

function TWABaseORMQueryBuilder.BuildInsert(const AColumns: array of string): string;
var
  Cols, Params: TArray<string>;
  I: Integer;
begin
  SetLength(Cols, Length(AColumns));
  SetLength(Params, Length(AColumns));
  for I := 0 to High(AColumns) do
  begin
    Cols[I] := AColumns[I];
    Params[I] := ':' + AColumns[I];
  end;

  Result := Format('INSERT INTO %s (%s) VALUES (%s)',
    [FTableName, String.Join(', ', Cols), String.Join(', ', Params)]);
end;

function TWABaseORMQueryBuilder.BuildUpdate(const AColumns: array of string; const APKColumn: string): string;
var
  SetClauses: TArray<string>;
  I: Integer;
begin
  SetLength(SetClauses, Length(AColumns));
  for I := 0 to High(AColumns) do
    SetClauses[I] := AColumns[I] + ' = :' + AColumns[I];

  Result := Format('UPDATE %s SET %s WHERE %s = :PK_%s',
    [FTableName, String.Join(', ', SetClauses), APKColumn, APKColumn]);
end;

function TWABaseORMQueryBuilder.BuildDelete(const APKColumn: string): string;
begin
  Result := Format('DELETE FROM %s WHERE %s = :%s', [FTableName, APKColumn, APKColumn]);
end;

end.
