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

implementation

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
