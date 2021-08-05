/*
 * Store - Sound item module
 * by: shanapu
 * https://github.com/shanapu/
 * 
 * Copyright (C) 2018-2019 Thomas Schmidt (shanapu)
 * Credits:
 * Contributer:
 *
 * Original development by Zephyrus - https://github.com/dvarnai/store-plugin
 *
 * Love goes out to the sourcemod team and all other plugin developers!
 * THANKS FOR MAKING FREE SOFTWARE!
 *
 * This file is part of the MyStore SourceMod Plugin.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 */

#include <sourcemod>
#include <sdktools>

#include <colors> 
#include <store>
#include <zephstocks>

//#include <smartdm>

#pragma semicolon 1
#pragma newdecls required

char g_sSound[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
char g_sTrigger[STORE_MAX_ITEMS][64];
//int g_unPrice[STORE_MAX_ITEMS];
int g_iCooldown[STORE_MAX_ITEMS];
int g_iOrigin[STORE_MAX_ITEMS];
float g_fVolume[STORE_MAX_ITEMS];
//int g_iPerm[STORE_MAX_ITEMS];
int g_iItemId[STORE_MAX_ITEMS];
int g_iFlagBits[STORE_MAX_ITEMS];

char g_sChatPrefix[128];
char g_sSteam[256];

int g_iCount = 0;
int g_iSpam[MAXPLAYERS + 1] = {0,...};

int g_iType;
int g_iMaxUses;

int g_iUses[MAXPLAYERS + 1] = {0,...};

/*
 * Build date: <DATE>
 * Build number: <BUILD>
 * Commit: https://github.com/shanapu/MyStore/commit/<COMMIT>
 */

public Plugin myinfo = 
{
	name = "Store - Sound item module",
	author = "shanapu, nuclear silo", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "1.1", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
};

public void OnPluginStart()
{
	Store_RegisterHandler("saysound", "sound", Sounds_OnMapStart, Sounds_Reset, Sounds_Config, Sounds_Equip, Sounds_Remove, false);
	
	g_iType = RegisterConVar("sm_store_saysound_type", "1", "Type of the max uses limit (0 = Map limit, 1 = Round limit)", TYPE_INT);
	g_iMaxUses = RegisterConVar("sm_store_saysound_max_uses", "1", "Max uses", TYPE_INT);

	LoadTranslations("store.phrases");

	HookEvent("player_say", Event_PlayerSay);
	//HookEvent("round_end", Reset_Count ,EventHookMode_Pre);
	HookEvent("round_start", Reset_Count);
}

public void Reset_Count(Handle event , const char[] name , bool dontBroadcast)
{
	for(int i=1; i<=MaxClients; i++)
	{
		if(g_eCvars[g_iType].aCache == 1)
		{
			g_iUses[i] = 0;
		}
	}
}

public void OnMapStart()
{
	for(int i=1; i<=MaxClients; i++)
	{
		//if(g_eCvars[g_iType].aCache == 0)
		//{
		g_iUses[i] = 0;
		//}
	}
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
}

public void Sounds_OnMapStart()
{
	char sBuffer[256];

	for (int i = 0; i < g_iCount; i++)
	{
		PrecacheSound(g_sSound[i], true);
		FormatEx(sBuffer, sizeof(sBuffer), "sound/%s", g_sSound[i]);
		AddFileToDownloadsTable(sBuffer);
	}
}

public void Sounds_Reset()
{
	g_iCount = 0;
}

public bool Sounds_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iCount);

	kv.GetString("sound", g_sSound[g_iCount], PLATFORM_MAX_PATH);

	char sBuffer[256];
	FormatEx(sBuffer, sizeof(sBuffer), "sound/%s", g_sSound[g_iCount]);

	if (!FileExists(sBuffer, true))
	{
		//Store_LogMessage(0, LOG_ERROR, "Can't find sound %s.", sBuffer);
		return false;
	}

	kv.GetString("trigger", g_sTrigger[g_iCount], 64);
	//g_iPerm[g_iCount] = kv.GetNum("perm", 0);
	g_iCooldown[g_iCount] = kv.GetNum("cooldown", 30);
	g_fVolume[g_iCount] = kv.GetFloat("volume", 0.5);
	g_iOrigin[g_iCount] = kv.GetNum("origin", 1);
	//g_unPrice[g_iCount] = kv.GetNum("price");
	g_iItemId[g_iCount] = itemid;

	kv.GetString("flag", sBuffer, sizeof(sBuffer), "\0");
	g_iFlagBits[g_iCount] = ReadFlagString(sBuffer);

	kv.GetString("steam", g_sSteam[g_iCount], 64, "\0");

	if (g_iCooldown[g_iCount] < 10)
	{
		g_iCooldown[g_iCount] = 10;
	}

	if (g_fVolume[g_iCount] > 1.0)
	{
		g_fVolume[g_iCount] = 1.0;
	}

	if (g_fVolume[g_iCount] <= 0.0)
	{
		g_fVolume[g_iCount] = 0.05;
	}

	g_iCount++;

	return true;
}

public int Sounds_Equip(int client, int itemid)
{
	int iIndex = Store_GetDataIndex(itemid);

	if (g_iSpam[client] > GetTime())
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Spam Cooldown", g_iSpam[client] - GetTime());
		Store_DisplayPreviousMenu(client);
		return 1;
	}

	if (!IsPlayerAlive(client) && g_iOrigin[iIndex] > 1)
	{
		CPrintToChat(client, "%s%t", g_sChatPrefix, "Must be Alive");
		return 1;
	}

	if(g_iUses[client]<view_as<int>(g_eCvars[g_iMaxUses].aCache))
	{
		g_iUses[client]++;
		switch (g_iOrigin[iIndex])
		{
			// Sound From global world
			case 1:
			{
				EmitSoundToAll(g_sSound[iIndex], SOUND_FROM_WORLD, _, SNDLEVEL_RAIDSIREN, _, g_fVolume[iIndex]);
				//g_iUses[client]++;
			}
			// Sound From local player
			case 2:
			{
				float fVec[3];
				GetClientAbsOrigin(client, fVec);
				EmitAmbientSound(g_sSound[iIndex], fVec, SOUND_FROM_PLAYER, SNDLEVEL_RAIDSIREN, _, g_fVolume[iIndex]);
				//g_iUses[client]++;
			}
			// Sound From player voice
			case 3:
			{
				float fPos[3], fAgl[3];
				GetClientEyePosition(client, fPos);
				GetClientEyeAngles(client, fAgl);

				// player`s mouth
				fPos[2] -= 3.0;
				//g_iUses[client]++;
				EmitSoundToAll(g_sSound[iIndex], client, SNDCHAN_VOICE, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fVolume[iIndex], SNDPITCH_NORMAL, client, fPos, fAgl, true);
			}
		}
	}
	else
	{
		if (g_eCvars[g_iType].aCache == 0)
			CPrintToChat(client, "%s%t", g_sChatPrefix, "say sound map max uses", view_as<int>(g_eCvars[g_iMaxUses].aCache));
		else CPrintToChat(client, "%s%t", g_sChatPrefix, "say sound round max uses", view_as<int>(g_eCvars[g_iMaxUses].aCache));
	}
	g_iSpam[client] = GetTime() + g_iCooldown[iIndex];
	
	//Store_SetClientPreviousMenu(client, MENU_PARENT);
	Store_DisplayPreviousMenu(client);

	return 1; // 1 ITEM_EQUIP_KEEP / 0 ITEM_EQUIP_REMOVE
}

public int Sounds_Remove(int client, int itemid)
{
	return 0;
}

public void Event_PlayerSay(Event event, char[] name, bool dontBroadcast)
{

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client)
		return;

	char sBuffer[32];
	GetEventString(event, "text", sBuffer, sizeof(sBuffer));

	//Old trigger method
	/*for (int i = 0; i < g_iCount; i++)
	{
		if (strcmp(sBuffer, g_sTrigger[i]) == 0)
		{
			if (g_iSpam[client] > GetTime())
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Spam Cooldown", g_iSpam[client] - GetTime());
				return;
			}

			if (!CheckFlagBits(client, g_iFlagBits[i]) || !Store_HasClientAccess(client) || !CheckSteamAuth(client, g_sSteam[i]))
				return;

			int credits = Store_GetClientCredits(client);
			if (credits >= g_unPrice[i] || Store_HasClientItem(client, g_iItemId[i]))
			{
				switch (g_iOrigin[i])
				{
					// Sound From global world
					case 1:
					{
						EmitSoundToAll(g_sSound[i], SOUND_FROM_WORLD, _, SNDLEVEL_RAIDSIREN, _, g_fVolume[i]);
					}
					// Sound From local player
					case 2:
					{
						float fVec[3];
						GetClientAbsOrigin(client, fVec);
						EmitAmbientSound(g_sSound[i], fVec, SOUND_FROM_PLAYER, SNDLEVEL_RAIDSIREN, _, g_fVolume[i]);
					}
					// Sound From player voice
					case 3:
					{
						float fPos[3], fAgl[3];
						GetClientEyePosition(client, fPos);
						GetClientEyeAngles(client, fAgl);

						// player`s mouth
						fPos[2] -= 3.0;

						EmitSoundToAll(g_sSound[i], client, SNDCHAN_VOICE, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fVolume[i], SNDPITCH_NORMAL, client, fPos, fAgl, true);
					}
				}
			
				if (!Store_HasClientItem(client, g_iItemId[i]))
				{
					Store_SetClientCredits(client, credits - g_unPrice[i]);
					if (g_iPerm[i] == 1)
					{
						Store_GiveItem(client, g_iItemId[i], 0, 0, g_unPrice[i]);
					}
				}
				else if (g_iPerm[i] == 0)
				{
					Store_RemoveItem(client, g_iItemId[i]);
				}

				g_iSpam[client] = GetTime() + g_iCooldown[i];
			}
			else
			{
				CPrintToChat(client, "%s%t", g_sChatPrefix, "Credit Not Enough");
			}

			break;
		}
	}*/
	
	for (int i = 0; i < g_iCount; i++)
	{
		if (strcmp(sBuffer, g_sTrigger[i]) == 0)
		{
			if (g_iUses[client] < g_eCvars[g_iMaxUses].aCache)
			{
				if (g_iSpam[client] > GetTime())
				{
					CPrintToChat(client, "%s%t", g_sChatPrefix, "Spam Cooldown", g_iSpam[client] - GetTime());
					return;
				}

				if (!CheckFlagBits(client, g_iFlagBits[i]) /*|| !Store_HasClientAccess(client) */|| !CheckSteamAuth(client, g_sSteam[i]))
					return;

				if (Store_HasClientItem(client, g_iItemId[i]))
				{
					switch (g_iOrigin[i])
					{
						// Sound From global world
						case 1:
						{
							EmitSoundToAll(g_sSound[i], SOUND_FROM_WORLD, _, SNDLEVEL_RAIDSIREN, _, g_fVolume[i]);
						}
						// Sound From local player
						case 2:
						{
							float fVec[3];
							GetClientAbsOrigin(client, fVec);
							EmitAmbientSound(g_sSound[i], fVec, SOUND_FROM_PLAYER, SNDLEVEL_RAIDSIREN, _, g_fVolume[i]);
						}
						// Sound From player voice
						case 3:
						{
							float fPos[3], fAgl[3];
							GetClientEyePosition(client, fPos);
							GetClientEyeAngles(client, fAgl);

							// player`s mouth
							fPos[2] -= 3.0;

							EmitSoundToAll(g_sSound[i], client, SNDCHAN_VOICE, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fVolume[i], SNDPITCH_NORMAL, client, fPos, fAgl, true);
						}
					}


					g_iSpam[client] = GetTime() + g_iCooldown[i];
					g_iUses[client]++;
				}
			}
			else
			{
				if (g_eCvars[g_iType].aCache == 0)
					CPrintToChat(client, "%s%t", g_sChatPrefix, "say sound map max uses", view_as<int>(g_eCvars[g_iMaxUses].aCache));
				else CPrintToChat(client, "%s%t", g_sChatPrefix, "say sound round max uses", view_as<int>(g_eCvars[g_iMaxUses].aCache));
			}
			break;
		}
	}
}

public void Store_OnPreviewItem(int client, char[] type, int index)
{
	if (!StrEqual(type, "saysound"))
		return;

	EmitSoundToClient(client, g_sSound[index], client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fVolume[index] / 1.5);

	CPrintToChat(client, "%s%t", g_sChatPrefix, "Play Preview", client);
}

bool CheckFlagBits(int client, int flagsNeed, int flags = -1)
{
	if (flags==-1)
	{
		flags = GetUserFlagBits(client);
	}

	if (flagsNeed == 0 || flags & flagsNeed || flags & ADMFLAG_ROOT)
	{
		return true;
	}
	return false;
}

bool CheckSteamAuth(int client, char[] steam)
{
	if (!steam[0])
		return true;

	char sSteam[32];
	if (!GetClientAuthId(client, AuthId_Steam2, sSteam, 32))
		return false;

	if (StrContains(steam, sSteam) == -1)
		return false;

	return true;
}