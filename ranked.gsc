#include common_scripts\utility;
#include maps\mp\_utility;
#include maps\mp\zombies\_zm_utility;

main()
{
	if ( GetDvarInt( "scr_disablePlutoniumFixes" ) )
	{
		return;
	}

	if ( isDedicated() )
	{
		// fix menuresponse exploits
		replaceFunc( GetFunction( "maps/mp/gametypes_zm/_zm_gametype", "menu_onmenuresponse" ), ::menu_onmenuresponse_fix, -1 );

		// fix player spawnpoints
		replaceFunc( GetFunction( "maps/mp/zombies/_zm", "getfreespawnpoint" ), ::getFreeSpawnpoint_override, -1 );

		// use coop revive
		level.using_solo_revive = false;
		replaceFunc( GetFunction( "maps/mp/zombies/_zm", "check_quickrevive_for_hotjoin" ), ::check_quickrevive_for_hotjoin_fix, -1 );

		// add a timeout for all_players_connected and kill solo revive
		replaceFunc( GetFunction( "maps/mp/zombies/_zm", "onallplayersready" ), ::onallplayersready_override, -1 );

		// make sure game is coop mode
		func = GetFunction( "maps/mp/zm_alcatraz_utility", "check_solo_status" );

		if ( !isDefined( func ) )
		{
			func = GetFunction( "maps/mp/zm_tomb_utility", "check_solo_status" );
		}

		if ( isDefined( func ) )
		{
			replaceFunc( func, ::check_solo_status_override, -1 );
		}

		// fix inert zombies spawning
		func = GetFunction( "maps/mp/zm_transit_classic", "spawn_inert_zombies" );

		if ( isDefined( func ) )
		{
			replaceFunc( func, ::spawn_inert_zombies_override, -1 );
		}

		// fix tombstone spawning
		func = GetFunction( "maps/mp/zm_transit_utility", "solo_tombstone_removal" );

		if ( isDefined( func ) )
		{
			replaceFunc( func, ::noop, -1 );
		}
	}

	// replaceFunc( GetFunction( "maps/mp/animscripts/zm_utility", "wait_network_frame" ), ::wait_network_frame_override, -1 );
	// replaceFunc( GetFunction( "maps/mp/zombies/_zm_utility", "wait_network_frame" ), ::wait_network_frame_override, -1 );
}

init()
{
	if ( GetDvarInt( "scr_disablePlutoniumFixes" ) )
	{
		return;
	}

	// enable 8 player zombie games
	level.player_too_many_players_check = false;

	if ( isDedicated() )
	{
		// fix ranking
		level thread upload_stats_on_round_end();
		level thread upload_stats_on_game_end();
		level thread upload_stats_on_player_connect();

		// fix teamchange exploit
		level.allow_teamchange = getgametypesetting( "allowInGameTeamChange" ) + "";
		SetDvar( "ui_allow_teamchange", level.allow_teamchange );
	}

	level thread watch_all_zombies();
}

watch_all_zombies()
{
	can_mantle_over_zambies = ( level.script == "zm_transit" || level.script == "zm_transit_dr" || level.script == "zm_prison" || level.script == "zm_nuked" || level.script == "zm_highrise" );

	for ( ;; )
	{
		zombies = getaiarray( level.zombie_team );

		foreach ( zombie in zombies )
		{
			if ( isDefined( zombie.pluto_audit ) )
			{
				continue;
			}

			zombie.pluto_audit = true;

			// fix jumping over zombies
			if ( isDedicated() && can_mantle_over_zambies )
			{
				zombie thread fix_zombie_physparams();
			}
		}

		wait 0.05;
	}
}

fix_zombie_physparams()
{
	self endon( "death" );

	if ( !is_true( self.completed_emerging_into_playable_area ) )
	{
		self waittill( "completed_emerging_into_playable_area" );
	}

	animname = self.animname;

	if ( !isDefined( animname ) )
	{
		animname = self.targetname;
	}

	if ( animname != "zombie" || !self.has_legs )
	{
		return;
	}

	self setphysparams( 15, 0, 60 );
}

upload_stats_on_round_end()
{
	level endon( "end_game" );

	for ( ;; )
	{
		level waittill( "end_of_round" );

		uploadstats();
	}
}

upload_stats_on_game_end()
{
	level waittill( "end_game" );

	uploadstats();
}

upload_stats_on_player_connect()
{
	level endon( "end_game" );

	for ( ;; )
	{
		level waittill( "connected" );

		level thread delay_uploadstats( 1 );
	}
}

delay_uploadstats( delay )
{
	level notify( "delay_uploadstats" );
	level endon( "delay_uploadstats" );

	level endon( "end_game" );

	wait delay;
	uploadstats();
}

check_quickrevive_for_hotjoin_fix( disconnecting_player )
{
	should_update = 0;
	solo_mode = 0;

	if ( flag( "solo_game" ) )
	{
		should_update = 1;
	}

	flag_clear( "solo_game" );

	level.using_solo_revive = solo_mode;
	level.revive_machine_is_solo = solo_mode;
	[[ GetFunction( "maps/mp/zombies/_zm", "set_default_laststand_pistol" ) ]]( solo_mode );

	if ( should_update && isdefined( level.quick_revive_machine ) )
	{
		[[ GetFunction( "maps/mp/zombies/_zm", "update_quick_revive" ) ]]( solo_mode );
	}
}

menu_onmenuresponse_fix()
{
	self endon( "disconnect" );

	for ( ;; )
	{
		self waittill( "menuresponse", menu, response );

		if ( response == "back" )
		{
			self closemenu();
			self closeingamemenu();

			if ( level.console )
			{
				if ( menu == game["menu_changeclass"] || menu == game["menu_changeclass_offline"] || menu == game["menu_team"] || menu == game["menu_controls"] )
				{
					if ( self.pers["team"] == "allies" )
					{
						self openmenu( game["menu_class"] );
					}

					if ( self.pers["team"] == "axis" )
					{
						self openmenu( game["menu_class"] );
					}
				}
			}

			continue;
		}

		if ( response == "changeteam" && level.allow_teamchange == "1" )
		{
			self closemenu();
			self closeingamemenu();
			self openmenu( game["menu_team"] );
		}

		if ( response == "changeclass_marines" )
		{
			self closemenu();
			self closeingamemenu();
			self openmenu( game["menu_changeclass_allies"] );
			continue;
		}

		if ( response == "changeclass_opfor" )
		{
			self closemenu();
			self closeingamemenu();
			self openmenu( game["menu_changeclass_axis"] );
			continue;
		}

		if ( response == "changeclass_wager" )
		{
			self closemenu();
			self closeingamemenu();
			self openmenu( game["menu_changeclass_wager"] );
			continue;
		}

		if ( response == "changeclass_custom" )
		{
			self closemenu();
			self closeingamemenu();
			self openmenu( game["menu_changeclass_custom"] );
			continue;
		}

		if ( response == "changeclass_barebones" )
		{
			self closemenu();
			self closeingamemenu();
			self openmenu( game["menu_changeclass_barebones"] );
			continue;
		}

		if ( response == "changeclass_marines_splitscreen" )
		{
			self openmenu( "changeclass_marines_splitscreen" );
		}

		if ( response == "changeclass_opfor_splitscreen" )
		{
			self openmenu( "changeclass_opfor_splitscreen" );
		}

		if ( menu == game["menu_team"] && level.allow_teamchange == "1" )
		{
			switch ( response )
			{
				case "allies":
					self [[ level.allies ]]();
					break;

				case "axis":
					self [[ level.teammenu ]]( response );
					break;

				case "autoassign":
					self [[ level.autoassign ]]( 1 );
					break;

				case "spectator":
					self [[ level.spectator ]]();
					break;
			}

			continue;
		}

		if ( menu == game["menu_changeclass"] || menu == game["menu_changeclass_offline"] || menu == game["menu_changeclass_wager"] || menu == game["menu_changeclass_custom"] || menu == game["menu_changeclass_barebones"] )
		{
			self closemenu();
			self closeingamemenu();

			if ( level.rankedmatch && issubstr( response, "custom" ) )
			{

			}

			self.selectedclass = 1;
			self [[ level.class ]]( response );
		}
	}
}

check_solo_status_override()
{
	level.is_forever_solo_game = false;
}

wait_network_frame_override()
{
	wait 0.05;
}

noop()
{
}

getFreeSpawnpoint_override( spawnpoints, player )
{
	if ( !isdefined( spawnpoints ) )
	{
/#
		iprintlnbold( "ZM >> No free spawn points in map" );
#/
		return undefined;
	}

	if ( !isdefined( game["spawns_randomized"] ) )
	{
		game["spawns_randomized"] = 1;
		spawnpoints = array_randomize( spawnpoints );
		random_chance = randomint( 100 );

		if ( random_chance > 50 )
		{
			set_game_var( "side_selection", 1 );
		}
		else
		{
			set_game_var( "side_selection", 2 );
		}
	}

	side_selection = get_game_var( "side_selection" );

	if ( get_game_var( "switchedsides" ) )
	{
		if ( side_selection == 2 )
		{
			side_selection = 1;
		}
		else if ( side_selection == 1 )
		{
			side_selection = 2;
		}
	}

	if ( isdefined( player ) && isdefined( player.team ) )
	{
		i = 0;

		while ( isdefined( spawnpoints ) && i < spawnpoints.size )
		{
			if ( side_selection == 1 )
			{
				if ( player.team != "allies" && ( isdefined( spawnpoints[i].script_int ) && spawnpoints[i].script_int == 1 ) )
				{
					arrayremovevalue( spawnpoints, spawnpoints[i] );
					i = 0;
				}
				else if ( player.team == "allies" && ( isdefined( spawnpoints[i].script_int ) && spawnpoints[i].script_int == 2 ) )
				{
					arrayremovevalue( spawnpoints, spawnpoints[i] );
					i = 0;
				}
				else
				{
					i++;
				}
			}
			else if ( player.team == "allies" && ( isdefined( spawnpoints[i].script_int ) && spawnpoints[i].script_int == 1 ) )
			{
				arrayremovevalue( spawnpoints, spawnpoints[i] );
				i = 0;
			}
			else if ( player.team != "allies" && ( isdefined( spawnpoints[i].script_int ) && spawnpoints[i].script_int == 2 ) )
			{
				arrayremovevalue( spawnpoints, spawnpoints[i] );
				i = 0;
			}
			else
			{
				i++;
			}
		}
	}

	max_clients = getdvarint( "sv_maxclients" );

	if ( !isdefined( self.playernum ) )
	{
		self.playernum = self getentitynumber();

		assert( self.playernum < max_clients );
	}

	for ( j = 0; j < spawnpoints.size; j++ )
	{
		if ( !isdefined( spawnpoints[j].en_num ) )
		{
			for ( m = 0; m < spawnpoints.size; m++ )
			{
				spawnpoints[m].en_num = m % max_clients;
			}
		}

		if ( spawnpoints[j].en_num == self.playernum )
		{
			return spawnpoints[j];
		}
	}

/#
	print( "getFreeSpawnpoint: no spawns found, use first spawn" );
#/
	assert( spawnpoints.size > 0 );
	return spawnpoints[0];
}

onallplayersready_override()
{
/#
	println( "ZM >> player_count_expected=" + getnumexpectedplayers() );
#/

	player_count_actual = 0;
	timeout_started = false;
	timeout_point = 0;

	while ( getnumexpectedplayers() == 0 || getnumconnectedplayers() < getnumexpectedplayers() || player_count_actual != getnumexpectedplayers() )
	{
		players = get_players();
		player_count_actual = 0;

		for ( i = 0; i < players.size; i++ )
		{
			players[i] freezecontrols( 1 );

			if ( players[i].sessionstate == "playing" )
			{
				player_count_actual++;
			}
		}

		if ( player_count_actual > 0 )
		{
			if ( !timeout_started )
			{
				timeout_started = true;
				timeout_point = ( getDvarFloat( "sv_connecttimeout" ) * 1000 ) + getTime();
			}

			if ( getTime() > timeout_point )
			{
				break;
			}
		}
		else
		{
			timeout_started = false;
		}

/#
		println( "ZM >> Num Connected =" + getnumconnectedplayers() + " Expected : " + getnumexpectedplayers() );
#/
		wait 0.1;
	}

	setinitialplayersconnected();

/#
	println( "ZM >> We have all players - START ZOMBIE LOGIC" );
#/

	flag_set( "initial_players_connected" );

	while ( !aretexturesloaded() )
	{
		wait 0.05;
	}

	thread [[ GetFunction( "maps/mp/zombies/_zm", "start_zombie_logic_in_x_sec" ) ]]( 3.0 );

	[[ GetFunction( "maps/mp/zombies/_zm", "fade_out_intro_screen_zm" ) ]]( 5.0, 1.5, 1 );
}

spawn_inert_zombies_override()
{
	flag_wait( "initial_players_connected" );

	func = GetFunction( "maps/mp/zm_transit_classic", "spawn_inert_zombies" );
	disableDetourOnce( func );
	self [[func]]();
}
