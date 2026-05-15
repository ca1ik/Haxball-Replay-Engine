module.exports = function(API){
  const { OperationType, VariableType, ConnectionState, AllowFlags, Direction, CollisionFlags, CameraFollow, BackgroundType, GamePlayState, BanEntryType, Callback, Utils, Room, Replay, Query, Library, RoomConfig, Plugin, Renderer, Errors, Language, EventFactory, Impl } = API;

  Object.setPrototypeOf(this, Plugin.prototype);
  Plugin.call(this, "multibox", true, { // "multibox" is plugin's name, "true" means "activated just after initialization". Every plugin should have a unique name.
    version: "0.1",
    author: "abc",
    description: `This plugin allows us to do multiboxing i.e. making any number of players join any room and then making these players imitate any given player in that room at any time.`,
    allowFlags: AllowFlags.CreateRoom | AllowFlags.JoinRoom // We allow this plugin to be activated on both CreateRoom and JoinRoom.
  });
  
  this.defineVariable({
    name: "roomId",
    description: "Id of the room to join.",
    type: VariableType.String,
    value: ""
  });
  
  this.defineVariable({
    name: "roomPassword",
    description: "Password of the room to join.",
    type: VariableType.String,
    value: ""
  });
  
  this.defineVariable({
    name: "imitatePlayerId",
    description: "Id of the player to imitate.",
    type: VariableType.PlayerId,
    value: 0
  });

  this.defineVariable({
    name: "unnecessaryEvents",
    description: "Whether to imitate unnecessary events or not.",
    type: VariableType.Boolean,
    value: false
  });
  
  this.defineVariable({
    name: "playerNick",
    description: "Name of the new player that will join the room.",
    type: VariableType.String,
    value: ""
  });
  
  this.defineVariable({
    name: "playerAvatar",
    description: "Initial avatar of the new player that will join the room.",
    type: VariableType.String,
    value: ""
  });
  
  this.defineVariable({
    name: "playerFlag",
    description: "Flag of the new player that will join the room.",
    type: VariableType.Flag,
    value: ""
  });

  this.defineVariable({
    name: "join",
    description: "Adds a new player to the chosen room that will imitate the chosen player.",
    type: VariableType.Void,
    value: async ()=>{
      var [authKey, authObj] = await Utils.generateAuth(), room = null;
      Room.join({
        id: that.roomId, 
        password: that.roomPassword,
        authObj: authObj
      }, {
        storage: {
          player_name: that.playerNick,
          avatar: that.playerAvatar,
          geo: {
            flag: that.playerFlag
          }
        }, 
        onOpen: (_room)=>{
          if (!clients){
            _room.leave();
            return;
          }
          room = _room;
          clients.push(room);
        },
        onClose: (msg)=>{
          if (!clients)
            return;
          var idx = clients.indexOf(room);
          if (idx>=0)
            clients.splice(idx, 1);
          room = null;
          msg && console.log(msg.toString());
        }
      });
    }
  });

  this.defineVariable({
    name: "leave",
    description: "Removes the last player who joined the room by this plugin.",
    type: VariableType.Void,
    value: ()=>{
      clients?.pop?.()?.leave();
    }
  });

  var that = this, clients = null;

  this.initialize = function(){
    clients = [];
    that.imitatePlayerId = that.room.currentPlayerId;
    that.playerNick = that.room.currentPlayer.name;
    that.playerAvatar = that.room.currentPlayer.avatar;
    that.playerFlag = that.room.currentPlayer.flag;
    setTimeout(()=>{
      var tmp = that.room.link, i;
      if (!tmp)
        return;
      tmp = tmp.substring(tmp.indexOf("c=")+2);
      i = tmp.indexOf("&");
      if (i>=0)
        tmp = tmp.substring(0, i);
      that.roomId = tmp;
    }, 3000);
  };

  this.finalize = function(){
    clients?.forEach((room)=>room.leave());
    clients = null;
  };

  this.onPlayerLeave = function(playerObj, reason, isBanned, byId, customData){
    if (playerObj.id==that.room.currentPlayerId){
      clients?.forEach((room)=>room.leave());
      clients = null;
    }
  };
  
  this.onPlayerInputChange = function(id, value){
    if (id!=that.imitatePlayerId)
      return;
    clients?.forEach((room)=>room.setKeyState(value));
  };
  this.onPlayerAvatarChange = function(id, value){
    if (id!=that.imitatePlayerId)
      return;
    clients?.forEach((room)=>room.setAvatar(value));
  };
  this.onPlayerChatIndicatorChange = function(id, value){
    if (id!=that.imitatePlayerId)
      return;
    clients?.forEach((room)=>room.setChatIndicatorActive(value));
  };
  this.onPlayerChat = function(id, message){
    if (id!=that.imitatePlayerId)
      return;
    clients?.forEach((room)=>room.sendChat(message));
  };
  this.onPlayerTeamChange = function(id, teamId, byId){
    if (byId!=that.imitatePlayerId)
      return;
    if (id==byId)
      clients?.forEach((room)=>room.setPlayerTeam(room.currentPlayerId, teamId));
    else if (!that.unnecessaryEvents)
      return;
    clients?.forEach((room)=>room.setPlayerTeam(id, teamId));
  };
  this.onAutoTeams = function(playerId1, teamId1, playerId2, teamId2, byId){
    if (!that.unnecessaryEvents || byId!=that.imitatePlayerId)
      return;
    clients?.forEach((room)=>room.autoTeams());
  };
  this.onScoreLimitChange = function(value, byId){
    if (!that.unnecessaryEvents || byId!=that.imitatePlayerId)
      return;
    clients?.forEach((room)=>room.setScoreLimit(value));
  };
  this.onTimeLimitChange = function(value, byId){
    if (!that.unnecessaryEvents || byId!=that.imitatePlayerId)
      return;
    clients?.forEach((room)=>room.setTimeLimit(value));
  };
  this.onPlayerAdminChange = function(id, isAdmin, byId){
    if (!that.unnecessaryEvents || byId!=that.imitatePlayerId)
      return;
    clients?.forEach((room)=>room.setPlayerAdmin(id, isAdmin));
  };
  this.onStadiumChange = function(stadium, byId){
    if (!that.unnecessaryEvents || byId!=that.imitatePlayerId)
      return;
    clients?.forEach((room)=>room.setCurrentStadium(stadium));
  };
  this.onTeamsLockChange = function(value, byId){
    if (!that.unnecessaryEvents || byId!=that.imitatePlayerId)
      return;
    clients?.forEach((room)=>room.lockTeams());
  };
  this.onGamePauseChange = function(isPaused, byId){
    if (!that.unnecessaryEvents || byId!=that.imitatePlayerId)
      return;
    clients?.forEach((room)=>room.pauseGame());
  };
  this.onKickRateLimitChange = function(min, rate, burst, byId){
    if (!that.unnecessaryEvents || byId!=that.imitatePlayerId)
      return;
    clients?.forEach((room)=>room.setKickRateLimit(min, rate, burst));
  };
  this.onTeamColorsChange = function(teamId, value, byId){
    if (!that.unnecessaryEvents || byId!=that.imitatePlayerId)
      return;
    clients?.forEach((room)=>room.setTeamColors(teamId, value.angle, value.text, ...value.inner));
  };
  this.onGameStart = function(byId){
    if (!that.unnecessaryEvents || byId!=that.imitatePlayerId)
      return;
    clients?.forEach((room)=>room.startGame());
  };
  this.onGameStop = function(byId){
    if (!that.unnecessaryEvents || byId!=that.imitatePlayerId)
      return;
    clients?.forEach((room)=>room.stopGame());
  };
  this.onCustomEvent = function(type, data, byId){
    if (!that.unnecessaryEvents || byId!=that.imitatePlayerId)
      return;
    clients?.forEach((room)=>room.sendCustomEvent(type, data));
  };
  this.onBinaryCustomEvent = function(type, data, byId){
    if (!that.unnecessaryEvents || byId!=that.imitatePlayerId)
      return;
    clients?.forEach((room)=>room.sendCustomEvent(type, data));
  };
};