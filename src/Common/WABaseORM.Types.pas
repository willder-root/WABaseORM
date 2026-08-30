unit WABaseORM.Types;

interface

type
  TWABaseORMSortDirection = (sdAsc, sdDesc);

  TWABaseORMDriverType = (dtFirebird, dtMSSQL, dtPostgres, dtSQLite, dtMySQL, dtOracle);

  TWABaseORMConnectionState = (csDisconnected, csConnected, csConnecting, csError);

const
  WABaseORMDriverIdMap: array[TWABaseORMDriverType] of string = (
    'FB',       // dtFirebird
    'MSSQL',    // dtMSSQL
    'PG',       // dtPostgres
    'SQLite',   // dtSQLite
    'MySQL',    // dtMySQL
    'Ora'       // dtOracle
  );

implementation

end.
