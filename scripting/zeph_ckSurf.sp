#include <sourcemod>
#include <colorvariables>
#include <sdktools>
#include <cstrike>
#include <ckSurf>
#include <store>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.1"

bool mapFinished[MAXPLAYERS + 1] = false;
bool bonusFinished[MAXPLAYERS + 1] = false;
bool practiceFinished[MAXPLAYERS + 1] = false;

char g_sTag[32];
ConVar gc_sTag;

Handle g_hCreditsNormal = INVALID_HANDLE;
Handle g_hCreditsBonus = INVALID_HANDLE;
Handle g_hCreditsPractice = INVALID_HANDLE;
Handle g_hCreditsNormalAfterCompletion = INVALID_HANDLE;
Handle g_hCreditsBonusAfterCompletion = INVALID_HANDLE;
Handle g_hCreditsPracticeAfterCompletion = INVALID_HANDLE;

int g_CreditsNormal, g_CreditsBonus, g_CreditsPractice, g_CreditsNormalAfterCompletion, g_CreditsBonusAfterCompletion, g_CreditsPracticeAfterCompletion;

public Plugin myinfo =
{
	name = "Zephyrus-Store: ckSurf",
	author = "Simon, Cruze",
	description = "Give credits on completion.",
	version = PLUGIN_VERSION,
	url = "yash1441@yahoo.com"
};

public void OnPluginStart()
{
	g_hCreditsNormal = CreateConVar("zeph_surf_normal", "50", "Credits given when a player finishes a map.");
	g_hCreditsBonus = CreateConVar("zeph_surf_bonus", "100", "Credits given when a player finishes a bonus.");
	g_hCreditsPractice = CreateConVar("zeph_surf_practice", "25", "Credits given when a player finishes a map in practice mode.");
	g_hCreditsNormalAfterCompletion = CreateConVar("zeph_surf_normal_again", "20", "Credits given when a player finishes a map again.");
	g_hCreditsBonusAfterCompletion = CreateConVar("zeph_surf_bonus_again", "50", "Credits given when a player finishes a bonus again.");
	g_hCreditsPracticeAfterCompletion = CreateConVar("zeph_surf_practice_again", "5", "Credits given when a player finishes a map in practice mode again.");
	
	HookConVarChange(g_hCreditsNormal, OnConVarChanged);
	HookConVarChange(g_hCreditsBonus, OnConVarChanged);
	HookConVarChange(g_hCreditsPractice, OnConVarChanged);
	HookConVarChange(g_hCreditsNormalAfterCompletion, OnConVarChanged);
	HookConVarChange(g_hCreditsBonusAfterCompletion, OnConVarChanged);
	HookConVarChange(g_hCreditsPracticeAfterCompletion, OnConVarChanged);
	
	AutoExecConfig(true, "zeph_cksurf");
	LoadTranslations("zeph_cksurf");
}

public int OnConVarChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_hCreditsNormal)
	{
		g_CreditsNormal = StringToInt(newValue);
	}
	else if (convar == g_hCreditsBonus)
	{
		g_CreditsBonus = StringToInt(newValue);
	}
	else if (convar == g_hCreditsPractice)
	{
		g_CreditsPractice = StringToInt(newValue);
	}
	else if (convar == g_hCreditsNormalAfterCompletion)
	{
		g_CreditsNormalAfterCompletion = StringToInt(newValue);
	}
	else if (convar == g_hCreditsBonusAfterCompletion)
	{
		g_CreditsBonusAfterCompletion = StringToInt(newValue);
	}
	else if (convar == g_hCreditsPracticeAfterCompletion)
	{
		g_CreditsPracticeAfterCompletion = StringToInt(newValue);
	}
}

public void OnConfigsExecuted()
{
	g_CreditsNormal = GetConVarInt(g_hCreditsNormal);
	g_CreditsBonus = GetConVarInt(g_hCreditsBonus);
	g_CreditsPractice = GetConVarInt(g_hCreditsPractice);
	g_CreditsNormalAfterCompletion = GetConVarInt(g_hCreditsNormalAfterCompletion);
	g_CreditsBonusAfterCompletion = GetConVarInt(g_hCreditsBonusAfterCompletion);
	g_CreditsPracticeAfterCompletion = GetConVarInt(g_hCreditsPracticeAfterCompletion);
	
	gc_sTag = FindConVar("ck_chat_prefix");
	gc_sTag.GetString(g_sTag, sizeof(g_sTag));
	
}

public void OnMapStart()
{
	for(int i = 1; i < MaxClients; i++)
	{
		mapFinished[i] = false;
		bonusFinished[i] = false;
		practiceFinished[i] = false;
	}
}

public Action ckSurf_OnMapFinished(int client, float fRunTime, char sRunTime[54], int rank, int total)
{
	if(!mapFinished[client])
	{
		CPrintToChat(client, "%t", "On Map Finished", g_sTag, g_CreditsNormal);
		Store_SetClientCredits(client, Store_GetClientCredits(client) + g_CreditsNormal);
		mapFinished[client] = true;
	}
	else
	{
		CPrintToChat(client, "%t", "On Map Finished Again", g_sTag, g_CreditsNormalAfterCompletion);
		Store_SetClientCredits(client, Store_GetClientCredits(client) + g_CreditsNormalAfterCompletion);
	}
}

public Action ckSurf_OnBonusFinished(int client, float fRunTime, char sRunTime[54], int rank, int total, int bonusid)
{
	if(!bonusFinished[client])
	{
		CPrintToChat(client, "%t", "On Bonus Finished", g_sTag, g_CreditsBonus);
		Store_SetClientCredits(client, Store_GetClientCredits(client) + g_CreditsBonus);
		bonusFinished[client] = true;
	}
	else
	{
		CPrintToChat(client, "%t", "On Bonus Finished Again", g_sTag, g_CreditsBonusAfterCompletion);
		Store_SetClientCredits(client, Store_GetClientCredits(client) + g_CreditsBonusAfterCompletion);
	}
}

public Action ckSurf_OnPracticeFinished(int client, float fRunTime, char sRunTime[54])
{
	if(!practiceFinished[client])
	{
		CPrintToChat(client, "%t", "On Practice Finished", g_sTag, g_CreditsPractice);
		Store_SetClientCredits(client, Store_GetClientCredits(client) + g_CreditsPractice);
		practiceFinished[client] = true;
	}
	else
	{
		CPrintToChat(client, "%t", "On Practice Finished Again", g_sTag, g_CreditsPracticeAfterCompletion);
		Store_SetClientCredits(client, Store_GetClientCredits(client) + g_CreditsPracticeAfterCompletion);
	}
}
