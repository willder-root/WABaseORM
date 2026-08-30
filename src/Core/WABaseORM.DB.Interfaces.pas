unit WABaseORM.DB.Interfaces;

interface

uses
  System.SysUtils, Data.DB, System.Generics.Collections;

type
  IWABaseORMTransaction = interface
    ['{9598B7DC-80B5-4E3E-8B79-F041FE35EDAE}']
    procedure Commit;
    procedure Rollback;
  end;

  IWABaseORMQuery = interface
    ['{32D98208-FB82-4AA8-A437-B144D7A86863}']
    procedure SetSQL(const ASQL: string);
    procedure SetParam(const AName: string; const AValue: Variant); overload;
    procedure SetParam(const AName: string; const AValue: Integer); overload;
    procedure SetParam(const AName: string; const AValue: Int64); overload;
    procedure SetParam(const AName: string; const AValue: string); overload;
    procedure SetParam(const AName: string; const AValue: Double); overload;
    procedure SetParam(const AName: string; const AValue: Currency); overload;
    procedure SetParam(const AName: string; const AValue: TDateTime); overload;
    procedure SetParam(const AName: string; const AValue: Boolean); overload;
    procedure SetParam(const AName: string); overload; // define o parâmetro como NULL
    function Open: TDataSet;
    function ExecSQL: Integer; // retorna linhas afetadas
    function AsDataSet: TDataSet;
  end;

  IWABaseORMConnection = interface
    ['{1913BB88-98D2-47F8-BE58-F6A76EBD67CD}']
    procedure Connect;
    procedure Disconnect;
    function Connected: Boolean;
    function CreateQuery: IWABaseORMQuery;
    function StartTransaction: IWABaseORMTransaction;
    function InTransaction: Boolean;
  end;

implementation

end.
