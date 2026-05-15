// attach to initial iFrame load
var el = document.getElementsByClassName("gameframe")[0];
var muteAllToggle = false;
var autoJoinObserver;
var refreshCycle;
var myNick;

// for kick/ban buttons
var dblDiv = document.createElement('div');
var dblTxt = document.createTextNode('Double click!');
dblDiv.appendChild(dblTxt);
dblDiv.style = 'visibility: hidden; position: fixed; background-color: #0004';

// wait until the game in iFrame loads, then continue
function waitForElement(selector) {
  return new Promise(function(resolve, reject) {
    var element = document.getElementsByClassName("gameframe")[0].contentWindow.document.querySelector(selector);

    if(element) {
      resolve(element);
      return;
    }

    var observer = new MutationObserver(function(mutations) {
      mutations.forEach(function(mutation) {
        var nodes = Array.from(mutation.addedNodes);
        for(var node of nodes) {
          if(node.matches && node.matches(selector)) {
            resolve(node);
            return;
          }
        };
      });
    });

    observer.observe(document.getElementsByClassName("gameframe")[0].contentWindow.document, { childList: true, subtree: true });
  });
}

// chat observer for mute
muted = new Set();
function mutePlayer(name) {
	if (muted.has(name)) {
		muted.delete(name);
	}
	else {
		muted.add(name);
	}
}

// linkify from stackoverflow 1500260
function linkify(text) {
    var urlRegex =/(\b(https?:\/\/|ftp:\/\/|file:\/\/|www\.)[-A-Z0-9+&@#\/%?=~_|!:,.;]*[-A-Z0-9+&@#\/%=~_|])/ig;
    return text.replace(urlRegex, function(url) {
		if (url.startsWith('www.')) { url = 'http://' + url; }
        return '<a href="' + url + '" target="blank">' + url + '</a>';
    });
}

// clicking for zoom
function simulateClick(item) {
  item.dispatchEvent(new PointerEvent('pointerdown', {bubbles: true}));
  item.dispatchEvent(new MouseEvent('mousedown', {bubbles: true}));
  item.dispatchEvent(new PointerEvent('pointerup', {bubbles: true}));
  item.dispatchEvent(new MouseEvent('mouseup', {bubbles: true}));
  item.dispatchEvent(new MouseEvent('mouseout', {bubbles: true}));
  item.dispatchEvent(new MouseEvent('click', {bubbles: true}));
  item.dispatchEvent(new Event('change', {bubbles: true}));
  return true;
}

function changeView(viewIndex) {
	if (5 <= viewIndex <= 8) {
		var gameframe = document.getElementsByClassName('gameframe')[0];
		gameframe.contentWindow.document.querySelector('[data-hook="settings"]').click();
		var viewModeToggle = waitForElement('[data-hook="viewmode"]')
		viewModeToggle.then(function (toggle) {
			toggle.selectedIndex = viewIndex;
			simulateClick(toggle);
			closeBtn = waitForElement('[data-hook="close"]');
			closeBtn.then(function (btn) { btn.click() })
		})
	}
}

function record(gameview = true) {
	var gameframe = document.getElementsByClassName('gameframe')[0];
	if (gameview) {
		gameframe.contentWindow.document.querySelector('[data-hook="menu"]').click();
		var recBtn = waitForElement('[data-hook="rec-btn"]');
		recBtn.then(function (btn) { btn.click() });
		gameframe.contentWindow.document.querySelector('[data-hook="menu"]').click();
	}
	else {
		gameframe.contentWindow.document.querySelector('[data-hook="rec-btn"]').click();
	}
}

chatObserver = new MutationObserver( function(mutations) {
	var candidates = mutations.flatMap(x => Array.from(x.addedNodes)).filter(x => x.tagName == 'P');
	var gameframe = document.documentElement.getElementsByClassName("gameframe")[0];
	var bottomSec = gameframe.contentWindow.document.getElementsByClassName('bottom-section')[0];
	var statSec = gameframe.contentWindow.document.getElementsByClassName('stats-view')[0];
	var chatInput = gameframe.contentWindow.document.querySelector('[data-hook="input"]');
	var chatLog = gameframe.contentWindow.document.querySelector('[data-hook="log"]');
	
	// i did in fact lag
	statSec.ondblclick = function () {
		var gameframe = document.documentElement.getElementsByClassName("gameframe")[0];
		var c = gameframe.contentWindow.document.getElementsByClassName('graph')[0].firstChild;
		var ctx = c.getContext("2d");
		var imgData = ctx.getImageData(0, 63, 31, 1);
		var hexString = Array.prototype.map.call(new Uint8Array(imgData.data), x => ('00' + x.toString(16)).slice(-2)).join('');

		var chatInput = gameframe.contentWindow.document.querySelector('[data-hook="input"]');
		chatInput.value = statSec.innerText.replace(/\n/g, ' ') + ' Red bars: ' + (hexString.match(/c13535ff/g) ? hexString.match(/c13535ff/g).length : 0);
		gameframe.contentWindow.document.querySelector('[data-hook="send"]').click()
	}
	
	chatCheck = function(chatLine) {
		if ([...muted].filter(x => chatLine.innerText.startsWith(x + ': ')).length > 0) {
			chatLine.hidden = true;
		}
		else if (muteAllToggle && muteExceptions.filter(x => chatLine.innerText.startsWith(x + ': ')) == 0 && chatLine.className != 'notice') {
			chatLine.hidden = true;
		}
		
		if (chatLine.innerText.startsWith('Game start')) {
			toggleChatOpt();
			toggleChatKb();
		}
		
		chrome.storage.local.get({'haxTransChatConfig' : false},
			function (items) {
				if (items.haxTransChatConfig) { 
					if (chatLine.innerText.startsWith('Game start')) {	
						chatFormat(bottomSec,statSec,chatInput,'absolute');
					}
					else if (chatLine.innerText.startsWith('Game stop')) {	
						bottomSec.removeAttribute('style');
					}
				}
		});
		
		if (!chatLine.processed) {
			chatLine.innerHTML = linkify(chatLine.innerHTML);
		}
		
		chrome.storage.local.get("haxChatTranslation", (items) => {
			if (items.haxChatTranslation) {
				// translation
				if (!chatLine.processed) {
					let chatRowDiv = document.createElement('div');
					chatRowDiv.className = 'chat-row';
					chatLine.parentNode.appendChild(chatRowDiv);
					chatLine.processed = true;
					chatRowDiv.appendChild(chatLine);
					chatLine.style.display = 'inline-block';
					chatLine.style.width = '75%';

					let translateBtn = document.createElement('button');
					translateBtn.innerText = 'Translate';
					translateBtn.className = 'translate-btn';

					// style translate btn
					translateBtn.style.backgroundColor = "#244967";
					translateBtn.style.color = "#fff";
					translateBtn.style.padding = "2px 15px";
					translateBtn.style.margin = "1px";
					translateBtn.style.border = "0";
					translateBtn.style.borderRadius = "5px";
					translateBtn.style.fontFamily = `"Open Sans",sans-serif`;
					translateBtn.style.fontWeight = `700`;
					translateBtn.style.fontSize = `15px`;

					chatLine.originalChatLine = chatLine.innerText;
					chatLine.state = 'original';
					translateBtn.addEventListener('click', function (e) {
						if (chatLine.state == 'translated') {
							chatLine.innerText = chatLine.originalChatLine;
							chatLine.state = 'original';
							translateBtn.innerText = 'Translate';
						}
						else if (chatLine.state == 'original') {
							if (chatLine.translation) chatLine.innerText = chatLine.translation;
							else {
								let senderName;
								let toBeTranslatedText;
								if (chatLine.originalChatLine.indexOf(':') > -1) {
									// player message
									senderName = chatLine.innerText.split(":")[0];
									toBeTranslatedText = chatLine.innerText.split(': ').slice(1).join('');
								} else {
									// bot message (no sender)
									senderName = "";
									toBeTranslatedText = chatLine.innerText;
								}
								translate(toBeTranslatedText).then(translationResult => {
									if (translationResult) {
										chatLine.innerText = senderName + ': ' + translationResult.translation + ' (translated from: ' + translationResult.lang + ')';
										chatLine.translation = chatLine.innerText;
									}
								});
							}
							chatLine.state = 'translated';
							translateBtn.innerText = 'Show Original';
						}
					});
					chatRowDiv.appendChild(translateBtn);
				}

			}
		});
		
		
		// right click to tag
		chatLine.oncontextmenu = function () {
			if (chatLine.innerText.includes(':')) {
				var chatAuthor = chatLine.innerText.split(':')[0].replace(' ', '_');
				if (chatInput.value !== null) {
					chatInput.value += ' @' + chatAuthor + ' ';
				}
				else {
					chatInput.value = '@' + chatAuthor + ' ';
				}
				chatInput.focus();
				return false;
			}
			else if (chatLine.className === 'notice' && chatLine.innerText.match(noticeRe)) {
				var chatAuthor = chatLine.innerText.match(noticeRe)[0].replace(' ', '_');
				if (chatInput.value !== null) {
					chatInput.value += ' @' + chatAuthor + ' ';
				}
				else {
					chatInput.value = '@' + chatAuthor + ' ';
				}
				chatInput.focus();
				return false;
			}
		}
	}
	candidates.forEach(x => chatCheck(x));
})

// text expansion stuffs
RegExp.escape = function(s) {
    return s.replace(/[-\/\\^$*+!?.()[\]{}]/g, '\\$&');
};

var chatShortcuts;
var chatTimer;
var expandRe;
const emojiRe = new RegExp("(" + RegExp.escape(Object.keys(emojiShortcuts).join("|")) + ")", "g");
const noticeRe = RegExp('.*(?= (has joined|was moved))', 'g');

// main observer to detect changes to views
moduleObserver = new MutationObserver(function(mutations) {
	candidates = mutations.flatMap(x => Array.from(x.addedNodes)).filter(x => x.className);
	if (candidates.length == 1) {
		var tempView = candidates[0].className;
		console.log(tempView);
		if(tempView == 'chat-row') return;
		switch(true) {
			case tempView == "choose-nickname-view":
				nickWait = waitForElement('[data-hook="input"]');
				nickWait.then(function(nicknameInput) { 
					myNick = nicknameInput.value;
					muteExceptions = ['humpyhost','Hostinho',myNick];
					})
				
				// addon settings
				addonSettingsPopup('choose-nickname-view');
				el.contentWindow.document.querySelector('h1').parentNode.appendChild(copyright());
				break;
				
			case tempView == "roomlist-view":
				// early exit
				chrome.storage.local.get({'haxSearchConfig' : true, 'haxAutoJoinConfig' : true},
				function (items) {
					if (items.haxSearchConfig) { createSearch(); }
					if (items.haxAutoJoinConfig) { createButton(); }
				});
				
				var gameframe = document.getElementsByClassName('gameframe')[0];
				var changeNickBtn = gameframe.contentWindow.document.querySelector('[data-hook="changenick"]');
				var addonSettingsBtn = document.createElement('button');
				var addonSettingsDiv = document.createElement('div');
				var addonSettingsIcon = document.createElement('i');
				
				addonSettingsIcon.className = 'icon-cog';
				addonSettingsBtn.appendChild(addonSettingsIcon);
				addonSettingsDiv.append('Add-on');
				addonSettingsBtn.appendChild(addonSettingsDiv);
				
				addonSettingsBtn.onclick = function () {
					changeNickBtn.click();
					var addonSettingsOpen = waitForElement('[data-hook="add-on"]');
					addonSettingsOpen.then(function (btn) { btn.click() });
				}
				
				changeNickBtn.parentNode.insertBefore(addonSettingsBtn,changeNickBtn);
				
				break;
				
			case tempView.includes("game-view"):
				muted = new Set();
				muteAllToggle = false;
				chatWait = waitForElement('[data-hook="log"]');
				chatWait.then(function (chatArea) {
					chatObserver.observe(chatArea, {childList: true, subtree: true});
				});
				
				var gameframe = document.documentElement.getElementsByClassName("gameframe")[0];
				var bottomSec = gameframe.contentWindow.document.getElementsByClassName('bottom-section')[0];
				var statSec = gameframe.contentWindow.document.getElementsByClassName('stats-view')[0];
				var chatInput = gameframe.contentWindow.document.querySelector('[data-hook="input"]');
				chatInput.placeholder = 'Press key below ESC to toggle chat hide';
				
				chatInput.addEventListener("keypress", chatListener);
				
				chrome.storage.local.get({'haxTransChatConfig' : false},
					function (items) {
						if (items.haxTransChatConfig) { 
							bottomSec.removeAttribute('style');
						}
				});
				
				inGame = waitForElement('.bar-container');
				inGame.then(function () {
					toggleChatOpt();
					toggleChatKb();
					showTranslateDisclaimer();
					chrome.storage.local.get({'haxTransChatConfig' : false},
					function (items) {
						if (items.haxTransChatConfig) { 
							chatFormat(bottomSec,statSec,chatInput,'absolute');
						}
					});
				});
				
				settingsWait = waitForElement('[data-hook="settings"]');
				settingsWait.then(function (settingButton) {
					navBar = document.getElementsByClassName('header')[0];
					navBar.style.transition = 'height 0.3s';
					hideNavBar = document.createElement('button');
					
					chrome.storage.local.get({'haxHideNavConfig' : true}, function (items) {
						if (items.haxHideNavConfig) {
							hideNavBar.innerText = 'Show Navbar';
							navBar.style.height = '0px';
						}
						else {
							navBar.setAttribute('id','nothidden'); 
							hideNavBar.innerText = 'Hide Navbar';
							navBar.style.height = '35px';
						}
					});
					
					hideNavBar.onclick = function () {
						if (navBar.hasAttribute('id')) { 
							navBar.removeAttribute('id','nothidden');
							navBar.style.height = '0px';
							hideNavBar.innerText = 'Show NavBar';
							}
						else { 
							navBar.style.height = '35px';
							navBar.setAttribute('id','nothidden'); 
							hideNavBar.innerText = 'Hide NavBar';
							}
					}
					
					addonSettingsPopup('game-view');
					settingButton.parentNode.appendChild(hideNavBar);
				})
				
				chrome.storage.local.get({'haxMuteConfig' : true}, function (items) {
					if (items.haxMuteConfig) {
						muteAll = document.createElement('button');
						muteAll.style.padding = '5px 10px';
						muteAll.style.width = '80px';
						muteAll.innerText = 'Mute';
						muteAll.onclick = function () { 
							if (muteAllToggle) {
								muteAllToggle = false;
								var chats = gameframe.contentWindow.document.querySelector('[data-hook="log"]').getElementsByTagName('p');
								for (i = 0; i < chats.length; i++) { chats[i].removeAttribute('hidden'); }
								muteAll.innerText = 'Mute';
							}
							else {
								muteAllToggle = true;
								muteAll.innerText = 'Unmute';
							}
						}
					var dividerDiv = document.createElement('div');
					dividerDiv.style = 'width: 5px';
					chatInput.parentNode.appendChild(dividerDiv);
					chatInput.parentNode.insertBefore(muteAll,chatInput);
					}
				});
				
				chrome.storage.local.get({'haxShortcutConfig' : false}, function (items) {
					if (items.haxShortcutConfig) {
						var emojiDoc = document.createElement('button');
						emojiDoc.style.padding = '5px 10px';
						emojiDoc.innerText = '😊';
						emojiDoc.onclick = function () { chrome.runtime.sendMessage({'type': 'emoji'}) };
						
						chatInput.parentNode.insertBefore(emojiDoc, chatInput.parentNode.lastChild.previousSibling);
					}
				});
				
			case tempView == "dialog":
				chrome.storage.local.get({'haxMuteConfig' : true}, function (items) {
					if (items.haxMuteConfig) {
						var popupWait = waitForElement('div.dialog');
						popupWait.then(function (popup) {
							var name = popup.firstChild.innerText;
							if (name === 'Add-on Settings') {
								return
							}
							var muteBtn = document.createElement('button');
							muteBtn.className = 'mb';
							popup.insertBefore(muteBtn, popup.lastChild);
							if (muted.has(name)) {
								muteBtn.innerText = 'Unmute';
							}
							else {
								muteBtn.innerText = 'Mute';
							}
							muteBtn.onclick = function () { 
								if (muted.has(name)) {
									muted.delete(name);
									muteBtn.innerText = 'Mute';
									}
								else {
									muted.add(name);
									muteBtn.innerText = 'Unmute';
									}
							}

							// tag stuff start here
							var tagBtn = document.createElement('button');
							tagBtn.className = 'tag';
							tagBtn.innerText = '@Mention'
							popup.insertBefore(tagBtn, popup.lastChild);
							tagBtn.onclick = function() {
								var gameframe = document.getElementsByClassName('gameframe')[0];
								var chatInput = gameframe.contentWindow.document.querySelector('[data-hook="input"]');
								var tagName = name.replace(' ', '_');
								if (chatInput.value !== null) {
									chatInput.value += ' @' + tagName + ' ';
									popup.lastChild.click();
									chatInput.focus();
								}
								else {
									chatInput.value = '@' + tagName + ' ';
									popup.lastChild.click();
									chatInput.focus();
								}
							}
						});}})
				break;
			case Boolean(tempView.match(/^(room-view|player-list-item|notice)/)):				
				// early exit
				var gameframe = document.documentElement.getElementsByClassName("gameframe")[0];
				
				if (tempView.startsWith('room-view')) {
					var bottomSec = gameframe.contentWindow.document.getElementsByClassName('bottom-section')[0];
					var statSec = gameframe.contentWindow.document.getElementsByClassName('stats-view')[0];
					var chatInput = gameframe.contentWindow.document.querySelector('[data-hook="input"]');
					bottomSec.removeAttribute('style');
					gameframe.contentWindow.document.onkeydown = function (f) {
						if (f.code == 'KeyR') {
							chrome.storage.local.get({'haxRecordHotkey' : false},
								function (items) { if (items.haxRecordHotkey) { record(false) }})
						}
					}
				}
				
				chrome.storage.local.get({'haxKickBanConfig' : false}, function (items) {
					if (items.haxKickBanConfig) {
						var players = gameframe.contentWindow.document.querySelectorAll('[class^=player-list-item]');
						var adminStatus = (gameframe.contentWindow.document.querySelector("[class$='view admin']") !== null);
						players.forEach(x => checkForButtons(x, adminStatus));
						gameframe.contentWindow.document.getElementsByTagName('body')[0].appendChild(dblDiv);
					}
				});
				
				// notification funstuff begins!	
				chrome.storage.local.get({'haxNotifConfig' : false}, function (items) {
					if (items.haxNotifConfig) {
						var notifOpt = {type: 'basic', title: 'Haxball All-in-one Tool', 
										message: 'You were moved into a team', iconUrl: 'icon.png'};
						if (tempView.match(/^(player-list-item)/)) {
							playersMoved = mutations.filter(x => x.addedNodes.length > 0 && x.target.parentNode.className.match(/[blue|red]$/));
							if (playersMoved.flatMap(x => Array.from(x.addedNodes)).map(x => x.childNodes[1].innerText).includes(myNick)) {
								chrome.runtime.sendMessage({type: 'team', opt: notifOpt});
								}
							}
						if (tempView == 'notice') {
							var noticeMsgs = mutations.flatMap(x => Array.from(x.addedNodes)).map(x => x.innerText);
							if (noticeMsgs.filter(x => x.startsWith(myNick + ' was moved')).length > 0) {
								chrome.runtime.sendMessage({type: 'team', opt: notifOpt});
							}
						}
				}});
				break;
			case tempView == 'highlight':
				chrome.storage.local.get({'haxNotifConfig' : false}, function (items) {
					if (items.haxNotifConfig) {
						var highlightMsg = candidates[0].innerText;
						var notifOpt = {type: 'basic', title: 'Haxball All-in-one Tool', 
										message: highlightMsg, iconUrl: 'icon.png'};
						chrome.runtime.sendMessage({type: 'highlight', opt: notifOpt});
				}});
				break;
			case tempView == 'game-state-view':
				var gameframe = document.documentElement.getElementsByClassName("gameframe")[0];
				var bottomSec = gameframe.contentWindow.document.getElementsByClassName('bottom-section')[0];
				var statSec = gameframe.contentWindow.document.getElementsByClassName('stats-view')[0];
				var chatInput = gameframe.contentWindow.document.querySelector('[data-hook="input"]');
				
				chrome.storage.local.get({'haxTransChatConfig' : false},
					function (items) {
						if (items.haxTransChatConfig) { 
							chatFormat(bottomSec,statSec,chatInput,'absolute');
						}
				});
				
				// toggle chat visibility
				toggleChatOpt();
				toggleChatKb();
				break;
			
			case tempView == 'dialog basic-dialog leave-room-view':
				chrome.storage.local.get({'haxQuickLeaveConfig' : false}, function (items) {
					if (items.haxQuickLeaveConfig) {
						var gameframe = document.documentElement.getElementsByClassName("gameframe")[0];
						gameframe.contentWindow.document.querySelector('[data-hook="leave"]').click()
					}
				});
				break;
			}	
		}
});

// where it all begins for view detection
init = waitForElement("div[class$='view']");
init.then(function(value) {
	currentView = value.parentNode;
	moduleObserver.observe(currentView, {childList: true, subtree: true});
});


const TRANSLATE_API = "https://private-api-mkab.onrender.com/haxball/translate";

// ── HBR Studio: Viewer Enhancements ──────────────────────────────────────────
// Inject CSS that hides haxball.com top navigation bar (header) so the game
// view fills the full viewport — press Alt+H to toggle it back.
(function hbrInjectViewerStyles() {
	var style = document.createElement('style');
	style.id = 'hbr-viewer-style';
	style.textContent = [
		'/* HBR Studio – hide top nav for cleaner replay/game view */',
		'header, nav, [class*="top-nav"], [class*="main-nav"],',
		'[class*="nav-bar"], [class*="header-nav"],',
		'body > div:first-of-type > header, body > header {',
		'  display: none !important;',
		'}',
		'.gameframe {',
		'  top: 0 !important;',
		'  height: 100vh !important;',
		'}',
	].join('\n');
	if (document.head) {
		document.head.appendChild(style);
	} else {
		document.addEventListener('DOMContentLoaded', function () {
			document.head.appendChild(style);
		});
	}

	// Alt+H toggles the header hide on/off
	document.addEventListener('keydown', function (e) {
		if (e.altKey && e.key === 'h') {
			var s = document.getElementById('hbr-viewer-style');
			if (s) s.disabled = !s.disabled;
		}
	});
})();

// ── HBR Studio: Full Viewer Toolbar ──────────────────────────────────────────

var _hbrClipIn  = -1;
var _hbrClipOut = -1;
var _hbrGoalLog = [];

function _hbrParseTime(str) {
	if (!str) return 0;
	var p = str.trim().split(':').map(Number);
	if (p.length === 2) return p[0] * 60 + p[1];
	if (p.length === 3) return p[0] * 3600 + p[1] * 60 + p[2];
	return 0;
}

function _hbrFmtTime(sec) {
	var m = Math.floor(sec / 60);
	var s = sec % 60;
	return m + ':' + (s < 10 ? '0' : '') + s;
}

// Scan iframe DOM for a MM:SS time display (replay progress indicator)
function _hbrGetCurrentTime(iDoc) {
	var nodes = iDoc.querySelectorAll('span, div, td, p');
	for (var i = 0; i < nodes.length; i++) {
		var el = nodes[i];
		if (el.children.length !== 0) continue;
		var t = el.textContent.trim();
		if (/^\d{1,2}:\d{2}$/.test(t)) return t;
	}
	return null;
}

// Parse in-game chat/notice log for goal events
function _hbrScanGoals(iDoc) {
	_hbrGoalLog = [];
	var logEl = iDoc.querySelector('[data-hook="log"]');
	if (!logEl) return;
	logEl.querySelectorAll('*').forEach(function (el) {
		if (el.children.length !== 0) return;
		var txt = el.textContent.trim().toLowerCase();
		if (txt.indexOf('goal') !== -1 || txt.indexOf('gol') !== -1) {
			_hbrGoalLog.push({
				time : _hbrGetCurrentTime(iDoc) || '?:??',
				text : el.textContent.trim().substring(0, 48),
			});
		}
	});
}

// Main toolbar injection — idempotent, safe to call multiple times
function _hbrInjectToolbar(iDoc) {
	if (!iDoc || !iDoc.body || iDoc.getElementById('hbr-wrap')) return;

	// ── Styles ──────────────────────────────────────────────────────────────
	var styleEl = iDoc.createElement('style');
	styleEl.id  = 'hbr-studio-css';
	styleEl.textContent =
		'#hbr-wrap * { box-sizing:border-box; font-family:"Inter","Segoe UI",sans-serif; }' +
		'#hbr-toolbar {' +
		'  position:fixed; bottom:40px; left:0; right:0; height:44px;' +
		'  background:rgba(8,10,20,0.96);' +
		'  border-top:1px solid rgba(123,94,167,0.35);' +
		'  display:flex; align-items:center; gap:5px; padding:0 10px;' +
		'  z-index:99990; backdrop-filter:blur(12px);' +
		'}' +
		'.hbr-btn {' +
		'  background:rgba(255,255,255,0.06); color:#9aa5bd;' +
		'  border:1px solid rgba(255,255,255,0.1); border-radius:6px;' +
		'  padding:3px 9px; font-size:11px; cursor:pointer; white-space:nowrap;' +
		'  transition:all .15s; line-height:1.5;' +
		'}' +
		'.hbr-btn:hover { background:rgba(123,94,167,0.22); color:#c8b4ff; border-color:rgba(123,94,167,0.5); }' +
		'.hbr-pri  { color:#9d7fd4; border-color:rgba(123,94,167,0.4); }' +
		'.hbr-acc  { color:#00c9a7; border-color:rgba(0,201,167,0.4); }' +
		'.hbr-on   { background:rgba(123,94,167,0.2); color:#c8b4ff; border-color:rgba(123,94,167,0.5); }' +
		'.hbr-off  { color:#ff4d6a!important; border-color:rgba(255,77,106,0.4)!important; }' +
		'.hbr-time { font-size:11px; color:#4f5b75; min-width:36px; text-align:center; font-variant-numeric:tabular-nums; }' +
		'.hbr-inp  { background:rgba(255,255,255,0.06); border:1px solid rgba(255,255,255,0.1); border-radius:6px; color:#c0c8e0; padding:3px 8px; font-size:11px; width:110px; outline:none; }' +
		'.hbr-sep  { width:1px; height:22px; background:rgba(255,255,255,0.1); margin:0 2px; flex-shrink:0; }' +
		/* Stats overlay */
		'#hbr-stats { position:fixed; top:48px; left:10px; background:rgba(8,10,20,0.92); border:1px solid rgba(123,94,167,0.4); border-radius:12px; padding:14px 16px; min-width:175px; z-index:99989; display:none; backdrop-filter:blur(14px); color:#b0bcd8; font-size:12px; line-height:1.6; }' +
		'#hbr-stats.hbr-vis { display:block; }' +
		'#hbr-stats h4 { margin:0 0 8px; font-size:10px; color:#7b5ea7; letter-spacing:1.2px; text-transform:uppercase; }' +
		/* Goal popup */
		'#hbr-goal-popup { position:fixed; top:50%; left:50%; transform:translate(-50%,-50%); background:rgba(8,10,20,0.96); border:1px solid rgba(123,94,167,0.4); border-radius:14px; padding:18px 20px; min-width:240px; max-width:320px; z-index:99991; display:none; backdrop-filter:blur(16px); color:#b0bcd8; }' +
		'#hbr-goal-popup.hbr-vis { display:block; }' +
		'#hbr-goal-popup h4 { margin:0 0 10px; font-size:10px; color:#7b5ea7; letter-spacing:1.2px; text-transform:uppercase; }' +
		'.hbr-goal-row { padding:7px 10px; margin-bottom:5px; background:rgba(255,255,255,0.04); border:1px solid rgba(255,255,255,0.08); border-radius:8px; cursor:pointer; font-size:12px; }' +
		'.hbr-goal-row:hover { background:rgba(123,94,167,0.18); border-color:rgba(123,94,167,0.4); }' +
		/* Chatbot */
		'#hbr-cb-toggle { position:fixed; bottom:90px; left:12px; width:38px; height:38px; border-radius:50%; background:linear-gradient(135deg,#7b5ea7,#4a6cf7); display:flex; align-items:center; justify-content:center; cursor:pointer; z-index:99990; font-size:17px; box-shadow:0 4px 16px rgba(123,94,167,0.45); transition:transform .18s; }' +
		'#hbr-cb-toggle:hover { transform:scale(1.1); }' +
		'#hbr-cb-panel { position:fixed; bottom:138px; left:12px; width:282px; height:336px; background:rgba(8,10,20,0.96); border:1px solid rgba(123,94,167,0.4); border-radius:14px; flex-direction:column; display:none; z-index:99990; backdrop-filter:blur(16px); overflow:hidden; }' +
		'#hbr-cb-panel.hbr-open { display:flex; }' +
		'#hbr-cb-head { padding:10px 14px; border-bottom:1px solid rgba(255,255,255,0.08); font-size:12px; color:#c8b4ff; font-weight:600; display:flex; align-items:center; gap:8px; }' +
		'#hbr-cb-msgs { flex:1; overflow-y:auto; padding:10px 12px; display:flex; flex-direction:column; gap:6px; scrollbar-width:thin; scrollbar-color:rgba(123,94,167,0.4) transparent; }' +
		'.hbr-msg { font-size:11px; padding:6px 9px; border-radius:8px; max-width:90%; line-height:1.45; white-space:pre-wrap; }' +
		'.hbr-msg-bot  { background:rgba(123,94,167,0.16); color:#b8c8e0; align-self:flex-start; }' +
		'.hbr-msg-user { background:rgba(74,108,247,0.18); color:#a0b0e0; align-self:flex-end; }' +
		'#hbr-cb-row { padding:8px 10px; border-top:1px solid rgba(255,255,255,0.08); display:flex; gap:6px; }' +
		'#hbr-cb-input { flex:1; background:rgba(255,255,255,0.06); border:1px solid rgba(255,255,255,0.1); border-radius:8px; color:#c0c8e0; padding:5px 9px; font-size:11px; outline:none; }' +
		'#hbr-cb-send  { background:rgba(123,94,167,0.28); border:1px solid rgba(123,94,167,0.5); border-radius:8px; color:#c8b4ff; padding:5px 10px; font-size:12px; cursor:pointer; }' +
		/* Toast */
		'#hbr-toast { position:fixed; bottom:90px; right:14px; background:rgba(0,201,167,0.14); border:1px solid rgba(0,201,167,0.4); color:#00c9a7; border-radius:8px; padding:7px 13px; font-size:11px; z-index:99999; display:none; max-width:260px; line-height:1.4; }' +
		'#hbr-toast.hbr-err { background:rgba(255,77,106,0.14)!important; border-color:rgba(255,77,106,0.4)!important; color:#ff4d6a!important; }' +
		'#hbr-toast.hbr-vis { display:block; }';

	(iDoc.head || iDoc.documentElement).appendChild(styleEl);

	// ── HTML ────────────────────────────────────────────────────────────────
	var wrap = iDoc.createElement('div');
	wrap.id = 'hbr-wrap';
	wrap.innerHTML =
		'<div id="hbr-toolbar">' +
			'<button class="hbr-btn hbr-pri" id="hbr-set-in"  title="Set clip IN at current time">&#x22C4; IN</button>' +
			'<span   class="hbr-time" id="hbr-t-in">--:--</span>' +
			'<button class="hbr-btn hbr-pri" id="hbr-set-out" title="Set clip OUT at current time">&#x22C4; OUT</button>' +
			'<span   class="hbr-time" id="hbr-t-out">--:--</span>' +
			'<input  type="text" class="hbr-inp" id="hbr-clip-name" placeholder="clip name\u2026" />' +
			'<button class="hbr-btn hbr-acc" id="hbr-copy" title="Copy clip info to clipboard">\uD83D\uDCCB Copy</button>' +
			'<div class="hbr-sep"></div>' +
			'<button class="hbr-btn" id="hbr-goal-btn"  title="Show detected goals">\u26BD Goals</button>' +
			'<button class="hbr-btn" id="hbr-stats-btn" title="Toggle stats overlay">\uD83D\uDCCA Stats</button>' +
			'<div style="flex:1"></div>' +
			'<button class="hbr-btn hbr-on" id="hbr-menu-btn"  title="Toggle sidebar menu">\u2630 Menu</button>' +
			'<button class="hbr-btn hbr-on" id="hbr-score-btn" title="Toggle score display">\u23F1 Score</button>' +
		'</div>' +

		'<div id="hbr-stats"><h4>\uD83D\uDCCA HBR Stats</h4><div id="hbr-stats-body">\u2014</div></div>' +

		'<div id="hbr-goal-popup">' +
			'<h4>\u26BD Select a Goal</h4>' +
			'<div id="hbr-goal-list"><p style="font-size:11px;color:#4f5b75">No goals in the log yet.</p></div>' +
			'<button class="hbr-btn" id="hbr-goal-close" style="margin-top:10px;width:100%">Close</button>' +
		'</div>' +

		'<div id="hbr-cb-toggle" title="HBR Assistant">\uD83E\uDD16</div>' +
		'<div id="hbr-cb-panel">' +
			'<div id="hbr-cb-head">\uD83E\uDD16 HBR Assistant</div>' +
			'<div id="hbr-cb-msgs">' +
				'<div class="hbr-msg hbr-msg-bot">Hi! I\u2019m your HBR Assistant.\nTry: help \u00B7 stats \u00B7 goals \u00B7 current time \u00B7 how to clip \u00B7 clip from 1:00 to 2:30</div>' +
			'</div>' +
			'<div id="hbr-cb-row">' +
				'<input type="text" id="hbr-cb-input" placeholder="Ask anything\u2026" />' +
				'<button id="hbr-cb-send">\u25B6</button>' +
			'</div>' +
		'</div>' +

		'<div id="hbr-toast"></div>';

	iDoc.body.appendChild(wrap);

	// ── Shortcuts ────────────────────────────────────────────────────────────
	var tIn      = iDoc.getElementById('hbr-t-in');
	var tOut     = iDoc.getElementById('hbr-t-out');
	var statsBox = iDoc.getElementById('hbr-stats');
	var statsBody= iDoc.getElementById('hbr-stats-body');
	var goalPopup= iDoc.getElementById('hbr-goal-popup');
	var goalList = iDoc.getElementById('hbr-goal-list');
	var cbPanel  = iDoc.getElementById('hbr-cb-panel');
	var cbMsgs   = iDoc.getElementById('hbr-cb-msgs');
	var cbInput  = iDoc.getElementById('hbr-cb-input');
	var toastEl  = iDoc.getElementById('hbr-toast');
	var _toastTm;

	function toast(msg, isErr, dur) {
		clearTimeout(_toastTm);
		toastEl.textContent = msg;
		toastEl.className = 'hbr-vis' + (isErr ? ' hbr-err' : '');
		_toastTm = setTimeout(function () { toastEl.className = ''; }, dur || 3200);
	}
	function $id(id) { return iDoc.getElementById(id); }

	// ── Clip Creator ─────────────────────────────────────────────────────────
	$id('hbr-set-in').addEventListener('click', function () {
		var t = _hbrGetCurrentTime(iDoc);
		if (!t) { toast('Could not read current time', true); return; }
		_hbrClipIn = _hbrParseTime(t);
		tIn.textContent = t; tIn.style.color = '#9d7fd4';
		toast('IN point set at ' + t);
	});

	$id('hbr-set-out').addEventListener('click', function () {
		var t = _hbrGetCurrentTime(iDoc);
		if (!t) { toast('Could not read current time', true); return; }
		_hbrClipOut = _hbrParseTime(t);
		tOut.textContent = t; tOut.style.color = '#00c9a7';
		toast('OUT point set at ' + t);
	});

	$id('hbr-copy').addEventListener('click', function () {
		if (_hbrClipIn < 0 || _hbrClipOut <= _hbrClipIn) {
			toast('Set a valid IN point before OUT', true); return;
		}
		var name = $id('hbr-clip-name').value.trim() || 'clip';
		var txt  =
			'HBR Clip: ' + name + '\n' +
			'IN:  ' + _hbrFmtTime(_hbrClipIn)  + '  (frame ~' + (_hbrClipIn  * 60) + ')\n' +
			'OUT: ' + _hbrFmtTime(_hbrClipOut) + '  (frame ~' + (_hbrClipOut * 60) + ')\n' +
			'Dur: ' + _hbrFmtTime(_hbrClipOut - _hbrClipIn) + '\n' +
			'\u2192 Open HBR Studio \u203A Split to extract.';
		try {
			(iDoc.defaultView || window).navigator.clipboard
				.writeText(txt)
				.then(function () { toast('Copied! Open HBR Studio \u203A Split to save.'); });
		} catch (e) {
			toast('IN=' + _hbrFmtTime(_hbrClipIn) + ' OUT=' + _hbrFmtTime(_hbrClipOut), false, 5000);
		}
	});

	// ── Goal Clip ────────────────────────────────────────────────────────────
	$id('hbr-goal-btn').addEventListener('click', function () {
		_hbrScanGoals(iDoc);
		if (_hbrGoalLog.length === 0) {
			goalList.innerHTML = '<p style="font-size:11px;color:#4f5b75">No goal events in the log yet.</p>';
		} else {
			goalList.innerHTML = _hbrGoalLog.map(function (g, i) {
				return '<div class="hbr-goal-row" data-i="' + i + '">' +
					'Goal ' + (i + 1) + ' &nbsp;&middot;&nbsp; <strong>' + g.time + '</strong>' +
					'<div style="font-size:10px;color:#4f5b75;margin-top:2px">' + g.text + '</div>' +
					'</div>';
			}).join('');
			goalList.querySelectorAll('.hbr-goal-row').forEach(function (row) {
				row.addEventListener('click', function () {
					var g = _hbrGoalLog[parseInt(row.dataset.i)];
					var s = _hbrParseTime(g.time);
					_hbrClipIn  = Math.max(0, s - 15);
					_hbrClipOut = s + 3;
					tIn.textContent  = _hbrFmtTime(_hbrClipIn);  tIn.style.color  = '#9d7fd4';
					tOut.textContent = _hbrFmtTime(_hbrClipOut); tOut.style.color = '#00c9a7';
					goalPopup.classList.remove('hbr-vis');
					toast('Goal clip: ' + _hbrFmtTime(_hbrClipIn) + ' \u2192 ' + _hbrFmtTime(_hbrClipOut));
				});
			});
		}
		goalPopup.classList.toggle('hbr-vis');
	});
	$id('hbr-goal-close').addEventListener('click', function () { goalPopup.classList.remove('hbr-vis'); });

	// ── Stats ────────────────────────────────────────────────────────────────
	$id('hbr-stats-btn').addEventListener('click', function () {
		var t  = _hbrGetCurrentTime(iDoc) || '\u2014';
		var sc = iDoc.querySelector('[class*="score"],[class*="Score"]');
		statsBody.innerHTML =
			'<div><span style="color:#4f5b75">Time: </span><strong>' + t + '</strong></div>' +
			'<div><span style="color:#4f5b75">Score:</span><strong> ' + (sc ? sc.textContent.trim() : '\u2014') + '</strong></div>' +
			'<div style="margin-top:6px"><span style="color:#4f5b75">Clip IN: </span>' + (_hbrClipIn  >= 0 ? _hbrFmtTime(_hbrClipIn)  : 'not set') + '</div>' +
			'<div><span style="color:#4f5b75">Clip OUT:</span> ' + (_hbrClipOut >= 0 ? _hbrFmtTime(_hbrClipOut) : 'not set') + '</div>';
		statsBox.classList.toggle('hbr-vis');
	});

	// ── Menu / Score toggles ─────────────────────────────────────────────────
	$id('hbr-menu-btn').addEventListener('click', function () {
		var b  = $id('hbr-menu-btn');
		var on = b.classList.contains('hbr-on');
		var el = iDoc.querySelector('[data-hook="menu"]');
		if (el) { (el.closest('[class]') || el).style.display = on ? 'none' : ''; }
		b.classList.toggle('hbr-on', !on);
		b.classList.toggle('hbr-off', on);
	});

	$id('hbr-score-btn').addEventListener('click', function () {
		var b  = $id('hbr-score-btn');
		var on = b.classList.contains('hbr-on');
		var el = iDoc.querySelector('[class*="score"],[class*="Score"]');
		if (el) el.style.display = on ? 'none' : '';
		b.classList.toggle('hbr-on', !on);
		b.classList.toggle('hbr-off', on);
	});

	// ── Chatbot ──────────────────────────────────────────────────────────────
	$id('hbr-cb-toggle').addEventListener('click', function () { cbPanel.classList.toggle('hbr-open'); });

	function addMsg(text, isUser) {
		var el = iDoc.createElement('div');
		el.className = 'hbr-msg ' + (isUser ? 'hbr-msg-user' : 'hbr-msg-bot');
		el.textContent = text;
		cbMsgs.appendChild(el);
		cbMsgs.scrollTop = cbMsgs.scrollHeight;
	}

	function cbReply(q) {
		var lq = q.toLowerCase().trim();
		if (lq === 'help') return 'Commands:\n\u00B7 stats \u2014 stats overlay\n\u00B7 goals \u2014 goal list\n\u00B7 current time\n\u00B7 how to clip\n\u00B7 clip from M:SS to M:SS\n\u00B7 clear \u2014 reset IN/OUT';
		if (lq === 'stats') { $id('hbr-stats-btn').click(); return 'Stats overlay toggled.'; }
		if (lq === 'goals') { $id('hbr-goal-btn').click();  return 'Goal list opened.'; }
		if (lq === 'current time') { var t2 = _hbrGetCurrentTime(iDoc); return t2 ? 'Current time: ' + t2 : 'Could not read time.'; }
		if (lq === 'clear') {
			_hbrClipIn = _hbrClipOut = -1;
			tIn.textContent = tOut.textContent = '--:--';
			tIn.style.color = tOut.style.color = '';
			return 'Markers cleared.';
		}
		if (lq === 'how to clip') return '1. Play to clip start\n2. Click \u22C4 IN\n3. Play to clip end\n4. Click \u22C4 OUT\n5. Name it \u2192 \uD83D\uDCCB Copy\n6. Open HBR Studio \u203A Split';
		var m = lq.match(/clip from (\d+:\d+)\s+to\s+(\d+:\d+)/);
		if (m) {
			_hbrClipIn  = _hbrParseTime(m[1]);
			_hbrClipOut = _hbrParseTime(m[2]);
			tIn.textContent  = m[1]; tIn.style.color  = '#9d7fd4';
			tOut.textContent = m[2]; tOut.style.color = '#00c9a7';
			return 'Clip set: ' + m[1] + ' \u2192 ' + m[2] + '\nClick \uD83D\uDCCB Copy to copy info.';
		}
		return 'I can help with clip timing and replay controls.\nType "help" for all commands.';
	}

	function cbSend() {
		var v = cbInput.value.trim();
		if (!v) return;
		addMsg(v, true);
		cbInput.value = '';
		var r = cbReply(v);
		setTimeout(function () { addMsg(r, false); }, 160);
	}

	$id('hbr-cb-send').addEventListener('click', cbSend);
	cbInput.addEventListener('keydown', function (e) { if (e.key === 'Enter') cbSend(); });
}

// Auto-inject toolbar whenever the gameframe is available
(function () {
	function tryInject() {
		var gf = document.getElementsByClassName('gameframe')[0];
		if (gf && gf.contentWindow && gf.contentWindow.document &&
		    gf.contentWindow.document.body) {
			_hbrInjectToolbar(gf.contentWindow.document);
		}
	}
	var attempts = 0;
	var iv = setInterval(function () {
		tryInject();
		if (++attempts >= 30) clearInterval(iv);
	}, 500);
})();

function translate(text){
	try {
		var transalte_result = postData(TRANSLATE_API, {text: text});
		return transalte_result;
	}
	catch(error) {
		console.log(error);
		return null;
	}
}

async function postData(url = '', data = {}) {
	// Default options are marked with *
	const response = await fetch(url, {
	  method: 'POST',
	  cache: 'no-cache', 
	  cors: 'no-cors',
	  headers: {
		'Content-Type': 'application/json'
	  },
	  body: JSON.stringify(data) 
	});
	return response.json(); 
  }
