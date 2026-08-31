unit WABaseORM.Mapper;

interface

uses
  System.Rtti, System.TypInfo, System.SysUtils, System.Variants, Data.DB,
  System.Generics.Collections,
  WABaseORM.DB.Interfaces, WABaseORM.Interfaces, WABaseORM.RttiCache, WABaseORM.Exceptions;

type
  TWABaseORMMapper<T: class, constructor> = class(TInterfacedObject, IWABaseORMEntityMapper<T>)
  private
    FClassInfo: TWABaseORMClassInfo;
    class procedure SetQueryParamFromValue(AQuery: IWABaseORMQuery; const AColumnName: string; const AValue: TValue); static;
  public
    constructor Create;
    function GetTableName: string;
    function GetPrimaryKeyColumn: string;
    procedure MapRowToObject(ADataSet: TDataSet; AObj: T); overload;
    /// <summary>Igual ao overload acima, mas lê os campos de ADataSet com o prefixo
    /// AColumnPrefix (ex: "P_ID" em vez de "ID"). Usado para popular objetos a partir de
    /// uma linha de um SELECT com JOIN, onde as colunas de cada tabela são reescritas com
    /// alias (ver GetAliasedSelectColumns) para não colidir entre si.</summary>
    procedure MapRowToObject(ADataSet: TDataSet; AObj: T; const AColumnPrefix: string); overload;
    /// <summary>Retorna as colunas desta classe qualificadas com o alias de tabela e
    /// renomeadas com AColumnPrefix (ex: "P.ID AS P_ID"), para montar um SELECT com JOIN
    /// entre múltiplas tabelas sem colisão de nomes de coluna.</summary>
    function GetAliasedSelectColumns(const ATableAlias, AColumnPrefix: string): TArray<string>;
    function MapObjectToParams(AObj: T; AIncludePK: Boolean): TArray<string>;
    function GetPrimaryKeyValue(AObj: T): TValue;
    /// <summary>Define os parâmetros de AQuery a partir das propriedades mapeadas de AObj,
    /// escolhendo em runtime a sobrecarga tipada de SetParam mais adequada (Integer, Int64,
    /// string, Double, Currency, TDateTime, Boolean), com Variant apenas como fallback para
    /// tipos não previstos.</summary>
    procedure SetParamsOnQuery(AObj: T; AQuery: IWABaseORMQuery; AIncludePK: Boolean);
    function GetColumnValue(AObj: T; const AColumnName: string): TValue;
    function FindRelation(const APropertyName: string; out ARelation: TWABaseORMRelationInfo): Boolean;
  end;

implementation

{ TWABaseORMMapper<T> }

constructor TWABaseORMMapper<T>.Create;
begin
  inherited Create;
  FClassInfo := TWABaseORMRttiCache.GetClassInfo(T);
end;

function TWABaseORMMapper<T>.GetTableName: string;
begin
  Result := FClassInfo.TableName;
end;

function TWABaseORMMapper<T>.GetPrimaryKeyColumn: string;
begin
  if not FClassInfo.HasPrimaryKey then
    raise EWABaseORMPrimaryKeyNotFound.Create(T.ClassName);
  Result := FClassInfo.PrimaryKey.ColumnName;
end;

procedure TWABaseORMMapper<T>.MapRowToObject(ADataSet: TDataSet; AObj: T);
begin
  MapRowToObject(ADataSet, AObj, '');
end;

procedure TWABaseORMMapper<T>.MapRowToObject(ADataSet: TDataSet; AObj: T; const AColumnPrefix: string);
var
  Col: TWABaseORMColumnInfo;
  FieldName: string;
begin
  for Col in FClassInfo.Columns do
  begin
    FieldName := AColumnPrefix + Col.ColumnName;
    if ADataSet.FindField(FieldName) <> nil then
      Col.Prop.SetValue(TObject(AObj), TValue.FromVariant(ADataSet.FieldByName(FieldName).Value));
  end;
end;

function TWABaseORMMapper<T>.GetAliasedSelectColumns(const ATableAlias, AColumnPrefix: string): TArray<string>;
var
  Col: TWABaseORMColumnInfo;
  List: TList<string>;
begin
  List := TList<string>.Create;
  try
    for Col in FClassInfo.Columns do
      List.Add(Format('%s.%s AS %s%s', [ATableAlias, Col.ColumnName, AColumnPrefix, Col.ColumnName]));
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TWABaseORMMapper<T>.MapObjectToParams(AObj: T; AIncludePK: Boolean): TArray<string>;
var
  Col: TWABaseORMColumnInfo;
  List: TList<string>;
begin
  List := TList<string>.Create;
  try
    for Col in FClassInfo.Columns do
    begin
      if Col.IsPK and not AIncludePK then
        Continue;
      List.Add(Col.ColumnName);
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TWABaseORMMapper<T>.GetPrimaryKeyValue(AObj: T): TValue;
begin
  if not FClassInfo.HasPrimaryKey then
    raise EWABaseORMPrimaryKeyNotFound.Create(T.ClassName);
  Result := FClassInfo.PrimaryKey.Prop.GetValue(TObject(AObj));
end;

function TWABaseORMMapper<T>.GetColumnValue(AObj: T; const AColumnName: string): TValue;
var
  Col: TWABaseORMColumnInfo;
begin
  if not FClassInfo.FindColumn(AColumnName, Col) then
    raise EWABaseORMException.CreateFmt('A classe "%s" não possui a coluna "%s" mapeada.', [T.ClassName, AColumnName]);
  Result := Col.Prop.GetValue(TObject(AObj));
end;

function TWABaseORMMapper<T>.FindRelation(const APropertyName: string; out ARelation: TWABaseORMRelationInfo): Boolean;
begin
  Result := FClassInfo.FindRelation(APropertyName, ARelation);
end;

class procedure TWABaseORMMapper<T>.SetQueryParamFromValue(AQuery: IWABaseORMQuery; const AColumnName: string; const AValue: TValue);
begin
  // Valor "vazio" (ex: propriedade nil/default não inicializada) -> NULL explícito.
  if AValue.IsEmpty then
  begin
    AQuery.SetParam(AColumnName);
    Exit;
  end;

  case AValue.Kind of
    tkInteger, tkChar, tkWChar:
      AQuery.SetParam(AColumnName, AValue.AsInteger);

    tkInt64:
      AQuery.SetParam(AColumnName, AValue.AsInt64);

    tkFloat:
      begin
        // TDateTime e Currency são "type Double" por baixo dos panos: só dá para
        // diferenciar comparando o TypeInfo real da propriedade.
        if AValue.TypeInfo = System.TypeInfo(TDateTime) then
          AQuery.SetParam(AColumnName, AValue.AsType<TDateTime>)
        else if AValue.TypeInfo = System.TypeInfo(TDate) then
          AQuery.SetParam(AColumnName, AValue.AsType<TDateTime>)
        else if AValue.TypeInfo = System.TypeInfo(TTime) then
          AQuery.SetParam(AColumnName, AValue.AsType<TDateTime>)
        else if AValue.TypeInfo = System.TypeInfo(Currency) then
          AQuery.SetParam(AColumnName, AValue.AsType<Currency>)
        else
          AQuery.SetParam(AColumnName, AValue.AsExtended);
      end;

    tkString, tkLString, tkWString, tkUString:
      AQuery.SetParam(AColumnName, AValue.AsString);

    tkEnumeration:
      begin
        if AValue.TypeInfo = System.TypeInfo(Boolean) then
          AQuery.SetParam(AColumnName, AValue.AsBoolean)
        else
          // Enum "comum" (não Boolean): grava o valor ordinal.
          AQuery.SetParam(AColumnName, AValue.AsOrdinal);
      end;
  else
    // Fallback de segurança para tipos não previstos acima (ex: tkClass, tkInterface,
    // tkVariant vindo de outro lugar) — mantém o comportamento antigo via Variant.
    AQuery.SetParam(AColumnName, AValue.AsVariant);
  end;
end;

procedure TWABaseORMMapper<T>.SetParamsOnQuery(AObj: T; AQuery: IWABaseORMQuery; AIncludePK: Boolean);
var
  Col: TWABaseORMColumnInfo;
begin
  for Col in FClassInfo.Columns do
  begin
    if Col.IsPK and not AIncludePK then
      Continue;
    SetQueryParamFromValue(AQuery, Col.ColumnName, Col.Prop.GetValue(TObject(AObj)));
  end;
end;

end.
