#pragma tabsize 0

#include <sourcemod>

#if SOURCEMOD_V_MINOR < 10
	#error This plugin can only compile on SourceMod 1.10.
#endif

#include <lvl_ranks>
#include <shop>

/*
    Thanks to Wend4r for the help.
*/

public Plugin myinfo = { 
    name = "LTS", 
    author = "bat9xxx || Thanks to Wend4r for the help.", 
    version = "2.0", 
    url = "github.com/bat9xxxru || Discord: Wend4r#0001"
}

Database _database;

KeyValues _collection;

char _table[64];

stock char[] GetSteamID2(int iAccountID)
{
    static char sSteamID2[22] = "STEAM_";

    if(!sSteamID2[6])
    {
        sSteamID2[6] = '0' + view_as<int>(GetEngineVersion() == Engine_CSGO);
        sSteamID2[7] = ':';
    }

    FormatEx(sSteamID2[8], 14, "%i:%i", iAccountID & 1, iAccountID >>> 1);

    return sSteamID2;
}

public void Stub(Database db, DBResultSet result, const char[] error, any data){
    return;
}

public void OnPluginStart(){
    if(LR_IsLoaded()) LR_OnCoreIsReady();

    RegAdminCmd("lts_reload", CommadReload, ADMFLAG_ROOT | ADMFLAG_RCON | ADMFLAG_CONFIG);

    LoadTranslations(GetEngineVersion() == Engine_SourceSDK2006 ? "lts_old.phrases" : "lts.phrases");
}

public void LR_OnCoreIsReady(){
    LR_GetTableName(_table, 64);

    if(_database != null) delete _database;

    _database = LR_GetDatabase();

    char query[128];

    _database.Format(query, 128, "ALTER TABLE `%s` ADD `lastrank` INTEGER DEFAULT 0", _table);
    
    SQL_LockDatabase(_database);
    SQL_FastQuery(_database, query);
    SQL_UnlockDatabase(_database);

    LR_Hook(LR_OnResetPlayerStats, OnResetPlayerStats);
    LR_Hook(LR_OnLevelChangedPost, OnLevelChangedPost);
}

public Action CommadReload(int client, int args){
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

public void OnResetPlayerStats(int client, int id){
    char query[128];
    _database.Format(query, 128, "UPDATE `%s` SET `lastrank` = '0' WHERE `steam` = '%s'", _table, client ? GetSteamID2(GetSteamAccountID(client)) : GetSteamID2(id));
    _database.Query(Stub, query);
}

public void OnLevelChangedPost(int client, int newLevel, int oldLevel){
    if(newLevel > oldLevel && _database){
        char query[128];

        DataPack data = new DataPack();
        data.WriteCell(client);
        data.WriteCell(newLevel);

        _database.Format(query, 128, "SELECT `lastrank` FROM `%s` WHERE `steam` = '%s'", _table, GetSteamID2(GetSteamAccountID(client)));
        _database.Query(OnLevelChangedPostCallBack, query, data);
    }
}

public void OnLevelChangedPostCallBack(Database db, DBResultSet result, const char[] error, DataPack data){
    if(!result){
        LogError("%s", error);
        return;
    }

    data.Reset();
    _collection.Rewind();

    int client = data.ReadCell();

    if(!IsClientInGame(client)) return;

    int newLevel = data.ReadCell();

    delete data;

    if(result.HasResults && result.FetchRow()){
        char buffer[128];

        IntToString(newLevel, buffer, 128);

        if(_collection.JumpToKey(buffer)){
            int credits = _collection.GetNum("credits", 0);
            int gold = _collection.GetNum("gold", 0);

            if(credits){
                Shop_GiveClientCredits(client, credits);
                LR_PrintToChat(client, true, "%t", "OnGiveCredits");
            }

            if(gold){
                Shop_GiveClientGold(client, gold);
                LR_PrintToChat(client, true, "%t", "OnGiveGold");
            }

            if(_collection.GotoNextKey()){
                if(_collection.GetSectionName(buffer, 128)){
                    if(StrEqual(buffer, "items")){
                        while(_collection.GotoNextKey(true)){
                            _collection.GetString("category", buffer, 128);
                            CategoryId category = Shop_GetCategoryId(buffer);
                            if(category == INVALID_CATEGORY) continue;

                            _collection.GetString("item", buffer, 128);
                            ItemId item = Shop_GetItemId(category, buffer);

                            if(item == INVALID_ITEM) continue;
                            Shop_GiveClientItem(client, item);

                            _collection.GetString("title", buffer, 128, "0");

                            if(StringToInt(buffer)) LR_PrintToChat(client, true, "%t", "OnGiveItem", buffer);
                        }
                    }
                }
            }
        }

        _database.Format(buffer, 128, "UPDATE `%s` SET `lastrank` = '%i' WHERE `steam` = '%s'", _table, newLevel, GetSteamID2(GetSteamAccountID(client)));
        _database.Query(Stub, buffer);
    }
}