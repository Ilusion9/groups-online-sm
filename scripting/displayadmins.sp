#include <sourcemod>
#pragma newdecls required

public Plugin myinfo =
{
    name = "Display admins online",
    author = "Ilusion9",
    description = "Display online admins by groups",
    version = "1.0",
    url = "https://github.com/Ilusion9/"
};

enum struct GroupInfo
{
	char name[65];
	int flag;
}

ArrayList g_List_Groups;

public void OnPluginStart()
{
	g_List_Groups = new ArrayList(sizeof(GroupInfo));
	RegConsoleCmd("sm_admins", Command_Admins);
}

public void OnConfigsExecuted()
{
	g_List_Groups.Clear();
	
	char path[PLATFORM_MAX_PATH];	
	BuildPath(Path_SM, path, sizeof(path), "configs/displayadmins.cfg");
	KeyValues kv = new KeyValues("Display Admins"); 
	
	if (!kv.ImportFromFile(path))
	{
		LogError("The configuration file could not be read.");
		return;
	}
	
	GroupInfo group;
	AdminFlag flag;
	
	if (kv.GotoFirstSubKey(false))
	{
		do
		{
			kv.GetSectionName(group.name, sizeof(GroupInfo::name));
			char value[2];
			kv.GetString(NULL_STRING, value, sizeof(value));
			
			if (!FindFlagByChar(value[0], flag))
			{
				LogError("Invalid flag specified for group: %s", group.name);
				continue;
			}
			
			group.flag = FlagToBit(flag);
			g_List_Groups.PushArray(group);
			
		} while (kv.GotoNextKey(false));
	}
	
	delete kv;
}

public Action Command_Admins(int client, int args)
{
	GroupInfo group;
	bool adminDisplayed[MAXPLAYERS + 1];
	
	for (int i = 0; i < g_List_Groups.Length; i++)
	{
		char buffer[256];
		bool memberFound = false;
		
		g_List_Groups.GetArray(i, group);
		Format(buffer, sizeof(buffer), "%s:", group.name);
		
		for (int j = 1; j <= MaxClients; j++)
		{
			if (IsClientInGame(j))
			{
				if (!adminDisplayed[j])
				{
					if (CheckCommandAccess(j, "", group.flag, true))
					{
						memberFound = true;
						adminDisplayed[j] = true;
						Format(buffer, sizeof(buffer), "%s %N,", buffer, j);
					}
				}
			}
		}
		
		if (memberFound)
		{
			buffer[strlen(buffer) - 1] = 0;
			ReplyToCommand(client, "[SM] %s", buffer);
		}
	}
	
	return Plugin_Handled;
}
