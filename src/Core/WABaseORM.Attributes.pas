unit WABaseORM.Attributes;

interface

type
  WABaseORMTableAttribute = class(TCustomAttribute)
  private
    FName: string;
  public
    constructor Create(const AName: string);
    property Name: string read FName;
  end;

  WABaseORMColumnAttribute = class(TCustomAttribute)
  private
    FName: string;
    FIsPK: Boolean;
    FIsAutoInc: Boolean;
  public
    constructor Create(const AName: string; AIsPK: Boolean = False; AIsAutoInc: Boolean = False);
    property Name: string read FName;
    property IsPK: Boolean read FIsPK;
    property IsAutoInc: Boolean read FIsAutoInc;
  end;

  WABaseORMTransientAttribute = class(TCustomAttribute)
  end;

  // Marca uma propriedade de navegação (ex: TObjectList<TPedido>) como o lado "muitos"
  // de um relacionamento 1:N. AForeignKeyColumn é a coluna, na tabela do tipo apontado
  // pela propriedade, que referencia a PK desta classe.
  WABaseORMHasManyAttribute = class(TCustomAttribute)
  private
    FForeignKeyColumn: string;
  public
    constructor Create(const AForeignKeyColumn: string);
    property ForeignKeyColumn: string read FForeignKeyColumn;
  end;

  // Marca uma propriedade de navegação (ex: TCliente) como o lado "um" de um
  // relacionamento N:1. AForeignKeyColumn é a coluna, na tabela desta classe, que
  // guarda o valor da PK da classe apontada pela propriedade.
  WABaseORMBelongsToAttribute = class(TCustomAttribute)
  private
    FForeignKeyColumn: string;
  public
    constructor Create(const AForeignKeyColumn: string);
    property ForeignKeyColumn: string read FForeignKeyColumn;
  end;

implementation

{ WABaseORMHasManyAttribute }

constructor WABaseORMHasManyAttribute.Create(const AForeignKeyColumn: string);
begin
  inherited Create;
  FForeignKeyColumn := AForeignKeyColumn;
end;

{ WABaseORMBelongsToAttribute }

constructor WABaseORMBelongsToAttribute.Create(const AForeignKeyColumn: string);
begin
  inherited Create;
  FForeignKeyColumn := AForeignKeyColumn;
end;

{ WABaseORMTableAttribute }

constructor WABaseORMTableAttribute.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
end;

{ WABaseORMColumnAttribute }

constructor WABaseORMColumnAttribute.Create(const AName: string; AIsPK: Boolean; AIsAutoInc: Boolean);
begin
  inherited Create;
  FName := AName;
  FIsPK := AIsPK;
  FIsAutoInc := AIsAutoInc;
end;

end.
