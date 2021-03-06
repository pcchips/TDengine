//lemon parser file to generate sql parse by using finite-state-machine code used to parse sql
//usage: lemon sql.y
%token_prefix TK_

%token_type {SStrToken}
%default_type {SStrToken}
%extra_argument {SSqlInfo* pInfo}

%fallback ID BOOL TINYINT SMALLINT INTEGER BIGINT FLOAT DOUBLE STRING TIMESTAMP BINARY NCHAR.

%left OR.
%left AND.
%right NOT.
%left EQ NE ISNULL NOTNULL IS LIKE GLOB BETWEEN IN.
%left GT GE LT LE.
%left BITAND BITOR LSHIFT RSHIFT.
%left PLUS MINUS.
%left DIVIDE TIMES.
%left STAR SLASH REM.
%left CONCAT.
%right UMINUS UPLUS BITNOT.

%include {
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <stdbool.h>
#include "qSqlparser.h"
#include "tcmdtype.h"
#include "tstoken.h"
#include "ttokendef.h"
#include "tutil.h"
#include "tvariant.h"
}

%syntax_error {
  pInfo->valid = false;
  int32_t outputBufLen = tListLen(pInfo->pzErrMsg);
  int32_t len = 0;

  if(TOKEN.z) {
    char msg[] = "syntax error near \"%s\"";
    int32_t sqlLen = strlen(&TOKEN.z[0]);

    if (sqlLen + sizeof(msg)/sizeof(msg[0]) + 1 > outputBufLen) {
        char tmpstr[128] = {0};
        memcpy(tmpstr, &TOKEN.z[0], sizeof(tmpstr)/sizeof(tmpstr[0]) - 1);
        len = sprintf(pInfo->pzErrMsg, msg, tmpstr);
    } else {
        len = sprintf(pInfo->pzErrMsg, msg, &TOKEN.z[0]);
    }

  } else {
    len = sprintf(pInfo->pzErrMsg, "Incomplete SQL statement");
  }

  assert(len <= outputBufLen);
}

%parse_accept       {}

program ::= cmd.    {}

//////////////////////////////////THE SHOW STATEMENT///////////////////////////////////////////
cmd ::= SHOW DATABASES.  { setShowOptions(pInfo, TSDB_MGMT_TABLE_DB, 0, 0);}
cmd ::= SHOW MNODES.     { setShowOptions(pInfo, TSDB_MGMT_TABLE_MNODE, 0, 0);}
cmd ::= SHOW DNODES.     { setShowOptions(pInfo, TSDB_MGMT_TABLE_DNODE, 0, 0);}
cmd ::= SHOW ACCOUNTS.   { setShowOptions(pInfo, TSDB_MGMT_TABLE_ACCT, 0, 0);}
cmd ::= SHOW USERS.      { setShowOptions(pInfo, TSDB_MGMT_TABLE_USER, 0, 0);}

cmd ::= SHOW MODULES.    { setShowOptions(pInfo, TSDB_MGMT_TABLE_MODULE, 0, 0);  }
cmd ::= SHOW QUERIES.    { setShowOptions(pInfo, TSDB_MGMT_TABLE_QUERIES, 0, 0);  }
cmd ::= SHOW CONNECTIONS.{ setShowOptions(pInfo, TSDB_MGMT_TABLE_CONNS, 0, 0);}
cmd ::= SHOW STREAMS.    { setShowOptions(pInfo, TSDB_MGMT_TABLE_STREAMS, 0, 0);  }
cmd ::= SHOW VARIABLES.  { setShowOptions(pInfo, TSDB_MGMT_TABLE_VARIABLES, 0, 0);  }
cmd ::= SHOW SCORES.     { setShowOptions(pInfo, TSDB_MGMT_TABLE_SCORES, 0, 0);   }
cmd ::= SHOW GRANTS.     { setShowOptions(pInfo, TSDB_MGMT_TABLE_GRANTS, 0, 0);   }

cmd ::= SHOW VNODES.                { setShowOptions(pInfo, TSDB_MGMT_TABLE_VNODES, 0, 0); }
cmd ::= SHOW VNODES IPTOKEN(X).     { setShowOptions(pInfo, TSDB_MGMT_TABLE_VNODES, &X, 0); }


%type dbPrefix {SStrToken}
dbPrefix(A) ::=.                   {A.n = 0; A.type = 0;}
dbPrefix(A) ::= ids(X) DOT.        {A = X;  }

%type cpxName {SStrToken}
cpxName(A) ::= .             {A.n = 0;  }
cpxName(A) ::= DOT ids(Y).   {A = Y; A.n += 1;    }

cmd ::= SHOW CREATE TABLE ids(X) cpxName(Y).    {
   X.n += Y.n;
   setDCLSQLElems(pInfo, TSDB_SQL_SHOW_CREATE_TABLE, 1, &X);
}    

cmd ::= SHOW CREATE DATABASE ids(X). {
  setDCLSQLElems(pInfo, TSDB_SQL_SHOW_CREATE_DATABASE, 1, &X);
} 

cmd ::= SHOW dbPrefix(X) TABLES.         {
    setShowOptions(pInfo, TSDB_MGMT_TABLE_TABLE, &X, 0);
}

cmd ::= SHOW dbPrefix(X) TABLES LIKE ids(Y).         {
    setShowOptions(pInfo, TSDB_MGMT_TABLE_TABLE, &X, &Y);
}

cmd ::= SHOW dbPrefix(X) STABLES.      {
    setShowOptions(pInfo, TSDB_MGMT_TABLE_METRIC, &X, 0);
}

cmd ::= SHOW dbPrefix(X) STABLES LIKE ids(Y).      {
    SStrToken token;
    setDBName(&token, &X);
    setShowOptions(pInfo, TSDB_MGMT_TABLE_METRIC, &token, &Y);
}

cmd ::= SHOW dbPrefix(X) VGROUPS.    {
    SStrToken token;
    setDBName(&token, &X);
    setShowOptions(pInfo, TSDB_MGMT_TABLE_VGROUP, &token, 0);
}

cmd ::= SHOW dbPrefix(X) VGROUPS ids(Y).    {
    SStrToken token;
    setDBName(&token, &X);    
    setShowOptions(pInfo, TSDB_MGMT_TABLE_VGROUP, &token, &Y);
}

//drop configure for tables
cmd ::= DROP TABLE ifexists(Y) ids(X) cpxName(Z).   {
    X.n += Z.n;
    setDropDBTableInfo(pInfo, TSDB_SQL_DROP_TABLE, &X, &Y);
}

cmd ::= DROP DATABASE ifexists(Y) ids(X).    { setDropDBTableInfo(pInfo, TSDB_SQL_DROP_DB, &X, &Y); }
cmd ::= DROP DNODE ids(X).       { setDCLSQLElems(pInfo, TSDB_SQL_DROP_DNODE, 1, &X);    }
cmd ::= DROP USER ids(X).        { setDCLSQLElems(pInfo, TSDB_SQL_DROP_USER, 1, &X);     }
cmd ::= DROP ACCOUNT ids(X).     { setDCLSQLElems(pInfo, TSDB_SQL_DROP_ACCT, 1, &X);  }

/////////////////////////////////THE USE STATEMENT//////////////////////////////////////////
cmd ::= USE ids(X).              { setDCLSQLElems(pInfo, TSDB_SQL_USE_DB, 1, &X);}

/////////////////////////////////THE DESCRIBE STATEMENT/////////////////////////////////////
cmd ::= DESCRIBE ids(X) cpxName(Y). {
    X.n += Y.n;
    setDCLSQLElems(pInfo, TSDB_SQL_DESCRIBE_TABLE, 1, &X);
}

/////////////////////////////////THE ALTER STATEMENT////////////////////////////////////////
cmd ::= ALTER USER ids(X) PASS ids(Y).          { setAlterUserSQL(pInfo, TSDB_ALTER_USER_PASSWD, &X, &Y, NULL);    }
cmd ::= ALTER USER ids(X) PRIVILEGE ids(Y).     { setAlterUserSQL(pInfo, TSDB_ALTER_USER_PRIVILEGES, &X, NULL, &Y);}
cmd ::= ALTER DNODE ids(X) ids(Y).              { setDCLSQLElems(pInfo, TSDB_SQL_CFG_DNODE, 2, &X, &Y);          }
cmd ::= ALTER DNODE ids(X) ids(Y) ids(Z).       { setDCLSQLElems(pInfo, TSDB_SQL_CFG_DNODE, 3, &X, &Y, &Z);      }
cmd ::= ALTER LOCAL ids(X).                     { setDCLSQLElems(pInfo, TSDB_SQL_CFG_LOCAL, 1, &X);              }
cmd ::= ALTER LOCAL ids(X) ids(Y).              { setDCLSQLElems(pInfo, TSDB_SQL_CFG_LOCAL, 2, &X, &Y);          }
cmd ::= ALTER DATABASE ids(X) alter_db_optr(Y). { SStrToken t = {0};  setCreateDBSQL(pInfo, TSDB_SQL_ALTER_DB, &X, &Y, &t);}

cmd ::= ALTER ACCOUNT ids(X) acct_optr(Z).      { setCreateAcctSQL(pInfo, TSDB_SQL_ALTER_ACCT, &X, NULL, &Z);}
cmd ::= ALTER ACCOUNT ids(X) PASS ids(Y) acct_optr(Z).      { setCreateAcctSQL(pInfo, TSDB_SQL_ALTER_ACCT, &X, &Y, &Z);}

// An IDENTIFIER can be a generic identifier, or one of several keywords.
// Any non-standard keyword can also be an identifier.
// And "ids" is an identifer-or-string.
%type ids {SStrToken}
ids(A) ::= ID(X).        {A = X; }
ids(A) ::= STRING(X).    {A = X; }

%type ifexists {SStrToken}
ifexists(X) ::= IF EXISTS.          {X.n = 1;}
ifexists(X) ::= .                   {X.n = 0;}

%type ifnotexists {SStrToken}
ifnotexists(X) ::= IF NOT EXISTS.   {X.n = 1;}
ifnotexists(X) ::= .                {X.n = 0;}

/////////////////////////////////THE CREATE STATEMENT///////////////////////////////////////
//create option for dnode/db/user/account
cmd ::= CREATE DNODE   ids(X).     { setDCLSQLElems(pInfo, TSDB_SQL_CREATE_DNODE, 1, &X);}
cmd ::= CREATE ACCOUNT ids(X) PASS ids(Y) acct_optr(Z).
                                { setCreateAcctSQL(pInfo, TSDB_SQL_CREATE_ACCT, &X, &Y, &Z);}
cmd ::= CREATE DATABASE ifnotexists(Z) ids(X) db_optr(Y).  { setCreateDBSQL(pInfo, TSDB_SQL_CREATE_DB, &X, &Y, &Z);}
cmd ::= CREATE USER ids(X) PASS ids(Y).     { setCreateUserSQL(pInfo, &X, &Y);}

pps(Y) ::= .                                {Y.n = 0;   }
pps(Y) ::= PPS INTEGER(X).                  {Y = X;     }

tseries(Y) ::= .                            {Y.n = 0;   }
tseries(Y) ::= TSERIES INTEGER(X).          {Y = X;     }

dbs(Y) ::= .                                {Y.n = 0;   }
dbs(Y) ::= DBS INTEGER(X).                  {Y = X;     }

streams(Y) ::= .                            {Y.n = 0;   }
streams(Y) ::= STREAMS INTEGER(X).          {Y = X;     }

storage(Y) ::= .                            {Y.n = 0;   }
storage(Y) ::= STORAGE INTEGER(X).          {Y = X;     }

qtime(Y) ::= .                              {Y.n = 0;   }
qtime(Y) ::= QTIME INTEGER(X).              {Y = X;     }

users(Y) ::= .                              {Y.n = 0;   }
users(Y) ::= USERS INTEGER(X).              {Y = X;     }

conns(Y) ::= .                              {Y.n = 0;   }
conns(Y) ::= CONNS INTEGER(X).              {Y = X;     }

state(Y) ::= .                              {Y.n = 0;   }
state(Y) ::= STATE ids(X).                  {Y = X;     }

%type acct_optr {SCreateAcctSQL}
acct_optr(Y) ::= pps(C) tseries(D) storage(P) streams(F) qtime(Q) dbs(E) users(K) conns(L) state(M). {
    Y.maxUsers   = (K.n>0)?atoi(K.z):-1;
    Y.maxDbs     = (E.n>0)?atoi(E.z):-1;
    Y.maxTimeSeries = (D.n>0)?atoi(D.z):-1;
    Y.maxStreams = (F.n>0)?atoi(F.z):-1;
    Y.maxPointsPerSecond     = (C.n>0)?atoi(C.z):-1;
    Y.maxStorage = (P.n>0)?strtoll(P.z, NULL, 10):-1;
    Y.maxQueryTime   = (Q.n>0)?strtoll(Q.z, NULL, 10):-1;
    Y.maxConnections   = (L.n>0)?atoi(L.z):-1;
    Y.stat    = M;
}

%type keep {tVariantList*}
%destructor keep {tVariantListDestroy($$);}
keep(Y)    ::= KEEP tagitemlist(X).           { Y = X; }

cache(Y)   ::= CACHE INTEGER(X).              { Y = X; }
replica(Y) ::= REPLICA INTEGER(X).            { Y = X; }
quorum(Y)  ::= QUORUM INTEGER(X).             { Y = X; }
days(Y)    ::= DAYS INTEGER(X).               { Y = X; }
minrows(Y) ::= MINROWS INTEGER(X).            { Y = X; }
maxrows(Y) ::= MAXROWS INTEGER(X).            { Y = X; }
blocks(Y)  ::= BLOCKS INTEGER(X).             { Y = X; }
ctime(Y)   ::= CTIME INTEGER(X).              { Y = X; }
wal(Y)     ::= WAL INTEGER(X).                { Y = X; }
fsync(Y)   ::= FSYNC INTEGER(X).              { Y = X; }
comp(Y)    ::= COMP INTEGER(X).               { Y = X; }
prec(Y)    ::= PRECISION STRING(X).           { Y = X; }

%type db_optr {SCreateDBInfo}
db_optr(Y) ::= . {setDefaultCreateDbOption(&Y);}

db_optr(Y) ::= db_optr(Z) cache(X).          { Y = Z; Y.cacheBlockSize = strtol(X.z, NULL, 10); }
db_optr(Y) ::= db_optr(Z) replica(X).        { Y = Z; Y.replica = strtol(X.z, NULL, 10); }
db_optr(Y) ::= db_optr(Z) quorum(X).         { Y = Z; Y.quorum = strtol(X.z, NULL, 10); }
db_optr(Y) ::= db_optr(Z) days(X).           { Y = Z; Y.daysPerFile = strtol(X.z, NULL, 10); }
db_optr(Y) ::= db_optr(Z) minrows(X).        { Y = Z; Y.minRowsPerBlock = strtod(X.z, NULL); }
db_optr(Y) ::= db_optr(Z) maxrows(X).        { Y = Z; Y.maxRowsPerBlock = strtod(X.z, NULL); }
db_optr(Y) ::= db_optr(Z) blocks(X).         { Y = Z; Y.numOfBlocks = strtol(X.z, NULL, 10); }
db_optr(Y) ::= db_optr(Z) ctime(X).          { Y = Z; Y.commitTime = strtol(X.z, NULL, 10); }
db_optr(Y) ::= db_optr(Z) wal(X).            { Y = Z; Y.walLevel = strtol(X.z, NULL, 10); }
db_optr(Y) ::= db_optr(Z) fsync(X).          { Y = Z; Y.fsyncPeriod = strtol(X.z, NULL, 10); }
db_optr(Y) ::= db_optr(Z) comp(X).           { Y = Z; Y.compressionLevel = strtol(X.z, NULL, 10); }
db_optr(Y) ::= db_optr(Z) prec(X).           { Y = Z; Y.precision = X; }
db_optr(Y) ::= db_optr(Z) keep(X).           { Y = Z; Y.keep = X; }

%type alter_db_optr {SCreateDBInfo}
alter_db_optr(Y) ::= . { setDefaultCreateDbOption(&Y);}

alter_db_optr(Y) ::= alter_db_optr(Z) replica(X).     { Y = Z; Y.replica = strtol(X.z, NULL, 10); }
alter_db_optr(Y) ::= alter_db_optr(Z) quorum(X).      { Y = Z; Y.quorum = strtol(X.z, NULL, 10); }
alter_db_optr(Y) ::= alter_db_optr(Z) keep(X).        { Y = Z; Y.keep = X; }
alter_db_optr(Y) ::= alter_db_optr(Z) blocks(X).      { Y = Z; Y.numOfBlocks = strtol(X.z, NULL, 10); }
alter_db_optr(Y) ::= alter_db_optr(Z) comp(X).        { Y = Z; Y.compressionLevel = strtol(X.z, NULL, 10); }
alter_db_optr(Y) ::= alter_db_optr(Z) wal(X).         { Y = Z; Y.walLevel = strtol(X.z, NULL, 10); }
alter_db_optr(Y) ::= alter_db_optr(Z) fsync(X).       { Y = Z; Y.fsyncPeriod = strtol(X.z, NULL, 10); }

%type typename {TAOS_FIELD}
typename(A) ::= ids(X). { 
  X.type = 0;
  tSQLSetColumnType (&A, &X); 
}

//define binary type, e.g., binary(10), nchar(10)
typename(A) ::= ids(X) LP signed(Y) RP.    {
    if (Y <= 0) {
      X.type = 0;
      tSQLSetColumnType(&A, &X);
    } else {
      X.type = -Y;          // negative value of name length
      tSQLSetColumnType(&A, &X);
    }
}

%type signed {int64_t}
signed(A) ::= INTEGER(X).         { A = strtol(X.z, NULL, 10); }
signed(A) ::= PLUS INTEGER(X).    { A = strtol(X.z, NULL, 10); }
signed(A) ::= MINUS INTEGER(X).   { A = -strtol(X.z, NULL, 10);}

////////////////////////////////// The CREATE TABLE statement ///////////////////////////////
cmd ::= CREATE TABLE ifnotexists(Y) ids(X) cpxName(Z) create_table_args.  {
    X.n += Z.n;
    setCreatedTableName(pInfo, &X, &Y);
}

%type create_table_args{SCreateTableSQL*}
create_table_args(A) ::= LP columnlist(X) RP. {
    A = tSetCreateSQLElems(X, NULL, NULL, NULL, NULL, TSQL_CREATE_TABLE);
    setSQLInfo(pInfo, A, NULL, TSDB_SQL_CREATE_TABLE);
}

// create super table
create_table_args(A) ::= LP columnlist(X) RP TAGS LP columnlist(Y) RP. {
    A = tSetCreateSQLElems(X, Y, NULL, NULL, NULL, TSQL_CREATE_STABLE);
    setSQLInfo(pInfo, A, NULL, TSDB_SQL_CREATE_TABLE);
}

// create table by using super table
// create table table_name using super_table_name tags(tag_values1, tag_values2)
create_table_args(A) ::= USING ids(X) cpxName(F) TAGS LP tagitemlist(Y) RP.  {
    X.n += F.n;
    A = tSetCreateSQLElems(NULL, NULL, &X, Y, NULL, TSQL_CREATE_TABLE_FROM_STABLE);
    setSQLInfo(pInfo, A, NULL, TSDB_SQL_CREATE_TABLE);
}

// create stream
// create table table_name as select count(*) from super_table_name interval(time)
create_table_args(A) ::= AS select(S). {
    A = tSetCreateSQLElems(NULL, NULL, NULL, NULL, S, TSQL_CREATE_STREAM);
    setSQLInfo(pInfo, A, NULL, TSDB_SQL_CREATE_TABLE);
}

%type column{TAOS_FIELD}
%type columnlist{tFieldList*}
%destructor columnlist {tFieldListDestroy($$);}
columnlist(A) ::= columnlist(X) COMMA column(Y).  {A = tFieldListAppend(X, &Y);   }
columnlist(A) ::= column(X).                      {A = tFieldListAppend(NULL, &X);}

// The information used for a column is the name and type of column:
// tinyint smallint int bigint float double bool timestamp binary(x) nchar(x)
column(A) ::= ids(X) typename(Y).          {
    tSQLSetColumnInfo(&A, &X, &Y);
}

%type tagitemlist {tVariantList*}
%destructor tagitemlist {tVariantListDestroy($$);}

%type tagitem {tVariant}
tagitemlist(A) ::= tagitemlist(X) COMMA tagitem(Y). { A = tVariantListAppend(X, &Y, -1);    }
tagitemlist(A) ::= tagitem(X).                      { A = tVariantListAppend(NULL, &X, -1); }

tagitem(A) ::= INTEGER(X).      {toTSDBType(X.type); tVariantCreate(&A, &X); }
tagitem(A) ::= FLOAT(X).        {toTSDBType(X.type); tVariantCreate(&A, &X); }
tagitem(A) ::= STRING(X).       {toTSDBType(X.type); tVariantCreate(&A, &X); }
tagitem(A) ::= BOOL(X).         {toTSDBType(X.type); tVariantCreate(&A, &X); }
tagitem(A) ::= NULL(X).         { X.type = 0; tVariantCreate(&A, &X); }

tagitem(A) ::= MINUS(X) INTEGER(Y).{
    X.n += Y.n;
    X.type = Y.type;
    toTSDBType(X.type);
    tVariantCreate(&A, &X);
}

tagitem(A) ::= MINUS(X) FLOAT(Y).  {
    X.n += Y.n;
    X.type = Y.type;
    toTSDBType(X.type);
    tVariantCreate(&A, &X);
}

tagitem(A) ::= PLUS(X) INTEGER(Y). {
    X.n += Y.n;
    X.type = Y.type;
    toTSDBType(X.type);
    tVariantCreate(&A, &X);
}

tagitem(A) ::= PLUS(X) FLOAT(Y).  {
    X.n += Y.n;
    X.type = Y.type;
    toTSDBType(X.type);
    tVariantCreate(&A, &X);
}

//////////////////////// The SELECT statement /////////////////////////////////
%type select {SQuerySQL*}
%destructor select {doDestroyQuerySql($$);}
select(A) ::= SELECT(T) selcollist(W) from(X) where_opt(Y) interval_opt(K) fill_opt(F) sliding_opt(S) groupby_opt(P) orderby_opt(Z) having_opt(N) slimit_opt(G) limit_opt(L). {
  A = tSetQuerySQLElems(&T, W, X, Y, P, Z, &K, &S, F, &L, &G);
}

%type union {SSubclauseInfo*}
%destructor union {destroyAllSelectClause($$);}

union(Y) ::= select(X). { Y = setSubclause(NULL, X); }
union(Y) ::= LP union(X) RP. { Y = X; }
union(Y) ::= union(Z) UNION ALL select(X). { Y = appendSelectClause(Z, X); }
union(Y) ::= union(Z) UNION ALL LP select(X) RP. { Y = appendSelectClause(Z, X); }

cmd ::= union(X). { setSQLInfo(pInfo, X, NULL, TSDB_SQL_SELECT); }

// Support for the SQL exprssion without from & where subclauses, e.g.,
// select current_database(),
// select server_version(), select client_version(),
// select server_state();
select(A) ::= SELECT(T) selcollist(W). {
  A = tSetQuerySQLElems(&T, W, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
}

// selcollist is a list of expressions that are to become the return
// values of the SELECT statement.  The "*" in statements like
// "SELECT * FROM ..." is encoded as a special expression with an opcode of TK_ALL.
%type selcollist {tSQLExprList*}
%destructor selcollist {tSQLExprListDestroy($$);}

%type sclp {tSQLExprList*}
%destructor sclp {tSQLExprListDestroy($$);}
sclp(A) ::= selcollist(X) COMMA.             {A = X;}
sclp(A) ::= .                                {A = 0;}
selcollist(A) ::= sclp(P) expr(X) as(Y).     {
   A = tSQLExprListAppend(P, X, Y.n?&Y:0);
}

selcollist(A) ::= sclp(P) STAR. {
   tSQLExpr *pNode = tSQLExprIdValueCreate(NULL, TK_ALL);
   A = tSQLExprListAppend(P, pNode, 0);
}

// An option "AS <id>" phrase that can follow one of the expressions that
// define the result set, or one of the tables in the FROM clause.
//
%type as {SStrToken}
as(X) ::= AS ids(Y).    { X = Y;    }
as(X) ::= ids(Y).       { X = Y;    }
as(X) ::= .             { X.n = 0;  }

// A complete FROM clause.
%type from {tVariantList*}
// current not support query from no-table
from(A) ::= FROM tablelist(X).                 {A = X;}

%type tablelist {tVariantList*}
tablelist(A) ::= ids(X) cpxName(Y).                     {
  toTSDBType(X.type);
  X.n += Y.n;
  A = tVariantListAppendToken(NULL, &X, -1);
  A = tVariantListAppendToken(A, &X, -1);  // table alias name
}

tablelist(A) ::= ids(X) cpxName(Y) ids(Z).             {
   toTSDBType(X.type);
   toTSDBType(Z.type);
   X.n += Y.n;
   A = tVariantListAppendToken(NULL, &X, -1);
   A = tVariantListAppendToken(A, &Z, -1);
}

tablelist(A) ::= tablelist(Y) COMMA ids(X) cpxName(Z).  {
  toTSDBType(X.type);
  X.n += Z.n;
  A = tVariantListAppendToken(Y, &X, -1);
  A = tVariantListAppendToken(A, &X, -1);
}

tablelist(A) ::= tablelist(Y) COMMA ids(X) cpxName(Z) ids(F). {
   toTSDBType(X.type);
   toTSDBType(F.type);
   X.n += Z.n;
   A = tVariantListAppendToken(Y, &X, -1);
   A = tVariantListAppendToken(A, &F, -1);
}

// The value of interval should be the form of "number+[a,s,m,h,d,n,y]" or "now"
%type tmvar {SStrToken}
tmvar(A) ::= VARIABLE(X).   {A = X;}

%type interval_opt {SIntervalVal}
interval_opt(N) ::= INTERVAL LP tmvar(E) RP.    {N.interval = E; N.offset.n = 0; N.offset.z = NULL; N.offset.type = 0;}
interval_opt(N) ::= INTERVAL LP tmvar(E) COMMA tmvar(O) RP.    {N.interval = E; N.offset = O;}
interval_opt(N) ::= .                           {memset(&N, 0, sizeof(N));}

%type fill_opt {tVariantList*}
%destructor fill_opt {tVariantListDestroy($$);}
fill_opt(N) ::= .                               {N = 0;     }
fill_opt(N) ::= FILL LP ID(Y) COMMA tagitemlist(X) RP.      {
    tVariant A = {0};
    toTSDBType(Y.type);
    tVariantCreate(&A, &Y);

    tVariantListInsert(X, &A, -1, 0);
    N = X;
}

fill_opt(N) ::= FILL LP ID(Y) RP.               {
    toTSDBType(Y.type);
    N = tVariantListAppendToken(NULL, &Y, -1);
}

%type sliding_opt {SStrToken}
sliding_opt(K) ::= SLIDING LP tmvar(E) RP.      {K = E;     }
sliding_opt(K) ::= .                            {K.n = 0; K.z = NULL; K.type = 0;   }

%type orderby_opt {tVariantList*}
%destructor orderby_opt {tVariantListDestroy($$);}

%type sortlist {tVariantList*}
%destructor sortlist {tVariantListDestroy($$);}

%type sortitem {tVariant}
%destructor sortitem {tVariantDestroy(&$$);}

orderby_opt(A) ::= .                          {A = 0;}
orderby_opt(A) ::= ORDER BY sortlist(X).      {A = X;}

sortlist(A) ::= sortlist(X) COMMA item(Y) sortorder(Z). {
    A = tVariantListAppend(X, &Y, Z);
}

sortlist(A) ::= item(Y) sortorder(Z). {
  A = tVariantListAppend(NULL, &Y, Z);
}

%type item {tVariant}
item(A) ::= ids(X) cpxName(Y).   {
  toTSDBType(X.type);
  X.n += Y.n;

  tVariantCreate(&A, &X);
}

%type sortorder {int}
sortorder(A) ::= ASC.           {A = TSDB_ORDER_ASC; }
sortorder(A) ::= DESC.          {A = TSDB_ORDER_DESC;}
sortorder(A) ::= .              {A = TSDB_ORDER_ASC;}  //default is descend order

//group by clause
%type groupby_opt {tVariantList*}
%destructor groupby_opt {tVariantListDestroy($$);}
%type grouplist {tVariantList*}
%destructor grouplist {tVariantListDestroy($$);}

groupby_opt(A) ::= .                       {A = 0;}
groupby_opt(A) ::= GROUP BY grouplist(X).  {A = X;}

grouplist(A) ::= grouplist(X) COMMA item(Y).    {
  A = tVariantListAppend(X, &Y, -1);
}

grouplist(A) ::= item(X).                       {
  A = tVariantListAppend(NULL, &X, -1);
}

//having clause, ignore the input condition in having
%type having_opt {tSQLExpr*}
%destructor having_opt {tSQLExprDestroy($$);}
having_opt(A) ::=.                  {A = 0;}
having_opt(A) ::= HAVING expr(X).   {A = X;}

//limit-offset subclause
%type limit_opt {SLimitVal}
limit_opt(A) ::= .                     {A.limit = -1; A.offset = 0;}
limit_opt(A) ::= LIMIT signed(X).      {A.limit = X;  A.offset = 0;}
limit_opt(A) ::= LIMIT signed(X) OFFSET signed(Y).
                                       {A.limit = X;  A.offset = Y;}
limit_opt(A) ::= LIMIT signed(X) COMMA signed(Y).
                                       {A.limit = Y;  A.offset = X;}

%type slimit_opt {SLimitVal}
slimit_opt(A) ::= .                    {A.limit = -1; A.offset = 0;}
slimit_opt(A) ::= SLIMIT signed(X).    {A.limit = X;  A.offset = 0;}
slimit_opt(A) ::= SLIMIT signed(X) SOFFSET signed(Y).
                                       {A.limit = X;  A.offset = Y;}
slimit_opt(A) ::= SLIMIT signed(X) COMMA  signed(Y).
                                       {A.limit = Y;  A.offset = X;}

%type where_opt {tSQLExpr*}
%destructor where_opt {tSQLExprDestroy($$);}

where_opt(A) ::= .                    {A = 0;}
where_opt(A) ::= WHERE expr(X).       {A = X;}

/////////////////////////// Expression Processing /////////////////////////////
//
%type expr {tSQLExpr*}
%destructor expr {tSQLExprDestroy($$);}

expr(A) ::= LP expr(X) RP.       {A = X; }

expr(A) ::= ID(X).               {A = tSQLExprIdValueCreate(&X, TK_ID);}
expr(A) ::= ID(X) DOT ID(Y).     {X.n += (1+Y.n); A = tSQLExprIdValueCreate(&X, TK_ID);}
expr(A) ::= ID(X) DOT STAR(Y).   {X.n += (1+Y.n); A = tSQLExprIdValueCreate(&X, TK_ALL);}

expr(A) ::= INTEGER(X).          {A = tSQLExprIdValueCreate(&X, TK_INTEGER);}
expr(A) ::= MINUS(X) INTEGER(Y). {X.n += Y.n; X.type = TK_INTEGER; A = tSQLExprIdValueCreate(&X, TK_INTEGER);}
expr(A) ::= PLUS(X)  INTEGER(Y). {X.n += Y.n; X.type = TK_INTEGER; A = tSQLExprIdValueCreate(&X, TK_INTEGER);}
expr(A) ::= FLOAT(X).            {A = tSQLExprIdValueCreate(&X, TK_FLOAT);}
expr(A) ::= MINUS(X) FLOAT(Y).   {X.n += Y.n; X.type = TK_FLOAT; A = tSQLExprIdValueCreate(&X, TK_FLOAT);}
expr(A) ::= PLUS(X) FLOAT(Y).    {X.n += Y.n; X.type = TK_FLOAT; A = tSQLExprIdValueCreate(&X, TK_FLOAT);}
expr(A) ::= STRING(X).           {A = tSQLExprIdValueCreate(&X, TK_STRING);}
expr(A) ::= NOW(X).              {A = tSQLExprIdValueCreate(&X, TK_NOW); }
expr(A) ::= VARIABLE(X).         {A = tSQLExprIdValueCreate(&X, TK_VARIABLE);}
expr(A) ::= BOOL(X).             {A = tSQLExprIdValueCreate(&X, TK_BOOL);}

// ordinary functions: min(x), max(x), top(k, 20)
expr(A) ::= ID(X) LP exprlist(Y) RP(E). { A = tSQLExprCreateFunction(Y, &X, &E, X.type); }

// for parsing sql functions with wildcard for parameters. e.g., count(*)/first(*)/last(*) operation
expr(A) ::= ID(X) LP STAR RP(Y).     { A = tSQLExprCreateFunction(NULL, &X, &Y, X.type); }

// is (not) null expression
expr(A) ::= expr(X) IS NULL.           {A = tSQLExprCreate(X, NULL, TK_ISNULL);}
expr(A) ::= expr(X) IS NOT NULL.       {A = tSQLExprCreate(X, NULL, TK_NOTNULL);}

// relational expression
expr(A) ::= expr(X) LT expr(Y).      {A = tSQLExprCreate(X, Y, TK_LT);}
expr(A) ::= expr(X) GT expr(Y).      {A = tSQLExprCreate(X, Y, TK_GT);}
expr(A) ::= expr(X) LE expr(Y).      {A = tSQLExprCreate(X, Y, TK_LE);}
expr(A) ::= expr(X) GE expr(Y).      {A = tSQLExprCreate(X, Y, TK_GE);}
expr(A) ::= expr(X) NE expr(Y).      {A = tSQLExprCreate(X, Y, TK_NE);}
expr(A) ::= expr(X) EQ expr(Y).      {A = tSQLExprCreate(X, Y, TK_EQ);}

expr(A) ::= expr(X) AND expr(Y).     {A = tSQLExprCreate(X, Y, TK_AND);}
expr(A) ::= expr(X) OR  expr(Y).     {A = tSQLExprCreate(X, Y, TK_OR); }

// binary arithmetic expression
expr(A) ::= expr(X) PLUS  expr(Y).   {A = tSQLExprCreate(X, Y, TK_PLUS);  }
expr(A) ::= expr(X) MINUS expr(Y).   {A = tSQLExprCreate(X, Y, TK_MINUS); }
expr(A) ::= expr(X) STAR  expr(Y).   {A = tSQLExprCreate(X, Y, TK_STAR);  }
expr(A) ::= expr(X) SLASH expr(Y).   {A = tSQLExprCreate(X, Y, TK_DIVIDE);}
expr(A) ::= expr(X) REM   expr(Y).   {A = tSQLExprCreate(X, Y, TK_REM);   }

// like expression
expr(A) ::= expr(X) LIKE expr(Y).    {A = tSQLExprCreate(X, Y, TK_LIKE);  }

//in expression
expr(A) ::= expr(X) IN LP exprlist(Y) RP.   {A = tSQLExprCreate(X, (tSQLExpr*)Y, TK_IN); }

%type exprlist {tSQLExprList*}
%destructor exprlist {tSQLExprListDestroy($$);}

%type expritem {tSQLExpr*}
%destructor expritem {tSQLExprDestroy($$);}

exprlist(A) ::= exprlist(X) COMMA expritem(Y). {A = tSQLExprListAppend(X,Y,0);}
exprlist(A) ::= expritem(X).                   {A = tSQLExprListAppend(0,X,0);}
expritem(A) ::= expr(X).                       {A = X;}
expritem(A) ::= .                              {A = 0;}

///////////////////////////////////reset query cache//////////////////////////////////////
cmd ::= RESET QUERY CACHE.  { setDCLSQLElems(pInfo, TSDB_SQL_RESET_CACHE, 0);}

///////////////////////////////////ALTER TABLE statement//////////////////////////////////
cmd ::= ALTER TABLE ids(X) cpxName(F) ADD COLUMN columnlist(A).     {
    X.n += F.n;
    SAlterTableSQL* pAlterTable = tAlterTableSQLElems(&X, A, NULL, TSDB_ALTER_TABLE_ADD_COLUMN);
    setSQLInfo(pInfo, pAlterTable, NULL, TSDB_SQL_ALTER_TABLE);
}

cmd ::= ALTER TABLE ids(X) cpxName(F) DROP COLUMN ids(A).     {
    X.n += F.n;

    toTSDBType(A.type);
    tVariantList* K = tVariantListAppendToken(NULL, &A, -1);

    SAlterTableSQL* pAlterTable = tAlterTableSQLElems(&X, NULL, K, TSDB_ALTER_TABLE_DROP_COLUMN);
    setSQLInfo(pInfo, pAlterTable, NULL, TSDB_SQL_ALTER_TABLE);
}

//////////////////////////////////ALTER TAGS statement/////////////////////////////////////
cmd ::= ALTER TABLE ids(X) cpxName(Y) ADD TAG columnlist(A).        {
    X.n += Y.n;
    SAlterTableSQL* pAlterTable = tAlterTableSQLElems(&X, A, NULL, TSDB_ALTER_TABLE_ADD_TAG_COLUMN);
    setSQLInfo(pInfo, pAlterTable, NULL, TSDB_SQL_ALTER_TABLE);
}
cmd ::= ALTER TABLE ids(X) cpxName(Z) DROP TAG ids(Y).          {
    X.n += Z.n;

    toTSDBType(Y.type);
    tVariantList* A = tVariantListAppendToken(NULL, &Y, -1);

    SAlterTableSQL* pAlterTable = tAlterTableSQLElems(&X, NULL, A, TSDB_ALTER_TABLE_DROP_TAG_COLUMN);
    setSQLInfo(pInfo, pAlterTable, NULL, TSDB_SQL_ALTER_TABLE);
}

cmd ::= ALTER TABLE ids(X) cpxName(F) CHANGE TAG ids(Y) ids(Z). {
    X.n += F.n;

    toTSDBType(Y.type);
    tVariantList* A = tVariantListAppendToken(NULL, &Y, -1);

    toTSDBType(Z.type);
    A = tVariantListAppendToken(A, &Z, -1);

    SAlterTableSQL* pAlterTable = tAlterTableSQLElems(&X, NULL, A, TSDB_ALTER_TABLE_CHANGE_TAG_COLUMN);
    setSQLInfo(pInfo, pAlterTable, NULL, TSDB_SQL_ALTER_TABLE);
}

cmd ::= ALTER TABLE ids(X) cpxName(F) SET TAG ids(Y) EQ tagitem(Z).     {
    X.n += F.n;

    toTSDBType(Y.type);
    tVariantList* A = tVariantListAppendToken(NULL, &Y, -1);
    A = tVariantListAppend(A, &Z, -1);

    SAlterTableSQL* pAlterTable = tAlterTableSQLElems(&X, NULL, A, TSDB_ALTER_TABLE_UPDATE_TAG_VAL);
    setSQLInfo(pInfo, pAlterTable, NULL, TSDB_SQL_ALTER_TABLE);
}

////////////////////////////////////////kill statement///////////////////////////////////////
cmd ::= KILL CONNECTION INTEGER(Y).   {setKillSQL(pInfo, TSDB_SQL_KILL_CONNECTION, &Y);}
cmd ::= KILL STREAM INTEGER(X) COLON(Z) INTEGER(Y).       {X.n += (Z.n + Y.n); setKillSQL(pInfo, TSDB_SQL_KILL_STREAM, &X);}
cmd ::= KILL QUERY INTEGER(X) COLON(Z) INTEGER(Y).        {X.n += (Z.n + Y.n); setKillSQL(pInfo, TSDB_SQL_KILL_QUERY, &X);}

%fallback ID ABORT AFTER ASC ATTACH BEFORE BEGIN CASCADE CLUSTER CONFLICT COPY DATABASE DEFERRED
  DELIMITERS DESC DETACH EACH END EXPLAIN FAIL FOR GLOB IGNORE IMMEDIATE INITIALLY INSTEAD
  LIKE MATCH KEY OF OFFSET RAISE REPLACE RESTRICT ROW STATEMENT TRIGGER VIEW ALL
  COUNT SUM AVG MIN MAX FIRST LAST TOP BOTTOM STDDEV PERCENTILE APERCENTILE LEASTSQUARES HISTOGRAM DIFF
  SPREAD TWA INTERP LAST_ROW RATE IRATE SUM_RATE SUM_IRATE AVG_RATE AVG_IRATE TBID NOW IPTOKEN SEMI NONE PREV LINEAR IMPORT
  METRIC TBNAME JOIN METRICS STABLE NULL INSERT INTO VALUES.
