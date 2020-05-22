int _playerKills[MAXPLAYERS + 1];
int _playerDeaths[MAXPLAYERS + 1];
int _playerMoney[MAXPLAYERS + 1];
int _playerTimePlayed[MAXPLAYERS + 1];
bool _isAdmin[MAXPLAYERS + 1];
bool _useChatSound[MAXPLAYERS + 1];
bool _isGodmode[MAXPLAYERS + 1];
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

	property int Money {
		public get() { return _playerMoney[this.index]; }
		public set(int value) { _playerMoney[this.index] = value; }
	}

	property int TimePlayed {
		public get() { return _playerTimePlayed[this.index]; }
		public set(int value) { _playerTimePlayed[this.index] = value; }
	}

	property bool IsAdmin {
		public get() { return _isAdmin[this.index]; }
		public set(bool value) { _isAdmin[this.index] = value; }
	}

	property bool UseChatSound {
		public get() { return _useChatSound[this.index]; }
		public set(bool value) { _useChatSound[this.index] = value; }
	}

	property bool HasGodmode {
		public get() { return _isGodmode[this.index]; }
		public set(bool value) { _isGodmode[this.index] = value; }
	}

	property Handle Hud {
		public get() { return _playerHud[this.index]; }
		public set(Handle value) { _playerHud[this.index] = value; }
	}
}