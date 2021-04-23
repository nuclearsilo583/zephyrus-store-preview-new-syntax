#pragma semicolon 1

#define PLUGIN_NAME         "CS:S Blackjack"
#define PLUGIN_AUTHOR       "Dunder"
#define PLUGIN_DESCRIPTION  "Play Blackjack using Zeph's Store" 
#define PLUGIN_VERSION      "1.6.1"
#define PLUGIN_URL          "https://github.com/ashort96/sp-blackjack"

#define NO_ONE      0
#define DEALER      1
#define HAND_ONE    2
#define HAND_TWO    3

#define NUMBEROFCARDS   52

#define PREFIX      "\x07B41F1F[Blackjack]\x07F8F8FF"

#include <sourcemod>
#include <store>

#pragma newdecls required

static const char g_cSuit[][] = {"♥", "◆", "♠", "♣"};
static const char g_sRank[][] = {"A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"};

ConVar g_Cvar_Minimum_Bid;
ConVar g_Cvar_Maximum_Bid;

int g_iDecks[MAXPLAYERS + 1][NUMBEROFCARDS];
int g_iCurrentHand[MAXPLAYERS + 1] = {HAND_ONE, ...};
int g_iBids[MAXPLAYERS + 1];

bool g_bPlayerSplit[MAXPLAYERS + 1] = {false, ...};
bool g_bInActiveGame[MAXPLAYERS + 1] = {false, ...};

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = PLUGIN_AUTHOR,
    description = PLUGIN_DESCRIPTION,
    version = PLUGIN_VERSION,
    url = PLUGIN_URL
}

public void OnPluginStart()
{

    // ConVars
    g_Cvar_Minimum_Bid = CreateConVar("sm_blackjack_minimum_bid", "50", "Minimum bid required to play", 0, true, 0.0);
    g_Cvar_Maximum_Bid = CreateConVar("sm_blackjack_maximum_bid", "1000", "Maximum bid", 0, true, 0.0);

    RegConsoleCmd("sm_blackjack", Command_Blackjack);
    RegConsoleCmd("sm_bj", Command_Blackjack);

    HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_PostNoCopy);

    LoadTranslations("blackjack.phrases");
    AutoExecConfig(true, "blackjack");

}

///////////////////////////////////////////////////////////////////////////////
// Helper Functions
///////////////////////////////////////////////////////////////////////////////

void GiveClientCredits(int client, int credits)
{
    int currentCredts = Store_GetClientCredits(client);
    Store_SetClientCredits(client, currentCredts + credits);
}

// Deal two cards to the hand playing
void InitializeHand(int hand, int[] cards)
{
    DealCard(hand, cards);
    DealCard(hand, cards);
}

// Assign a card to the hand
int DealCard(int hand, int[] cards)
{
    int index;
    for (;;)
    {
        index = GetRandomInt(0, 51);
        if (cards[index] == NO_ONE)
            break;
    }
    cards[index] = hand;
}

// "Resets" the deck
void ClearDeck(int[] cards)
{
    for (int i = 0; i < NUMBEROFCARDS; i++)
    {
        cards[i] = NO_ONE;
    }
}

// Returns the score of the hand
int ScoreHand(int hand, int[] cards)
{
    int score = 0;

    // We need to loop through the cards twice; first, add up everything that
    // is not an Ace. Then, if the score + ace <= 21, add 11. Otherwise, add 1.
    for (int i = 0; i < NUMBEROFCARDS; i++)
    {
        if (cards[i] == hand)
        {
            // Deal with cards 2-9
            if ((i % 13 > 0) && (i % 13 <= 9))
            {
                score += (i % 13) + 1;
            }
            // Deal with 10s, Jacks, Queens, and Kings
            else if (i % 13 > 9)
            {
                score += 10;
            }
        }
    }

    // Now to loop through again and see if there are any Aces.
    for (int i = 0; i < NUMBEROFCARDS; i++)
    {
        if ((cards[i] == hand) && (i % 13 == 0))
        {
            if ((score + 11) > 21)
                score += 1;
            else
                score += 11;
        }
    }

    return score;
}

// Returns the number of cards in a hand
int GetNumberOfCards(int hand, int[] cards)
{
    int count = 0;
    for (int i = 0; i < NUMBEROFCARDS; i++)
    {
        if (cards[i] == hand)
        {
            count++;
        }
    }
    return count;
}

// Returns the first card (used for the Dealer)
void GetFirstCard(int hand, int[] cards, char[] buf, int size)
{

    for (int i = 0; i < NUMBEROFCARDS; i++)
    {
        if (cards[i] == hand)
        {
            Format(buf, size, "%s%s",
                g_sRank[i % 13],
                g_cSuit[i / 13]
            );
            return;
        }
    }

}

// Puts the cards of the current hand into the buffer.
// Example:
//      AH, 2D, 3S
void GetCards(int hand, int[] cards, char[] buf, int size)
{


    int currentCard = 0;
    int numberOfCards = GetNumberOfCards(hand, cards);

    for (int i = 0; i < NUMBEROFCARDS; i++)
    {
        if (cards[i] == hand)
        {
            currentCard++;
            char tmpbuf[16];
            // If this card is the last one the player has, no need to add a
            // ',' after
            if(currentCard == numberOfCards)
            {
                Format(tmpbuf, sizeof(tmpbuf), "%s%s",
                    g_sRank[i % 13],
                    g_cSuit[i / 13]
                );
            }
            else
            {
                Format(tmpbuf, sizeof(tmpbuf), "%s%s, ",
                    g_sRank[i % 13],
                    g_cSuit[i / 13]
                );
            }
            StrCat(buf, size, tmpbuf);
        }
    }
}

// Displays all hands to the client. If showDealer is false, then only the top
// card will be displayed. If it is true, the dealer will show all cards.
void DisplayHandsToClient(int client, int[] cards, bool showDealer = false)
{
    int dealerScore = ScoreHand(DEALER, cards);
    int handOneScore = ScoreHand(HAND_ONE, cards);
    int handTwoScore = ScoreHand(HAND_TWO, cards);

    if (showDealer)
    {
        char dealerHand[128];
        GetCards(DEALER, cards, dealerHand, sizeof(dealerHand));
        PrintToChat(client, "%s %t", PREFIX, "DealerHand", dealerHand, dealerScore);
    }
    else 
    {
        char dealerCard[64];
        GetFirstCard(DEALER, cards, dealerCard, sizeof(dealerCard));
        PrintToChat(client, "%s %t", PREFIX, "DealerCard", dealerCard);
    }

    char handOne[128];
    GetCards(HAND_ONE, cards, handOne, 128);

    if (handTwoScore > 0)
    {
        char handTwo[128];
        GetCards(HAND_TWO, cards, handTwo, sizeof(handTwo));
        PrintToChat(client, "%s %t", PREFIX, "PlayerSplitHandOne", handOne, handOneScore);
        PrintToChat(client, "%s %t", PREFIX, "PlayerSplitHandTwo", handTwo, handTwoScore);

    }
    else 
    {
        PrintToChat(client, "%s %t", PREFIX, "PlayerSingleHand", handOne, handOneScore);
    }
}

bool CanPlayerSplit(int client, int[] cards)
{
    int cardOneValue = 0;
    int cardTwoValue = 0;

    // If the player has already split...
    if (g_bPlayerSplit[client])
        return false;


    for (int i = 0; i < NUMBEROFCARDS; i++)
    {
        if (cards[i] == HAND_ONE)
        {
            if (cardOneValue == 0)
            {
                if (i % 13 == 1)
                {
                    cardOneValue = 11;
                }
                // Deal with cards 2-9
                if ((i % 13 > 1) && (i % 13 < 10))
                {
                    cardOneValue = (i % 13) + 1;
                }
                // Deal with 10s, Jacks, Queens, and Kings
                else if (i % 13 > 9)
                {
                    cardOneValue = 10;
                }
            }
            else if (cardTwoValue == 0)
            {
                if (i % 13 == 1)
                {
                    cardTwoValue = 11;
                }
                // Deal with cards 2-9
                if ((i % 13 > 1) && (i % 13 < 10))
                {
                    cardTwoValue = (i % 13) + 1;
                }
                // Deal with 10s, Jacks, Queens, and Kings
                else if (i % 13 > 9)
                {
                    cardTwoValue = 10;
                }
            }

        }
    }

    if ((cardOneValue == cardTwoValue))
        return true;
    else
        return false;

}

void SplitHand(int client)
{
    for (int i = 0; i < NUMBEROFCARDS; i++)
    {
        if (g_iDecks[client][i] == HAND_ONE)
        {
            g_iDecks[client][i] = HAND_TWO;
            // The player has split
            g_bPlayerSplit[client] = true;
            // They need to put in another bid
            GiveClientCredits(client, -g_iBids[client]);
            return;
        }
    }

}

void DisplayBlackjackMenu(int client)
{
    Menu blackjackMenu = new Menu(Menu_Blackjack, MENU_ACTIONS_DEFAULT);
    blackjackMenu.SetTitle("Blackjack");
    blackjackMenu.AddItem("hit", "Hit");
    blackjackMenu.AddItem("stand", "Stand");

    if (CanPlayerSplit(client, g_iDecks[client]))
    {
        blackjackMenu.AddItem("split", "Split");
    }
    else 
    {
        blackjackMenu.AddItem("", "Split", ITEMDRAW_DISABLED);
    }
    blackjackMenu.ExitButton = false;
    blackjackMenu.Display(client, MENU_TIME_FOREVER);
}

void Finalize(int client)
{

    int totalWon;
    int scoreHandOne;
    int scoreHandTwo;
    int scoreDealer;
    g_bInActiveGame[client] = false;
    DisplayHandsToClient(client, g_iDecks[client], true);

    // Deal the rest of the cards to the Dealer
    while (ScoreHand(DEALER, g_iDecks[client]) < 17)
    {
        DealCard(DEALER, g_iDecks[client]);
    }

    scoreDealer = ScoreHand(DEALER, g_iDecks[client]);
    scoreHandOne = ScoreHand(HAND_ONE, g_iDecks[client]);
    if (g_bPlayerSplit[client])
        scoreHandTwo = ScoreHand(HAND_TWO, g_iDecks[client]);


    DisplayHandsToClient(client, g_iDecks[client], true);

    // If the Dealer busts
    if (scoreDealer > 21)
    {
        PrintToChat(client, "%s %t", PREFIX, "DealerBust");
        // If the player has split
        if (g_bPlayerSplit[client])
        {
            if (scoreHandOne <= 21)
            {
                GiveClientCredits(client, g_iBids[client] * 2);
                totalWon += g_iBids[client];
            }
            if (scoreHandTwo <= 21)
            {
                GiveClientCredits(client, g_iBids[client] * 2);
                totalWon += g_iBids[client];
            }
            PrintToChat(client, "%s %t", PREFIX, "PlayerWonCredits", totalWon, Store_GetClientCredits(client));

        }
        // If the player has not split
        else 
        {
            if (ScoreHand(HAND_ONE, g_iDecks[client]) <= 21)
            {
                GiveClientCredits(client, g_iBids[client] * 2);
                totalWon += g_iBids[client];
                PrintToChat(client, "%s %t", PREFIX, "PlayerWonCredits", totalWon, Store_GetClientCredits(client));
            }
        }
    }
    // Otherwise, math
    else
    {
        // If the player split, look at each hand
        if (g_bPlayerSplit[client])
        {
            bool didEitherHandWin = false;
            bool didEitherHandTie = false;
            // If HandOne won
            if ((scoreHandOne > scoreDealer) && (scoreHandOne <= 21))
            {
                didEitherHandWin = true;
                GiveClientCredits(client, g_iBids[client] * 2);
                totalWon += g_iBids[client];
            }
            // If HandOne tied
            else if ((scoreHandOne == scoreDealer) && (scoreHandOne <= 21))
            {
                didEitherHandTie = true;
                PrintToChat(client, "%s %t", PREFIX, "SplitHandOnePush");
                GiveClientCredits(client, g_iBids[client]);
            }

            // If HandTwo won
            if ((scoreHandTwo > scoreDealer) && (scoreHandTwo <= 21))
            {
                didEitherHandWin = true;
                GiveClientCredits(client, g_iBids[client] * 2);
                totalWon += g_iBids[client];
            }
            // If HandTwo tied
            else if ((scoreHandTwo == scoreDealer) && (scoreHandTwo <= 21))
            {
                didEitherHandTie = true;
                PrintToChat(client, "%s %t", PREFIX, "SplitHandTwoPush");
                GiveClientCredits(client, g_iBids[client]);
            }

            if (didEitherHandWin)
            {
                PrintToChat(client, "%s %t", PREFIX, "PlayerWonCredits", totalWon, Store_GetClientCredits(client));
            }

            if (!didEitherHandWin && !didEitherHandTie)
            {
                PrintToChat(client, "%s %t", PREFIX, "SplitHandDealerWon");
            }



        }
        // Player only had one hand
        else 
        {
            // If HandOne won
            if ((scoreHandOne > scoreDealer) && (scoreHandOne <= 21))
            {
                GiveClientCredits(client, g_iBids[client] * 2);
                totalWon += g_iBids[client];
                PrintToChat(client, "%s %t", PREFIX, "PlayerWonCredits", totalWon, Store_GetClientCredits(client));
            }
            // If HandOne tied
            else if ((scoreHandOne == scoreDealer) && (scoreHandOne <= 21))
            {
                PrintToChat(client, "%s %t", PREFIX, "SingleHandPush");
                GiveClientCredits(client, g_iBids[client]);
            }
            else
            {
                PrintToChat(client, "%s %t", PREFIX, "SingleHandDealerWon");
            }
        }

    }

}

///////////////////////////////////////////////////////////////////////////////
// Command Functions
///////////////////////////////////////////////////////////////////////////////
public Action Command_Blackjack(int client, int args)
{

    // If the player was already in an active game
    if (g_bInActiveGame[client])
    {
        PrintToChat(client, "%s %t", PREFIX, "ResumePreviousGame");
        DisplayBlackjackMenu(client);
        return Plugin_Handled;
    }


    int tmpbid = g_Cvar_Minimum_Bid.IntValue;
    int clientCredits = Store_GetClientCredits(client);

    // If an argument is supplied, use that as the bid. Otherwise, assume
    // the client is using a minimum bid of 50
    if (args == 1)
    {
        char buf[64];
        GetCmdArg(1, buf, sizeof(buf));
        tmpbid = StringToInt(buf);

        // Validate that the bid is within range(min_bid, max_bid)
        if (tmpbid < g_Cvar_Minimum_Bid.IntValue || tmpbid > g_Cvar_Maximum_Bid.IntValue)
        {
            PrintToChat(client, "%s %t", PREFIX, "BidRequirements", g_Cvar_Minimum_Bid.IntValue, g_Cvar_Maximum_Bid.IntValue);
            return Plugin_Handled;
        }

    }
    else if (args > 1)
    {
        PrintToChat(client, "%s Usage: sm_blackjack OR sm_blackjack <amount>", PREFIX);
        return Plugin_Handled;
    }

    if (clientCredits < tmpbid)
    {
        PrintToChat(client, "%s %t", PREFIX, "NotEnoughCredits", clientCredits);
        return Plugin_Handled;
    }

    g_iBids[client] = tmpbid;
    PrintToChat(client, "%s %t", PREFIX, "BeginGame", g_iBids[client]);
    GiveClientCredits(client, -g_iBids[client]);
    g_bInActiveGame[client] = true;

    // Verify that the deck is "new"
    ClearDeck(g_iDecks[client]);
    g_bPlayerSplit[client] = false;
    g_iCurrentHand[client] = HAND_ONE;

    // Deal out cards
    InitializeHand(HAND_ONE, g_iDecks[client]);
    InitializeHand(DEALER, g_iDecks[client]);

    DisplayHandsToClient(client, g_iDecks[client]);
    
    // If the player has Blackjack...
    if (ScoreHand(HAND_ONE, g_iDecks[client]) == 21)
    {
        DisplayHandsToClient(client, g_iDecks[client], true);
        if (ScoreHand(DEALER, g_iDecks[client]) == 21)
        {
            PrintToChat(client, "%s %t", PREFIX, "DealerAndPlayerBlackjack");
            GiveClientCredits(client, g_iBids[client]);
            g_bInActiveGame[client] = false;
            return Plugin_Handled;
        }
        else 
        {
            GiveClientCredits(client, RoundFloat(g_iBids[client] * 2.5));
            PrintToChat(client, "%s %t", PREFIX, "PlayerBlackjack", RoundFloat(g_iBids[client] * 1.5));
            g_bInActiveGame[client] = false;
            return Plugin_Handled;
        }
    }
    // Dealer got Blackjack and won
    if (ScoreHand(DEALER, g_iDecks[client]) == 21)
    {
        DisplayHandsToClient(client, g_iDecks[client], true);
        PrintToChat(client, "%s %t", PREFIX, "DealerBlackjack");
        g_bInActiveGame[client] = false;
        return Plugin_Handled;
    }

    DisplayBlackjackMenu(client);

    return Plugin_Handled;

}


///////////////////////////////////////////////////////////////////////////////
// Menu Handler
///////////////////////////////////////////////////////////////////////////////
public int Menu_Blackjack(Menu blackjackMenu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char selection[32];
            blackjackMenu.GetItem(param2, selection, sizeof(selection));

            if (StrEqual(selection, "hit"))
            {
                DealCard(g_iCurrentHand[param1], g_iDecks[param1]);
                // If the user has busted
                if (ScoreHand(g_iCurrentHand[param1], g_iDecks[param1]) > 21)
                {
                    // If the user has another hand
                    if (g_bPlayerSplit[param1] && g_iCurrentHand[param1] == HAND_ONE)
                    {
                        g_iCurrentHand[param1] = HAND_TWO;
                        PrintToChat(param1, "%s %t", PREFIX, "SplitHandOneBust");
                        DisplayHandsToClient(param1, g_iDecks[param1]);
                        DisplayBlackjackMenu(param1);
                    }
                    // If the user is on their second hand
                    else if(g_bPlayerSplit[param1] && g_iCurrentHand[param1] == HAND_TWO)
                    {
                        PrintToChat(param1, "%s %t", PREFIX, "SplitHandTwoBust");
                        Finalize(param1);
                        // TODO: Finalize everything
                    }
                    // The user busted on their only hand
                    else if (!g_bPlayerSplit[param1])
                    {
                        DisplayHandsToClient(param1, g_iDecks[param1], true);
                        PrintToChat(param1, "%s %t", PREFIX, "SingleHandBust");
                        g_bInActiveGame[param1] = false;
                    }
                }
                else if (ScoreHand(g_iCurrentHand[param1], g_iDecks[param1]) == 21)
                {
                    // If the user has another hand
                    if (g_bPlayerSplit[param1] && g_iCurrentHand[param1] == HAND_ONE)
                    {
                        g_iCurrentHand[param1] = HAND_TWO;
                        PrintToChat(param1, "%s %t", PREFIX, "SplitHandOne21");
                        DisplayHandsToClient(param1, g_iDecks[param1]);
                        DisplayBlackjackMenu(param1);
                    }
                    if (g_bPlayerSplit[param1] && g_iCurrentHand[param1] == HAND_TWO)
                    {
                        PrintToChat(param1, "%s %t", PREFIX, "SplitHandTwo21");
                        Finalize(param1);
                    }
                    // Else if the user has not split
                    if (!g_bPlayerSplit[param1] && g_iCurrentHand[param1] == HAND_ONE)
                    {
                        Finalize(param1);
                    }
                }
                else 
                {
                    DisplayHandsToClient(param1, g_iDecks[param1]);
                    DisplayBlackjackMenu(param1);
                }
            }
            else if (StrEqual(selection, "stand"))
            {
                // If they split and are still on hand one
                if (g_bPlayerSplit[param1] && g_iCurrentHand[param1] == HAND_ONE)
                {
                    g_iCurrentHand[param1] = HAND_TWO;
                    DisplayHandsToClient(param1, g_iDecks[param1]);
                    DisplayBlackjackMenu(param1);
                }
                // Otherwise, finalize everything
                else
                {
                    Finalize(param1);
                }
            }
            else if (StrEqual(selection, "split"))
            {
                SplitHand(param1);
                DealCard(HAND_ONE, g_iDecks[param1]);
                DealCard(HAND_TWO, g_iDecks[param1]);
                DisplayHandsToClient(param1, g_iDecks[param1]);
                DisplayBlackjackMenu(param1);
            }

        }
        case MenuAction_Cancel:
        {
            PrintToServer("Client %d's menu was cancelled: Reason %d", param1, param2);
        }
        case MenuAction_End:
        {
            delete blackjackMenu;
        }
    }
}

///////////////////////////////////////////////////////////////////////////////
// Event Handler
///////////////////////////////////////////////////////////////////////////////
public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    g_bInActiveGame[client] = false;
}