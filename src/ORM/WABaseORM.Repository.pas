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
    /// <summary>Busca o registro de ID AId e, na mesma consulta (LEFT JOIN, uma única
    /// query), carrega o lado "muitos" do relacionamento 1:N declarado via
    /// [WABaseORMHasManyAttribute(...)] na propriedade APropertyName, já populando essa
    /// propriedade (TObjectList&lt;TChild&gt;). Retorna nil se o registro não existir.</summary>
    function FindByIDWithHasMany<TChild: class, constructor>(const AId: Integer; const APropertyName: string): T;
    /// <summary>Busca o registro de ID AId e, na mesma consulta (LEFT JOIN, uma única
    /// query), carrega o lado "um" do relacionamento N:1 declarado via
    /// [WABaseORMBelongsToAttribute(...)] na propriedade APropertyName, já populando essa
    /// propriedade (TParent, ou nil se a FK estiver vazia). Retorna nil se o registro não
    /// existir.</summary>
    function FindByIDWithBelongsTo<TParent: class, constructor>(const AId: Integer; const APropertyName: string): T;
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

function TWABaseORMRepository<T>.FindByIDWithHasMany<TChild>(const AId: Integer; const APropertyName: string): T;
const
  MainAlias = 'M';
  ChildAlias = 'C';
  MainPrefix = 'M_';
  ChildPrefix = 'C_';
var
  Relation: TWABaseORMRelationInfo;
  ChildMapper: TWABaseORMMapper<TChild>;
  Builder: TWABaseORMQueryBuilder;
  Qry: IWABaseORMQuery;
  DS: TDataSet;
  Cols: TList<string>;
  Children: TObjectList<TChild>;
  ChildPKField: string;
  Item: TChild;
begin
  Result := nil;

  if not FMapper.FindRelation(APropertyName, rkHasMany, Relation) then
    raise EWABaseORMRelationNotFound.Create(T.ClassName, APropertyName);

  ChildMapper := TWABaseORMMapper<TChild>.Create;
  try
    Cols := TList<string>.Create;
    Builder := TWABaseORMQueryBuilder.Create(FMapper.GetTableName);
    try
      Cols.AddRange(FMapper.GetAliasedSelectColumns(MainAlias, MainPrefix));
      Cols.AddRange(ChildMapper.GetAliasedSelectColumns(ChildAlias, ChildPrefix));

      // LEFT JOIN: uma única consulta traz o registro principal e todos os relacionados
      // de uma vez, mesmo quando não há nenhum filho (o INNER JOIN eliminaria a linha
      // principal nesse caso).
      Qry := FConnection.CreateQuery;
      Qry.SetSQL(
        Builder
          .Alias(MainAlias)
          .Select(Cols.ToArray)
          .LeftJoin(ChildMapper.GetTableName, ChildAlias,
            Format('%s.%s = %s.%s', [ChildAlias, Relation.ForeignKeyColumn, MainAlias, FMapper.GetPrimaryKeyColumn]))
          .Where(Format('%s.%s = :ID', [MainAlias, FMapper.GetPrimaryKeyColumn]))
          .BuildSelect);
      Qry.SetParam('ID', AId);
      DS := Qry.Open;

      Children := TObjectList<TChild>.Create(True);
      ChildPKField := ChildPrefix + ChildMapper.GetPrimaryKeyColumn;
      while not DS.Eof do
      begin
        if not Assigned(Result) then
        begin
          Result := T.Create;
          FMapper.MapRowToObject(DS, Result, MainPrefix);
        end;

        if not DS.FieldByName(ChildPKField).IsNull then
        begin
          Item := TChild.Create;
          ChildMapper.MapRowToObject(DS, Item, ChildPrefix);
          Children.Add(Item);
        end;

        DS.Next;
      end;

      if Assigned(Result) and Assigned(Relation.Prop) then
        Relation.Prop.SetValue(TObject(Result), TValue.From<TObjectList<TChild>>(Children))
      else
        Children.Free;
    finally
      Builder.Free;
      Cols.Free;
    end;
  finally
    ChildMapper.Free;
  end;
end;

function TWABaseORMRepository<T>.FindByIDWithBelongsTo<TParent>(const AId: Integer; const APropertyName: string): T;
const
  MainAlias = 'M';
  ParentAlias = 'P';
  MainPrefix = 'M_';
  ParentPrefix = 'P_';
var
  Relation: TWABaseORMRelationInfo;
  ParentMapper: TWABaseORMMapper<TParent>;
  Builder: TWABaseORMQueryBuilder;
  Qry: IWABaseORMQuery;
  DS: TDataSet;
  Cols: TList<string>;
  ParentPKField: string;
  ParentObj: TParent;
begin
  Result := nil;

  if not FMapper.FindRelation(APropertyName, rkBelongsTo, Relation) then
    raise EWABaseORMRelationNotFound.Create(T.ClassName, APropertyName);

  ParentMapper := TWABaseORMMapper<TParent>.Create;
  try
    Cols := TList<string>.Create;
    Builder := TWABaseORMQueryBuilder.Create(FMapper.GetTableName);
    try
      Cols.AddRange(FMapper.GetAliasedSelectColumns(MainAlias, MainPrefix));
      Cols.AddRange(ParentMapper.GetAliasedSelectColumns(ParentAlias, ParentPrefix));

      // LEFT JOIN: uma única consulta traz o registro principal e o pai relacionado,
      // mesmo quando a FK está vazia (o INNER JOIN eliminaria a linha principal nesse caso).
      Qry := FConnection.CreateQuery;
      Qry.SetSQL(
        Builder
          .Alias(MainAlias)
          .Select(Cols.ToArray)
          .LeftJoin(ParentMapper.GetTableName, ParentAlias,
            Format('%s.%s = %s.%s', [ParentAlias, ParentMapper.GetPrimaryKeyColumn, MainAlias, Relation.ForeignKeyColumn]))
          .Where(Format('%s.%s = :ID', [MainAlias, FMapper.GetPrimaryKeyColumn]))
          .BuildSelect);
      Qry.SetParam('ID', AId);
      DS := Qry.Open;

      if not DS.Eof then
      begin
        Result := T.Create;
        FMapper.MapRowToObject(DS, Result, MainPrefix);

        ParentPKField := ParentPrefix + ParentMapper.GetPrimaryKeyColumn;
        if not DS.FieldByName(ParentPKField).IsNull then
        begin
          ParentObj := TParent.Create;
          ParentMapper.MapRowToObject(DS, ParentObj, ParentPrefix);
          if Assigned(Relation.Prop) then
            Relation.Prop.SetValue(TObject(Result), TValue.From<TParent>(ParentObj));
        end;
      end;
    finally
      Builder.Free;
      Cols.Free;
    end;
  finally
    ParentMapper.Free;
  end;
end;

end.
