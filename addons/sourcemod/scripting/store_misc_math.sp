#include <sourcemod>
#include <sdktools>
#include <store>
#include <multicolors>
#include <autoexecconfig>

char g_sCreditsName[64] = "credits";
char g_sChatPrefix[128];

#define PLUS				"+"
#define MINUS				"-"
#define DIVISOR				"/"
#define MULTIPLE			"*"

bool inQuizz;

char op[32];
char operators[4][5] = {"+", "-", "/", "*"};

int nbrmin;
int nbrmax;
int maxcredits;
int mincredits;
int questionResult;
int credits;
int minplayers;

Handle timerQuestionEnd;

ConVar MinimumNumber;
ConVar MaximumNumber;
ConVar MaximumCredits;
ConVar MinimumCredits;
ConVar TimeBetweenQuestion;
ConVar TimeAnswer;
ConVar MinimumPlayers;


public Plugin myinfo =
{
	name = "Math Quiz",
	author = "Arkarr & Simon & AiDN™",
	description = "Give credits on correct math answer, to nuclear silo's edited store by AiDN™.",
	version = "1.2",
	url = ""
};
 
public void OnPluginStart()
{
	LoadTranslations("store.phrases");
	LoadTranslations("common.phrases");
	
	RegAdminCmd("sm_math", Command_StartQuestion, ADMFLAG_ROOT);
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");

	inQuizz = false;
	
	AutoExecConfig_SetFile("math", "sourcemod/store");
	AutoExecConfig_SetCreateFile(true);
	
	MinimumNumber = AutoExecConfig_CreateConVar("store_math_minimum_number", "1", "Minimum number for questions");
	MaximumNumber = AutoExecConfig_CreateConVar("store_math_maximum_number", "100", "Maximum number for questions");
	MinimumCredits = AutoExecConfig_CreateConVar("store_math_minimum_credits", "10", "Minimum number of credits earned for a correct answers");
	MaximumCredits = AutoExecConfig_CreateConVar("store_math_maximum_credits", "50", "Maximum number of credits earned for a correct answers");
	TimeBetweenQuestion = AutoExecConfig_CreateConVar("store_math_time_between_questions", "120", "Time in seconds between each questions");
	TimeAnswer = AutoExecConfig_CreateConVar("store_math_time_answer_questions", "20", "Time in seconds to give answer to a question");
	MinimumPlayers = AutoExecConfig_CreateConVar("store_math_min_players", "5", "Minimum players to work math system");
	
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
	
	// Supress warnings about unused variables.....
	if(g_cvarChatTag){}
}

public void OnMapStart()
{
	CreateTimer(GetConVarFloat(TimeBetweenQuestion) + GetConVarFloat(TimeAnswer), CreateQuestion, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void Store_OnConfigExecuted(char[] prefix)
{
	strcopy(g_sChatPrefix, sizeof(g_sChatPrefix), prefix);
	ReadCoreCFG();
}

public Action Command_StartQuestion(int client, int args)
{
	CreateTimer(1.0, CreateQuestion, client);
	return Plugin_Handled;
}

public void OnConfigsExecuted()
{		
	nbrmin = GetConVarInt(MinimumNumber);
	nbrmax = GetConVarInt(MaximumNumber);
	maxcredits = GetConVarInt(MaximumCredits);
	mincredits = GetConVarInt(MinimumCredits);
	minplayers = GetConVarInt(MinimumPlayers);
}

public Action EndQuestion(Handle timer, any data)
{
	SendEndQuestion(-1);
}

public int PlayerCount()
{
	int count;
	for (int i=1;i<=MaxClients;i++)
		if(IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i))
			count++;
	
	return count;
}

public Action CreateQuestion(Handle timer, any data)
{
	int count;
	count = PlayerCount();
	
	if (count >= minplayers)
	{
		int client = data;
		int nbr1 = GetRandomInt(nbrmin, nbrmax);
		int nbr2 = GetRandomInt(nbrmin, nbrmax);
		credits = GetRandomInt(mincredits, maxcredits);
		
		Format(op, sizeof(op), operators[GetRandomInt(0,3)]);

		if(StrEqual(op, PLUS))
		{
			questionResult = nbr1 + nbr2;
		}
		else if(StrEqual(op, MINUS))
		{
			do{
				nbr1 = GetRandomInt(nbrmin, nbrmax);
				nbr2 = GetRandomInt(nbrmin, nbrmax);
			}
			while(nbr1 % nbr2 != 0);
			questionResult = nbr1 - nbr2;
		}
		else if(StrEqual(op, DIVISOR))
		{
			do{
				nbr1 = GetRandomInt(nbrmin, nbrmax);
				nbr2 = GetRandomInt(nbrmin, nbrmax);
			}
			while(nbr1 % nbr2 != 0);
			questionResult = nbr1 / nbr2;
		}
		else if(StrEqual(op, MULTIPLE))
		{
			questionResult = nbr1 * nbr2;
		}
		CPrintToChatAll("%s%t", g_sChatPrefix, "QuizzGenerated", nbr1, op, nbr2, credits, g_sCreditsName);
		
		inQuizz = true;

		timerQuestionEnd = CreateTimer(GetConVarFloat(TimeAnswer), EndQuestion, client);
	}
	else
	{
	}
}

public Action Command_Say(int client, const char[] command, int args)
{
	
	if (inQuizz)
	{
		char szNumber[128];
		GetCmdArg(1, szNumber, sizeof(szNumber));
		int iNumber = StringToInt(szNumber);
		new len = strlen(szNumber);
		for (new i = 0; i < len; i++)
		{
			if ( !IsCharNumeric(szNumber[i]) )
				return Plugin_Continue;
		}
		if (ProcessSolution(client, iNumber))
			SendEndQuestion(client);
	}
	return Plugin_Continue;
}

public bool ProcessSolution(client, int number)
{
	if(questionResult == number)
	{
		Store_SetClientCredits(client, Store_GetClientCredits(client) + credits);

		return true;
	}
	else
	{
		return false;
	}
}

public void SendEndQuestion(int client)
{
	if(timerQuestionEnd != INVALID_HANDLE)
	{
		KillTimer(timerQuestionEnd);
		timerQuestionEnd = INVALID_HANDLE;
	}

	char answer[200], name[64];
	
	if(client != -1) 
	{
		GetClientName(client, name, sizeof(name));
		Format(answer, sizeof(answer), "%s%t", g_sChatPrefix, "CorrectAnswer", name, credits, g_sCreditsName);	
		Store_SQLLogMessage(client, LOG_EVENT, "%s won %i credits on Math", name, credits);
	}
	else 
	{	
		Format(answer, sizeof(answer), "NoAnswer");
	}

	Handle pack = CreateDataPack();
	CreateDataTimer(0.3, AnswerQuestion, pack);
	WritePackString(pack, answer);

	inQuizz = false;
}

public Action AnswerQuestion(Handle timer, Handle pack)
{
	char str[200];
	ResetPack(pack);
	ReadPackString(pack, str, sizeof(str));

	if (StrEqual(str, "NoAnswer")) {

		CPrintToChatAll("%s%t", g_sChatPrefix, "NoAnswer", questionResult);
	}
	else {
		CPrintToChatAll(str);
	}
}

void ReadCoreCFG()
{
	char sFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFile, sizeof(sFile), "configs/core.cfg");

	Handle hParser = SMC_CreateParser();
	char error[128];
	int line = 0;
	int col = 0;

	SMC_SetParseEnd(hParser, INVALID_FUNCTION);

	SMCError result = SMC_ParseFile(hParser, sFile, line, col);
	delete hParser;

	if (result == SMCError_Okay)
		return;

	SMC_GetErrorString(result, error, sizeof(error));
	Store_SQLLogMessage(0, LOG_ERROR, "ReadCoreCFG: Error: %s on line %i, col %i of %s", error, line, col, sFile);
}