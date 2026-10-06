// Help guide for the Create studio. Each section is { id, title, html } (trusted HTML written here).
window.STUDIO_DOCS = [
  {
    id: "start",
    title: "Getting started",
    html: `
<h3>A game is one web page</h3>
<p>Your whole game is one HTML page: a little HTML, plus JavaScript inside a <code>&lt;script&gt;</code> tag.
It loads the <b>BlockOS game kit</b>, which gives you ready-made helpers for drawing, keys, sounds, badges,
your avatar and online play. Every template starts like this:</p>
<pre>&lt;!doctype html&gt;
&lt;html&gt;
&lt;head&gt;
  &lt;link rel="stylesheet" href="kit.css"&gt;
&lt;/head&gt;
&lt;body&gt;
  &lt;script src="kit.js"&gt;&lt;/script&gt;
  &lt;script&gt;
    const GAME_ID = "my-game";   // your game's name for badges and scores
    // ... your code ...
  &lt;/script&gt;
&lt;/body&gt;
&lt;/html&gt;</pre>
<p>The kit files are always there for you, so write <code>kit.js</code> just like that (no folder in front).
Put your scripts inside <code>&lt;body&gt;</code>: the kit adds the game screen to the body, so it has to exist first.</p>

<h3>Run, save and share</h3>
<ul>
  <li><b>Run</b> (or <code>Ctrl+Enter</code>) starts your game in the preview, so you can try every change.</li>
  <li>Your code is <b>saved by itself</b> on this computer while you type. <code>Ctrl+S</code> saves right away.</li>
  <li><b>Save file</b> downloads a copy of your game, which you can open again later.</li>
  <li><b>Publish</b> shares your game with other players on the server you're online on (see <i>Rules for sharing</i>).</li>
</ul>

<h3>Reading the Output panel</h3>
<p>The <b>Output</b> panel shows messages from your game. Use <code>console.log</code> to print anything you want to check:</p>
<pre>console.log("score is", score);</pre>
<p>When something goes wrong, the error shows up in Output in red, with the <b>line number</b> where it happened.
Go to that line in your code and look for things like:</p>
<ul>
  <li>a typo in a name: <code>Kit.hdu</code> instead of <code>Kit.hud</code> ("is not a function"),</li>
  <li>a name you never made with <code>let</code> or <code>const</code> ("is not defined"),</li>
  <li>a missing <code>)</code>, <code>}</code> or <code>"</code> ("Unexpected token" or "Unexpected end of input").</li>
</ul>
<p>Fix it, then press <b>Run</b> again. Changing one small thing at a time makes problems easy to find!</p>
`,
  },
  {
    id: "drawing",
    title: "Drawing and moving",
    html: `
<h3>The game screen</h3>
<p><code>Kit.stage(width, height)</code> makes a canvas (a drawing area) that grows to fit the window.
It gives you the canvas, its drawing tool <code>ctx</code>, and its size <code>W</code> and <code>H</code>:</p>
<pre>const { canvas, ctx, W, H } = Kit.stage(800, 500);</pre>
<p>Positions are in pixels: <code>x</code> goes right, <code>y</code> goes <b>down</b>. (0, 0) is the top-left corner.</p>

<h3>The game loop</h3>
<p><code>Kit.loop(update, draw)</code> calls your two functions about 60 times a second.
<code>update(dt)</code> moves things (<code>dt</code> is the seconds since the last frame, about 0.016),
and <code>draw()</code> paints the picture.</p>
<pre>let x = 100;
function update(dt) {
  if (Kit.key("ArrowRight")) x += 200 * dt;   // 200 pixels per second
  if (Kit.key("ArrowLeft")) x -= 200 * dt;
}
function draw() {
  ctx.fillStyle = "#1e293b";
  ctx.fillRect(0, 0, W, H);                  // clear the screen
  ctx.fillStyle = "#facc15";
  ctx.fillRect(x, 200, 40, 40);              // a yellow square
}
const loop = Kit.loop(update, draw);
loop.start();                                // loop.stop() pauses it</pre>
<p>Multiplying speeds by <code>dt</code> keeps your game the same speed on fast and slow computers.</p>

<h3>Keys</h3>
<ul>
  <li><code>Kit.key(code)</code> is <code>true</code> while a key is held down. Codes look like
    <code>"ArrowLeft"</code>, <code>"Space"</code>, <code>"KeyA"</code>, <code>"Digit1"</code>, <code>"Enter"</code>.</li>
  <li><code>Kit.onKey(function (code) { ... })</code> runs once each time a key is pressed (good for jumping or shooting).</li>
  <li>The <code>Escape</code> key belongs to BlockOS (it opens the menu), so don't use it in your game.</li>
</ul>
<pre>Kit.onKey((code) =&gt; {
  if (code === "Space") console.log("Jump!");
});</pre>

<h3>Mouse and touch</h3>
<p>Listen for <code>pointerdown</code> on the canvas: it works for mouse clicks <b>and</b> finger taps.
<code>Kit.pointer(canvas, event)</code> turns the event into game-screen pixels:</p>
<pre>canvas.addEventListener("pointerdown", (e) =&gt; {
  const p = Kit.pointer(canvas, e);
  console.log("tapped at", p.x, p.y);
});</pre>
<p>On a tablet there is no keyboard. Add tap or drag controls, or on-screen buttons
(the Blank, Platformer and 3D obby templates show how to make buttons that press keys).</p>

<h3>Handy helpers</h3>
<ul>
  <li><code>Kit.hud("Score: 5")</code> shows text in the top-right corner. Put smaller text in <code>&lt;small&gt;...&lt;/small&gt;</code>.</li>
  <li><code>Kit.overlay(title, text, buttonText)</code> shows a message box. It waits until the button
    (or Enter or Space) is pressed: <code>Kit.overlay("Game over", "Score: 5", "Try again").then(restart);</code></li>
  <li><code>Kit.brick(ctx, x, y, width, height, color)</code> draws a shiny block.</li>
  <li><code>Kit.rand(1, 10)</code> a random number, <code>Kit.randInt(1, 6)</code> a random whole number (like a dice),
    <code>Kit.pick(["red", "blue"])</code> a random item, <code>Kit.clamp(x, 0, W)</code> keeps a number between two others.</li>
  <li><code>Kit.colors</code> has ready colors: <code>Kit.colors.red</code>, <code>.orange</code>, <code>.yellow</code>, <code>.green</code>,
    <code>.teal</code>, <code>.blue</code>, <code>.purple</code>, <code>.pink</code>, <code>.white</code>, <code>.gray</code>, <code>.dark</code>.</li>
</ul>
<p>Note: <code>alert()</code>, <code>prompt()</code> and <code>confirm()</code> don't work in BlockOS games. Use <code>Kit.overlay</code> instead.</p>
`,
  },
  {
    id: "scores",
    title: "Scores and badges",
    html: `
<h3>Your game's name</h3>
<p>Scores and badges are kept under your game's name. Put it at the top of your code and give it your own name,
using lowercase letters, numbers and dashes:</p>
<pre>const GAME_ID = "super-coin-hunt";</pre>

<h3>Best scores</h3>
<ul>
  <li><code>Kit.finish(GAME_ID, score)</code> at the end of a round saves the score if it's your best,
    and gives back the best score.</li>
  <li>If a smaller score is better (like a race time), add <code>true</code>: <code>Kit.finish(GAME_ID, time, true)</code>.</li>
  <li><code>Kit.best(GAME_ID)</code> tells you the best score so far (or <code>null</code> if there isn't one yet).</li>
</ul>
<pre>const best = Kit.finish(GAME_ID, score);
Kit.overlay("Game over", "Score: " + score + "\\nBest: " + best, "Play again");</pre>
<p>Tip: <code>\\n</code> inside text starts a new line in <code>Kit.overlay</code>.</p>

<h3>Badges</h3>
<p><code>Kit.badge(GAME_ID, badgeId, name, description)</code> gives the player a badge, with a pop-up.
Each badge is only given once, so it's fine to call it again and again:</p>
<pre>if (score &gt;= 100) Kit.badge(GAME_ID, "hundred", "Century", "Scored 100 points.");</pre>
<p>Badges from games players make show up in the Output panel when you test. They're just for fun:
they don't give Bricks.</p>

<h3>Saving progress</h3>
<p><code>localStorage</code> keeps things after the game closes (each game gets its own). It stores text,
so use <code>JSON</code> for numbers, lists and objects:</p>
<pre>localStorage.setItem(GAME_ID + ".save", JSON.stringify({ coins: 12, level: 3 }));
const saved = JSON.parse(localStorage.getItem(GAME_ID + ".save"));   // null the first time</pre>
<p>A game can save up to about 200,000 letters of data.</p>

<h3>A player list</h3>
<p><code>Kit.leaderboard(columns, rows)</code> shows a Roblox-style list in the top-right corner.
<code>Kit.leaderboard(null)</code> hides it.</p>
<pre>Kit.leaderboard(["Coins"], [
  { name: "You", values: [12], me: true },
  { name: "Robot", values: [8] },
]);</pre>
`,
  },
  {
    id: "avatar",
    title: "Your avatar",
    html: `
<h3>Who is playing</h3>
<p><code>Kit.player()</code> gives the player's name and the avatar they made on the BlockOS Avatar page:</p>
<pre>const me = Kit.player();
console.log("Hi " + me.name);</pre>

<h3>Drawing an avatar</h3>
<p><code>Kit.drawAvatar(ctx, x, y, height, options)</code> draws a blocky character seen from the side.
<code>x, y</code> is where its <b>feet</b> are, and <code>height</code> is how tall it is in pixels.
Options (all can be left out):</p>
<ul>
  <li><code>facing</code>: <code>1</code> looks right, <code>-1</code> looks left.</li>
  <li><code>walk</code>: a number that swings the arms and legs. Add to it while walking: <code>walk += dt * 12</code>.</li>
  <li><code>air</code>: <code>true</code> shows the jumping pose.</li>
  <li><code>name</code>: text shown above the head.</li>
  <li><code>look</code>: someone else's avatar. Leave it out to draw your own.</li>
</ul>
<pre>Kit.drawAvatar(ctx, 200, 400, 60, { facing: 1, walk: walk, name: Kit.player().name });</pre>

<h3>Making your own characters</h3>
<p>A look is an object with colors and styles. Anything you leave out comes from the default look
(<code>Kit.DEFAULT_LOOK</code>):</p>
<pre>const robot = { head: "#9ca3af", torso: "#ef4444", arms: "#9ca3af", legs: "#1f2328", face: "robot", hat: "none" };
Kit.drawAvatar(ctx, 500, 400, 60, { look: robot, facing: -1, name: "Robo" });</pre>
<ul>
  <li><code>head</code>, <code>torso</code>, <code>arms</code>, <code>legs</code>: colors like <code>"#3b82f6"</code>.</li>
  <li><code>face</code>: <code>"smile"</code>, <code>"grin"</code>, <code>"wink"</code>, <code>"wow"</code>, <code>"cool"</code>, <code>"determined"</code>, <code>"robot"</code>.</li>
  <li><code>hat</code>: <code>"none"</code>, <code>"cap"</code>, <code>"cone"</code>, <code>"tophat"</code>, <code>"headphones"</code>, <code>"wizard"</code>, <code>"crown"</code>.</li>
  <li><code>shirt</code>: <code>"plain"</code>, <code>"stripes"</code>, <code>"star"</code>, <code>"brick"</code>, <code>"bolt"</code>, <code>"suit"</code>.</li>
</ul>
<p>The side view is small, so some faces and shirts look simpler in 2D than in 3D worlds.</p>
`,
  },
  {
    id: "sounds",
    title: "Sounds",
    html: `
<h3>Ready-made sounds</h3>
<p><code>Kit.sfx(name)</code> plays a short sound effect. Names: <code>"click"</code>, <code>"score"</code>, <code>"coin"</code>,
<code>"jump"</code>, <code>"hit"</code>, <code>"lose"</code>, <code>"win"</code>.</p>
<pre>Kit.sfx("coin");</pre>
<p>If the player turned the sound off in BlockOS, <code>Kit.sfx</code> stays quiet by itself.</p>

<h3>Making your own beeps</h3>
<p>Games can't load sound files from the internet, but you can make sounds with code using the browser's
Web Audio. This plays a note (<code>freq</code> is how high it is, <code>seconds</code> how long):</p>
<pre>let audio = null;
function beep(freq, seconds) {
  if (localStorage.getItem("blockos.muted") === "1") return;   // sound is off in BlockOS
  audio = audio || new AudioContext();
  const osc = audio.createOscillator();
  const gain = audio.createGain();
  osc.type = "square";              // also try "sine", "triangle", "sawtooth"
  osc.frequency.value = freq;
  gain.gain.value = 0.08;           // keep it quiet!
  osc.connect(gain).connect(audio.destination);
  osc.start();
  osc.stop(audio.currentTime + seconds);
}
beep(440, 0.2);</pre>
<p>Browsers only play sound after the player has clicked or pressed a key, so start sounds from the game, not right when the page opens.</p>
`,
  },
  {
    id: "online",
    title: "Online play",
    html: `
<h3>Connecting</h3>
<p><code>Kit.net(GAME_ID)</code> connects your game to the BlockOS game server when the player is online,
so everyone playing your game (with the same <code>GAME_ID</code>) is in the same world.
For online play, the name must be short: up to 20 lowercase letters, numbers and dashes.</p>
<pre>const net = Kit.net(GAME_ID);</pre>
<p>When BlockOS isn't online, nothing breaks: <code>net.online</code> stays <code>false</code> and your game is played solo.
Always make sure your game works on its own too!</p>
<p>Options: <code>Kit.net(GAME_ID, { room: "red-team" })</code> puts players in separate rooms,
and <code>{ chat: false }</code> hides the chat buttons.</p>

<h3>What you can use</h3>
<ul>
  <li><code>net.online</code>: <code>true</code> while connected.</li>
  <li><code>net.me</code>: you, with <code>id</code>, <code>name</code> and <code>avatar</code>.</li>
  <li><code>net.players</code>: everyone else (a <code>Map</code>). Each player has <code>id</code>, <code>name</code>,
    <code>avatar</code> and <code>state</code> (what they shared last).</li>
  <li><code>net.isHost</code>: <code>true</code> for the player who has been there longest. Let only the host run shared things like enemies or timers.</li>
  <li><code>net.state(object)</code>: share your own state (like your position). Call it every frame; the kit sends it up to 10 times a second.</li>
  <li><code>net.event(object)</code>: send a one-time message to everyone else (a hit, a pick-up, a round start).</li>
  <li><code>net.say(text)</code>: send a chat message.</li>
</ul>

<h3>Listening</h3>
<p><code>net.on(type, function)</code> runs your function when something happens:</p>
<ul>
  <li><code>"join"</code> and <code>"leave"</code> give you the player.</li>
  <li><code>"state"</code> gives the player whose state changed.</li>
  <li><code>"event"</code> gives the player and the data they sent.</li>
  <li><code>"chat"</code> gives the player and the text.</li>
  <li><code>"status"</code> gives <code>true</code> or <code>false</code> when you go online or offline.</li>
</ul>
<pre>// Share where you are
net.state({ x: me.x, y: me.y });

// Draw everyone else
for (const p of net.players.values()) {
  if (p.state) Kit.drawAvatar(ctx, p.state.x, p.state.y, 60, { look: p.avatar, name: p.name });
}

// One-time messages
net.event({ type: "boom", x: 100, y: 200 });
net.on("event", (player, data) =&gt; {
  if (data.type === "boom") console.log(player.name + " made a boom!");
});</pre>

<h3>Chat</h3>
<p><code>Kit.net</code> adds the BlockOS chat for you when you're online: press <code>/</code> or the <b>Chat</b> button to type,
and <b>People</b> to see who's here and add friends. Messages are checked by the server, which hides rude words
and personal details. To show chat in your own way, like speech bubbles, use <code>net.on("chat", ...)</code>
(the Online hangout template does this).</p>
`,
  },
  {
    id: "3d",
    title: "3D worlds",
    html: `
<h3>Starting a 3D world</h3>
<p>The 3D kit is a <i>module</i>, so it's loaded with <code>import</code> inside <code>&lt;script type="module"&gt;</code>.
Load <code>kit.js</code> first:</p>
<pre>&lt;body&gt;
&lt;link rel="stylesheet" href="kit.css"&gt;
&lt;script src="kit.js"&gt;&lt;/script&gt;
&lt;script type="module"&gt;
import { World } from "./kit3d.js";

const world = new World({ sky: "#8fd3ff" });
world.baseplate(200);                          // a big green floor
world.spawnPad([0, 0, 0]);                     // where you start
world.part({ size: [8, 1, 8], pos: [0, 4, -16], color: "#ef4444" });
world.spawnPlayer({ pos: [0, 3, 0] });
world.start((dt) =&gt; {
  // runs every frame
});
&lt;/script&gt;
&lt;/body&gt;</pre>
<p>Sizes and positions are in <b>studs</b>, written as <code>[x, y, z]</code>. <code>y</code> is up, and forward
(away from the camera at the start) is toward <b>-z</b>. Your character is 5.2 studs tall, walks 16 studs a second
and jumps about 7 studs high.</p>
<p>Controls: W A S D or the up and down arrows to walk, Space to jump, left and right arrows or dragging to turn the camera,
the mouse wheel (or I and O) to zoom, Shift for shift lock.</p>

<h3>Parts</h3>
<p><code>world.part(options)</code> makes a block and gives it back. Options:</p>
<ul>
  <li><code>size: [x, y, z]</code> and <code>pos: [x, y, z]</code> (the middle of the block), <code>color</code>.</li>
  <li><code>material</code>: <code>"plastic"</code>, <code>"neon"</code> (glows), <code>"glass"</code> or <code>"wood"</code>.</li>
  <li><code>rot: [x, y, z]</code> turns it (in radians: <code>Math.PI / 4</code> is an eighth of a turn).</li>
  <li><code>kill: true</code>: touching it knocks you out (a kill brick!).</li>
  <li><code>collide: false</code>: you walk right through it.</li>
  <li><code>studs: false</code>: no studs on top.</li>
  <li><code>moving: true</code>: set this if you move the part in your loop, so players can ride it.</li>
  <li><code>onTouch: function (player, part) { ... }</code>: runs when you start touching it.</li>
</ul>
<pre>const lift = world.part({ size: [6, 1, 6], pos: [0, 2, -30], color: "#facc15", moving: true });
let t = 0;
world.start((dt) =&gt; {
  t += dt;
  lift.position.y = 2 + Math.sin(t) * 5;   // up and down
});</pre>
<p>Other part helpers: <code>world.remove(part)</code>, and <code>world.touching(part)</code> is <code>true</code> while you touch it.</p>

<h3>The player</h3>
<p><code>world.spawnPlayer({ pos })</code> gives back your player. Useful things on it: <code>pos</code> (where you are:
<code>player.pos.x</code>, <code>.y</code>, <code>.z</code>), <code>onGround</code>, <code>alive</code>, <code>speed</code>,
<code>jump</code>, and <code>frozen</code> (set it to <code>true</code> to stop the player moving).
You can also pass <code>speed</code> and <code>jump</code> to <code>spawnPlayer</code> to change how fast you run and how high you jump.</p>
<ul>
  <li><code>world.checkpoint([x, y, z])</code> sets where you come back after being knocked out.</li>
  <li><code>world.kill()</code> knocks the player out; they come back at the checkpoint after 2 seconds.
    <code>world.respawn()</code> puts the player back at the checkpoint right away (handy for a Restart button).</li>
  <li><code>world.onDeath(fn)</code> and <code>world.onRespawn(fn)</code> run your function when that happens.</li>
  <li>With <code>new World({ sky: "#8fd3ff", health: true })</code> you get a health bar: <code>world.damage(20)</code>, <code>world.heal(20)</code>.</li>
  <li>Falling far below the world knocks you out too.</li>
</ul>

<h3>Signs, characters and friends</h3>
<ul>
  <li><code>world.label("Hello!", { pos: [0, 10, -20], height: 3 })</code> shows floating text.</li>
  <li><code>world.character(look, name)</code> makes a character (like an NPC). Move it with
    <code>npc.position.set(x, y, z)</code> and animate it each frame with <code>npc.userData.animate(dt, speed, inAir)</code>.</li>
  <li><code>world.bubble(model, "Hi!")</code> shows a chat bubble over a character.</li>
  <li><code>world.online(Kit.net(GAME_ID))</code> shows other online players as avatars with name tags and chat bubbles,
    and shares where you are. That one line makes your world multiplayer!</li>
</ul>
<p>Other <code>World</code> options: <code>fog: false</code>, <code>dark: true</code> (night lighting), <code>shadows: false</code>
(faster on slow computers).</p>
`,
  },
  {
    id: "rules",
    title: "Rules for sharing",
    html: `
<h3>What games can't do (and why)</h3>
<p>Games made in Create run inside a locked box, so every game is safe to play, even one made by someone you don't know:</p>
<ul>
  <li><b>No internet.</b> A game can't load pictures, sounds, code or websites from the internet. Draw your pictures
    with code and make sounds with <code>Kit.sfx</code> or Web Audio. (Pictures written right into your code as
    <code>data:</code> addresses work too.)</li>
  <li><b>No pop-ups.</b> <code>alert()</code>, <code>prompt()</code> and <code>confirm()</code> don't work, and a game can't open
    new windows or leave its page. Use <code>Kit.overlay</code> for messages.</li>
  <li><b>No peeking at BlockOS.</b> A game can't see or change your Bricks, other games' saves or your friends.
    It can read your name and avatar, so it can draw you. It gets its own <code>localStorage</code> for its saves.</li>
  <li>Online, a game can only talk to the BlockOS game server you're playing on.</li>
</ul>

<h3>Publishing</h3>
<p><b>Publish</b> puts your game on the game server you're online on. New games (and updates) are <b>checked by the
server's owner</b> before other players can see them on the Community page. Until then, only you (and the people who check games) can play it there.
Players can report a game that breaks the rules, and it gets hidden until it's checked again.</p>

<h3>Be a good game maker</h3>
<ul>
  <li><b>Be kind.</b> No mean, rude or scary stuff, and nothing that makes fun of people.</li>
  <li><b>Keep personal info out.</b> Never put real names, addresses, schools, phone numbers, emails or photos
    of anyone (including you) in your game. Your BlockOS name is enough!</li>
  <li><b>Give credit.</b> Don't copy someone else's game and say you made it. If you built on someone's idea or code,
    say so, for example in the description or on the start screen.</li>
  <li><b>Make it fair.</b> Games shouldn't trick players, for example by pretending to be part of BlockOS.</li>
</ul>
<p>If you're not sure whether something is OK, ask a grown-up before you publish.</p>
`,
  },
];
