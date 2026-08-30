unit WABaseORM.Utils;

interface

uses
  System.SysUtils, System.Variants;

type
  TWABaseORMUtils = class
  public
    /// <summary>Escapa aspas simples para uso seguro em literais SQL (uso pontual; prefira sempre parâmetros).</summary>
    class function SanitizeLiteral(const AValue: string): string;
    /// <summary>Converte um Variant nulo/vazio em Null de banco, evitando erro de conversão.</summary>
    class function NullIfEmpty(const AValue: Variant): Variant;
    /// <summary>Monta a cláusula IN (...) a partir de uma lista de inteiros, ex: "ID IN (1,2,3)".</summary>
    class function BuildInClauseInt(const AColumn: string; const AValues: array of Integer): string;
  end;

implementation

{ TWABaseORMUtils }

class function TWABaseORMUtils.SanitizeLiteral(const AValue: string): string;
begin
  Result := StringReplace(AValue, '''', '''''', [rfReplaceAll]);
end;

class function TWABaseORMUtils.NullIfEmpty(const AValue: Variant): Variant;
begin
  if VarIsEmpty(AValue) or VarIsNull(AValue) then
    Result := Null
  else if VarIsStr(AValue) and (VarToStr(AValue) = '') then
    Result := Null
  else
    Result := AValue;
end;

class function TWABaseORMUtils.BuildInClauseInt(const AColumn: string; const AValues: array of Integer): string;
var
  Parts: TArray<string>;
  I: Integer;
begin
  if Length(AValues) = 0 then
    Exit('1 = 0'); // nenhuma condição satisfaz -> resultado vazio, evita "IN ()" inválido

  SetLength(Parts, Length(AValues));
  for I := 0 to High(AValues) do
    Parts[I] := IntToStr(AValues[I]);

  Result := Format('%s IN (%s)', [AColumn, String.Join(',', Parts)]);
end;

end.
