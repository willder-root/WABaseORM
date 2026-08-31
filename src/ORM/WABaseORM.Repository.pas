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
    // Carregam o registro/relacionamento propriamente ditos, já com o Kind (HasMany ou
    // BelongsTo) resolvido por quem chama (FindByID<TRelated>/FindAll<TRelated> abaixo).
    function LoadByIDHasMany<TChild: class, constructor>(const AId: Integer; const ARelation: TWABaseORMRelationInfo): T;
    function LoadByIDBelongsTo<TParent: class, constructor>(const AId: Integer; const ARelation: TWABaseORMRelationInfo): T;
    function LoadWhereHasMany<TChild: class, constructor>(const ACondition: string; const ARelation: TWABaseORMRelationInfo): TObjectList<T>;
    function LoadWhereBelongsTo<TParent: class, constructor>(const ACondition: string; const ARelation: TWABaseORMRelationInfo): TObjectList<T>;
  public
    constructor Create(AConnection: IWABaseORMConnection);
    destructor Destroy; override;
    function FindAll: TObjectList<T>; overload;
    /// <summary>Igual a FindAll, mas filtrando pela cláusula WHERE em ACondition
    /// (ex: "NOME = 'Joao'").</summary>
    function FindAll(const ACondition: string): TObjectList<T>; overload;
    function FindByID(const AId: Integer): T; overload;
    procedure Insert(AObj: T);
    procedure Update(AObj: T);
    procedure Delete(const AId: Integer);
    /// <summary>Busca o registro de ID AId e, na mesma consulta (LEFT JOIN, uma única
    /// query), carrega o relacionamento declarado na propriedade APropertyName, já
    /// populando essa propriedade. O Kind do relacionamento (HasMany ou BelongsTo) é
    /// detectado automaticamente a partir do atributo usado na propriedade — quem chama
    /// não precisa saber qual dos dois foi mapeado, só o tipo do lado relacionado
    /// (TRelated) e o nome da propriedade. Retorna nil se o registro não existir.</summary>
    function FindByID<TRelated: class, constructor>(const AId: Integer; const APropertyName: string): T; overload;
    /// <summary>Igual ao FindAll(ACondition), mas carrega, na mesma consulta (LEFT
    /// JOIN), o relacionamento declarado na propriedade APropertyName — com o Kind
    /// (HasMany ou BelongsTo) detectado automaticamente, como em FindByID&lt;TRelated&gt;.
    /// Como a consulta junta duas tabelas, colunas com o mesmo nome nos dois lados
    /// (ex: "ID") ficam ambíguas sem qualificação: prefixe ACondition com o alias da
    /// tabela principal, "M." (ex: "M.ID IN (1, 2)"), quando isso puder ocorrer.</summary>
    function FindAll<TRelated: class, constructor>(const ACondition: string; const APropertyName: string): TObjectList<T>; overload;
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

function TWABaseORMRepository<T>.FindAll(const ACondition: string): TObjectList<T>;
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

function TWABaseORMRepository<T>.FindByID<TRelated>(const AId: Integer; const APropertyName: string): T;
var
  Relation: TWABaseORMRelationInfo;
begin
  if not FMapper.FindRelation(APropertyName, Relation) then
    raise EWABaseORMRelationNotFound.Create(T.ClassName, APropertyName);

  case Relation.Kind of
    rkHasMany: Result := LoadByIDHasMany<TRelated>(AId, Relation);
    rkBelongsTo: Result := LoadByIDBelongsTo<TRelated>(AId, Relation);
  else
    Result := nil;
  end;
end;

function TWABaseORMRepository<T>.FindAll<TRelated>(const ACondition, APropertyName: string): TObjectList<T>;
var
  Relation: TWABaseORMRelationInfo;
begin
  if not FMapper.FindRelation(APropertyName, Relation) then
    raise EWABaseORMRelationNotFound.Create(T.ClassName, APropertyName);

  case Relation.Kind of
    rkHasMany: Result := LoadWhereHasMany<TRelated>(ACondition, Relation);
    rkBelongsTo: Result := LoadWhereBelongsTo<TRelated>(ACondition, Relation);
  else
    Result := TObjectList<T>.Create(True);
  end;
end;

function TWABaseORMRepository<T>.LoadByIDHasMany<TChild>(const AId: Integer; const ARelation: TWABaseORMRelationInfo): T;
const
  MainAlias = 'M';
  ChildAlias = 'C';
  MainPrefix = 'M_';
  ChildPrefix = 'C_';
var
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
            Format('%s.%s = %s.%s', [ChildAlias, ARelation.ForeignKeyColumn, MainAlias, FMapper.GetPrimaryKeyColumn]))
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

      if Assigned(Result) and Assigned(ARelation.Prop) then
        ARelation.Prop.SetValue(TObject(Result), TValue.From<TObjectList<TChild>>(Children))
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

function TWABaseORMRepository<T>.LoadByIDBelongsTo<TParent>(const AId: Integer; const ARelation: TWABaseORMRelationInfo): T;
const
  MainAlias = 'M';
  ParentAlias = 'P';
  MainPrefix = 'M_';
  ParentPrefix = 'P_';
var
  ParentMapper: TWABaseORMMapper<TParent>;
  Builder: TWABaseORMQueryBuilder;
  Qry: IWABaseORMQuery;
  DS: TDataSet;
  Cols: TList<string>;
  ParentPKField: string;
  ParentObj: TParent;
begin
  Result := nil;

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
            Format('%s.%s = %s.%s', [ParentAlias, ParentMapper.GetPrimaryKeyColumn, MainAlias, ARelation.ForeignKeyColumn]))
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
          if Assigned(ARelation.Prop) then
            ARelation.Prop.SetValue(TObject(Result), TValue.From<TParent>(ParentObj))
          else
            ParentObj.Free;
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

function TWABaseORMRepository<T>.LoadWhereHasMany<TChild>(const ACondition: string; const ARelation: TWABaseORMRelationInfo): TObjectList<T>;
const
  MainAlias = 'M';
  ChildAlias = 'C';
  MainPrefix = 'M_';
  ChildPrefix = 'C_';
var
  ChildMapper: TWABaseORMMapper<TChild>;
  Builder: TWABaseORMQueryBuilder;
  Qry: IWABaseORMQuery;
  DS: TDataSet;
  Cols: TList<string>;
  Index: TDictionary<string, T>;
  MainPKField, ChildPKField, MainKey: string;
  MainObj: T;
  Children: TObjectList<TChild>;
  Item: TChild;
begin
  Result := TObjectList<T>.Create(True);

  ChildMapper := TWABaseORMMapper<TChild>.Create;
  try
    Cols := TList<string>.Create;
    Index := TDictionary<string, T>.Create;
    Builder := TWABaseORMQueryBuilder.Create(FMapper.GetTableName);
    try
      Cols.AddRange(FMapper.GetAliasedSelectColumns(MainAlias, MainPrefix));
      Cols.AddRange(ChildMapper.GetAliasedSelectColumns(ChildAlias, ChildPrefix));

      // LEFT JOIN: cada registro principal aparece em 1 linha por filho (ou 1 linha só,
      // com os campos do filho em NULL, quando não há nenhum). As linhas do mesmo
      // registro principal são agrupadas abaixo por PK (Index), então nem precisam vir
      // contíguas.
      Qry := FConnection.CreateQuery;
      Qry.SetSQL(
        Builder
          .Alias(MainAlias)
          .Select(Cols.ToArray)
          .LeftJoin(ChildMapper.GetTableName, ChildAlias,
            Format('%s.%s = %s.%s', [ChildAlias, ARelation.ForeignKeyColumn, MainAlias, FMapper.GetPrimaryKeyColumn]))
          .Where(ACondition)
          .BuildSelect);
      DS := Qry.Open;

      MainPKField := MainPrefix + FMapper.GetPrimaryKeyColumn;
      ChildPKField := ChildPrefix + ChildMapper.GetPrimaryKeyColumn;
      while not DS.Eof do
      begin
        MainKey := DS.FieldByName(MainPKField).AsString;
        if not Index.TryGetValue(MainKey, MainObj) then
        begin
          MainObj := T.Create;
          FMapper.MapRowToObject(DS, MainObj, MainPrefix);
          Result.Add(MainObj);
          Index.Add(MainKey, MainObj);

          if Assigned(ARelation.Prop) then
            ARelation.Prop.SetValue(TObject(MainObj), TValue.From<TObjectList<TChild>>(TObjectList<TChild>.Create(True)));
        end;

        if not DS.FieldByName(ChildPKField).IsNull and Assigned(ARelation.Prop) then
        begin
          Item := TChild.Create;
          ChildMapper.MapRowToObject(DS, Item, ChildPrefix);
          Children := ARelation.Prop.GetValue(TObject(MainObj)).AsType<TObjectList<TChild>>;
          Children.Add(Item);
        end;

        DS.Next;
      end;
    finally
      Builder.Free;
      Cols.Free;
      Index.Free;
    end;
  finally
    ChildMapper.Free;
  end;
end;

function TWABaseORMRepository<T>.LoadWhereBelongsTo<TParent>(const ACondition: string; const ARelation: TWABaseORMRelationInfo): TObjectList<T>;
const
  MainAlias = 'M';
  ParentAlias = 'P';
  MainPrefix = 'M_';
  ParentPrefix = 'P_';
var
  ParentMapper: TWABaseORMMapper<TParent>;
  Builder: TWABaseORMQueryBuilder;
  Qry: IWABaseORMQuery;
  DS: TDataSet;
  Cols: TList<string>;
  ParentPKField: string;
  MainObj: T;
  ParentObj: TParent;
begin
  Result := TObjectList<T>.Create(True);

  ParentMapper := TWABaseORMMapper<TParent>.Create;
  try
    Cols := TList<string>.Create;
    Builder := TWABaseORMQueryBuilder.Create(FMapper.GetTableName);
    try
      Cols.AddRange(FMapper.GetAliasedSelectColumns(MainAlias, MainPrefix));
      Cols.AddRange(ParentMapper.GetAliasedSelectColumns(ParentAlias, ParentPrefix));

      // LEFT JOIN: cada registro principal é uma única linha (relacionamento N:1), então,
      // diferente do HasMany, não há necessidade de agrupar linhas por PK.
      Qry := FConnection.CreateQuery;
      Qry.SetSQL(
        Builder
          .Alias(MainAlias)
          .Select(Cols.ToArray)
          .LeftJoin(ParentMapper.GetTableName, ParentAlias,
            Format('%s.%s = %s.%s', [ParentAlias, ParentMapper.GetPrimaryKeyColumn, MainAlias, ARelation.ForeignKeyColumn]))
          .Where(ACondition)
          .BuildSelect);
      DS := Qry.Open;

      ParentPKField := ParentPrefix + ParentMapper.GetPrimaryKeyColumn;
      while not DS.Eof do
      begin
        MainObj := T.Create;
        FMapper.MapRowToObject(DS, MainObj, MainPrefix);
        Result.Add(MainObj);

        if not DS.FieldByName(ParentPKField).IsNull then
        begin
          ParentObj := TParent.Create;
          ParentMapper.MapRowToObject(DS, ParentObj, ParentPrefix);
          if Assigned(ARelation.Prop) then
            ARelation.Prop.SetValue(TObject(MainObj), TValue.From<TParent>(ParentObj))
          else
            ParentObj.Free;
        end;

        DS.Next;
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
