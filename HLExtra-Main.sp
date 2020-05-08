#include <sourcemod>
#include <sdktools>
#include <morecolors>

//Terminate
#pragma semicolon 1
#pragma newdecls required

static char _pluginVersion[] = "1.0.0.0";
static char _ownerID[] = "[U:1:13299075]";

int _playerKills[MAXPLAYERS + 1];
int _playerDeaths[MAXPLAYERS + 1];
int _playerScore[MAXPLAYERS + 1];
bool _hasPassiveEnabled[MAXPLAYERS + 1];
bool _isAdmin[MAXPLAYERS + 1];
bool _useChatSound[MAXPLAYERS + 1];
Handle _playerHud[MAXPLAYERS + 1];
methodmap Player 
{	
	public Player(int index) {
		return view_as<Player>(index);
	}

	property int index {
		public get() { return view_as<int>(this); }
	}

	property int Kills {
		public get() { return _playerKills[this.index]; }
		public set(int value) { _playerKills[this.index] = value; }
	}

	property int Deaths {
		public get() { return _playerDeaths[this.index]; }
		public set(int value) { _playerDeaths[this.index] = value; }
	}

	property int Score {
		public get() { return _playerScore[this.index]; }
		public set(int value) { _playerScore[this.index] = value; }
	}

	property bool PassiveMode {
		public get() { return _hasPassiveEnabled[this.index]; }
		public set(bool value) { _hasPassiveEnabled[this.index] = value; }
	}

	property bool IsAdmin {
		public get() { return _isAdmin[this.index]; }
		public set(bool value) { _isAdmin[this.index] = value; }
	}

	property bool UseChatSound {
		public get() { return _useChatSound[this.index]; }
		public set(bool value) { _useChatSound[this.index] = value; }
	}

	property Handle Hud {
		public get() { return _playerHud[this.index]; }
		public set(Handle value) { _playerHud[this.index] = value; }
	}
}

public Plugin myinfo = {
	name        = "HL2DM Extra",
	author      = "SirTiggs",
	description = "Adds more functionality to the base game",
	version     = _pluginVersion,
	url         = "https://github.com/Hazukiy/HL2DM-Extra"
};

//FORWARDS
public void OnPluginStart() {
	//Client commands
	RegConsoleCmd("sm_ping", Command_PingPong, "Tests plugin functionality");
	RegConsoleCmd("sm_passive", Command_Passive, "Enables passive mode.");
	RegConsoleCmd("sm_chatsound", Command_ChatSound, "Enables chat sound.");

	//Admin commands
	RegAdminCmd("sm_reload", Command_ReloadServer, ADMFLAG_ROOT, "Reloads the server.");
	RegAdminCmd("sm_getauth", Command_GetAuth, ADMFLAG_ROOT, "Returns client auth id.");

	//Hooks
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_connect", Event_PlayerConnect, EventHookMode_Pre);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);

	//Override chat
	AddCommandListener(Event_PlayerChat, "say");
}

public Action Event_PlayerConnect(Event event, const char[] name, bool dontBroadcast) {
	char clientName[32], networkID[32], ipAddress[32];

	event.GetString("name", clientName, sizeof(clientName));
	event.GetString("networkid", networkID, sizeof(networkID));
	event.GetString("address", ipAddress, sizeof(ipAddress));

	//Output
	CPrintToChatAll("{green}%s{gold} %s (%s) has connected to the server.", clientName, networkID, ipAddress);

	event.BroadcastDisabled = true;
	dontBroadcast = true;
	return Plugin_Handled;
}


public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
	char playerName[32], reason[32], networkID[32];
	event.GetString("name", playerName, sizeof(playerName));
	event.GetString("reason", reason, sizeof(reason));
	event.GetString("networkID", networkID, sizeof(networkID));

	CPrintToChatAll("{red}%s{gold} %s has disconnected from the server. Reason: %s", playerName, networkID, reason);

	event.BroadcastDisabled = true;
	dontBroadcast = true;
	return Plugin_Continue;
}

public void OnClientPostAdminCheck(int client) {	
	if(IsClientConnected(client) && IsClientInGame(client)) {
		char authID[32];
		GetClientAuthId(client, AuthId_Steam3, authID, sizeof(authID));

		//Construct player datamap
		Player player = Player(client);
		player.Kills = 0;
		player.PassiveMode = false;
		player.UseChatSound = true;
		player.Hud = CreateTimer(1.0, ProcessHud, client, TIMER_REPEAT);

		if(StrEqual(authID, _ownerID)) {
			player.IsAdmin = true;
		}
		else {
			player.IsAdmin = false;
		}
	}
}

public Action Command_ChatSound(int client, int args) {
	Player player = Player(client);
	if(player.UseChatSound) {
		player.UseChatSound = false;
		CPrintToChat(client, "{gold}Chat sounds have been {red}disabled.");
	}
	else {
		player.UseChatSound = true;
		CPrintToChat(client, "{gold}Chat sounds have been {greenyellow}enabled.");
	}

	return Plugin_Handled;
}

public Action Command_GetAuth(int client, int args) {
	char authID[255];
	GetClientAuthId(client, AuthId_Steam3, authID, sizeof(authID));

	CPrintToChat(client, "Your auth is: %s", authID);

	return Plugin_Handled;
}

public Action Event_PlayerChat(int client, const char[] command, int args) {
	char time[24], message[512], clientName[32], authID[32];
	static int timeStamp = 0;
	
	GetCmdArg(1, message, sizeof(message));
	GetClientName(client, clientName, sizeof(clientName));
	GetClientAuthId(client, AuthId_Steam3, authID, sizeof(authID));
	
	if(message[0] == '/') return Plugin_Handled;

	timeStamp = GetTime();
	FormatTime(time, sizeof(time), "%H:%M:%S", timeStamp);

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
		CPrintToChatAll("{legendary}%s | ({red}Admin{legendary}) {green}%s: {gold}%s", time, clientName, message);
	}
	else {
		CPrintToChatAll("{legendary}%s | (Player) {green}%s: {gold}%s", time, clientName, message);
	}
	return Plugin_Handled;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	static int victim = 0, attacker = 0;
	char victimName[32], attackerName[32];

	victim = GetClientOfUserId(event.GetInt("userid", 0));
	attacker = GetClientOfUserId(event.GetInt("attacker", 0));

	if (victim == 0) return Plugin_Handled;
	if (attacker == 0) return Plugin_Handled; 

	if(victim == attacker) {
		CPrintToChat(victim, "You killed yourself.");
		return Plugin_Handled;
	}

	//Victim
	if(IsClientConnected(victim)) {
		if(!IsClientInGame(attacker)) {
			CPrintToChat(victim, "{gold}You've been killed.");
			return Plugin_Handled;
		}

		GetClientName(attacker, attackerName, sizeof(attackerName));
		CPrintToChat(victim, "{gold}You've been killed by {red}%s", attackerName);
		IncreaseDeaths(victim);
	}

	//Attacker
	if(IsClientConnected(attacker)) {
		GetClientName(victim, victimName, sizeof(victimName));
		CPrintToChat(attacker, "{gold}You've killed {greenyellow}%s", victimName);
		IncreaseKills(attacker);
	}

	return Plugin_Continue;
}

public void IncreaseDeaths(int client) {
	Player player = Player(client);
	player.Deaths++;

	CalculateScore(client);
}

public void IncreaseKills(int client) {
	Player player = Player(client);
	player.Kills++;

	CalculateScore(client);
}

public void CalculateScore(int client) {
	Player player = Player(client);

	if(player.Kills != 0 || player.Deaths != 0) {
		player.Score = player.Kills / player.Deaths;
	}
}

public Action OnGetGameDescription(char gameDesc[64]) {
	gameDesc = "HL2DM-Extra";
	return Plugin_Handled; 
}

public Action ProcessHud(Handle timer, any client) {
	if(IsClientInGame(client)) {
		char status[10], hudText[250];

		Player player = Player(client);

		if(player.PassiveMode) {
			status = "Enabled";
		}
		else {
			status = "Disabled";
		}

		Format(hudText, sizeof(hudText), "Kills: %d\nDeaths: %d\nScore: %d\nPassive Mode: %s", player.Kills, player.Deaths, player.Score, status);

		SetHudTextParams(0.015, -0.50, 1.0, 255, 209, 51, 255, 0);

		ShowHudText(client, -1, hudText);
	}
	return Plugin_Continue;
}

//Purpose: Enable & disable passive mode
public Action Command_Passive(int client, int args) {
	Player player = Player(client);
	if(player.PassiveMode) {
		player.PassiveMode = false;
		CPrintToChat(client, "{red}Passive mode disabled.");
	}
	else {
		player.PassiveMode = true;
		CPrintToChat(client, "{greenyellow}Passive mode enabled");
	}

	return Plugin_Handled;
}

//Test command
public Action Command_PingPong(int client, int args) {
	CPrintToChat(client, "{gold}Pong!");

	return Plugin_Handled;
}

public Action Command_ReloadServer(int client, int args) {
	char mapName[32], playerName[32], format[255], ip[12], auth[32];

	GetCurrentMap(mapName, sizeof(mapName));
	GetClientName(client, playerName, sizeof(playerName));
	GetClientIP(client, ip, sizeof(ip), false);
	GetClientAuthId(client, AuthId_Steam3, auth, sizeof(auth));

	//Maybe in future add a ~5 second delay before restarting
	Format(format, sizeof(format), "Server reloaded by user %s(%s): %s", playerName, ip, auth);
	LogMessage(format);
	ForceChangeLevel(mapName, format);
	return Plugin_Handled;
}