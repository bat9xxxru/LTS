#include <sourcemod>
#include <lvl_ranks>
#include <shop>

public Plugin myinfo = { 
    name = "LTS", 
    discription = "Levels Ranks for Shop Integration",
    author = "bat9xxx", 
    version = "1.0", 
    url = "github.com/bat9xxxru"
}

Database _database;

KeyValues _collection;

char _table[64];

public void OnPluginStart(){
    if(LR_IsLoaded()) LR_OnCoreIsReady();

    RegAdminCmd("lts_reload", CommadReload, ADMFLAG_ROOT | ADMFLAG_RCON | ADMFLAG_CONFIG);

    LoadTranslations(GetEngineVersion() == Engine_SourceSDK2006 ? "lts_old.phrases" : "lts.phrases");
}

public void LR_OnCoreIsReady(){
    LR_GetTableName(_table, 64);

    if(!(_database = LR_GetDatabase())) SetFailState("Could not connect to the database");

    char query[128];

    _database.Format(query, 128, "ALTER TABLE `%s` ADD `lastrank` INTEGER DEFAULT 0", _table);
    
    SQL_LockDatabase(_database);
    SQL_FastQuery(_database, query);
    SQL_UnlockDatabase(_database);
}

public Action CommandReload(int client, int args){
    OnMapStart();
    
    return Plugin_Handled;
}

public void OnMapStart(){
    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, PLATFORM_MAX_PATH, "configs/levels_ranks/lts.ini");

    if(_collection != null) delete _collection;

    _collection = new KeyValues("LTS");

    if(!_collection.ImportFromFile(path)) SetFailState("File is not found (%s)", path);
}