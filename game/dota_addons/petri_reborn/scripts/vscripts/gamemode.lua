-- This is the primary barebones gamemode script and should be used to assist in initializing your game mode


-- Set this to true if you want to see a complete debug output of all events/processes done by barebones
-- You can also change the cvar 'barebones_spew' at any time to 1 or 0 for output/no output
BAREBONES_DEBUG_SPEW = false 

if GameMode == nil then
    DebugPrint( '[BAREBONES] creating barebones game mode' )
    _G.GameMode = class({})
end

require('libraries/timers')
require('libraries/physics')
require('libraries/projectiles')
require('libraries/notifications')

require('libraries/FlashUtil')
require('libraries/buildinghelper')
require('buildings/bh_abilities')

require('settings')
require('internal/events')
require('events')

require('internal/gamemode')

function GameMode:PostLoadPrecache()
  DebugPrint("[BAREBONES] Performing Post-Load precache")    
  --PrecacheItemByNameAsync("item_example_item", function(...) end)
  --PrecacheItemByNameAsync("example_ability", function(...) end)

  --PrecacheUnitByNameAsync("npc_dota_hero_viper", function(...) end)
  --PrecacheUnitByNameAsync("npc_dota_hero_enigma", function(...) end)
end

--[[
  This function is called once and only once as soon as the first player (almost certain to be the server in local lobbies) loads in.
  It can be used to initialize state that isn't initializeable in InitGameMode() but needs to be done before everyone loads in.
]]
function GameMode:OnFirstPlayerLoaded()
  DebugPrint("[BAREBONES] First Player has loaded")
end

--[[
  This function is called once and only once after all players have loaded into the game, right as the hero selection time begins.
  It can be used to initialize non-hero player state or adjust the hero selection (i.e. force random etc)
]]
function GameMode:OnAllPlayersLoaded()
  DebugPrint("[BAREBONES] All Players have loaded into the game")
end

--[[
  This function is called once and only once for every player when they spawn into the game for the first time.  It is also called
  if the player's hero is replaced with a new hero for any reason.  This function is useful for initializing heroes, such as adding
  levels, changing the starting gold, removing/adding abilities, adding physics, etc.

  The hero parameter is the hero entity that just spawned in
]]
function GameMode:OnHeroInGame(hero)
  DebugPrint("[BAREBONES] Hero spawned in game for first time -- " .. hero:GetUnitName())

  -- This line for example will set the starting gold of every hero to 500 unreliable gold
  hero:SetGold(0, false)

  if hero:GetClassname() == "npc_dota_hero_viper" then
    local team = hero:GetTeamNumber()
    local player = hero:GetPlayerOwner()

    local newHero

    if team == 2 then
      UTIL_Remove( hero )
      newHero = CreateHeroForPlayer("npc_dota_hero_rattletrap", player)

      InitAbilities(newHero)

      newHero:SetAbilityPoints(0)

      newHero:SetGold(1000, false)

      newHero:AddItemByName("item_petri_builder_blink")
      newHero:AddItemByName("item_petri_give_permission_to_build")
    end

    if team == 3 then

      UTIL_Remove( hero )
      newHero = CreateHeroForPlayer("npc_dota_hero_brewmaster", player)

      -- It's dangerous to go alone, take this
      newHero:SetAbilityPoints(3)
      newHero:UpgradeAbility(newHero:GetAbilityByIndex(0))
      newHero:UpgradeAbility(newHero:GetAbilityByIndex(5))

      -- Wait a bit
      Timers:CreateTimer(0.03,
        function()
          CreateUnitByName( "npc_petri_exploration_tower" , Vector(784,1164,129) , true, nil, nil, DOTA_TEAM_BADGUYS )
          
          newHero.spawnPosition = newHero:GetAbsOrigin()
          end)
    end

    -- We don't need 'undefined' variables
    player.lumber = 4000
    player.food = 0
    player.maxFood = 10

    --Update player's UI
    Timers:CreateTimer(0.03,
    function()
      local event_data =
      {
          gold = newHero:GetGold(),
          lumber = player.lumber,
          food = player.food,
          maxFood = player.maxFood
      }
      CustomGameEventManager:Send_ServerToPlayer( player, "receive_resources_info", event_data )
      return 0.21
    end)
  end
end

--[[
  This function is called once and only once when the game completely begins (about 0:00 on the clock).  At this point,
  gold will begin to go up in ticks if configured, creeps will spawn, towers will become damageable etc.  This function
  is useful for starting any game logic timers/thinkers, beginning the first round, etc.
]]
function GameMode:OnGameInProgress()
  DebugPrint("[BAREBONES] The game has officially begun")

  Timers:CreateTimer(30, -- Start this timer 30 game-time seconds later
    function()
      DebugPrint("This function is called 30 seconds after the game begins, and every 30 seconds thereafter")
      return 30.0 -- Rerun this timer every 30 game-time seconds 
    end)
end

-- function GameMode:FilterExecuteOrder( filterTable )
--     local units = filterTable["units"]
--     local order_type = filterTable["order_type"]
--     local issuer = filterTable["issuer_player_id_const"]

--     print(order_type)

--     for n,unit_index in pairs(units) do
--         local unit = EntIndexToHScript(unit_index)
--         local ownerID = unit:GetPlayerOwnerID()

--         if unit:GetUnitLabel() == "building" then
--           if order_type == 1 then
--             return false
--           end
--         end
--     end

--     return true
-- end

function GameMode:OnUnitSelected(args)
  local unit = EntIndexToHScript(tonumber(args["main_unit"]))

  if unit ~= nil and unit:GetPlayerOwner() ~= nil then
    if unit:GetPlayerOwner().selection == nil then 
      unit:GetPlayerOwner().selection = {}
    end

    if unit:GetPlayerOwner().selection.flag ~= nil then
      unit:GetPlayerOwner().selection.flag:SetModelScale(0)
    end

    if unit:GetUnitLabel() == "building" then
      if unit:HasAbility("building_queue") then
        if unit.flag ~= nil then
          unit.flag:SetModelScale(0.5)
        end 
      end
    end

    unit:GetPlayerOwner().selection = unit
  end
end

-- This function initializes the game mode and is called before anyone loads into the game
-- It can be used to pre-initialize any values/tables that will be needed later
function GameMode:InitGameMode()
  GameMode = self

  GameMode:_InitGameMode()
  SendToServerConsole( "dota_combine_models 0" )

  --GameRules:GetGameModeEntity():SetExecuteOrderFilter( Dynamic_Wrap( GameMode, "FilterExecuteOrder" ), self )

  -- Some creepy shit for hiding rally point
  Timers:CreateTimer(1, function()
    CustomGameEventManager:RegisterListener( "custom_dota_player_update_selected_unit", Dynamic_Wrap(GameMode, 'OnUnitSelected') )
  end)

  

  BuildingHelper:Init()
end