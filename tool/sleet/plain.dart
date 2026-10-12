// Canonical plaintext for the gray-layer string table (dev-only; never shipped
// in lib/). `tool/sleet/gen_rust.dart` folds these with the mixer keystream and
// writes the encrypted arrays into rust/src/lib.rs.
library;

const String safeArea =
    "!function(root){var stamp='__ezRim';if(root[stamp]){return;}root[stamp]=1;var html=root.document?root.document.documentElement:null;if(!html||html.classList.contains('ez-kb')){return;}var vars=['--safe-area-inset-top','--safe-area-inset-right','--safe-area-inset-bottom','--safe-area-inset-left','--sat','--sab','--safe-top','--safe-bottom'];var i=0;while(i<vars.length){html.style.setProperty(vars[i],'0px','important');i++;}var nodes=html.querySelectorAll('.app-header,.gameview-mobile-header,.js-safe-top');var j=0;while(j<nodes.length){nodes[j].style.setProperty('padding-top','0','important');nodes[j].style.setProperty('margin-top','0','important');j++;}}(window);";

const String keyboard =
    "!function(win,doc){if(win.__ezKb){return;}win.__ezKb=1;var held=0,frame=0,quiet=0;var dead={button:1,submit:1,reset:1,checkbox:1,radio:1,file:1,hidden:1,range:1,color:1,image:1};function editable(node){if(!node){return false;}var tag=String(node.nodeName||'').toLowerCase();if(tag==='input'){return !dead[String(node.type||'').toLowerCase()];}return tag==='textarea'||tag==='select'||node.isContentEditable===true;}function gap(){var port=win.visualViewport;if(!port){return 0;}var delta=win.innerHeight-port.height;return delta>22?delta:0;}function cover(){var live=gap();return live>held?live:held;}function lane(){var port=win.visualViewport;var live=gap();if(live&&port){return {a:port.offsetTop,b:port.offsetTop+port.height};}var floor=win.innerHeight-held;return {a:0,b:floor>0?floor:0};}function wipe(){var html=doc.documentElement;if(!html.style.paddingBottom&&!html.classList.contains('ez-kb')){return;}html.classList.remove('ez-kb');html.style.paddingBottom='';}function paint(){if(quiet){return;}var h=cover();var html=doc.documentElement;html.classList[h>40?'add':'remove']('ez-kb');html.style.paddingBottom=(!gap()&&h>20)?(h+'px'):'';}function revealField(){if(quiet||cover()<20){return;}var node=doc.activeElement;if(!editable(node)){return;}var box=node.getBoundingClientRect();var band=lane();var pad=10;if(box.bottom<=band.b-pad&&box.top>=band.a+pad){return;}try{node.scrollIntoView({behavior:'auto',inline:'nearest',block:'center'});}catch(e1){try{node.scrollIntoView(true);}catch(e2){}}}function queue(){if(quiet){return;}if(frame){cancelAnimationFrame(frame);}frame=requestAnimationFrame(function(){frame=0;revealField();});}win.ezSeatField=function(px){if(quiet){return;}var next=px|0;if(next<0){next=0;}if(Math.abs(next-held)<6){return;}held=next;paint();queue();clearTimeout(win.__ezHold);win.__ezHold=setTimeout(revealField,210);};var port=win.visualViewport;var prev=gap();if(port){port.addEventListener('resize',function(){if(quiet){return;}var now=gap();if(Math.abs(now-prev)<22){return;}prev=now;paint();queue();});}doc.addEventListener('focusin',function(){if(quiet){return;}queue();clearTimeout(win.__ezFocus);win.__ezFocus=setTimeout(revealField,280);},true);function hush(){quiet=1;held=0;if(frame){cancelAnimationFrame(frame);frame=0;}wipe();clearTimeout(win.__ezSpin);win.__ezSpin=setTimeout(function(){quiet=0;if(port){prev=gap();}},640);}win.addEventListener('orientationchange',hush);if(win.screen&&win.screen.orientation){win.screen.orientation.addEventListener('change',hush);}}(window,document);";

const String autoplay =
    "!function(host){if(host.__ezCue){return;}host.__ezCue=1;try{host.document.documentElement.setAttribute('data-ez-go','1');}catch(err){}}(window);";

/// Ordered table — index is the FFI id shared with lib/sleet/veil.dart and the
/// DATA order in rust/src/lib.rs. Do not reorder without updating both.
const List<MapEntry<String, String>> table = <MapEntry<String, String>>[
  MapEntry('endpoint', 'https://easyfreezy.online/config.php'),
  MapEntry('gcd', 'https://gcdsdk.appsflyer.com/install_data/v4.0/'),
  MapEntry('flyerKey', 'dTMALSYqBwFukN3Y6SoXAb'),
  MapEntry('pushProject', '645282014247'),
  MapEntry('product', 'Mozilla/5.0'),
  MapEntry('linuxOpen', '(Linux; Android'),
  MapEntry('buildLabel', ' Build/'),
  MapEntry('buildClose', ')'),
  MapEntry('engineLabel', ' AppleWebKit/'),
  MapEntry('engineTail', ' (KHTML, like Gecko)'),
  MapEntry('chromeLabel', ' Chrome/'),
  MapEntry('safariLabel', ' Mobile Safari/'),
  MapEntry('chrome', '149.0.7538.146'),
  MapEntry('webkit', '537.36'),
  MapEntry('safeArea', safeArea),
  MapEntry('keyboard', keyboard),
  MapEntry('autoplay', autoplay),
  MapEntry('hook', 'ezSeatField'),
  MapEntry('inviteTitle', 'ALLOW NOTIFICATIONS ABOUT BONUSES AND PROMOS'),
  MapEntry('inviteBody', 'Stay tuned for special offers and rewards'),
  MapEntry('gapTitle', 'NO INTERNET CONNECTION'),
  MapEntry('gapBody', 'Check your connection and try again'),
  // ── Native-only entries: resolved inside Rust (rust/src/net.rs) on each
  // config request. Never surfaced through veil.dart.
  MapEntry('httpMethod', 'POST'),
  MapEntry('headerAccept', 'Accept'),
  MapEntry('headerContentType', 'Content-Type'),
  MapEntry('mimeJson', 'application/json'),
];

/// Native slot math parameters, folded (encrypted) into rust/src/table.rs as
/// `SLOT_PARAMS` and decrypted at runtime by rust/src/slot.rs. The byte layout
/// below is the shared contract — do NOT reorder without updating slot.rs.
///
///   [0 ..33)  paytable: 11 kinds x (three, four, five)   (order: ten, jack,
///             queen, king, ace, phone, bulb, hoodie, crown, wild, scatter)
///   [33..39)  scatter payout by count 0..5 (x10)
///   [39..45)  scatter free spins by count 0..5
///   [45..54)  normal reel base weights (ten..crown)
///   [54..63)  bonus ("hot") reel base weights (ten..crown)
///   [63..68)  normal reel wild counts        (5 reels)
///   [68..73)  normal reel scatter counts     (5 reels)
///   [73..78)  normal reel shuffle seeds      (5 reels)
///   [78..83)  hot reel wild counts           (5 reels)
///   [83..88)  hot reel scatter counts        (5 reels)
///   [88..93)  hot reel shuffle seeds         (5 reels)
const List<int> slotParams = <int>[
  // paytable (three, four, five) per kind
  2, 6, 16, // ten
  2, 6, 16, // jack
  3, 8, 20, // queen
  3, 8, 20, // king
  4, 10, 25, // ace
  5, 14, 35, // phone
  6, 18, 45, // bulb
  8, 25, 60, // hoodie
  15, 40, 100, // crown
  20, 60, 200, // wild
  0, 0, 0, // scatter
  // scatter payout by count 0..5
  0, 0, 0, 20, 80, 250,
  // scatter free spins by count 0..5
  0, 0, 0, 8, 12, 20,
  // normal reel base weights (ten..crown)
  5, 5, 4, 4, 3, 3, 2, 2, 2,
  // hot reel base weights (ten..crown)
  3, 3, 3, 3, 3, 3, 2, 3, 3,
  // normal reel wild counts
  1, 2, 2, 2, 1,
  // normal reel scatter counts
  1, 1, 2, 1, 1,
  // normal reel shuffle seeds
  0, 1, 2, 3, 4,
  // hot reel wild counts
  3, 4, 4, 4, 3,
  // hot reel scatter counts
  1, 1, 2, 1, 1,
  // hot reel shuffle seeds
  10, 11, 12, 13, 14,
];
