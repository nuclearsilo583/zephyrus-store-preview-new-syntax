#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>

bool GAME_TF2 = false;


public Plugin myinfo = 
{
	name = "Store - Bunny module",
	author = "nuclear silo", // If you should change the code, even for your private use, please PLEASE add your name to the author here
	description = "",
	version = "1.0", // If you should change the code, even for your private use, please PLEASE make a mark here at the version number
	url = ""
};

public OnPluginStart()
{
	// TF2 is unsupported
	char m_szGameDir[32];
	GetGameFolderName(m_szGameDir, sizeof(m_szGameDir));
	if(strcmp(m_szGameDir, "tf")==0)
		GAME_TF2 = true;
		
	Store_RegisterHandler("bunnyhop", "", Bunnyhop_OnMapStart, Bunnyhop_Reset, Bunnyhop_Config, Bunnyhop_Equip, Bunnyhop_Remove, true);
}

public void Bunnyhop_OnMapStart()
{
}

public void Bunnyhop_Reset()
{
}

public bool Bunnyhop_Config(Handle &kv,int itemid)
{
	Store_SetDataIndex(itemid, 0);
	return true;
}

public int Bunnyhop_Equip(int client,int id)
{
	return -1;
}

public int Bunnyhop_Remove(int client,int id)
{
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon)
{
	int m_iEquipped = Store_GetEquippedItem(client, "bunnyhop");
	if(m_iEquipped < 0)
		return Plugin_Continue;

	int m_iWater = GetEntProp(client, Prop_Data, "m_nWaterLevel");
	if (IsPlayerAlive(client))
		if (buttons & IN_JUMP)
			if (m_iWater <= 1)
				if (!(GetEntityMoveType(client) & MOVETYPE_LADDER))
				{
					if(!GAME_TF2)
						SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
					if (!(GetEntityFlags(client) & FL_ONGROUND))
						buttons &= ~IN_JUMP;
				}

	return Plugin_Continue;
}