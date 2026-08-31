unit WABaseORM.Repository;

interface

uses
  System.SysUtils, System.Rtti, Data.DB, System.Generics.Collections,
  WABaseORM.DB.Interfaces, WABaseORM.Interfaces,
  WABaseORM.Mapper, WABaseORM.QueryBuilder, WABaseORM.Exceptions, WABaseORM.RttiCache;

type
  TWABaseORMRepository<T: class, constructor> = class(TInterfacedObject, IWABaseORMRepository<T>)
  private
    FConnection: IWABaseORMConnection;
    FMapper: TWABaseORMMapper<T>;
  public
    constructor Create(AConnection: IWABaseORMConnection);
    destructor Destroy; override;
    function FindAll: TObjectList<T>;
    function FindByID(const AId: Integer): T;
    function FindWhere(const ACondition: string): TObjectList<T>;
    procedure Insert(AObj: T);
    procedure Update(AObj: T);
    procedure Delete(const AId: Integer);
    /// <summary>Carrega o lado "muitos" de um relacionamento 1:N declarado em AObj via
    /// [WABaseORMHasManyAttribute(...)] na propriedade APropertyName, populando essa
    /// propriedade (TObjectList&lt;TChild&gt;) e também retornando a lista carregada.</summary>
    function LoadHasMany<TChild: class, constructor>(AObj: T; const APropertyName: string): TObjectList<TChild>;
    /// <summary>Carrega o lado "um" de um relacionamento N:1 declarado em AObj via
    /// [WABaseORMBelongsToAttribute(...)] na propriedade APropertyName, populando essa
    /// propriedade (TParent) e também retornando o registro carregado (ou nil se a FK
    /// estiver vazia ou o registro pai não existir).</summary>
    function LoadBelongsTo<TParent: class, constructor>(AObj: T; const APropertyName: string): TParent;
  end;

implementation

{ TWABaseORMRepository<T> }

constructor TWABaseORMRepository<T>.Create(AConnection: IWABaseORMConnection);
begin
  inherited Create;
  FConnection := AConnection;
  FMapper := TWABaseORMMapper<T>.Create;
end;

destructor TWABaseORMRepository<T>.Destroy;
begin
  FMapper.Free;
  inherited;
end;

function TWABaseORMRepository<T>.FindAll: TObjectList<T>;
var
  Builder: TWABaseORMQueryBuilder;
  Qry: IWABaseORMQuery;
  Obj: T;
  DS: TDataSet;
begin
  Result := TObjectList<T>.Create(True);
  Builder := TWABaseORMQueryBuilder.Create(FMapper.GetTableName);
  try
    Qry := FConnection.CreateQuery;
    Qry.SetSQL(Builder.SelectAll.BuildSelect);
    DS := Qry.Open;
    while not DS.Eof do
    begin
      Obj := T.Create;
      FMapper.MapRowToObject(DS, Obj);
      Result.Add(Obj);
      DS.Next;
    end;
  finally
    Builder.Free;
  end;
end;

function TWABaseORMRepository<T>.FindByID(const AId: Integer): T;
var
  Builder: TWABaseORMQueryBuilder;
  Qry: IWABaseORMQuery;
  DS: TDataSet;
  PKCol: string;
begin
  Result := nil;
  PKCol := FMapper.GetPrimaryKeyColumn;

  Builder := TWABaseORMQueryBuilder.Create(FMapper.GetTableName);
  try
    Qry := FConnection.CreateQuery;
    Qry.SetSQL(Builder.SelectAll.Where(PKCol + ' = :ID').BuildSelect);
    Qry.SetParam('ID', AId);
    DS := Qry.Open;
    if not DS.Eof then
    begin
      Result := T.Create;
      FMapper.MapRowToObject(DS, Result);
    end;
  finally
    Builder.Free;
  end;
end;

function TWABaseORMRepository<T>.FindWhere(const ACondition: string): TObjectList<T>;
var
  Builder: TWABaseORMQueryBuilder;
  Qry: IWABaseORMQuery;
  Obj: T;
  DS: TDataSet;
begin
  Result := TObjectList<T>.Create(True);
  Builder := TWABaseORMQueryBuilder.Create(FMapper.GetTableName);
  try
    Qry := FConnection.CreateQuery;
    Qry.SetSQL(Builder.SelectAll.Where(ACondition).BuildSelect);
    DS := Qry.Open;
    while not DS.Eof do
    begin
      Obj := T.Create;
      FMapper.MapRowToObject(DS, Obj);
      Result.Add(Obj);
      DS.Next;
    end;
  finally
    Builder.Free;
  end;
end;

procedure TWABaseORMRepository<T>.Insert(AObj: T);
var
  Builder: TWABaseORMQueryBuilder;
  Qry: IWABaseORMQuery;
  Cols: TArray<string>;
begin
  Cols := FMapper.MapObjectToParams(AObj, true);

  Builder := TWABaseORMQueryBuilder.Create(FMapper.GetTableName);
  try
    Qry := FConnection.CreateQuery;
    Qry.SetSQL(Builder.BuildInsert(Cols));

    // O mapper escolhe em runtime a sobrecarga tipada de SetParam mais adequada
    // (Integer, Int64, string, Double, Currency, TDateTime, Boolean) para cada
    // propriedade, com Variant apenas como fallback.
    FMapper.SetParamsOnQuery(AObj, Qry, true);

    Qry.ExecSQL;
  finally
    Builder.Free;
  end;
end;

procedure TWABaseORMRepository<T>.Update(AObj: T);
var
  Builder: TWABaseORMQueryBuilder;
  Qry: IWABaseORMQuery;
  Cols: TArray<string>;
  PKCol: string;
  PKValue: TValue;
begin
  PKCol := FMapper.GetPrimaryKeyColumn;
  Cols := FMapper.MapObjectToParams(AObj, False);
  PKValue := FMapper.GetPrimaryKeyValue(AObj);

  Builder := TWABaseORMQueryBuilder.Create(FMapper.GetTableName);
  try
    Qry := FConnection.CreateQuery;
    Qry.SetSQL(Builder.BuildUpdate(Cols, PKCol));

    FMapper.SetParamsOnQuery(AObj, Qry, false);

    Qry.SetParam('PK_' + PKCol, PKValue.AsVariant);
    Qry.ExecSQL;
  finally
    Builder.Free;
  end;
end;

procedure TWABaseORMRepository<T>.Delete(const AId: Integer);
var
  Builder: TWABaseORMQueryBuilder;
  Qry: IWABaseORMQuery;
  PKCol: string;
begin
  PKCol := FMapper.GetPrimaryKeyColumn;

  Builder := TWABaseORMQueryBuilder.Create(FMapper.GetTableName);
  try
    Qry := FConnection.CreateQuery;
    Qry.SetSQL(Builder.BuildDelete(PKCol));
    Qry.SetParam(PKCol, AId);
    Qry.ExecSQL;
  finally
    Builder.Free;
  end;
end;

function TWABaseORMRepository<T>.LoadHasMany<TChild>(AObj: T; const APropertyName: string): TObjectList<TChild>;
var
  Relation: TWABaseORMRelationInfo;
  ChildMapper: TWABaseORMMapper<TChild>;
  Builder: TWABaseORMQueryBuilder;
  Qry: IWABaseORMQuery;
  DS: TDataSet;
  Item: TChild;
begin
  if not FMapper.FindRelation(APropertyName, rkHasMany, Relation) then
    raise EWABaseORMRelationNotFound.Create(T.ClassName, APropertyName);

  Result := TObjectList<TChild>.Create(True);
  ChildMapper := TWABaseORMMapper<TChild>.Create;
  try
    Builder := TWABaseORMQueryBuilder.Create(ChildMapper.GetTableName);
    try
      Qry := FConnection.CreateQuery;
      Qry.SetSQL(Builder.SelectAll.Where(Relation.ForeignKeyColumn + ' = :FK').BuildSelect);
      Qry.SetParam('FK', FMapper.GetPrimaryKeyValue(AObj).AsVariant);
      DS := Qry.Open;
      while not DS.Eof do
      begin
        Item := TChild.Create;
        ChildMapper.MapRowToObject(DS, Item);
        Result.Add(Item);
        DS.Next;
      end;
    finally
      Builder.Free;
    end;

    if Assigned(Relation.Prop) then
      Relation.Prop.SetValue(TObject(AObj), TValue.From<TObjectList<TChild>>(Result));
  finally
    ChildMapper.Free;
  end;
end;

function TWABaseORMRepository<T>.LoadBelongsTo<TParent>(AObj: T; const APropertyName: string): TParent;
var
  Relation: TWABaseORMRelationInfo;
  ParentMapper: TWABaseORMMapper<TParent>;
  Builder: TWABaseORMQueryBuilder;
  Qry: IWABaseORMQuery;
  DS: TDataSet;
  FKValue: TValue;
begin
  Result := nil;

  if not FMapper.FindRelation(APropertyName, rkBelongsTo, Relation) then
    raise EWABaseORMRelationNotFound.Create(T.ClassName, APropertyName);

  FKValue := FMapper.GetColumnValue(AObj, Relation.ForeignKeyColumn);
  if FKValue.IsEmpty then
    Exit(nil);

  ParentMapper := TWABaseORMMapper<TParent>.Create;
  try
    Builder := TWABaseORMQueryBuilder.Create(ParentMapper.GetTableName);
    try
      Qry := FConnection.CreateQuery;
      Qry.SetSQL(Builder.SelectAll.Where(ParentMapper.GetPrimaryKeyColumn + ' = :PK').BuildSelect);
      Qry.SetParam('PK', FKValue.AsVariant);
      DS := Qry.Open;
      if not DS.Eof then
      begin
        Result := TParent.Create;
        ParentMapper.MapRowToObject(DS, Result);
      end;
    finally
      Builder.Free;
    end;

    if Assigned(Relation.Prop) and Assigned(Result) then
      Relation.Prop.SetValue(TObject(AObj), TValue.From<TParent>(Result));
  finally
    ParentMapper.Free;
  end;
end;

end.
