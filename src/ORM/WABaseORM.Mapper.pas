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
    procedure MapRowToObject(ADataSet: TDataSet; AObj: T);
    function MapObjectToParams(AObj: T; AIncludePK: Boolean): TArray<string>;
    function GetPrimaryKeyValue(AObj: T): TValue;
    /// <summary>Define os parâmetros de AQuery a partir das propriedades mapeadas de AObj,
    /// escolhendo em runtime a sobrecarga tipada de SetParam mais adequada (Integer, Int64,
    /// string, Double, Currency, TDateTime, Boolean), com Variant apenas como fallback para
    /// tipos não previstos.</summary>
    procedure SetParamsOnQuery(AObj: T; AQuery: IWABaseORMQuery; AIncludePK: Boolean);
    function GetColumnValue(AObj: T; const AColumnName: string): TValue;
    function FindRelation(const APropertyName: string; AKind: TWABaseORMRelationKind;
      out ARelation: TWABaseORMRelationInfo): Boolean;
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
var
  Col: TWABaseORMColumnInfo;
begin
  for Col in FClassInfo.Columns do
    if ADataSet.FindField(Col.ColumnName) <> nil then
      Col.Prop.SetValue(TObject(AObj), TValue.FromVariant(ADataSet.FieldByName(Col.ColumnName).Value));
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

function TWABaseORMMapper<T>.FindRelation(const APropertyName: string; AKind: TWABaseORMRelationKind;
  out ARelation: TWABaseORMRelationInfo): Boolean;
begin
  Result := FClassInfo.FindRelation(APropertyName, AKind, ARelation);
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
