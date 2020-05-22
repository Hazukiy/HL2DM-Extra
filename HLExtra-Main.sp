#include <sourcemod>
#include <sdktools>
#include <morecolors>

#include "HLExtra-Player.sp"

//Terminate
#pragma semicolon 1
#pragma newdecls required

static char _pluginVersion[] = "1.0.0.1";
static char _ownerID[] = "[U:1:13299075]";
static char _chatPrefix[] = "[HL2DM-Ex]";


static char _databaseName[] = "HL2DMExtra";
static char _playerTableName[] = "Players";
static Handle _databaseHandle;

int _serverUptime;
Handle _serverUptimeTimer;

public Plugin myinfo = {
	name        = "HL2DM Extra",
	author      = "SirTiggs",
	description = "Provices more functionality to the base game",
	version     = _pluginVersion,
	url         = "https://github.com/Hazukiy/HL2DM-Extra"
};


//* REGION Forwards *//
public void OnPluginStart() {
	//Client commands
	RegConsoleCmd("sm_chatsound", Command_ChatSound, "Enables chat sound.");
	RegConsoleCmd("sm_store", Command_Store, "Opens the store.");
	RegConsoleCmd("sm_buy", Command_BuyFromStore, "Buy an item from the store.");

	//Admin commands
	RegAdminCmd("sm_reload", Command_ReloadServer, ADMFLAG_ROOT, "Reloads the server.");
	RegAdminCmd("sm_getauth", Command_GetAuth, ADMFLAG_ROOT, "Returns client auth id.");
	RegAdminCmd("sm_testsound", Command_TestSound, ADMFLAG_ROOT, "Returns client auth id.");

	//Hooks
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_connect", Event_PlayerConnect, EventHookMode_Pre);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);

	//Downloads table
	AddFileToDownloadsTable("sound/hitmarker.mp3");

	//Precache sounds
	bool cacheResult1 = PrecacheSound("hitmarker.mp3", true);

	if(cacheResult1) {
		PrintToServer("[HL2DM-Extra] - Precache result for hitmarker passed.");
	}
	else {
		PrintToServer("[HL2DM-Extra] - Precache result for hitmarker failed.");
	}

	//Override chat
	AddCommandListener(Event_PlayerChat, "say");

	//Initialise SQL
	SQL_Initialise();
}

public void OnMapStart() {
	_serverUptimeTimer = CreateTimer(1.0, Timer_CalculateUptime,_,TIMER_REPEAT);
}

public void OnMapEnd() {
	CloseHandle(_serverUptimeTimer);
	CloseHandle(_databaseHandle);
}

public void OnClientPostAdminCheck(int client) {	
	if(IsClientConnected(client) && IsClientInGame(client)) {
		//Load player
		SQL_Load(client);
	}
}

public void OnClientDisconnect(int client) {
	Player player = Player(client);

	//Save the player
	SQL_Save(client);

	CloseHandle(player.Hud);
}
//* REGIONEND Forwards *//





//* REGION EventHandlers *//
public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	static int victim = 0, attacker = 0;
	char victimName[32], attackerName[32], weapon[255];

	victim = GetClientOfUserId(event.GetInt("userid", 0));
	attacker = GetClientOfUserId(event.GetInt("attacker", 0));

	if (victim == 0) return Plugin_Handled;
	if (attacker == 0) return Plugin_Handled; 

	if(victim == attacker) {
		CPrintToChat(victim, "{purple}%s{gold} You killed yourself.", _chatPrefix);
		return Plugin_Handled;
	}

	//Get the weapon used 
	event.GetString("weapon", weapon, sizeof(weapon));

	//Victim
	if(IsClientConnected(victim)) {
		if(!IsClientInGame(attacker)) {
			CPrintToChat(victim, "{purple}%s{gold} You've been killed.", _chatPrefix);
			return Plugin_Handled;
		}

		int healthLeft = GetClientHealth(attacker);
		GetClientName(attacker, attackerName, sizeof(attackerName));

		CPrintToChat(victim, "{purple}%s{gold} You've been killed with a {red}%s{gold} by {red}%s{gold} ({green}%d/100 hp{gold})", _chatPrefix, weapon, attackerName, healthLeft);
		IncreaseDeaths(victim);
		SQL_Save(victim);
	}

	//Attacker
	if(IsClientConnected(attacker)) {
		GetClientName(victim, victimName, sizeof(victimName));

		int money = CalculateMoneyReward(attacker, weapon);

		CPrintToChat(attacker, "{purple}%s{gold} You killed player {red}%s{gold} earning {green}$%d", _chatPrefix, victimName, money);
		IncreaseKills(attacker);
		SQL_Save(attacker);
	}

	return Plugin_Continue;
}

public Action Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast) {
	char clientName[32], networkID[32], ipAddress[32];

	event.GetString("name", clientName, sizeof(clientName));
	event.GetString("networkid", networkID, sizeof(networkID));
	event.GetString("address", ipAddress, sizeof(ipAddress));

	//Output
	CPrintToChatAll("{purple}%s{gold} {red}%s{gold} has connected to the server.", _chatPrefix, clientName);
	PrintToServer("Player %s connected: IP = %s | SteamID = %s", clientName, ipAddress, networkID);

	event.BroadcastDisabled = true;
	dontBroadcast = true;
	return Plugin_Handled;
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
	char playerName[32], reason[32], networkID[32];
	event.GetString("name", playerName, sizeof(playerName));
	event.GetString("reason", reason, sizeof(reason));
	event.GetString("networkID", networkID, sizeof(networkID));

	CPrintToChatAll("{purple}%s{gold} {red}%s{gold} has disconnected from the server.", _chatPrefix, playerName);
	PrintToServer("Player %s disconnected: SteamID = %s | Reason: %s", playerName, networkID, reason);

	event.BroadcastDisabled = true;
	dontBroadcast = true;
	return Plugin_Continue;
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) {
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));

	//Play sound to attacker
	if(attacker > 0) {
		EmitSoundToClient(attacker, "hitmarker.mp3", SOUND_FROM_PLAYER, SNDCHAN_STATIC, 100);
	}

	//Play sound to victim
	if(victim > 0) {
		EmitSoundToClient(victim, "hitmarker.mp3", SOUND_FROM_PLAYER, SNDCHAN_STATIC, 100);
	}

	return Plugin_Handled;
}

public Action Event_PlayerChat(int client, const char[] command, int args) {
	char message[512], clientName[32], authID[32];

	GetCmdArg(1, message, sizeof(message));
	GetClientName(client, clientName, sizeof(clientName));
	GetClientAuthId(client, AuthId_Steam3, authID, sizeof(authID));
	
	if(message[0] == '/') return Plugin_Handled;

	for(int i = 1; i < MaxClients + 1; i++){
		if(IsClientConnected(i) && IsClientInGame(i)){
			Player player = Player(i);		
			if(player.UseChatSound) {
				ClientCommand(i, "play %s", "Friends/friend_join.wav");
			}
		}
	}

	Player player = Player(client);
	if(player.IsAdmin) {
		CPrintToChatAll("{gold}%d|{red}Owner{gold}|{cyan}%s: {gold}%s", client, clientName, message);
	}
	else {
		CPrintToChatAll("{gold}%d|{white}Player{gold}|{cyan}%s: {gold}%s", client, clientName, message);
	}
	return Plugin_Handled;
}
//* REGIONEND EventHandlers *//



//* REGION Commands *//
public Action Command_ChatSound(int client, int args) {
	Player player = Player(client);
	if(player.UseChatSound) {
		player.UseChatSound = false;
		CPrintToChat(client, "{purple}%s{gold} Your chat sounds have been {red}disabled.", _chatPrefix);
	}
	else {
		player.UseChatSound = true;
		CPrintToChat(client, "{purple}%s{gold} Your chat sounds have been {green}enabled.", _chatPrefix);
	}

	return Plugin_Handled;
}

public Action Command_GetAuth(int client, int args) {
	char authID[255];
	GetClientAuthId(client, AuthId_Steam3, authID, sizeof(authID));

	CPrintToChat(client, "{purple}%s{gold} Your auth is: {green}%s", _chatPrefix, authID);

	return Plugin_Handled;
}

public Action Command_ReloadServer(int client, int args) {
	char mapName[32], playerName[32], format[255], ip[12], auth[32];

	GetCurrentMap(mapName, sizeof(mapName));
	GetClientName(client, playerName, sizeof(playerName));
	GetClientIP(client, ip, sizeof(ip), false);
	GetClientAuthId(client, AuthId_Steam3, auth, sizeof(auth));

	Format(format, sizeof(format), "Server reloaded by user %s(%s): %s", playerName, ip, auth);
	LogMessage(format);
	ForceChangeLevel(mapName, format);
	return Plugin_Handled;
}

public Action Command_TestSound(int client, int args) {
	EmitSoundToClient(client, "hitmarker.mp3", SOUND_FROM_PLAYER, SNDCHAN_STATIC, 100);
	return Plugin_Handled;
}

public Action Command_Store(int client, int args) {
	//TODO
	return Plugin_Handled;
}

public Action Command_BuyFromStore(int client, int args) {
	//TODO
	return Plugin_Handled;
}

//* REGIONEND Commands *//




//* REGION SQL Database *//
static void SQL_InsertNewPlayer(int client) {
	char query[250], playerAuth[32];

	GetClientAuthId(client, AuthId_Steam3, playerAuth, sizeof(playerAuth));

	Format(query, sizeof(query), "INSERT INTO %s ('ID') VALUES ('%s')", _playerTableName, playerAuth);

	SQL_TQuery(_databaseHandle, SQL_InsertCallback, query, client);

	PrintToServer("%s Successfully inserted new profile: %s", _chatPrefix, playerAuth);
}

static void SQL_Load(int client) {
	char query[200], playerAuth[32];

	GetClientAuthId(client, AuthId_Steam3, playerAuth, sizeof(playerAuth));

	Format(query, sizeof(query), "SELECT * FROM `%s` WHERE `ID` = '%s'", _playerTableName, playerAuth);

	SQL_TQuery(_databaseHandle, SQL_LoadCallback, query, client);

	PrintToServer("%s Profile %s loaded.", _chatPrefix, playerAuth);
}

static void SQL_Save(int client) {
	char query[200], playerAuth[32];

	if(IsClientInGame(client)) {
		GetClientAuthId(client, AuthId_Steam3, playerAuth, sizeof(playerAuth));

		Player player = Player(client);

		Format(query, sizeof(query), "UPDATE %s SET Kills = '%i', Deaths = '%i', Money = '%i', TimePlayed = '%i', IsAdmin = '%i' WHERE ID = '%s'", _playerTableName, player.Kills, player.Deaths, player.Money, player.TimePlayed, BoolToBit(player.IsAdmin), playerAuth);
		
		SQL_TQuery(_databaseHandle, SQL_GenericTQueryCallback, query);
	}
}

static void SQL_Initialise() {
	char error[200];

	_databaseHandle = SQLite_UseDatabase(_databaseName, error, sizeof(error));
	if(_databaseHandle == null) {
		PrintToServer("%s Error at SQL_Initialise: %s", _chatPrefix, error);
		LogError("%s Error at SQL_Initialise: %s", _chatPrefix, error);
	}
	else {
		SQL_CreatePlayerTable();
	}
}

static Action SQL_CreatePlayerTable() {
	char query[600];
	Format(query, sizeof(query), "CREATE TABLE IF NOT EXISTS '%s' ('ID' VARCHAR(32), Kills INT(9) NOT NULL DEFAULT 0, Deaths INT(9) NOT NULL DEFAULT 0, Money INT(9) NOT NULL DEFAULT 0, TimePlayed INT(9) NOT NULL DEFAULT 0, IsAdmin BIT NOT NULL DEFAULT 0)", _playerTableName);
	SQL_TQuery(_databaseHandle, SQL_GenericTQueryCallback, query);
	return Plugin_Handled;
}

static void SQL_LoadCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if(hndl != null) {
		if(!SQL_GetRowCount(hndl)) {
			SQL_InsertNewPlayer(data);
		}
		else {
			char authID[32];

			GetClientAuthId(data, AuthId_Steam3, authID, sizeof(authID));

			//Load in db values
			Player player = Player(data);
			player.Kills = SQL_FetchInt(hndl, 1);
			player.Deaths = SQL_FetchInt(hndl, 2);
			player.Money = SQL_FetchInt(hndl, 3);
			player.TimePlayed = SQL_FetchInt(hndl, 4);
			player.IsAdmin = BitToBool(SQL_FetchInt(hndl, 5));
			
			//Non-db locals
			player.UseChatSound = true;
			player.HasGodmode = false;

			if(StrEqual(authID, _ownerID)) {
				player.IsAdmin = true;
			}
			else {
				player.IsAdmin = false;
			}
			
			player.Hud = CreateTimer(1.0, Timer_RenderHud, data, TIMER_REPEAT);
		}
	}
	else {
		PrintToServer("%s Found error on LoadPlayer: %s", _chatPrefix, error);
		LogError("%s Found error on LoadPlayer: %s", _chatPrefix, error);
		return;
	}
}

static void SQL_InsertCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if(hndl != null) {
		SQL_Load(data);
	}
	else {
		PrintToServer("%s Error at SQL_InsertCallback: %s", _chatPrefix, error);
		LogError("%s Error at SQL_InsertCallback: %s", _chatPrefix, error);
	}
}

static void SQL_GenericTQueryCallback(Handle owner, Handle hndl, const char[] error, any data) {
	if(hndl == null) {
		PrintToServer("%s Error at SQL_GenericTQueryCallback: %s", _chatPrefix, error);
		LogError("%s Error at SQL_GenericTQueryCallback: %s", _chatPrefix, error);
	}
}
//* REGIONEND SQL Database *//



//* REGION TIMERS *//
public Action Timer_RenderHud(Handle timer, any client) {
	if(IsClientConnected(client) && IsClientInGame(client)) {
		char uptimeText[100], timePlayedText[100], hudText[250];

		//Update player time
		Player player = Player(client);
		player.TimePlayed++;

		//Format times
		FormatTime(uptimeText, sizeof(uptimeText), "Server Uptime: %H Hours %M Minutes %S Seconds", GetServerUptime());
		FormatTime(timePlayedText, sizeof(timePlayedText), "Time Played: %H Hours %M Minutes", player.TimePlayed);

		SetHudTextParams(0.015, -0.95, 1.0, 0, 217, 255, 255, 0);
		ShowHudText(client, -1, "%s\n%s", uptimeText, timePlayedText);

		Format(hudText, sizeof(hudText), "Kills: %d\nDeaths: %d\nMoney: $%d", player.Kills, player.Deaths, player.Money);
		SetHudTextParams(0.015, -0.80, 1.0, 0, 212, 89, 255, 0);
		ShowHudText(client, -1, hudText);
	}
	return Plugin_Continue;
}

public Action Timer_CalculateUptime(Handle timer) {
	_serverUptime++;
	return Plugin_Continue;
}
//* REGIONEND TIMERS *//




public void IncreaseDeaths(int client) {
	Player player = Player(client);
	player.Deaths++;
}

public void IncreaseKills(int client) {
	Player player = Player(client);
	player.Kills++;
}

public int CalculateMoneyReward(int client, char[] weapon) {
	int killValue = 0;

	//Get value based on weapon
	if(StrContains(weapon, "crowbar") || StrContains(weapon, "stunstick")) {
		killValue = GetRandomInt(20, 30);
	}
	else if(StrContains(weapon, "357") || StrContains(weapon, "crossbow")) {
		killValue = GetRandomInt(40, 50);
	}
	else if(StrContains(weapon, "ar2") || StrContains(weapon, "smg") || StrContains(weapon, "shotgun")) {
		killValue = GetRandomInt(10, 20);
	}
	else if(StrContains(weapon, "frag") || StrContains(weapon, "rpg")) {
		killValue = GetRandomInt(10, 20); 
	}
	else if(StrContains(weapon, "physcannon")) {
		killValue = GetRandomInt(60, 70);
	}
	else if (StrContains(weapon, "pistol")) {
		killValue = GetRandomInt(40, 50);
	}
	else {
		killValue = GetRandomInt(10, 20);
	}

	//Update player model
	Player player = Player(client);
	player.Money += killValue;

	return killValue;
}

stock int GetServerUptime() {
	return _serverUptime;
}

stock bool BitToBool(int val) {
	if(val == 0) {
		return false;
	}
	else {
		return true;
	}
}

stock int BoolToBit(bool val) {
	if(val) {
		return 1;
	}
	else {
		return 0;
	}
}