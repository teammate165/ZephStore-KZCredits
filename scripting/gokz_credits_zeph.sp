#include <sourcemod>
#include <colorlib>
#include <sdktools>
#include <cstrike>

#include <gokz/core>
#include <gokz/localdb>
#include <gokz/localranks>

#include <GlobalAPI-Core>

#include <store>

#include <AutoExecConfig>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.1"

int proFinished[MAXPLAYERS + 1];
int bonusFinished[MAXPLAYERS + 1];
int nubFinished[MAXPLAYERS + 1];

bool gB_KZGlobal;

char g_sTag[32];
ConVar gc_sTag;

ConVar gCV_BaseCredits;
ConVar gCV_ProMultiplier;
ConVar gCV_BonusMultiplier;
ConVar gCV_NubMultiplier;
ConVar gCV_ProMultiplierAfterCompletion;
ConVar gCV_BonusMultiplierAfterCompletion;
ConVar gCV_NubMultiplierAfterCompletion;

Database gH_DB = null;

int g_CreditsPro, g_CreditsBonus, g_CreditsNub, g_CreditsProAfterCompletion, g_CreditsBonusAfterCompletion, g_CreditsNubAfterCompletion;

float gF_BaseMultiplier;

public Plugin myinfo =
{
	name = "Zephyrus-Store: KZTimer, GOKZ",
	author = "Simon, Cruze, Caaine, Brock",
	description = "Give credits on map completion.",
	version = PLUGIN_VERSION,
	url = "yash1441@yahoo.com"
};

public void OnPluginStart() //Rework to multiplier system
{
	CreateConVars();
	
	LoadTranslations("kz_credits.phrases");
}

void CreateConVars()
{
	AutoExecConfig_SetFile("kz_credits", "sourcemod");
	AutoExecConfig_SetCreateFile(true);

	gCV_BaseCredits = AutoExecConfig_CreateConVar("sm_store_kz_base", "20", "Base credits, because this plugin uses multipliers, becareful with this value.", _, true, 0.0);
	gCV_ProMultiplier = AutoExecConfig_CreateConVar("sm_store_kz_pro", "1.5", "Credits given when a player finishes a map in Pro mode.", _, true, 0.0);
	gCV_BonusMultiplier = AutoExecConfig_CreateConVar("sm_store_kz_bonus", "0.5", "Credits given when a player finishes a bonus.", _, true, 0.0);
	gCV_NubMultiplier = AutoExecConfig_CreateConVar("sm_store_kz_nub", "1", "Credits given when a player finishes a map in TP mode.", _, true, 0.0);
	gCV_ProMultiplierAfterCompletion = AutoExecConfig_CreateConVar("sm_store_kz_pro_again", "0.7", "Credits given when a player finishes a map in Pro mode again.", _, true, 0.0);
	gCV_BonusMultiplierAfterCompletion = AutoExecConfig_CreateConVar("sm_store_kz_bonus_again", "0.5", "Credits given when a player finishes a bonus again.", _, true, 0.0);
	gCV_NubMultiplierAfterCompletion = AutoExecConfig_CreateConVar("sm_store_kz_nub_again", "0.25", "Credits given when a player finishes a map in TP mode again.", _, true, 0.0);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
}

public void OnConfigExecuted()
{
	gc_sTag = FindConVar("sm_store_chat_tag");
	gc_sTag.GetString(g_sTag, sizeof(g_sTag));
	
}

// === DB stuff ===

public void OnAllPluginsLoaded()
{
	gH_DB = GOKZ_DB_GetDatabase();

	gB_KZGlobal = LibraryExists("GlobalAPI-Core");
}

public void GOKZ_DB_OnDatabaseConnect(DatabaseType DBType)
{
	gH_DB = GOKZ_DB_GetDatabase();
}

// SQL for getting average PB time, taken from GOKZ LocalRanks plugin.
char sql_getaverage[] = "\
SELECT AVG(PBTime), COUNT(*) \
    FROM \
    (SELECT MIN(Times.RunTime) AS PBTime \
    FROM Times \
    INNER JOIN MapCourses ON Times.MapCourseID=MapCourses.MapCourseID \
    INNER JOIN Players ON Times.SteamID32=Players.SteamID32 \
    WHERE Players.Cheater=0 AND MapCourses.MapID=%d \
    AND MapCourses.Course=0 AND Times.Mode=%d \
    GROUP BY Times.SteamID32) AS PBTimes";

public void GOKZ_DB_OnMapSetup(int mapID)
{
	DB_SetMultiplier(mapID);
}

void DB_SetMultiplier(int mapID)
{
	char query[1024];
	int mode = GOKZ_GetDefaultMode();
	Transaction txn = SQL_CreateTransaction();

	FormatEx(query, sizeof(query), sql_getaverage, mapID, mode);
	txn.AddQuery(query);
	
	SQL_ExecuteTransaction(gH_DB, txn, DB_TxnSuccess_SetMultiplier, DB_TxnFailure_Generic, _, DBPrio_High);
}

void DB_TxnSuccess_SetMultiplier(Handle db, DataPack data, int numQueries, Handle[] results, any[] queryData)
{
	if (!SQL_FetchRow(results[0]))
	{
		return;
	}

	int mapCompletions = SQL_FetchInt(results[0], 1);
	if (mapCompletions < 5)
	{
		gF_BaseMultiplier = 1.5; //Maybe insert default values here
	}
	
	// DB has the times in ms. We convert it to seconds.
	int averageTime = RoundToNearest(SQL_FetchInt(results[0], 0) / 1000.0);
	
	gF_BaseMultiplier = 0.0;

	// Do some magic scaling for lower numbers:
	if (averageTime <= 60) gF_BaseMultiplier = 0.5;
	else if (averageTime <= 120) gF_BaseMultiplier = 0.6;
	else if (averageTime <= 180) gF_BaseMultiplier = 0.8;
	else if (averageTime <= 300) gF_BaseMultiplier = 1.0;
	else if (averageTime <= 600) gF_BaseMultiplier = 1.4;
	else if (averageTime <= 1200) gF_BaseMultiplier = 1.8;
	else gF_BaseMultiplier = 2.0;
    
	if (gB_KZGlobal)
	{
		int MapTier = GlobalAPI_GetMapTier();
		float TierMultiplier;
		switch (MapTier)
		{
			case 1: TierMultiplier = 0.5;
			case 2: TierMultiplier = 0.7;
			case 3: TierMultiplier = 1.0;
			case 4: TierMultiplier = 1.2;
			case 5: TierMultiplier = 1.5;
			case 6: TierMultiplier = 2.0;
			case 7: TierMultiplier = 3.0;
		}
		gF_BaseMultiplier = gF_BaseMultiplier * TierMultiplier;
	}
	
	g_CreditsPro = RoundFloat(GetConVarInt(gCV_BaseCredits) * gF_BaseMultiplier * GetConVarFloat(gCV_ProMultiplier));
	g_CreditsProAfterCompletion = RoundFloat(GetConVarInt(gCV_BaseCredits) *  gF_BaseMultiplier * GetConVarFloat(gCV_ProMultiplierAfterCompletion));
	g_CreditsNub = RoundFloat(GetConVarInt(gCV_BaseCredits) *  gF_BaseMultiplier * GetConVarFloat(gCV_NubMultiplier));
	g_CreditsNubAfterCompletion = RoundFloat(GetConVarInt(gCV_BaseCredits) *  gF_BaseMultiplier * GetConVarFloat(gCV_NubMultiplierAfterCompletion));
	g_CreditsBonus = RoundFloat(GetConVarInt(gCV_BaseCredits) *  gF_BaseMultiplier * GetConVarFloat(gCV_BonusMultiplier));
	g_CreditsBonusAfterCompletion = RoundFloat(GetConVarInt(gCV_BaseCredits) *  gF_BaseMultiplier * GetConVarFloat(gCV_BonusMultiplierAfterCompletion));
}

// TxnFailure helper taken from GOKZ.
public void DB_TxnFailure_Generic(Handle db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
    LogError("Database transaction error: %s", error);
}
// === End of DB ===
public void OnMapStart()
{
	for(int i = 1; i < MaxClients; i++)
	{
		proFinished[i] = 0;
		bonusFinished[i] = 0;
		nubFinished[i] = 0;
	}
}

public void GOKZ_OnTimerEnd_Post(int client, int course, float time, int teleportsUsed)
{
	if (course == 0)
	{
		if (teleportsUsed == 0)
		{
			if(proFinished[client] == 0)
			{
				CPrintToChat(client, "%t", "OnProFinished", g_sTag, g_CreditsPro);
				Store_SetClientCredits(client, Store_GetClientCredits(client) + g_CreditsPro);
				proFinished[client]++;
			}
			else if(proFinished[client] <= 10)
			{
				CPrintToChat(client, "%t", "OnProFinishedAgain", g_sTag, g_CreditsProAfterCompletion);
				Store_SetClientCredits(client, Store_GetClientCredits(client) + g_CreditsProAfterCompletion);
				proFinished[client]++;
			}
			else CPrintToChat(client, "%t", "Too Many Pro Runs", g_sTag, proFinished[client] - 1);
		}
		else
		{
			if(nubFinished[client] == 0)
			{
				CPrintToChat(client, "%t", "OnNubFinished", g_sTag, g_CreditsNub);
				Store_SetClientCredits(client, Store_GetClientCredits(client) + g_CreditsNub);
				nubFinished[client]++;
			}
			else if(nubFinished[client] <= 5)
			{
				CPrintToChat(client, "%t", "OnNubFinishedAgain", g_sTag, g_CreditsNubAfterCompletion);
				Store_SetClientCredits(client, Store_GetClientCredits(client) + g_CreditsNubAfterCompletion);
				nubFinished[client]++;
			}
			else CPrintToChat(client, "%t", "Too Many Nub Runs", g_sTag, proFinished[client] - 1);
		}
	}
	else
	{
		if(bonusFinished[client] == 0)
		{
			CPrintToChat(client, "%t", "OnBonusFinished", g_sTag, g_CreditsBonus);
			Store_SetClientCredits(client, Store_GetClientCredits(client) + g_CreditsBonus);
			bonusFinished[client]++;
		}
		else if(bonusFinished[client] <= 5)
		{
			CPrintToChat(client, "%t", "OnBonusFinishedAgain", g_sTag, g_CreditsBonusAfterCompletion);
			Store_SetClientCredits(client, Store_GetClientCredits(client) + g_CreditsBonusAfterCompletion);
			bonusFinished[client]++;
		}
		else CPrintToChat(client, "%t", "Too Many Bonus Runs", g_sTag, bonusFinished[client] - 1);
	}
}

