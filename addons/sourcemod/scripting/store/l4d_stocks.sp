Action L4D_OnPlayerDeath(Handle event, int victim, int attacker)
{
	if(victim) // still give credits on killing Specials Infected
	{
		char buffer[32];
		GetEventString(event, "victimname", buffer, sizeof(buffer));
		if( strlen(buffer) != 0 && !StrEqual(buffer, "infected") )
		{
			//PrintToChatAll("\x03Special infected '\x01%s\x03' death", buffer);  // debug
			//do some function - SPECIAL INFECTED DEATH
			g_eClients[attacker].iCredits += GetMultipliedCredits(attacker, g_eCvars[g_cvarCreditAmountKill].aCache);
			//Chat(attacker, "%t", "Credits Earned For Killing", g_eCvars[g_cvarCreditAmountKill].aCache, g_eClients[victim].szName_Client);
			CPrintToChat(attacker, "%s%t", g_sChatPrefix, "Credits Earned For Killing", g_eCvars[g_cvarCreditAmountKill].aCache, g_eClients[victim].szName_Client);
		}
	}
	else // prevent farming credits by killing Commin Infected
	{
		int victimentityid = GetEventInt(event, "entityid");
		if( IsCommonInfected(victimentityid) )
		{
			//PrintToChatAll("\x01Common infected death"); // debug
			return Plugin_Continue;
			//do some function - COMMNON INFECTED DEATH
		}
	}
	
	return Plugin_Continue;
}

stock bool IsCommonInfected(int iEntity)
{
    if(iEntity > 0 && IsValidEntity(iEntity) && IsValidEdict(iEntity))
    {
        char strClassName[64];
        GetEdictClassname(iEntity, strClassName, sizeof(strClassName));
        return StrEqual(strClassName, "infected");
    }
    return false;
} 