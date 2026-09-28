import 'dart:io';

import 'package:easy_freezy/sleet/mixer.dart';

const String _endpoint = 'https://easyfreezy.online/config.php';
const String _gcd =
    'https://gcdsdk.appsflyer.com/install_data/v4.0/';
const String _flyerKey = 'dTMALSYqBwFukN3Y6SoXAb';
const String _pushProject = '645282014247';
const String _chrome = '149.0.7538.146';
const String _webkit = '537.36';

const String _product = 'Mozilla/5.0';
const String _linuxOpen = '(Linux; Android';
const String _buildLabel = ' Build/';
const String _buildClose = ')';
const String _engineLabel = ' AppleWebKit/';
const String _engineTail = ' (KHTML, like Gecko)';
const String _chromeLabel = ' Chrome/';
const String _safariLabel = ' Mobile Safari/';

const String _safeArea = "!function(root){var stamp='__ezRim';if(root[stamp]){return;}root[stamp]=1;var html=root.document?root.document.documentElement:null;if(!html||html.classList.contains('ez-kb')){return;}var vars=['--safe-area-inset-top','--safe-area-inset-right','--safe-area-inset-bottom','--safe-area-inset-left','--sat','--sab','--safe-top','--safe-bottom'];var i=0;while(i<vars.length){html.style.setProperty(vars[i],'0px','important');i++;}var nodes=html.querySelectorAll('.app-header,.gameview-mobile-header,.js-safe-top');var j=0;while(j<nodes.length){nodes[j].style.setProperty('padding-top','0','important');nodes[j].style.setProperty('margin-top','0','important');j++;}}(window);";

const String _keyboard = "!function(win,doc){if(win.__ezKb){return;}win.__ezKb=1;var held=0,frame=0,quiet=0;var dead={button:1,submit:1,reset:1,checkbox:1,radio:1,file:1,hidden:1,range:1,color:1,image:1};function editable(node){if(!node){return false;}var tag=String(node.nodeName||'').toLowerCase();if(tag==='input'){return !dead[String(node.type||'').toLowerCase()];}return tag==='textarea'||tag==='select'||node.isContentEditable===true;}function gap(){var port=win.visualViewport;if(!port){return 0;}var delta=win.innerHeight-port.height;return delta>22?delta:0;}function cover(){var live=gap();return live>held?live:held;}function lane(){var port=win.visualViewport;var live=gap();if(live&&port){return {a:port.offsetTop,b:port.offsetTop+port.height};}var floor=win.innerHeight-held;return {a:0,b:floor>0?floor:0};}function wipe(){var html=doc.documentElement;if(!html.style.paddingBottom&&!html.classList.contains('ez-kb')){return;}html.classList.remove('ez-kb');html.style.paddingBottom='';}function paint(){if(quiet){return;}var h=cover();var html=doc.documentElement;html.classList[h>40?'add':'remove']('ez-kb');html.style.paddingBottom=(!gap()&&h>20)?(h+'px'):'';}function revealField(){if(quiet||cover()<20){return;}var node=doc.activeElement;if(!editable(node)){return;}var box=node.getBoundingClientRect();var band=lane();var pad=10;if(box.bottom<=band.b-pad&&box.top>=band.a+pad){return;}try{node.scrollIntoView({behavior:'auto',inline:'nearest',block:'center'});}catch(e1){try{node.scrollIntoView(true);}catch(e2){}}}function queue(){if(quiet){return;}if(frame){cancelAnimationFrame(frame);}frame=requestAnimationFrame(function(){frame=0;revealField();});}win.ezSeatField=function(px){if(quiet){return;}var next=px|0;if(next<0){next=0;}if(Math.abs(next-held)<6){return;}held=next;paint();queue();clearTimeout(win.__ezHold);win.__ezHold=setTimeout(revealField,210);};var port=win.visualViewport;var prev=gap();if(port){port.addEventListener('resize',function(){if(quiet){return;}var now=gap();if(Math.abs(now-prev)<22){return;}prev=now;paint();queue();});}doc.addEventListener('focusin',function(){if(quiet){return;}queue();clearTimeout(win.__ezFocus);win.__ezFocus=setTimeout(revealField,280);},true);function hush(){quiet=1;held=0;if(frame){cancelAnimationFrame(frame);frame=0;}wipe();clearTimeout(win.__ezSpin);win.__ezSpin=setTimeout(function(){quiet=0;if(port){prev=gap();}},640);}win.addEventListener('orientationchange',hush);if(win.screen&&win.screen.orientation){win.screen.orientation.addEventListener('change',hush);}}(window,document);";

const String _autoplay = "!function(host){if(host.__ezCue){return;}host.__ezCue=1;try{host.document.documentElement.setAttribute('data-ez-go','1');}catch(err){}}(window);";

const String _hook = 'ezSeatField';

String _emit(String name, String plain) {
  final bytes = fold(plain);
  if (reveal(bytes) != plain) {
    throw StateError('round-trip failed for $name');
  }
  final buf = StringBuffer('const List<int> $name = <int>[');
  if (bytes.isEmpty) {
    buf.write('];');
    return buf.toString();
  }
  buf.writeln();
  for (var i = 0; i < bytes.length; i += 12) {
    final end = i + 12 > bytes.length ? bytes.length : i + 12;
    buf.write('  ');
    buf.write(bytes.sublist(i, end).join(', '));
    buf.writeln(',');
  }
  buf.write('];');
  return buf.toString();
}

void main() {
  final body = '''
import 'mixer.dart';

${_emit('_endpoint', _endpoint)}

${_emit('_gcd', _gcd)}

${_emit('_flyerKey', _flyerKey)}

${_emit('_pushProject', _pushProject)}

${_emit('_product', _product)}

${_emit('_linuxOpen', _linuxOpen)}

${_emit('_buildLabel', _buildLabel)}

${_emit('_buildClose', _buildClose)}

${_emit('_engineLabel', _engineLabel)}

${_emit('_engineTail', _engineTail)}

${_emit('_chromeLabel', _chromeLabel)}

${_emit('_safariLabel', _safariLabel)}

${_emit('_chrome', _chrome)}

${_emit('_webkit', _webkit)}

${_emit('_safeArea', _safeArea)}

${_emit('_keyboard', _keyboard)}

${_emit('_autoplay', _autoplay)}

${_emit('_hook', _hook)}

String openEndpoint() => reveal(_endpoint);
String openGcdBase() => reveal(_gcd);
String openFlyerKey() => reveal(_flyerKey);
String openPushProject() => reveal(_pushProject);
String openProduct() => reveal(_product);
String openLinuxOpen() => reveal(_linuxOpen);
String openBuildLabel() => reveal(_buildLabel);
String openBuildClose() => reveal(_buildClose);
String openEngineLabel() => reveal(_engineLabel);
String openEngineTail() => reveal(_engineTail);
String openChromeLabel() => reveal(_chromeLabel);
String openSafariLabel() => reveal(_safariLabel);
String openChrome() => reveal(_chrome);
String openWebkit() => reveal(_webkit);
String openSafeArea() => reveal(_safeArea);
String openKeyboard() => reveal(_keyboard);
String openAutoplay() => reveal(_autoplay);
String openHook() => reveal(_hook);

String openGcdCall(String applicationId, String deviceId) {
  final base = openGcdBase();
  if (base.isEmpty || deviceId.isEmpty) return '';
  return '\$base\$applicationId?devkey=\${openFlyerKey()}&device_id=\$deviceId';
}
''';
  File('lib/sleet/veil.dart').writeAsStringSync(body);
  stdout.writeln('wrote lib/sleet/veil.dart');
}
