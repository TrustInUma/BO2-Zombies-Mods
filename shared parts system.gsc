/*
"Scavenger Project" - TranZit / Die Rise / Buried
v1.9

Created by: NickB_05

 This script lets you carry all the buildable pieces from the maps
 in the Victis group, similar to the piece-carrying system used
 in Mob, Origins, and BO3.

 My goal is for the piece-carrying system to be as close as possible
 to the one in Mob and Origins, including similar interface elements
 and showing the pieces on the scoreboard; for now that's not the
 case, since I'm still learning how to implement the interface, but
 at least the concept is 100% faithful to the original.

 The only pieces that can't all be carried at once are the liquor,
 the candy, and the weapon chalks; this is mainly to preserve the
 mechanics and... because I have a few ideas
 for the elevator key... enjoy the script!

 NOTICE: If you're going to use this script for another project, please
 give credit for this work, since it took at least a month to finish.

v1.1 Patch Fixes made by: SyntaXError
v1.2 Patch Fixes made by: NickB_05
v1.3 Patch Fixes and v1.4 for multiplayer made by: NickB_05
v1.5 and v1.6 Leaderboard Update made by: NickB_05
v1.7 Elevator Key Update made by: NickB_05
v1.8 Elevator Key Patch Fixes made by: NickB_05
v1.9 Patch Fixes made by: NickB_05
*/

#include maps\mp\zombies\_zm_buildables;
#include maps\mp\zombies\_zm_weapons;
#include maps\mp\zombies\_zm_utility;
#include maps\mp\gametypes_zm\_hud_util;
#include maps\mp\_utility;

#define MC_BUILD_RADIUS_SQ 7000 // horizontal distance (X/Y) for most buildable areas
#define MC_BUILD_RADIUS_SQ_TIGHT 2500 // Hatch/ladder/plow: placed closer together to avoid overlapping the window repair zone or other nearby elements
#define MC_HEIGHT_TOLERANCE 82 // Maximum allowed height difference (Z): filters out different levels (usually separated by 128 units or more) without interfering with standard building
#define MC_DEFAULT_BUILD_TIME 3000 // ms, used if the stub doesn't bring its own use time

#define MC_TAB_SQUARE_X 91  // horizontal position (from the top-left corner, 640 scale)
#define MC_TAB_SQUARE_Y 97 // base vertical position: no pieces, or buildable already built
#define MC_TAB_SQUARE_Y_ACTIVE 87 // vertical position when that slot has >=1 piece and is not built
#define MC_TAB_SQUARE_SIZE 29 // width/height of each black square (lower this number to shrink it)
#define MC_TAB_BORDER_PAD 2 // thickness of the gray border on each side of the square
#define MC_TAB_SLOT_GAP 6 // horizontal spacing between squares in the row
#define MC_TAB_CHECK_SIZE 10 // size of the checkmark (zm_hud_icon_sq_scafold) in the bottom-right corner
#define MC_TAB_LOCK_SIZE 10 // size of the red cross (zm_hud_icon_fan) when the buildable is locked by its pair (gallows/guillotine)

#define MC_NAVCARD_X 634 // horizontal position of the navcard square (tip opposite the row)
#define MC_NAVCARD_Y 97 // vertical position of the navcard square

#define MC_KEY_COOLDOWN_MS 15000 // ms of wait per player between uses of the Elevator Key
#define MC_KEY_INSERT_TIME 500 // ms it takes to insert the Elevator Key (hold [use])

init()
{
    map = getdvar( "mapname" );

    if ( (map == "zm_transit" && !is_classic()) || (map != "zm_transit" && map != "zm_highrise" && map != "zm_buried") )
        return;

    precacheshader( "zm_hud_icon_sq_scafold" );
    precacheshader( "zm_hud_icon_sq_tranceiver" );
    precacheshader( "zm_hud_icon_fan" );
    precacheshader( "zom_hud_icon_epod_key" );
    precacheshader( "zm_hud_icon_panel" );
    precacheshader( "zm_hud_icon_papbody" );

    if ( map == "zm_buried" )
    {
        func = getfunction( "maps/mp/zombies/_zm_buildables_pooled", "pooledbuildable_stub_for_piece" );
        if ( isdefined( func ) )
        {
            replacefunc( func, ::custom_pooledbuildable_stub_for_piece );
        }
    }

    func = getfunction( "maps/mp/zombies/_zm_buildables", "player_can_take_piece" );
    if ( isdefined( func ) )
    {
        replacefunc( func, ::mc_player_can_take_piece );
    }

    level.mc_is_buried = ( map == "zm_buried" );

    level.mc_elevator_is_on_floor_func = undefined;
    level.mc_elevator_level_for_floor_func = undefined;

    if ( map == "zm_highrise" )
    {
        level.mc_elevator_is_on_floor_func = getfunction( "maps/mp/zm_highrise_elevators", "elevator_is_on_floor" );
        level.mc_elevator_level_for_floor_func = getfunction( "maps/mp/zm_highrise_elevators", "elevator_level_for_floor" );
    }

    level.mc_have = [];

    level.mc_debug = 0;
    if ( getdvar( "mc_debug" ) == "1" )
        level.mc_debug = 1;

    level.mc_gated_buildables = [];
    level.mc_gated_buildables["jetgun_zm"] = 1;
    level.mc_gated_buildables["turbine"] = 1;
    level.mc_gated_buildables["riotshield_zm"] = 1;
    level.mc_gated_buildables["turret"] = 1;
    level.mc_gated_buildables["electric_trap"] = 1;
    level.mc_gated_buildables["powerswitch"] = 1;
    level.mc_gated_buildables["pap"] = 1;
    level.mc_gated_buildables["sq_common"] = 1;
    level.mc_gated_buildables["springpad_zm"] = 1; 
    level.mc_gated_buildables["slipgun_zm"] = 1;
    level.mc_gated_buildables["headchopper_zm"] = 1;
    level.mc_gated_buildables["subwoofer_zm"] = 1;
    level.mc_gated_buildables["buried_sq_bt_m_tower"] = 1;
    level.mc_gated_buildables["buried_sq_bt_r_tower"] = 1;
    level.mc_immediate_buildables = [];
    level.mc_immediate_buildables["cattlecatcher"] = 1;
    level.mc_immediate_buildables["bushatch"] = 1;
    level.mc_immediate_buildables["dinerhatch"] = 1;
    level.mc_immediate_buildables["busladder"] = 1;

    level.mc_key_buildables = [];

    if ( map == "zm_highrise" )
    {
        level.mc_key_buildables["ekeys_zm"] = 1;
        level.mc_immediate_buildables["ekeys_zm"] = 1;
        level.mc_key_buildables["keys_zm"] = 1;
        level.mc_immediate_buildables["keys_zm"] = 1;
    }

    level thread on_player_connect();
    level thread mc_debug_print_names();
    level thread mc_setup_custom_prompts();
}

mc_player_can_take_piece( piece )
{
    if ( !isdefined( piece ) )
        return false;

    if ( mc_is_key( piece.buildablename ) && isdefined( self.mc_has_key ) && self.mc_has_key )
        return false;

    return true;
}

mc_debug_print_names()
{
    level waittill( "buildables_setup" );

    if ( !level.mc_debug )
        return;

    foreach ( stub in level.buildable_stubs )
    {
        if ( !isdefined( stub.buildablezone ) )
            continue;

        name = stub.buildablezone.buildable_name;
        gated = isdefined( level.mc_gated_buildables[name] );
        immediate = isdefined( level.mc_immediate_buildables[name] );
        println( "[mc_debug] buildable_name = " + name + "  (gated=" + gated + ", immediate=" + immediate + ")" );
    }
}

mc_display_name( name )
{
    switch ( name )
    {
        case "riotshield_zm":
            return "Zombie Shield";
        case "jetgun_zm":
            return "Jet Gun";
        case "turbine":
            return "Turbine";
        case "turret":
            return "Turret";
        case "electric_trap":
            return "Electric Trap";
        case "powerswitch":
            return "Power Switch";
        case "pap":
            return "Pack-a-Punch";
        case "sq_common":
            return "Navcard";
        case "springpad_zm":
            return "Trample Steam";
        case "slipgun_zm":
            return "Sliquifier";
        case "headchopper_zm":
            return "Head Chopper";
        case "subwoofer_zm":
        case "subwoofer":
            return "Resonator";
        case "buried_sq_bt_m_tower":
            return "Gallows";
        case "buried_sq_bt_r_tower":
            return "Guillotine";
        case "cattlecatcher":
            return "Bus Plow";
        case "bushatch":
            return "Bus Hatch";
        case "dinerhatch":
            return "Diner Hatch";
        case "busladder":
            return "Bus Ladder";
    }

    return name;
}

mc_representative_icon( name )
{
    switch ( name )
    {
        case "riotshield_zm":
            return "riotshield_zm_icon";
        case "jetgun_zm":
            return "jetgun_zm_icon";
        case "turbine":
            return "turbine_zm_icon";
        case "turret":
            return "turret_zm_icon";
        case "electric_trap":
            return "etrap_zm_icon";
        case "powerswitch":
            return "zm_hud_icon_panel";
        case "pap":
            return "zm_hud_icon_papbody";
        case "sq_common":
            return "zm_hud_icon_sq_powerbox";
        case "springpad_zm":
            return "zom_hud_trample_steam_complete";
        case "slipgun_zm":
            return "zom_hud_icon_buildable_slip_ext";
        case "headchopper_zm":
            return "zom_hud_icon_buildable_chop_a";
        case "subwoofer_zm":
        case "subwoofer":
            return "zom_hud_icon_buildable_woof_speaker";
        case "buried_sq_bt_m_tower":
            return "zm_hud_icon_battery";
        case "buried_sq_bt_r_tower":
            return "zm_hud_icon_sq_meteor";
        case "cattlecatcher":
            return "zm_hud_icon_plow";
        case "bushatch":
            return "zm_hud_icon_hatch";
        case "dinerhatch":
            return "zm_hud_icon_hatch";
        case "busladder":
            return "zm_hud_icon_ladder";
        case "ekeys_zm":
        case "keys_zm":
            return "zom_hud_icon_epod_key";
    }

    return undefined;
}

mc_show_piece_notify( display_name, hud_icon, progress_text )
{
    self endon( "disconnect" );

    if ( isdefined( self.mc_notify_icon ) )
        self.mc_notify_icon destroy();

    if ( isdefined( self.mc_notify_text ) )
        self.mc_notify_text destroy();

    icon = newclienthudelem( self );
    icon.horzalign = "left";
    icon.vertalign = "top";
    icon.alignx = "right";
    icon.aligny = "top";
    icon.x = -12;
    icon.y = 69;
    icon.alpha = 1;

    if ( isdefined( hud_icon ) )
        icon setshader( hud_icon, 20, 20 );

    self.mc_notify_icon = icon;
    icon thread mc_fade_and_destroy( 2.5 );

    if ( !isdefined( display_name ) )
        return;

    text = newclienthudelem( self );
    text.horzalign = "left";
    text.vertalign = "top";
    text.alignx = "left";
    text.aligny = "top";
    text.x = -8;
    text.y = 69;
    text.fontscale = 1.3;
    text.alpha = 1;

    if ( isdefined( progress_text ) )
        text settext( display_name + " (" + progress_text + ")" );
    else
        text settext( display_name );

    self.mc_notify_text = text;

    text thread mc_fade_and_destroy( 2.5 );
}

mc_show_key_pickup_notify( hud_icon )
{
    self endon( "disconnect" );

    if ( isdefined( self.mc_key_notify_icon ) )
        self.mc_key_notify_icon destroy();

    if ( isdefined( self.mc_key_notify_text ) )
        self.mc_key_notify_text destroy();

    icon = newclienthudelem( self );
    icon.horzalign = "left";
    icon.vertalign = "top";
    icon.alignx = "right";
    icon.aligny = "top";
    icon.x = -12;
    icon.y = 69;
    icon.alpha = 1;

    if ( isdefined( hud_icon ) )
        icon setshader( hud_icon, 20, 20 );

    text = newclienthudelem( self );
    text.horzalign = "left";
    text.vertalign = "top";
    text.alignx = "left";
    text.aligny = "top";
    text.x = -8;
    text.y = 69;
    text.fontscale = 1.3;
    text.alpha = 1;
    text settext( "Elevator Key" );

    self.mc_key_notify_icon = icon;
    self.mc_key_notify_text = text;

    icon thread mc_fade_and_destroy( 2.5 );
    text thread mc_fade_and_destroy( 2.5 );
}

mc_fade_and_destroy( delay )
{
    self endon( "death" );
    wait delay;

    if ( !isdefined( self ) )
        return;

    self fadeovertime( 0.5 );
    self.alpha = 0;
    wait 0.5;

    if ( isdefined( self ) )
        self destroy();
}

mc_is_ours( name )
{
    return isdefined( level.mc_gated_buildables[name] ) || isdefined( level.mc_immediate_buildables[name] ) || isdefined( level.mc_key_buildables[name] );
}

mc_is_gated( name )
{
    return isdefined( level.mc_gated_buildables[name] );
}

mc_is_key( name )
{
    return isdefined( level.mc_key_buildables[name] );
}

mc_fix_key_buildable_slot()
{
    key_slot = 1;

    if ( isdefined( level.zombie_include_buildables ) )
    {
        if ( isdefined( level.zombie_include_buildables["keys_zm"] ) )
            level.zombie_include_buildables["keys_zm"].buildable_slot = key_slot;

        if ( isdefined( level.zombie_include_buildables["ekeys_zm"] ) )
            level.zombie_include_buildables["ekeys_zm"].buildable_slot = key_slot;
    }

    foreach ( stub in level.buildable_stubs )
    {
        if ( !isdefined( stub.buildablezone ) || !mc_is_key( stub.buildablezone.buildable_name ) )
            continue;

        stub.buildablezone.buildable_slot = key_slot;

        if ( !isdefined( stub.buildablezone.pieces ) )
            continue;

        for ( i = 0; i < stub.buildablezone.pieces.size; i++ )
        {
            if ( isdefined( stub.buildablezone.pieces[i] ) )
                stub.buildablezone.pieces[i].buildable_slot = key_slot;
        }
    }
}

mc_key_target_is_elevator( name )
{
    return name == "ekeys_zm";
}

mc_is_buried_fixed( name )
{
    return name == "buried_sq_bt_m_tower" || name == "buried_sq_bt_r_tower";
}

mc_other_buried_tower( name )
{
    if ( name == "buried_sq_bt_m_tower" )
        return "buried_sq_bt_r_tower";

    if ( name == "buried_sq_bt_r_tower" )
        return "buried_sq_bt_m_tower";

    return undefined;
}

mc_buried_tower_locked( name )
{
    if ( !level.mc_is_buried || !mc_is_buried_fixed( name ) )
        return false;

    other_name = mc_other_buried_tower( name );

    if ( !isdefined( other_name ) )
        return false;

    other_stub = mc_find_stub_by_buildable_name( other_name );

    return isdefined( other_stub ) && isdefined( other_stub.built ) && other_stub.built;
}

mc_in_range( origin, target, radius_sq )
{
    if ( distance2dsquared( origin, target ) >= radius_sq )
        return false;

    zdiff = origin[2] - target[2];

    if ( zdiff < 0 )
        zdiff = zdiff * -1;

    if ( zdiff > MC_HEIGHT_TOLERANCE )
        return false;

    return true;
}

mc_build_radius_sq( name )
{
    switch ( name )
    {
        case "bushatch":
        case "dinerhatch":
        case "busladder":
        case "cattlecatcher":
            return MC_BUILD_RADIUS_SQ_TIGHT;
    }

    return MC_BUILD_RADIUS_SQ;
}

mc_setup_custom_prompts()
{
    level waittill( "buildables_setup" );
	
    level.mc_buildables_ready = true;
    level.mc_stub_by_name = [];

    ours_stubs = [];
    key_samples = [];

    foreach ( stub in level.buildable_stubs )
    {
        if ( !isdefined( stub.buildablezone ) )
            continue;

        if ( !mc_is_ours( stub.buildablezone.buildable_name ) )
            continue;

        level.mc_stub_by_name[stub.buildablezone.buildable_name] = stub;

        stub.mc_original_prompt = stub.custom_buildablestub_update_prompt;
        stub.custom_buildablestub_update_prompt = ::mc_custom_prompt;

        ours_stubs[ours_stubs.size] = stub;

        zone = stub.buildablezone;

        if ( isdefined( zone.pieces ) )
        {
            for ( i = 0; i < zone.pieces.size; i++ )
            {
                pkey = mc_piece_key( zone.pieces[i] );

                if ( !isdefined( key_samples[pkey] ) )
                    key_samples[pkey] = zone.pieces[i];
            }
        }
    }

    level.mc_key_stubs = [];

    foreach ( stub in ours_stubs )
    {
        if ( !mc_is_key( stub.buildablezone.buildable_name ) )
            continue;

        level.mc_key_stubs[level.mc_key_stubs.size] = stub;
    }

    mc_fix_key_buildable_slot();

    level.mc_piece_candidates = [];

    if ( !level.mc_is_buried )
    {
        foreach ( sample in key_samples )
        {
            pkey = mc_piece_key( sample );
            candidates = [];

            foreach ( cand_stub in ours_stubs )
            {
                if ( isdefined( cand_stub.buildablezone ) && cand_stub.buildablezone buildable_has_piece( sample ) )
                    candidates[candidates.size] = cand_stub;
            }

            level.mc_piece_candidates[pkey] = candidates;
        }
    }
}

mc_buried_find_ready_target()
{
    now = gettime();

    if ( isdefined( self.mc_buried_ready_cache_tick ) && self.mc_buried_ready_cache_tick == now )
        return self.mc_buried_ready_cache;

    result = undefined;

    foreach ( stub in level.buildable_stubs )
    {
        if ( !isdefined( stub.buildablezone ) || !mc_is_ours( stub.buildablezone.buildable_name ) )
            continue;

        if ( mc_is_buried_fixed( stub.buildablezone.buildable_name ) )
            continue;

        if ( isdefined( stub.table_built ) && stub.table_built )
            continue;

        if ( isdefined( stub.built ) && stub.built )
            continue;

        zone = stub.buildablezone;
        deliverable = self mc_get_deliverable_pieces( zone );
        can_attempt = false;

        if ( mc_is_gated( zone.buildable_name ) )
            can_attempt = deliverable.size > 0 && deliverable.size == mc_count_remaining( zone );
        else
            can_attempt = deliverable.size > 0;

        if ( can_attempt )
        {
            result = stub;
            break;
        }
    }

    self.mc_buried_ready_cache_tick = now;
    self.mc_buried_ready_cache = result;

    return result;
}

mc_custom_prompt( player )
{
    if ( isdefined( self.built ) && self.built )
        return true;

    if ( isdefined( self.buildablezone ) && mc_is_key( self.buildablezone.buildable_name ) )
        return self mc_key_prompt_logic( player );

    if ( isdefined( self.mc_original_prompt ) && !( self [[ self.mc_original_prompt ]]( player ) ) )
        return false;

    if ( !isdefined( self.buildablezone ) )
        return true;

    zone = self.buildablezone;

    if ( !mc_is_ours( zone.buildable_name ) )
        return true;

    if ( mc_buried_tower_locked( zone.buildable_name ) )
        return true;

    deliverable = player mc_get_deliverable_pieces( zone );
    ready = false;

    if ( mc_is_gated( zone.buildable_name ) )
        ready = deliverable.size > 0 && deliverable.size == mc_count_remaining( zone );
    else
        ready = deliverable.size > 0;

    display_name = zone.buildable_name;

    if ( !ready && level.mc_is_buried && !mc_is_buried_fixed( zone.buildable_name ) )
    {
        target = player mc_buried_find_ready_target();

        if ( isdefined( target ) )
        {
            ready = true;
            display_name = target.buildablezone.buildable_name;
        }
    }

    if ( ready )
    {
        if ( isdefined( level.zombie_buildables[self.equipname] ) && isdefined( level.zombie_buildables[self.equipname].hint ) )
            self.hint_string = level.zombie_buildables[self.equipname].hint;
			
        self.cursor_hint = "HINT_NOICON";
        return false;
    }

    return true;
}

mc_key_prompt_logic( player )
{
    if ( !isdefined( player.mc_has_key ) || !player.mc_has_key )
        return true;

    if ( isdefined( self.buildablezone ) && mc_key_target_is_elevator( self.buildablezone.buildable_name ) )
    {
        if ( !mc_key_resolve_elevator( self ) )
            return true;

        if ( isdefined( level.mc_elevator_is_on_floor_func ) && self.elevator [[ level.mc_elevator_is_on_floor_func ]]( self.floor ) )
            return true;
    }

    remaining = player mc_key_cooldown_remaining();

    if ( remaining > 0 )
    {
        self.hint_string = "Key on cooldown...";
        self.cursor_hint = "HINT_NOICON";
        return false;
    }
	
    if ( isdefined( level.zombie_buildables[self.equipname] ) && isdefined( level.zombie_buildables[self.equipname].hint ) )
        self.hint_string = level.zombie_buildables[self.equipname].hint;

    self.cursor_hint = "HINT_NOICON";
    return false;
}

mc_key_resolve_elevator( stub )
{
    if ( isdefined( stub.elevator ) && isdefined( stub.floor ) )
        return true;

    elevatorname = stub.script_noteworthy;

    if ( !isdefined( elevatorname ) || !isdefined( stub.script_parameters ) )
        return false;

    if ( !isdefined( level.elevators ) || !isdefined( level.elevators[elevatorname] ) )
        return false;

    elevator = level.elevators[elevatorname];
    floor = int( stub.script_parameters );

    stub.elevator = elevator;

    if ( isdefined( level.mc_elevator_level_for_floor_func ) )
        stub.floor = elevator [[ level.mc_elevator_level_for_floor_func ]]( floor );

    return true;
}

mc_key_cooldown_remaining()
{
    if ( !isdefined( self.mc_key_cooldown_end ) )
        return 0;

    remaining_ms = self.mc_key_cooldown_end - gettime();

    if ( remaining_ms <= 0 )
        return 0;

    return int( remaining_ms / 1000 ) + 1;
}

on_player_connect()
{
    level endon( "end_game" );

    while ( true )
    {
        level waittill( "connected", player );
        player thread player_collect_and_build();
        player thread mc_tab_square_watch();
    }
}

mc_tab_buildable_list()
{
    map = getdvar( "mapname" );

    list = [];
	
	if ( map == "zm_highrise" )
    {
        list[0] = "springpad_zm";
        list[1] = "slipgun_zm";
        return list;
    }

    if ( map == "zm_buried" )
    {
        list[0] = "turbine";
        list[1] = "springpad_zm";
        list[2] = "subwoofer_zm";
        list[3] = "headchopper_zm";
        return list;
    }
	
    list[0] = "turbine";
    list[1] = "riotshield_zm";
    list[2] = "turret";
    list[3] = "electric_trap";
    list[4] = "powerswitch";
    list[5] = "pap";
    list[6] = "jetgun_zm";
    return list;
}

mc_tab_attached_list()
{
    map = getdvar( "mapname" );

    list = [];

    if ( map == "zm_highrise" )
    {
        list[0] = "ekeys_zm"; 
        return list;
    }

    if ( map == "zm_buried" )
    {
        list[0] = "buried_sq_bt_m_tower"; 
        list[1] = "buried_sq_bt_r_tower";
        return list;
    }

    list[0] = "cattlecatcher";
    list[1] = "bushatch";
    list[2] = "busladder";
    return list;
}

mc_tab_square_watch()
{
    self endon( "disconnect" );

    self notifyonplayercommand( "mc_tab_down", "+scores" );
    self notifyonplayercommand( "mc_tab_up", "-scores" );

    self.mc_tab_held = false;

    self thread mc_tab_down_listener();
    self thread mc_tab_up_listener();

    list = mc_tab_buildable_list();
    attached_list = mc_tab_attached_list();

    left_bg_border = undefined;
    right_bg_border = undefined;
    icons = [];
    attached_icons = [];
    navcard_icon = undefined;
    shown = false;

    slot_pitch = MC_TAB_SQUARE_SIZE + MC_TAB_BORDER_PAD * 2 + MC_TAB_SLOT_GAP;
    slot_height = MC_TAB_SQUARE_SIZE + MC_TAB_BORDER_PAD * 2;

    while ( true )
    {
        if ( self.mc_tab_held && !shown )
        {
            self.mc_tab_counters = [];
            self.mc_tab_locks = [];

            // 1. Create Left Background Container (Spans all main buildables)
            if ( list.size > 0 )
            {
                first_x = MC_TAB_SQUARE_X;
                last_x = MC_TAB_SQUARE_X + ( list.size - 1 ) * slot_pitch;
                bg_center_x = ( first_x + last_x ) / 2;
                bg_width = ( list.size - 1 ) * slot_pitch + slot_height;

                left_bg_border = newclienthudelem( self );
                left_bg_border.horzalign = "left";
                left_bg_border.vertalign = "top";
                left_bg_border.alignx = "center";
                left_bg_border.aligny = "middle";
                left_bg_border.x = bg_center_x;
                left_bg_border.y = MC_TAB_SQUARE_Y;
                left_bg_border.alpha = 0.7;
                left_bg_border.color = ( 1, 1, 1 );
                left_bg_border.sort = 1;
                left_bg_border setshader( "zm_hud_icon_sq_tranceiver", bg_width, slot_height );
            }

            // Create Icons for main buildables
            for ( i = 0; i < list.size; i++ )
            {
                slot_x = MC_TAB_SQUARE_X + i * slot_pitch;

                icon = newclienthudelem( self );
                icon.horzalign = "left";
                icon.vertalign = "top";
                icon.alignx = "center";
                icon.aligny = "middle";
                icon.x = slot_x;
                icon.y = MC_TAB_SQUARE_Y;
                icon.alpha = 0.20;
                icon.sort = 3;

                icon_shader = mc_representative_icon( list[i] );
                if ( isdefined( icon_shader ) )
                    icon setshader( icon_shader, MC_TAB_SQUARE_SIZE - MC_TAB_BORDER_PAD * 2, MC_TAB_SQUARE_SIZE - MC_TAB_BORDER_PAD * 2 );

                icons[i] = icon;
            }

            // 2. Create Right Background Container (Spans attached buildables + navcard)
            num_attached = attached_list.size + 1;
            first_x_right = MC_NAVCARD_X - ( num_attached - 1 ) * slot_pitch;
            last_x_right = MC_NAVCARD_X;
            bg_center_x_right = ( first_x_right + last_x_right ) / 2;
            bg_width_right = ( num_attached - 1 ) * slot_pitch + slot_height;

            right_bg_border = newclienthudelem( self );
            right_bg_border.horzalign = "left";
            right_bg_border.vertalign = "top";
            right_bg_border.alignx = "center";
            right_bg_border.aligny = "middle";
            right_bg_border.x = bg_center_x_right;
            right_bg_border.y = MC_TAB_SQUARE_Y;
            right_bg_border.alpha = 0.7;
            right_bg_border.color = ( 1, 1, 1 );
            right_bg_border.sort = 1;
            right_bg_border setshader( "zm_hud_icon_sq_tranceiver", bg_width_right, slot_height );

            // Create Icons for attached buildables
            for ( i = 0; i < attached_list.size; i++ )
            {
                slot_x = MC_NAVCARD_X - ( attached_list.size - i ) * slot_pitch;

                icon = newclienthudelem( self );
                icon.horzalign = "left";
                icon.vertalign = "top";
                icon.alignx = "center";
                icon.aligny = "middle";
                icon.x = slot_x;
                icon.y = MC_TAB_SQUARE_Y;
                icon.alpha = 0.20;
                icon.sort = 3;

                icon_shader = mc_representative_icon( attached_list[i] );
                if ( isdefined( icon_shader ) )
                    icon setshader( icon_shader, MC_TAB_SQUARE_SIZE - MC_TAB_BORDER_PAD * 2, MC_TAB_SQUARE_SIZE - MC_TAB_BORDER_PAD * 2 );

                attached_icons[i] = icon;
            }

            // Create Icon for Navcard
            navcard_icon = newclienthudelem( self );
            navcard_icon.horzalign = "left";
            navcard_icon.vertalign = "top";
            navcard_icon.alignx = "center";
            navcard_icon.aligny = "middle";
            navcard_icon.x = MC_NAVCARD_X;
            navcard_icon.y = MC_NAVCARD_Y;
            navcard_icon.alpha = 0.20;
            navcard_icon.sort = 3;

            icon_shader = mc_representative_icon( "sq_common" );
            if ( isdefined( icon_shader ) )
                navcard_icon setshader( icon_shader, MC_TAB_SQUARE_SIZE - MC_TAB_BORDER_PAD * 2, MC_TAB_SQUARE_SIZE - MC_TAB_BORDER_PAD * 2 );

            shown = true;
        }
        else if ( !self.mc_tab_held && shown )
        {
            if ( isdefined( left_bg_border ) )
                left_bg_border destroy();

            if ( isdefined( right_bg_border ) )
                right_bg_border destroy();

            left_bg_border = undefined;
            right_bg_border = undefined;

            for ( i = 0; i < list.size; i++ )
            {
                if ( isdefined( icons[i] ) )
                    icons[i] destroy();
            }

            icons = [];

            for ( i = 0; i < attached_list.size; i++ )
            {
                if ( isdefined( attached_icons[i] ) )
                    attached_icons[i] destroy();
            }

            attached_icons = [];

            if ( isdefined( navcard_icon ) )
                navcard_icon destroy();

            navcard_icon = undefined;

            if ( isdefined( self.mc_tab_counters ) )
            {
                foreach ( counter_elem in self.mc_tab_counters )
                {
                    if ( isdefined( counter_elem ) )
                        counter_elem destroy();
                }
            }

            if ( isdefined( self.mc_tab_locks ) )
            {
                foreach ( lock_elem in self.mc_tab_locks )
                {
                    if ( isdefined( lock_elem ) )
                        lock_elem destroy();
                }
            }

            self.mc_tab_counters = [];
            self.mc_tab_locks = [];

            shown = false;
        }

        if ( shown )
        {
            for ( i = 0; i < list.size; i++ )
            {
                slot_x = MC_TAB_SQUARE_X + i * slot_pitch;
                self mc_update_tab_slot_hud( list[i], slot_x, undefined, icons[i] );
            }

            for ( i = 0; i < attached_list.size; i++ )
            {
                slot_x = MC_NAVCARD_X - ( attached_list.size - i ) * slot_pitch;
                self mc_update_tab_slot_hud( attached_list[i], slot_x, undefined, attached_icons[i] );
            }

            self mc_update_tab_slot_hud( "sq_common", MC_NAVCARD_X, undefined, navcard_icon );
        }

        wait 0.05;
    }
}

mc_tab_down_listener()
{
    self endon( "disconnect" );

    while ( true )
    {
        self waittill( "mc_tab_down" );
        self.mc_tab_held = true;
    }
}

mc_tab_up_listener()
{
    self endon( "disconnect" );

    while ( true )
    {
        self waittill( "mc_tab_up" );
        self.mc_tab_held = false;
    }
}

mc_find_stub_by_buildable_name( name )
{
    if ( isdefined( level.mc_stub_by_name ) && isdefined( level.mc_stub_by_name[name] ) )
        return level.mc_stub_by_name[name];

    foreach ( stub in level.buildable_stubs )
    {
        if ( isdefined( stub.buildablezone ) && stub.buildablezone.buildable_name == name )
            return stub;
    }

    return undefined;
}

mc_update_tab_slot_hud( name, slot_x, border, icon )
{
    square_y = MC_TAB_SQUARE_Y;

    stub = mc_find_stub_by_buildable_name( name );

    need_counter = false;
    need_lock = false;
    have = 0;
    total = 0;

    if ( !isdefined( stub ) )
    {
        icon.alpha = 0;
    }
    else
    {
        zone = stub.buildablezone;
        is_built = isdefined( stub.built ) && stub.built;

        if ( name == "bushatch" || name == "dinerhatch" )
        {
            other_name = ( name == "bushatch" ) ? "dinerhatch" : "bushatch";
            other_stub = mc_find_stub_by_buildable_name( other_name );

            if ( isdefined( other_stub ) && isdefined( other_stub.built ) && other_stub.built )
                is_built = true;
        }

        if ( mc_is_key( name ) )
        {
            have = ( isdefined( self.mc_has_key ) && self.mc_has_key ) ? 1 : 0;
            total = 1;
        }
        else
        {
            built_count = 0;

            for ( i = 0; i < zone.pieces.size; i++ )
            {
                if ( isdefined( zone.pieces[i].built ) && zone.pieces[i].built )
                    built_count++;
            }

            deliverable = self mc_get_deliverable_pieces( zone );
            have = built_count + deliverable.size;
            total = zone.pieces.size;
        }

        is_immediate_style = isdefined( level.mc_immediate_buildables[name] );

        if ( is_immediate_style )
        {
            if ( is_built )
            {
                icon.alpha = 1;
            }
            else if ( have > 0 )
            {
                icon.alpha = 1;
            }
            else
            {
                icon.alpha = 0.20;
            }
        }
        else if ( is_built )
        {
            icon.alpha = 1; // Completed icons light up to 1.0 opacity inside the border
        }
        else if ( have > 0 )
        {
            icon.alpha = 0.20;
            need_counter = true;
            square_y = MC_TAB_SQUARE_Y_ACTIVE;
        }
        else
        {
            icon.alpha = 0.20;
        }

        if ( mc_buried_tower_locked( name ) )
        {
            need_lock = true;
            need_counter = false;
            icon.alpha = 0.20;
            square_y = MC_TAB_SQUARE_Y;
        }
    }

    if ( isdefined( border ) )
        border.y = square_y;

    icon.y = square_y;

    if ( !isdefined( self.mc_tab_counters ) )
        self.mc_tab_counters = [];

    if ( !isdefined( self.mc_tab_locks ) )
        self.mc_tab_locks = [];

    counter = self.mc_tab_counters[name];

    if ( need_counter && !isdefined( counter ) )
    {
        counter = newclienthudelem( self );
        counter.horzalign = "left";
        counter.vertalign = "top";
        counter.alignx = "center";
        counter.aligny = "middle";
        counter.fontscale = 1.17;
        counter.alpha = 1;
        counter.sort = 3;
        self.mc_tab_counters[name] = counter;
    }
    else if ( !need_counter && isdefined( counter ) )
    {
        counter destroy();
        self.mc_tab_counters[name] = undefined;
        counter = undefined;
    }

    if ( isdefined( counter ) )
    {
        counter.x = slot_x;
        counter.y = square_y + ( MC_TAB_SQUARE_SIZE / 2 ) + MC_TAB_BORDER_PAD + 6;
        counter settext( have + "/" + total );
    }

    lock = self.mc_tab_locks[name];

    if ( need_lock && !isdefined( lock ) )
    {
        lock = newclienthudelem( self );
        lock.horzalign = "left";
        lock.vertalign = "top";
        lock.alignx = "center";
        lock.aligny = "middle";
        lock.alpha = 1;
        lock.sort = 4;
        lock setshader( "zm_hud_icon_fan", MC_TAB_LOCK_SIZE, MC_TAB_LOCK_SIZE );
        self.mc_tab_locks[name] = lock;
    }
    else if ( !need_lock && isdefined( lock ) )
    {
        lock destroy();
        self.mc_tab_locks[name] = undefined;
        lock = undefined;
    }

    if ( isdefined( lock ) )
    {
        lock.x = slot_x + ( MC_TAB_SQUARE_SIZE / 2 ) - ( MC_TAB_LOCK_SIZE / 2 );
        lock.y = square_y + ( MC_TAB_SQUARE_SIZE / 2 ) - ( MC_TAB_LOCK_SIZE / 2 );
    }
}

mc_get_stub_origin( stub )
{
    if ( isdefined( stub.originfunc ) )
        return stub [[ stub.originfunc ]]();

    return stub.origin;
}

mc_count_remaining( zone )
{
    remaining = 0;

    for ( i = 0; i < zone.pieces.size; i++ )
    {
        if ( !( isdefined( zone.pieces[i].built ) && zone.pieces[i].built ) )
            remaining++;
    }

    return remaining;
}

mc_piece_key( piece )
{
    return piece.buildablename + "|" + piece.modelname;
}

mc_get_deliverable_pieces( zone )
{
    use_cache = !level.mc_is_buried;

    if ( use_cache )
    {
        now = gettime();

        if ( !isdefined( self.mc_deliverable_cache_tick ) || self.mc_deliverable_cache_tick != now )
        {
            self.mc_deliverable_cache = [];
            self.mc_deliverable_cache_tick = now;
        }

        if ( isdefined( self.mc_deliverable_cache[zone.buildable_name] ) )
            return self.mc_deliverable_cache[zone.buildable_name];
    }

    result = [];
    used = [];

    for ( i = 0; i < zone.pieces.size; i++ )
    {
        if ( isdefined( zone.pieces[i].built ) && zone.pieces[i].built )
            continue;

        key = mc_piece_key( zone.pieces[i] );

        pool = 0;
        if ( isdefined( level.mc_have[key] ) )
            pool = level.mc_have[key];

        consumed = 0;
        if ( isdefined( used[key] ) )
            consumed = used[key];

        if ( pool - consumed > 0 )
        {
            result[result.size] = zone.pieces[i];
            used[key] = consumed + 1;
        }
    }

    if ( use_cache )
        self.mc_deliverable_cache[zone.buildable_name] = result;

    return result;
}

player_collect_and_build()
{
    self endon( "disconnect" );
    if ( !isdefined( level.mc_buildables_ready ) )
        level waittill( "buildables_setup" );

    self thread mc_collect_loop();
    self thread mc_deliver_loop();
    self thread mc_key_use_loop();
}

mc_collect_loop()
{
    self endon( "disconnect" );

    while ( true )
    {
        self mc_try_collect();
        wait 0.05;
    }
}

mc_deliver_loop()
{
    self endon( "disconnect" );

    while ( true )
    {
        if ( level.mc_is_buried )
            self mc_try_deliver_buried();
        else
            self mc_try_deliver_default();

        wait 0.1;
    }
}

mc_key_use_loop()
{
    self endon( "disconnect" );

    while ( true )
    {
        self mc_try_use_key();
        wait 0.05;
    }
}

mc_try_use_key()
{
    if ( isdefined( self.mc_key_inserting ) && self.mc_key_inserting )
        return;

    if ( !isdefined( level.mc_key_stubs ) || level.mc_key_stubs.size == 0 )
        return;

    if ( !isdefined( self.mc_has_key ) || !self.mc_has_key )
        return;

    if ( self mc_key_cooldown_remaining() > 0 )
        return;

    if ( !self usebuttonpressed() )
        return;

    foreach ( stub in level.mc_key_stubs )
    {
        zone = stub.buildablezone;
        stub_origin = mc_get_stub_origin( stub );

        if ( !isdefined( stub_origin ) || !mc_in_range( self.origin, stub_origin, mc_build_radius_sq( zone.buildable_name ) ) )
            continue;

        if ( mc_key_target_is_elevator( zone.buildable_name ) )
        {
            if ( !mc_key_resolve_elevator( stub ) )
                continue;

            if ( isdefined( level.mc_elevator_is_on_floor_func ) && stub.elevator [[ level.mc_elevator_is_on_floor_func ]]( stub.floor ) )
                continue;
        }

        self thread mc_key_insert_sequence( stub );
        return;
    }
}

mc_key_insert_sequence( stub )
{
    self endon( "disconnect" );
    self endon( "death" );

    if ( isdefined( self.mc_key_inserting ) && self.mc_key_inserting )
        return;

    self.mc_key_inserting = true;

    zone = stub.buildablezone;

    insert_bar = self createprimaryprogressbar();
    insert_bar_text = self createprimaryprogressbartext();
    insert_bar_text settext( "Inserting key..." );

    start_time = gettime();
    success = true;

    while ( gettime() - start_time < MC_KEY_INSERT_TIME )
    {
        if ( !isdefined( self ) || !self usebuttonpressed() )
        {
            success = false;
            break;
        }

        stub_origin = mc_get_stub_origin( stub );

        if ( !isdefined( stub_origin ) || !mc_in_range( self.origin, stub_origin, mc_build_radius_sq( zone.buildable_name ) ) )
        {
            success = false;
            break;
        }

        if ( self mc_key_cooldown_remaining() > 0 )
        {
            success = false;
            break;
        }

        progress = ( gettime() - start_time ) / MC_KEY_INSERT_TIME;

        if ( progress < 0 )
            progress = 0;

        if ( progress > 1 )
            progress = 1;

        insert_bar updatebar( progress );

        wait 0.05;
    }

    insert_bar_text destroyelem();
    insert_bar destroyelem();

    self.mc_key_inserting = false;

    if ( !success || !isdefined( self ) )
        return;

    if ( isdefined( stub.elevator ) && isdefined( level.mc_elevator_is_on_floor_func ) && stub.elevator [[ level.mc_elevator_is_on_floor_func ]]( stub.floor ) )
        return;

    if ( isdefined( level.flag ) && isdefined( level.flag["power_on"] ) && level.flag["power_on"] )
    {
        if ( isdefined( stub.buildablestruct ) && isdefined( stub.buildablestruct.onuseplantobject ) )
        {
            held_pieces = self player_get_buildable_pieces();

            foreach ( held in held_pieces )
            {
                if ( !isdefined( held ) || !mc_is_key( held.buildablename ) )
                    continue;

                self player_set_buildable_piece( held, stub.buildablezone.buildable_slot );
                break;
            }

            stub [[ stub.buildablestruct.onuseplantobject ]]( self );
        }
    }

    self.mc_key_cooldown_end = gettime() + MC_KEY_COOLDOWN_MS;
    self playsound( "zmb_buildable_pickup" );
}

mc_try_collect()
{
    held_pieces = self player_get_buildable_pieces();

    if ( held_pieces.size == 0 )
        return;

    foreach ( held in held_pieces )
    {
        if ( !isdefined( held ) )
            continue;

        if ( isdefined( held.mc_collected ) && held.mc_collected )
            continue;

        candidates = [];
        held_key = mc_piece_key( held );

        if ( level.mc_is_buried )
        {
            foreach ( stub in level.buildable_stubs )
            {
                if ( !isdefined( stub.buildablezone ) || !isdefined( stub.buildablezone.pieces ) )
                    continue;

                if ( !mc_is_ours( stub.buildablezone.buildable_name ) )
                    continue;

                if ( isdefined( stub.built ) && stub.built )
                    continue;

                if ( stub.buildablezone buildable_has_piece( held ) )
                    candidates[candidates.size] = stub;
            }
        }
        else
        {
            base_candidates = [];

            if ( isdefined( level.mc_piece_candidates ) && isdefined( level.mc_piece_candidates[held_key] ) )
                base_candidates = level.mc_piece_candidates[held_key];

            foreach ( stub in base_candidates )
            {
                if ( isdefined( stub.built ) && stub.built )
                    continue;

                candidates[candidates.size] = stub;
            }
        }

        if ( candidates.size == 0 )
            continue;

        key = held_key;

        count = 0;

        if ( isdefined( level.mc_have[key] ) )
            count = level.mc_have[key];

        level.mc_have[key] = count + 1;
        self.mc_last_pickup_time = gettime();
        nearest = candidates[0];
        nearest_dist = distancesquared( self.origin, mc_get_stub_origin( nearest ) );

        for ( i = 1; i < candidates.size; i++ )
        {
            d = distancesquared( self.origin, mc_get_stub_origin( candidates[i] ) );

            if ( d < nearest_dist )
            {
                nearest_dist = d;
                nearest = candidates[i];
            }
        }

        if ( level.mc_debug )
            println( "[mc_debug] piece " + held.buildablename + "/" + held.modelname + " -> candidates=" + candidates.size + " (available for everyone, no random values)" );

        if ( mc_is_key( nearest.buildablezone.buildable_name ) )
        {
            self.mc_has_key = true;

            // Broadcast Key Pickup to all players
            foreach ( player in level.players )
            {
                if ( isdefined( player ) )
                    player mc_show_key_pickup_notify( mc_representative_icon( nearest.buildablezone.buildable_name ) );
            }

            self clear_buildable_clientfield( nearest.buildablezone.buildable_slot );

            held.mc_collected = true;
            continue;
        }

        names = mc_display_name( candidates[0].buildablezone.buildable_name );

        for ( i = 1; i < candidates.size; i++ )
            names = names + " / " + mc_display_name( candidates[i].buildablezone.buildable_name );

        progress_text = self mc_progress_text( nearest.buildablezone );

        // BROADCAST TO ALL PLAYERS
        foreach ( player in level.players )
        {
            if ( isdefined( player ) )
                player mc_show_piece_notify( names, mc_representative_icon( nearest.buildablezone.buildable_name ), progress_text );
        }


        self player_destroy_piece( held );
    }
}

mc_try_deliver_default()
{
    if ( isdefined( self.mc_last_pickup_time ) && gettime() - self.mc_last_pickup_time < 400 )
        return;

    if ( !self usebuttonpressed() )
        return;

    foreach ( stub in level.buildable_stubs )
    {
        if ( !isdefined( stub.buildablezone ) || !isdefined( stub.buildablezone.pieces ) )
            continue;

        if ( !mc_is_ours( stub.buildablezone.buildable_name ) )
            continue;

        if ( mc_is_key( stub.buildablezone.buildable_name ) )
            continue;

        if ( isdefined( stub.built ) && stub.built )
            continue;

        zone = stub.buildablezone;
        stub_origin = mc_get_stub_origin( stub );

        if ( !mc_in_range( self.origin, stub_origin, mc_build_radius_sq( zone.buildable_name ) ) )
            continue;

        deliverable = self mc_get_deliverable_pieces( zone );
        can_attempt = false;

        if ( mc_is_gated( zone.buildable_name ) )
            can_attempt = deliverable.size > 0 && deliverable.size == mc_count_remaining( zone );
        else
            can_attempt = deliverable.size > 0;

        if ( !can_attempt )
            continue;

        if ( isdefined( stub.mc_original_prompt ) )
        {
            if ( !( stub [[ stub.mc_original_prompt ]]( self ) ) )
                continue;
        }

        success = self mc_do_build_hold( stub, zone );

        if ( success )
        {
            deliverable = self mc_get_deliverable_pieces( zone );
            self mc_deliver_pieces( zone, deliverable );
        }
    }
}

find_bench( bench_name )
{
    return getent( bench_name, "targetname" );
}

mc_swap_buildable_fields( stub1, stub2 )
{
    tbz = stub2.buildablezone;
    stub2.buildablezone = stub1.buildablezone;
    stub2.buildablezone.stub = stub2;
    stub1.buildablezone = tbz;
    stub1.buildablezone.stub = stub1;
    tbs = stub2.buildablestruct;
    stub2.buildablestruct = stub1.buildablestruct;
    stub1.buildablestruct = tbs;
    te = stub2.equipname;
    stub2.equipname = stub1.equipname;
    stub1.equipname = te;
    th = stub2.hint_string;
    stub2.hint_string = stub1.hint_string;
    stub1.hint_string = th;
    ths = stub2.trigger_hintstring;
    stub2.trigger_hintstring = stub1.trigger_hintstring;
    stub1.trigger_hintstring = ths;
    tp = stub2.persistent;
    stub2.persistent = stub1.persistent;
    stub1.persistent = tp;
    tobu = stub2.onbeginuse;
    stub2.onbeginuse = stub1.onbeginuse;
    stub1.onbeginuse = tobu;
    tocu = stub2.oncantuse;
    stub2.oncantuse = stub1.oncantuse;
    stub1.oncantuse = tocu;
    toeu = stub2.onenduse;
    stub2.onenduse = stub1.onenduse;
    stub1.onenduse = toeu;
    tt = stub2.target;
    stub2.target = stub1.target;
    stub1.target = tt;
    ttn = stub2.targetname;
    stub2.targetname = stub1.targetname;
    stub1.targetname = ttn;
    twn = stub2.weaponname;
    stub2.weaponname = stub1.weaponname;
    stub1.weaponname = twn;
    pav = stub2.original_prompt_and_visibility_func;
    stub2.original_prompt_and_visibility_func = stub1.original_prompt_and_visibility_func;
    stub1.original_prompt_and_visibility_func = pav;
    bench1 = undefined;
    bench2 = undefined;
    transfer_pos_as_is = 1;

    if ( isdefined( stub1.model ) && isdefined( stub2.model ) && isdefined( stub1.model.target ) && isdefined( stub2.model.target ) )
    {
        bench1 = find_bench( stub1.model.target );
        bench2 = find_bench( stub2.model.target );

        if ( isdefined( bench1 ) && isdefined( bench2 ) )
        {
            transfer_pos_as_is = 0;
            w2lo1 = bench1 worldtolocalcoords( stub1.model.origin );
            w2la1 = stub1.model.angles - bench1.angles;
            w2lo2 = bench2 worldtolocalcoords( stub2.model.origin );
            w2la2 = stub2.model.angles - bench2.angles;
            stub1.model.origin = bench2 localtoworldcoords( w2lo1 );
            stub1.model.angles = bench2.angles + w2la1;
            stub2.model.origin = bench1 localtoworldcoords( w2lo2 );
            stub2.model.angles = bench1.angles + w2la2;
        }

        tmt = stub2.model.target;
        stub2.model.target = stub1.model.target;
        stub1.model.target = tmt;
    }

    tm = stub2.model;
    stub2.model = stub1.model;
    stub1.model = tm;

    if ( transfer_pos_as_is && isdefined( stub1.model ) && isdefined( stub2.model ) )
    {
        tmo = stub2.model.origin;
        tma = stub2.model.angles;
        stub2.model.origin = stub1.model.origin;
        stub2.model.angles = stub1.model.angles;
        stub1.model.origin = tmo;
        stub1.model.angles = tma;
    }

    if ( isdefined( level.mc_stub_by_name ) )
    {
        if ( isdefined( stub1.buildablezone ) )
            level.mc_stub_by_name[stub1.buildablezone.buildable_name] = stub1;

        if ( isdefined( stub2.buildablezone ) )
            level.mc_stub_by_name[stub2.buildablezone.buildable_name] = stub2;
    }
}

mc_try_deliver_buried()
{
    if ( isdefined( self.mc_last_pickup_time ) && gettime() - self.mc_last_pickup_time < 400 )
        return;

    if ( !self usebuttonpressed() )
        return;

    near_bench_stub = undefined;
    best_dist = MC_BUILD_RADIUS_SQ;

    foreach ( stub in level.buildable_stubs )
    {
        if ( !isdefined( stub.buildablezone ) || !mc_is_ours( stub.buildablezone.buildable_name ) )
            continue;

        if ( isdefined( stub.table_built ) && stub.table_built )
            continue;

        if ( isdefined( stub.built ) && stub.built )
            continue;

        s_orig = mc_get_stub_origin( stub );
        if ( isdefined( s_orig ) && mc_in_range( self.origin, s_orig, MC_BUILD_RADIUS_SQ ) )
        {
            dist = distance2dsquared( self.origin, s_orig );
            if ( dist < best_dist )
            {
                best_dist = dist;
                near_bench_stub = stub;
            }
        }
    }

    if ( !isdefined( near_bench_stub ) )
        return;

    near_name = near_bench_stub.buildablezone.buildable_name;

    if ( mc_is_buried_fixed( near_name ) )
    {
        if ( mc_buried_tower_locked( near_name ) )
            return;

        zone = near_bench_stub.buildablezone;
        deliverable = self mc_get_deliverable_pieces( zone );
        can_attempt = deliverable.size > 0 && deliverable.size == mc_count_remaining( zone );

        if ( !can_attempt )
            return;

        if ( isdefined( near_bench_stub.mc_original_prompt ) )
        {
            if ( !( near_bench_stub [[ near_bench_stub.mc_original_prompt ]]( self ) ) )
                return;
        }

        near_bench_stub.bound_to_buildable = near_bench_stub;
        active_stub = near_bench_stub;

        success = self mc_do_build_hold( active_stub, active_stub.buildablezone );

        if ( success )
        {
            deliverable = self mc_get_deliverable_pieces( active_stub.buildablezone );
            self mc_deliver_pieces( active_stub.buildablezone, deliverable );

            active_stub.table_built = true;
            active_stub.built = true;
            active_stub.bound_to_buildable = undefined;
        }

        return;
    }

    target_stub = undefined;

    foreach ( stub in level.buildable_stubs )
    {
        if ( !isdefined( stub.buildablezone ) || !mc_is_ours( stub.buildablezone.buildable_name ) )
            continue;

        if ( mc_is_buried_fixed( stub.buildablezone.buildable_name ) )
            continue;

        if ( isdefined( stub.table_built ) && stub.table_built )
            continue;

        if ( isdefined( stub.built ) && stub.built )
            continue;

        zone = stub.buildablezone;
        deliverable = self mc_get_deliverable_pieces( zone );
        can_attempt = false;

        if ( mc_is_gated( zone.buildable_name ) )
            can_attempt = deliverable.size > 0 && deliverable.size == mc_count_remaining( zone );
        else
            can_attempt = deliverable.size > 0;

        if ( can_attempt )
        {
            target_stub = stub;
            break;
        }
    }

    if ( !isdefined( target_stub ) )
        return;

    if ( near_bench_stub != target_stub )
    {
        mc_swap_buildable_fields( near_bench_stub, target_stub );
    }

    near_bench_stub.bound_to_buildable = near_bench_stub;
    active_stub = near_bench_stub;

    success = self mc_do_build_hold( active_stub, active_stub.buildablezone );

    if ( success )
    {
        deliverable = self mc_get_deliverable_pieces( active_stub.buildablezone );
        self mc_deliver_pieces( active_stub.buildablezone, deliverable );

        active_stub.table_built = true;
        active_stub.built = true;
        active_stub.bound_to_buildable = undefined;
    }
}

custom_pooledbuildable_stub_for_piece( piece )
{
    if ( !isdefined( piece ) )
        return undefined;

    if ( !isdefined( self.stubs ) )
        return undefined;

    bound_match = undefined;
    unbuilt_match = undefined;
    any_match = undefined;

    foreach ( stub in level.buildable_stubs )
    {
        if ( !isdefined( stub.buildablezone ) || !( stub.buildablezone buildable_has_piece( piece ) ) )
            continue;

        if ( !isdefined( any_match ) )
            any_match = stub;

        if ( !isdefined( unbuilt_match ) && !( isdefined( stub.built ) && stub.built ) )
            unbuilt_match = stub;

        if ( !isdefined( bound_match ) && isdefined( stub.bound_to_buildable ) && stub.bound_to_buildable == stub )
        {
            bound_match = stub;
            break;
        }
    }

    if ( isdefined( bound_match ) )
        return bound_match;

    if ( isdefined( unbuilt_match ) )
        return unbuilt_match;

    return any_match;
}

mc_deliver_pieces( zone, pieces )
{
    for ( i = 0; i < pieces.size; i++ )
    {
        piece = pieces[i];

        if ( isdefined( zone.stub.buildablestruct ) && isdefined( zone.stub.buildablestruct.onuseplantobject ) )
        {
            self player_set_buildable_piece( piece, zone.buildable_slot );
            zone.stub [[ zone.stub.buildablestruct.onuseplantobject ]]( self );
        }

        one_piece = [];
        one_piece[0] = piece;
        self player_build( zone, one_piece );

        key = mc_piece_key( piece );

        if ( isdefined( level.mc_have[key] ) )
        {
            level.mc_have[key] = level.mc_have[key] - 1;

            if ( level.mc_have[key] <= 0 )
                level.mc_have[key] = undefined;
        }
    }

    // Trigger Completion Popup if all parts are placed
    if ( isdefined( zone ) && ( ( isdefined( zone.stub ) && isdefined( zone.stub.built ) && zone.stub.built ) || mc_count_remaining( zone ) == 0 ) )
    {
        name_str = mc_display_name( zone.buildable_name );
        icon_str = mc_representative_icon( zone.buildable_name );
        
        // BROADCAST TO ALL PLAYERS
        foreach ( player in level.players )
        {
            if ( isdefined( player ) )
                player mc_show_completion_notify( name_str, icon_str );
        }
    }
}

mc_do_build_hold( stub, zone )
{
    self endon( "disconnect" );
    self endon( "death" );

    build_time = MC_DEFAULT_BUILD_TIME;

    if ( isdefined( stub.usetime ) )
        build_time = stub.usetime;

    self disable_player_move_states( 1 );
    self increment_is_drinking();
    orgweapon = self getcurrentweapon();
    self giveweapon( "zombie_builder_zm" );
    self switchtoweapon( "zombie_builder_zm" );

    self.mc_buildaudio = spawn( "script_origin", self.origin );
    self.mc_buildaudio playloopsound( "zmb_buildable_loop" );

    self.mc_build_active = 1;
    start_time = gettime();
    self thread mc_build_progress_bar( start_time, build_time );
    self thread mc_build_dust_fx();

    success = true;

    while ( gettime() - start_time < build_time )
    {
        if ( !isdefined( self ) || !self usebuttonpressed() )
        {
            success = false;
            break;
        }

        stub_origin = mc_get_stub_origin( stub );

        if ( !mc_in_range( self.origin, stub_origin, mc_build_radius_sq( zone.buildable_name ) ) )
        {
            success = false;
            break;
        }

        wait 0.05;
    }

    self.mc_build_active = 0;

    if ( isdefined( self.mc_buildaudio ) )
    {
        self.mc_buildaudio delete();
        self.mc_buildaudio = undefined;
    }

    self maps\mp\zombies\_zm_weapons::switch_back_primary_weapon( orgweapon );
    self takeweapon( "zombie_builder_zm" );

    if ( isdefined( self.is_drinking ) && self.is_drinking )
        self decrement_is_drinking();

    self enable_player_move_states();

    return success;
}

mc_build_progress_bar( start_time, build_time )
{
    self endon( "disconnect" );
    self endon( "death" );

    usebar = self createprimaryprogressbar();
    usebartext = self createprimaryprogressbartext();
    usebartext settext( &"ZOMBIE_BUILDING" );

    while ( isdefined( self ) && isdefined( self.mc_build_active ) && self.mc_build_active && gettime() - start_time < build_time )
    {
        progress = ( gettime() - start_time ) / build_time;

        if ( progress < 0 )
            progress = 0;

        if ( progress > 1 )
            progress = 1;

        usebar updatebar( progress );
        wait 0.05;
    }

    usebartext destroyelem();
    usebar destroyelem();
}

mc_build_dust_fx()
{
    self endon( "disconnect" );
    self endon( "death" );

    while ( isdefined( self ) && isdefined( self.mc_build_active ) && self.mc_build_active )
    {
        playfx( level._effect["building_dust"], self getplayercamerapos(), self.angles );
        wait 0.5;
    }
}

mc_progress_text( zone )
{
    built = 0;

    for ( i = 0; i < zone.pieces.size; i++ )
    {
        if ( isdefined( zone.pieces[i].built ) && zone.pieces[i].built )
            built++;
    }

    deliverable = self mc_get_deliverable_pieces( zone );
    have = built + deliverable.size;

    return have + "/" + zone.pieces.size;
}

mc_show_completion_notify( display_name, hud_icon )
{
    self endon( "disconnect" );

    if ( isdefined( self.mc_notify_icon ) )
        self.mc_notify_icon destroy();

    if ( isdefined( self.mc_notify_check ) )
        self.mc_notify_check destroy();

    if ( isdefined( self.mc_notify_text ) )
        self.mc_notify_text destroy();

    // 1. Item Icon (x = -12, alignx = "right")
    icon = newclienthudelem( self );
    icon.horzalign = "left";
    icon.vertalign = "top";
    icon.alignx = "right";
    icon.aligny = "top";
    icon.x = -12;
    icon.y = 69;
    icon.alpha = 1;

    if ( isdefined( hud_icon ) )
        icon setshader( hud_icon, 20, 20 );

    self.mc_notify_icon = icon;
    icon thread mc_fade_and_destroy( 2.5 );

    // 2. Checkmark Icon (x = -8, alignx = "left", placed right after the item icon)
    check = newclienthudelem( self );
    check.horzalign = "left";
    check.vertalign = "top";
    check.alignx = "left";
    check.aligny = "top";
    check.x = -8;
    check.y = 73; // Slightly offset down to align vertically with text
    check.alpha = 1;
    check.sort = 5;
    check setshader( "zm_hud_icon_sq_scafold", 12, 12 );

    self.mc_notify_check = check;
    check thread mc_fade_and_destroy( 2.5 );

    if ( !isdefined( display_name ) )
        return;

    // 3. Buildable Name Text (x = 8, alignx = "left", placed right after the checkmark)
    text = newclienthudelem( self );
    text.horzalign = "left";
    text.vertalign = "top";
    text.alignx = "left";
    text.aligny = "top";
    text.x = 8;
    text.y = 69;
    text.fontscale = 1.3;
    text.alpha = 1;
    text settext( display_name );

    self.mc_notify_text = text;
    text thread mc_fade_and_destroy( 2.5 );
}