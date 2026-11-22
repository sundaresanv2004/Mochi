#if os(Windows)
/// The Windows settings page (served by `SettingsServer`): the same pages as the Mac's settings window.
enum SettingsPage {
    static let html = #"""
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Mochi Settings</title>
<style>
:root { --bg:#f3f3f7; --card:#fff; --ink:#1d1b20; --soft:#6b6870; --line:#e4e2ea; --accent:#6750c8; --accent-ink:#fff; --side:#ebe9f2; }
@media (prefers-color-scheme: dark) { :root { --bg:#1c1b20; --card:#27262c; --ink:#f0eef4; --soft:#a6a3ad; --line:#38363e; --accent:#a493ff; --accent-ink:#1c1b20; --side:#222127; } }
* { box-sizing:border-box } body { margin:0; font:14px/1.45 "Segoe UI Variable Text","Segoe UI",system-ui,sans-serif; background:var(--bg); color:var(--ink); display:flex; min-height:100vh }
nav { width:220px; background:var(--side); padding:18px 10px; position:sticky; top:0; height:100vh; flex-shrink:0 }
nav h1 { font-size:18px; margin:4px 10px 16px } nav a { display:flex; gap:10px; align-items:center; padding:9px 12px; border-radius:9px; color:var(--ink); text-decoration:none; margin-bottom:2px }
nav a.on { background:var(--card); font-weight:600; box-shadow:0 1px 2px #0001 } nav a span { width:20px; text-align:center }
main { flex:1; padding:26px 34px 60px; max-width:900px } h2 { margin:0 0 2px; font-size:24px } .sub { color:var(--soft); margin-bottom:20px }
.card { background:var(--card); border:1px solid var(--line); border-radius:14px; margin:14px 0; overflow:hidden } .card h3 { margin:0; padding:12px 16px 4px; font-size:13px; color:var(--soft); font-weight:600 }
.row { display:flex; align-items:center; gap:14px; padding:12px 16px; border-top:1px solid var(--line) } .card h3 + .row { border-top:0 }
.row .t { flex:1 } .row .t b { display:block; font-weight:600 } .row .t small { color:var(--soft) } .foot { color:var(--soft); font-size:12px; padding:0 4px 6px }
button { font:inherit; border:1px solid var(--line); background:var(--card); color:var(--ink); padding:6px 14px; border-radius:8px; cursor:pointer } button:hover { border-color:var(--accent) }
button.primary { background:var(--accent); color:var(--accent-ink); border-color:var(--accent) } button:disabled { opacity:.5; cursor:default }
input[type=text], input[type=password], select { font:inherit; padding:6px 10px; border:1px solid var(--line); border-radius:8px; background:var(--bg); color:var(--ink); min-width:260px }
.switch { position:relative; width:40px; height:22px; flex-shrink:0 } .switch input { opacity:0; width:0; height:0 } .switch i { position:absolute; inset:0; background:#bbb8c3; border-radius:22px; transition:.15s }
.switch i:before { content:""; position:absolute; width:16px; height:16px; left:3px; top:3px; background:#fff; border-radius:50%; transition:.15s } .switch input:checked + i { background:var(--accent) } .switch input:checked + i:before { transform:translateX(18px) }
.grid { display:grid; grid-template-columns:repeat(5,1fr); gap:10px } .pet { background:var(--card); border:2px solid var(--line); border-radius:14px; padding:8px; text-align:center; cursor:pointer }
.pet.on { border-color:var(--accent) } .pet img { width:84px; height:84px } .pet b { display:block; font-size:13px }
.hero { display:flex; gap:22px; align-items:center } .hero img { width:150px; height:150px } .hero .name { font-size:32px; font-weight:700 }
.meter { margin:6px 0 } .meter div { height:8px; border-radius:6px; background:var(--line); overflow:hidden } .meter div i { display:block; height:100% }
.seg { display:inline-flex; border:1px solid var(--line); border-radius:9px; overflow:hidden } .seg button { border:0; border-radius:0 } .seg button.on { background:var(--accent); color:var(--accent-ink) }
.stats { display:grid; grid-template-columns:repeat(3,1fr); gap:10px } .stat { background:var(--card); border:1px solid var(--line); border-radius:14px; padding:14px } .stat b { font-size:24px; display:block }
.pill { display:inline-block; padding:2px 10px; border-radius:20px; background:var(--accent); color:var(--accent-ink); font-size:12px; font-weight:600 }
.list div { padding:8px 16px; border-top:1px solid var(--line) } .muted { color:var(--soft) } pre { white-space:pre-wrap; font:12px Consolas,monospace; margin:0 }
.page { display:none } .page.on { display:block }
</style></head><body>
<nav><h1>🍡 Mochi</h1>
<a href="#pet"><span>🐾</span>Pet</a><a href="#behavior"><span>🚶</span>Behavior</a><a href="#reminders"><span>🔔</span>Reminders</a>
<a href="#today"><span>📊</span>Today</a><a href="#ai"><span>✨</span>AI</a><a href="#general"><span>⚙️</span>General</a><a href="#debug"><span>🐞</span>Debug</a></nav>
<main>
<section class="page" id="p-pet"><h2>Pet</h2><div class="sub">Who lives on your screen, and how they're doing</div>
 <div class="card"><div class="row hero"><img id="heroImg"><div class="t"><div class="name" id="heroName"></div><div class="muted" id="heroTag"></div>
  <div class="muted" id="heroBond"></div><div style="margin-top:8px"><span class="pill" id="feeling"></span></div></div>
  <div style="width:240px" id="meters"></div></div>
  <div class="row"><div class="t"></div><button onclick="act('treat')">🎁 Give a treat</button><button onclick="act('play')">⚽ Play ball</button><button onclick="act('sayHi')">👋 Say hi</button></div></div>
 <div class="row" style="padding:12px 0 0"><b style="flex:1">Choose your pet</b><span class="seg" id="styleSeg"><button data-s="cute">Cute</button><button data-s="tough">Tough</button></span></div>
 <div class="grid" id="pets" style="margin-top:10px"></div>
 <div class="card"><h3>Wardrobe and friends</h3>
  <div class="row"><div class="t"><b>Outfit</b><small id="nextOutfit"></small></div><select id="outfit"></select></div>
  <div class="row"><div class="t"><b>Second pet</b><small id="secondHint"></small></div><label class="switch"><input type="checkbox" data-k="secondPet"><i></i></label></div>
  <div class="row" id="friendRow"><div class="t"><b>Friend</b></div><select id="companion"></select></div></div></section>

<section class="page" id="p-behavior"><h2>Behavior</h2><div class="sub">Where your pet goes and what it notices</div>
 <div class="card"><h3>Desktop movement</h3>
  <div class="row"><div class="t"><b>Walk on windows</b><small>Walk and leap onto window tops, following them as they move.</small></div><label class="switch"><input type="checkbox" data-k="walkOnWindows"><i></i></label></div>
  <div class="row"><div class="t"><b>Climb edges</b><small>Climb the sides of the screen and hang from the top.</small></div><label class="switch"><input type="checkbox" data-k="climbEdges"><i></i></label></div>
  <div class="row"><div class="t"><b>Chase cursor</b><small>Occasionally follow the pointer.</small></div><label class="switch"><input type="checkbox" data-k="followCursor"><i></i></label></div></div>
 <div class="card"><h3>Sound and calls</h3>
  <div class="row"><div class="t"><b>React to media</b><small>Vibe to whatever is playing (Spotify, YouTube in a browser…) and settle down for videos or calls.</small></div><label class="switch"><input type="checkbox" data-k="reactToMedia"><i></i></label></div>
  <div class="row"><div class="t"><b>Stay quiet during calls</b><small>Pause speech bubbles while a calling app uses your microphone.</small></div><label class="switch"><input type="checkbox" data-k="quietOnCalls"><i></i></label></div>
  <div class="row"><div class="t"><b>React to other audio</b><small>Only if Windows can't report what's playing: count any app with the speakers open.</small></div><label class="switch"><input type="checkbox" data-k="reactToOtherAudio"><i></i></label></div></div>
 <div class="card"><h3>Keyboard and PC</h3>
  <div class="row"><div class="t"><b>Bop along while I type</b></div><label class="switch"><input type="checkbox" data-k="reactToTyping"><i></i></label></div>
  <div class="row"><div class="t"><b>Comment on my PC</b><small>Notice battery level, time of day and a busy processor.</small></div><label class="switch"><input type="checkbox" data-k="systemAware"><i></i></label></div></div>
 <div class="card"><h3>Claude Code</h3>
  <div class="row"><div class="t"><b>Notice when Claude is working</b><small>Say when Claude starts on something, how long it's been at it, and when it's done.</small></div><label class="switch"><input type="checkbox" data-k="claudeAware"><i></i></label></div>
  <div class="row"><div class="t"><b>Warn about usage limits</b><small>Speak up each time the 5-hour or weekly limit passes another 10%.</small></div><label class="switch"><input type="checkbox" data-k="claudeLimitAlerts"><i></i></label></div></div>
 <div class="foot">Typing activity stays on your PC. Mochi counts keystrokes without reading them.</div></section>

<section class="page" id="p-reminders"><h2>Reminders</h2><div class="sub">Gentle nudges while you work</div>
 <div class="card"><h3>Repeating reminders</h3><div id="remRows"></div>
  <div class="row"><div class="t"><b>Stretch break</b><small>After a stretch of work</small></div><select id="breakMinutes"></select><label class="switch"><input type="checkbox" data-k="breakReminders"><i></i></label></div></div>
 <div class="foot">Only time at your PC counts. Reminders wait until calls and focus sessions end.</div>
 <div class="card"><h3>Daily recap</h3>
  <div class="row"><div class="t"><b>Daily check-in</b><small>A recap at 6 pm and the next morning.</small></div><label class="switch"><input type="checkbox" data-k="dailyCheckIn"><i></i></label></div></div>
 <div class="card"><h3>Google Calendar</h3><div id="google"></div></div>
 <div class="foot">Read-only. Mochi talks to Google directly from this PC and keeps the sign-in in Windows Credential Manager. Event titles only appear in your pet's bubble and are never sent to the AI server.</div></section>

<section class="page" id="p-today"><h2>Today</h2><div class="sub">Your day in numbers</div>
 <span class="seg" id="daySeg"><button data-d="today">Today</button><button data-d="yesterday" id="prevBtn">Previous day</button></span>
 <div class="card"><h3>Pet time</h3><div class="row"><div class="t" id="daySummary"></div></div></div><div class="stats" id="dayStats"></div></section>

<section class="page" id="p-ai"><h2>AI</h2><div class="sub">Give your pet a language model to think and talk with</div>
 <div class="card"><div class="row"><div class="t"><b id="aiHead"></b><small id="aiSub"></small></div><label class="switch"><input type="checkbox" data-k="aiEnabled"><i></i></label></div></div>
 <div class="card"><h3>Model connection</h3>
  <div class="row"><div class="t"><b>Server</b></div><input type="text" data-t="aiBaseURL" placeholder="http://localhost:11434/v1"></div>
  <div class="row"><div class="t"><b>Model</b></div><input type="text" data-t="aiModel" list="models" placeholder="llama3.2, gpt-4o-mini…"><datalist id="models"></datalist></div>
  <div class="row"><div class="t"><b>API key</b><small id="keyState"></small></div><input type="password" id="aiKey" placeholder="Not needed for local servers"></div>
  <div class="row"><div class="t"><b>Test connection</b><small id="aiStatus"></small></div><button id="aiTest" onclick="act('aiTest')">Test</button></div></div>
 <div class="foot">Use an OpenAI-compatible endpoint such as Ollama, LM Studio, llama.cpp, OpenRouter or OpenAI. API keys are saved in Windows Credential Manager. Prompts can include your pet's name and mood, the time of day, the app playing audio, daily counts, memories and requests you type in Ask. Keystrokes, screen contents and calendar events stay private.</div>
 <div class="card"><h3>Pet abilities</h3>
  <div class="row"><div class="t"><b>Fresh lines</b><small id="linesSub"></small></div><label class="switch"><input type="checkbox" data-k="aiDialogue"><i></i></label></div>
  <div class="row"><div class="t"><b>Remarks about what's going on</b><small>Music starting, coming back, the time of day, the battery, a busy PC</small></div><label class="switch"><input type="checkbox" data-k="aiReactions"><i></i></label></div>
  <div class="row"><div class="t"><b>Decide what to do</b><small>Every few minutes the model picks the next move; the rest of the time the pet follows its instincts</small></div><label class="switch"><input type="checkbox" data-k="aiBrain"><i></i></label></div>
  <div class="row"><div class="t"><b>Two pets talk to each other</b><small>They chat when they meet: about you, your day, what's on, or pet life</small></div><label class="switch"><input type="checkbox" data-k="aiBanter"><i></i></label></div>
  <div class="row"><div class="t"><b>Ask your pet</b><small>Type a request from the menu: "dance", "remind me to drink water every 30 minutes", "25 minute focus"</small></div><label class="switch"><input type="checkbox" data-k="aiCommands"><i></i></label></div>
  <div class="row"><div class="t"><b>Memory and diary</b><small>Remembers a few things about you and writes a diary entry for each day</small></div><label class="switch"><input type="checkbox" data-k="aiMemory"><i></i></label></div>
  <div class="row"><div class="t"><b>Written lines</b><small>Throw them away after changing model; new ones are written as needed</small></div><button id="clearLines" onclick="act('clearLines')">Start over</button></div></div>
 <div class="card"><h3>Diary</h3><div class="row"><div class="t"><b>Today's entry</b><small id="diarySub"></small></div><button id="writeDiary" onclick="act('writeDiary')">Write</button></div><div class="list" id="diary"></div></div>
 <div class="card"><h3 id="factsHead"></h3><div class="list" id="facts"></div><div class="row" id="forgetRow"><div class="t"><b>Forget everything</b><small>Clears the memories and the diary</small></div><button onclick="if(confirm('Forget all memories and the diary?'))act('forgetAll')">Forget</button></div></div></section>

<section class="page" id="p-general"><h2>General</h2><div class="sub">Size, speech and system options</div>
 <div class="card"><h3>Desktop pet size</h3><div class="row"><span class="seg" id="sizeSeg"></span></div></div>
 <div class="card"><h3>Voice</h3><div class="row"><div class="t"><b>Speech bubbles</b></div><span class="seg" id="chatSeg"></span></div></div>
 <div class="card"><h3>System</h3>
  <div class="row"><div class="t"><b>Launch at sign-in</b><small id="loginSub"></small></div><label class="switch"><input type="checkbox" data-k="launchAtLogin" id="login"><i></i></label></div>
  <div class="row"><div class="t"><b>Lost your pet?</b><small>Drops it back in from the top of the screen</small></div><button onclick="act('bringBack')">Bring back</button></div></div></section>

<section class="page" id="p-debug"><h2>Debug</h2><div class="sub">Test reminders and see what the pet notices</div>
 <div class="card"><h3>Activity</h3><div class="row"><pre id="petState"></pre></div></div>
 <div class="card"><h3>Test a reminder (shows at once, even when switched off)</h3><div class="row" id="testBtns" style="flex-wrap:wrap"></div>
  <div class="row"><div class="t"><b>Skip ahead</b><small id="remState"></small></div><button onclick="act('skip',{minutes:5})">5 min</button><button onclick="act('skip',{minutes:15})">15 min</button></div></div>
 <div class="card"><h3>What your pet notices</h3>
  <div class="row"><div class="t"><b>Presence</b><small id="presence"></small></div></div>
  <div class="row"><div class="t"><b id="sound">Sound</b><small id="soundApps"></small></div></div>
  <div class="row"><div class="t"><b>Displays</b><small id="screens"></small></div><button onclick="act('nextScreen')">Send to next display</button></div></div>
 <div class="card"><h3>Two pets</h3><div class="row" id="socialBtns" style="flex-wrap:wrap"></div><div class="foot" id="petsInfo" style="padding:0 16px 12px"></div></div></section>
</main>
<script>
const T = new URLSearchParams(location.search).get('t'); let S = null, browse = null, day = 'today', editing = null;
const $ = id => document.getElementById(id), esc = s => String(s).replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const img = (sp, out, mood) => `/pet.png?t=${T}&species=${sp}&outfit=${out||''}&mood=${mood||''}`;
async function call(path, body) { const r = await fetch(path + '?t=' + T, body ? {method:'POST', body:JSON.stringify(body)} : {}); S = await r.json(); render(); }
const set = (key, value) => call('/api/set', {key, value}), act = (action, extra) => call('/api/do', Object.assign({action}, extra||{}));
function page() { const p = (location.hash || '#pet').slice(1); document.querySelectorAll('.page').forEach(e => e.classList.toggle('on', e.id == 'p-' + p));
  document.querySelectorAll('nav a').forEach(a => a.classList.toggle('on', a.hash == '#' + p)); }
window.onhashchange = page;
document.addEventListener('change', e => { const k = e.target.dataset.k; if (k) set(k, e.target.checked); });
document.querySelectorAll('[data-t]').forEach(i => { i.onfocus = () => editing = i; i.onblur = () => { editing = null; set(i.dataset.t, i.value); }; i.onkeydown = e => { if (e.key == 'Enter') i.blur(); }; });
$('aiKey').onchange = e => { set('aiKey', e.target.value); e.target.value = ''; };
$('styleSeg').onclick = e => { if (e.target.dataset.s) { browse = e.target.dataset.s; render(); } };
$('daySeg').onclick = e => { if (e.target.dataset.d) { day = e.target.dataset.d; render(); } };
function seg(el, items, cur, key) { el.innerHTML = items.map(i => `<button class="${i.id == cur ? 'on' : ''}" onclick="set('${key}','${i.id}')">${esc(i.label)}</button>`).join(''); }
function opts(el, items, cur) { if (document.activeElement == el) return; el.innerHTML = items.map(i => `<option value="${i.id}" ${i.id == cur ? 'selected' : ''}>${esc(i.label)}</option>`).join(''); }
const meter = (label, v, c) => `<div class="meter"><small>${label}</small><div><i style="width:${Math.round(v*100)}%;background:${c}"></i></div></div>`;
function render() {
  if (!S) return; const s = S.settings, sp = S.species.find(x => x.id == s.species), m = S.mind;
  document.querySelectorAll('[data-k]').forEach(i => i.checked = !!s[i.dataset.k]);
  document.querySelectorAll('[data-t]').forEach(i => { if (i != editing) i.value = s[i.dataset.t] || ''; });
  // Pet
  $('heroImg').src = img(s.species, s.outfit); $('heroName').textContent = sp.name; $('heroTag').textContent = sp.tagline;
  $('heroBond').textContent = `${m.bondTitle} · Level ${m.level} · Day ${m.days}`; $('feeling').textContent = m.feeling;
  $('meters').innerHTML = meter('Energy', m.energy, '#f29d38') + meter('Tummy', m.fullness, '#4caf6a') + meter('Joy', m.joy, '#ec5f9a') + meter('Bond', m.bond, '#8a6ad8');
  const style = browse || sp.style; document.querySelectorAll('#styleSeg button').forEach(b => b.classList.toggle('on', b.dataset.s == style));
  $('pets').innerHTML = S.species.filter(x => x.style == style).map(x => `<div class="pet ${x.id == s.species ? 'on' : ''}" onclick="set('species','${x.id}')"><img src="${img(x.id)}"><b>${esc(x.name)}</b></div>`).join('');
  opts($('outfit'), S.outfits, s.outfit); $('nextOutfit').textContent = S.nextOutfit; $('secondHint').textContent = `A friend that lives alongside ${sp.name}`;
  $('friendRow').style.display = s.secondPet ? '' : 'none'; opts($('companion'), S.species.map(x => ({id:x.id, label:x.name})), s.companionSpecies);
  // Reminders
  $('remRows').innerHTML = S.reminders.map(r => { const v = s.reminderMinutes[r.id] || 0; return `<div class="row"><div class="t"><b>${esc(r.label)}</b></div>
    <select onchange="set('reminder.${r.id}', +this.value)" ${v ? '' : 'disabled'}>${S.intervals.map(n => `<option value="${n}" ${n == (v || r.default) ? 'selected' : ''}>Every ${n} min</option>`).join('')}</select>
    <label class="switch"><input type="checkbox" ${v ? 'checked' : ''} onchange="set('reminder.${r.id}', this.checked ? ${r.default} : 0)"><i></i></label></div>`; }).join('');
  opts($('breakMinutes'), S.intervals.map(n => ({id:n, label:`After ${n} min`})), s.breakMinutes); $('breakMinutes').onchange = e => set('breakMinutes', +e.target.value);
  google();
  // Today
  const d = day == 'today' ? S.today : (S.yesterday || S.today); $('prevBtn').textContent = S.hasFreshYesterday ? 'Yesterday' : 'Previous day';
  document.querySelectorAll('#daySeg button').forEach(b => b.classList.toggle('on', b.dataset.d == day)); $('daySummary').textContent = d.summary;
  $('dayStats').innerHTML = [['At your PC', d.active], ['Typing', d.typing], ['Focus sessions', d.focusSessions, d.focusMinutes + ' min'], ['Breaks', d.breaks], ['Treats', d.treats], ['Pets and plays', d.pets + d.plays]]
    .map(x => `<div class="stat">${esc(x[0])}<b>${esc(x[1])}</b><small class="muted">${x[2] ? esc(x[2]) : ''}</small></div>`).join('');
  // AI
  const ai = S.ai; $('aiHead').textContent = s.aiEnabled ? 'AI enabled' : 'Built-in mode';
  $('aiSub').textContent = s.aiEnabled ? (s.aiModel || 'Choose a model below.') : `${sp.name} uses its built-in lines and instincts.`;
  $('keyState').textContent = s.aiHasKey ? 'A key is saved (type a new one to replace it, or a space to remove it)' : '';
  $('aiStatus').textContent = ai.testing ? 'Asking the server…' : (ai.testResult || (ai.lastError ? 'Last call failed: ' + ai.lastError : ''));
  $('aiTest').disabled = ai.testing; $('aiTest').textContent = ai.testing ? 'Testing…' : 'Test';
  $('models').innerHTML = ai.models.map(x => `<option value="${esc(x)}">`).join('');
  $('linesSub').textContent = `Writes new things to say for every moment, in your pet's own voice. ${ai.lines} written so far`; $('clearLines').disabled = !ai.lines;
  $('diarySub').textContent = ai.writingDiary ? 'Writing…' : 'Write it now from today so far'; $('writeDiary').disabled = ai.writingDiary || !(ai.ready && s.aiMemory);
  $('diary').innerHTML = S.memory.diary.map(e => `<div><small class="muted">${esc(e.day)}</small><br>${esc(e.text)}</div>`).join('');
  $('factsHead').textContent = `What ${sp.name} remembers about you`;
  $('facts').innerHTML = S.memory.facts.length ? S.memory.facts.map((f, i) => `<div style="display:flex;gap:10px"><span style="flex:1">${esc(f)}</span><button onclick="act('forget',{index:${i}})">✕</button></div>`).join('') : '<div class="muted">Nothing yet.</div>';
  $('forgetRow').style.display = (S.memory.facts.length || S.memory.diary.length) ? '' : 'none';
  // General
  seg($('sizeSeg'), S.sizes, s.petSize, 'petSize'); seg($('chatSeg'), S.chattiness, s.chattiness, 'chattiness');
  $('login').disabled = !s.launchAtLoginAvailable; $('loginSub').textContent = s.launchAtLoginAvailable ? 'Starts Mochi when you sign in to Windows' : 'Needs the built Mochi.exe (not swift run)';
  // Debug
  const g = S.debug; $('petState').textContent = g.petState || 'Waiting for a reading…'; $('remState').textContent = g.reminderState;
  $('testBtns').innerHTML = S.reminders.map(r => `<button onclick="act('testReminder',{kind:'${r.id}'})">${esc(r.label)}<br><small class="muted">${esc(g.reminders[r.id] || '')}</small></button>`).join('')
    + `<button onclick="act('testStretch')">Stretch break<br><small class="muted">${esc(g.reminders.stretch || '')}</small></button><button onclick="act('testCalendar')">Calendar alert</button><button onclick="act('checkIn')">Daily check-in</button>`;
  $('presence').textContent = g.presence; $('sound').textContent = g.sound ? 'Sound: ' + g.sound : 'Sound'; $('soundApps').innerHTML = g.soundApps.length ? g.soundApps.map(esc).join('<br>') : 'Nothing playing';
  $('screens').textContent = g.screens; $('petsInfo').textContent = g.pets;
  $('socialBtns').innerHTML = g.social.map(k => `<button ${s.secondPet ? '' : 'disabled'} onclick="act('meet',{kind:'${k.id}'})">${esc(k.label)}</button>`).join('');
}
function google() {
  const g = S.google, s = S.settings; let h = '';
  if (g.status == 'signedOut') {
    h += `<div class="row"><div class="t"><b>Connect Google Calendar</b><small>${esc(g.problem || "Your pet says each event's reminders when they're due: 10 minutes before, 30 minutes before, whatever you set in Google Calendar.")}</small></div><button class="primary" onclick="act('googleSignIn')" ${g.hasClient ? '' : 'disabled'}>Sign in with Google…</button></div>`;
    h += `<div class="row"><div class="t"><b>OAuth client ID</b><small>In Google Cloud Console, turn on the Google Calendar API and create an OAuth client of type "Desktop app".</small></div><input type="text" id="gid" value="${esc(s.googleClientID)}" placeholder="…apps.googleusercontent.com" onchange="set('googleClientID', this.value)"></div>`;
    h += `<div class="row"><div class="t"><b>Client secret</b></div><input type="password" placeholder="Saved in Credential Manager" onchange="set('googleClientSecret', this.value); this.value=''"></div>`;
  } else if (g.status == 'signingIn') {
    h += `<div class="row"><div class="t"><b>Finish signing in in your browser</b><small>Pick your Google account and allow Mochi to see your calendars. This page will update by itself.</small></div><button onclick="act('googleCancel')">Cancel</button></div>`;
  } else {
    const line = g.problem || (g.lastSync ? `${g.events} events · synced ${g.lastSync}` : (g.syncing ? 'Fetching your events…' : 'Not synced yet'));
    h += `<div class="row"><div class="t"><b>${esc(g.email)}</b><small>${esc(line)}</small></div><button onclick="act('googleSync')" ${g.syncing ? 'disabled' : ''}>${g.syncing ? 'Syncing…' : 'Sync Now'}</button><button onclick="act('googleSignOut')">Sign Out</button></div>`;
    h += `<div class="row"><div class="t"><b>Say my Google Calendar reminders</b><small>At each event's own notification times.</small></div><label class="switch"><input type="checkbox" data-k="googleCalendarAlerts" ${s.googleCalendarAlerts ? 'checked' : ''}><i></i></label></div>`;
    if (s.googleCalendarAlerts) h += `<div class="row"><div class="t"><b>Also when an event starts</b><small>Even if it has no notification at the start time.</small></div><label class="switch"><input type="checkbox" data-k="googleAlertAtStart" ${s.googleAlertAtStart ? 'checked' : ''}><i></i></label></div>`;
    h += '<div class="list">' + (g.upNext.length ? g.upNext.map(e => `<div><b>${esc(e.title)}</b> <span class="muted">· ${esc(e.when)} · ${esc(e.reminders)}</span></div>`).join('') : '<div class="muted">No upcoming events with reminders in the next week.</div>') + '</div>';
  }
  const el = $('google'); if (!el.contains(document.activeElement)) el.innerHTML = h;
}
page(); call('/api/state'); setInterval(() => { if (!document.hidden) call('/api/state'); }, 1500);
</script></body></html>
"""#
}
#endif
