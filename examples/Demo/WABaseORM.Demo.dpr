program WABaseORM.Demo;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  WABaseORM.DB.Interfaces,
  WABaseORM.FireDAC.ConnectionFactory,
  WABaseORM.Repository,
  WABaseORM.UnitOfWork,
  system.generics.collections,
  Model.Cliente in 'Model.Cliente.pas';
procedure DemoCRUDBasico;
var
  Conn: IWABaseORMConnection;
  Repo: TWABaseORMRepository<TCliente>;
  Cliente: TCliente;
  Lista: TArray<TCliente>;
  Todos: TObjectList<TCliente>;

begin
  // Troque pelos dados reais do seu banco.
  Conn := TWABaseORMConnectionFactory.CreateFirebird('localhost', '.\teste.FDB', 'SYSDBA', 'masterkey');
  Conn.Connect;
  try
    Repo := TWABaseORMRepository<TCliente>.Create(Conn);
    try
      Cliente := TCliente.Create;
      try
        cliente.Id := 7;
        Cliente.Nome := 'João';
        Cliente.Email := 'joao@teste.com';
        Repo.Insert(Cliente);
        Writeln('Cliente inserido!');
      finally
        Cliente.Free;
      end;

      Todos := Repo.FindAll;
      try
        Writeln(Format('Total de clientes: %d', [Todos.Count]));
      finally
        Todos.Free;
      end;
    finally
      Repo.Free;
    end;
  finally
    Conn.Disconnect;
  end;
end;

procedure DemoUnitOfWork;
var
  Conn: IWABaseORMConnection;
  UoW: TWABaseORMUnitOfWork;
  Repo: TWABaseORMRepository<TCliente>;
  ClienteNovo: TCliente;
begin
  Conn := TWABaseORMConnectionFactory.CreateFirebird('localhost', '.\teste.FDB', 'SYSDBA', 'masterkey');
  Conn.Connect;
  try
    Repo := TWABaseORMRepository<TCliente>.Create(Conn);
    try
      UoW := TWABaseORMUnitOfWork.Create(Conn);
      try
        // Registra como cada classe deve ser persistida ao dar Commit.
        UoW.RegisterPersister(TCliente,
          procedure(AConnection: IWABaseORMConnection; AObj: TObject; AAction: TWABaseORMEntityAction)
          begin
            case AAction of
              eaInsert: Repo.Insert(TCliente(AObj));
              eaUpdate: Repo.Update(TCliente(AObj));
              eaDelete: Repo.Delete(TCliente(AObj).Id);
            end;
          end);

        ClienteNovo := TCliente.Create;
        try
          ClienteNovo.Nome := 'Maria';
          ClienteNovo.Email := 'maria@teste.com';
          UoW.RegisterNew(ClienteNovo);

          UoW.Commit; // uma única transação para todas as operações registradas
          Writeln('Unit of Work concluída com sucesso!');
        finally
          ClienteNovo.Free;
        end;
      finally
        UoW.Free;
      end;
    finally
      Repo.Free;
    end;
  finally
    Conn.Disconnect;
  end;
end;

begin
  try
    DemoCRUDBasico;
    DemoUnitOfWork;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

  Writeln('Pressione <Enter> para sair...');
  Readln;
end.
