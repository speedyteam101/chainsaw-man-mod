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
    id: "easy3d",
    title: "Easy 3D",
    html: `
<p>The easiest way to make a 3D game: <b>178 simple commands</b>. Start from the <b>Easy 3D obby</b> template, or put this in a new game:</p>
<pre><code>&lt;!doctype html&gt;
&lt;html&gt;
&lt;head&gt;&lt;title&gt;My Obby&lt;/title&gt;&lt;link rel="stylesheet" href="kit.css"&gt;&lt;/head&gt;
&lt;body&gt;
&lt;script src="kit.js"&gt;&lt;/script&gt;
&lt;script type="module"&gt;
import "./easy3d.js";

part("part 1", 0, 0, -12);
color("part 1", "red");
killOnTouch("part 1");
&lt;/script&gt;
&lt;/body&gt;
&lt;/html&gt;</code></pre>
<h3>How it works</h3>
<ul>
  <li>Make a part and give it a name with <code>part("name", x, y, z)</code>. <b>x</b> is left and right, <b>y</b> is up, <b>z</b> is forward (more negative = further ahead).</li>
  <li>Then use the name to give it powers. Names can be anything, like <code>"part 1"</code> or <code>"Big Wall"</code>.</li>
  <li><b>Groups:</b> a name also means every part that starts with it. <code>color("stairs", "blue")</code> colors "stairs 1", "stairs 2" and so on.</li>
  <li>You start on a yellow spawn pad at 0, 0, 0. The game starts by itself, with a timer, deaths and coins at the top.</li>
  <li>Capital letters in commands don't matter: <code>killOnTouch</code> and <code>killontouch</code> both work.</li>
  <li>If you spell a name wrong, the Output panel tells you which part it couldn't find.</li>
</ul>
<h3>Building</h3>
<table class="st-cmds"><tr><td><code>part("part 1", 0, 2, -10)</code></td><td>Make a part called "part 1" at x, y, z. Add a size: <code>part("wall", 0, 3, -20, 10, 6, 1)</code> (width, height, depth).</td></tr><tr><td><code>copy("part 1", "part 2", 0, 2, -20)</code></td><td>Copy a part (with all its powers) to a new place.</td></tr><tr><td><code>remove("part 1")</code></td><td>Delete a part.</td></tr><tr><td><code>floor("ground", 0, 0, -30, 20, 20)</code></td><td>A flat floor (width, depth).</td></tr><tr><td><code>wall("wall", 0, 0, -40, 12, 8)</code></td><td>A wall standing on y (width, height).</td></tr><tr><td><code>tower("tower", 10, 0, -40, 20)</code></td><td>A tall tower (height).</td></tr><tr><td><code>stairs("stairs", 0, 0, -10, 8)</code></td><td>Stairs going forward: "stairs 1" to "stairs 8".</td></tr><tr><td><code>row("hops", 0, 0, -10, 5, 9)</code></td><td>A row of jump blocks: "hops 1" to "hops 5", 9 apart.</td></tr><tr><td><code>tree(10, 0, -5)</code></td><td>A tree.</td></tr><tr><td><code>cloud(0, 40, -50)</code></td><td>A cloud in the sky.</td></tr><tr><td><code>house("home", -20, 0, 0)</code></td><td>A little house with a door gap.</td></tr><tr><td><code>baseplate()</code></td><td>A big green floor everywhere. <code>baseplate("sand")</code> for another color.</td></tr><tr><td><code>lava()</code></td><td>Lava far below: fall in and you go back to your checkpoint.</td></tr><tr><td><code>sign("Hello!", 0, 5, -10)</code></td><td>Floating words.</td></tr><tr><td><code>npc("Bob", 5, 0, -10)</code></td><td>A character who looks at you. Make them speak with <code>talk</code>.</td></tr></table>
<h3>How parts look</h3>
<table class="st-cmds"><tr><td><code>color("part 1", "blue")</code></td><td>red, orange, yellow, gold, lime, green, darkgreen, teal, cyan, lightblue, blue, darkblue, purple, pink, brown, sand, white, gray, black, or a code like <code>"#ff8800"</code>.</td></tr><tr><td><code>randomColor("part 1")</code></td><td>A random bright color.</td></tr><tr><td><code>rainbow("part 1")</code></td><td>Keeps changing color.</td></tr><tr><td><code>glow("part 1")</code></td><td>Glowing neon.</td></tr><tr><td><code>glass("part 1")</code></td><td>See-through glass.</td></tr><tr><td><code>wood("part 1")</code></td><td>Wood.</td></tr><tr><td><code>smooth("part 1")</code></td><td>No studs on top.</td></tr><tr><td><code>transparent("part 1", 0.5)</code></td><td>See-through: 0 = solid, 1 = gone.</td></tr><tr><td><code>invisible("part 1")</code></td><td>Can't be seen, but you can still stand on it.</td></tr><tr><td><code>ghost("part 1")</code></td><td>You can walk through it. <code>solid("part 1")</code> makes it solid again.</td></tr><tr><td><code>blink("part 1", 1)</code></td><td>Appears and disappears every 1 second.</td></tr><tr><td><code>size("part 1", 4, 1, 4)</code></td><td>Change its size.</td></tr><tr><td><code>scale("part 1", 2)</code></td><td>Make it 2 times bigger (0.5 = half).</td></tr><tr><td><code>rotate("part 1", 45)</code></td><td>Turn it round (degrees).</td></tr><tr><td><code>label("part 1", "Jump here!")</code></td><td>Words floating above the part.</td></tr><tr><td><code>hide("part 1")</code></td><td>Make it vanish. <code>show("part 1")</code> brings it back.</td></tr></table>
<h3>Moving parts</h3>
<table class="st-cmds"><tr><td><code>moveSideToSide("part 1", 8, 1)</code></td><td>Moves left and right (how far, how fast). You can ride it!</td></tr><tr><td><code>moveUpAndDown("part 1", 4, 1)</code></td><td>An elevator.</td></tr><tr><td><code>moveForwardAndBack("part 1", 8, 1)</code></td><td>Moves forward and back.</td></tr><tr><td><code>moveInCircle("part 1", 6, 1)</code></td><td>Goes round in a circle (size, speed).</td></tr><tr><td><code>spin("bar", 1)</code></td><td>Spins round. Spinning parts are ghosts: add <code>killOnTouch</code> for a spinning kill bar.</td></tr><tr><td><code>follow("enemy", 6)</code></td><td>Chases you! Add <code>killOnTouch("enemy")</code> to make it dangerous.</td></tr><tr><td><code>moveTo("part 1", 0, 5, -10)</code></td><td>Jump straight to a new place.</td></tr><tr><td><code>slideTo("part 1", 0, 5, -10, 2)</code></td><td>Slide smoothly to a new place in 2 seconds.</td></tr><tr><td><code>conveyor("belt", 10)</code></td><td>A conveyor belt that pushes you forward (negative pushes back).</td></tr><tr><td><code>fallOnTouch("part 1")</code></td><td>Shakes and falls when you step on it, then comes back.</td></tr><tr><td><code>stopMoving("part 1")</code></td><td>Stops it moving.</td></tr></table>
<h3>Touch powers (something happens when you touch the part)</h3>
<table class="st-cmds"><tr><td><code>killOnTouch("part 1")</code></td><td>Sends you back to your last checkpoint.</td></tr><tr><td><code>checkpoint("part 2")</code></td><td>Saves your place (turns green).</td></tr><tr><td><code>finish("end")</code></td><td>You win!</td></tr><tr><td><code>bounce("part 3", 100)</code></td><td>A trampoline. Bigger numbers bounce higher.</td></tr><tr><td><code>disappearOnTouch("part 4")</code></td><td>Vanishes just after you touch it, then comes back.</td></tr><tr><td><code>coin(0, 3, -20)</code></td><td>A coin to collect. <code>coin("part 1")</code> turns a part into a coin.</td></tr><tr><td><code>coinDoor("door", 5)</code></td><td>The door opens once you have 5 coins.</td></tr><tr><td><code>keyFor("gold key", "door")</code></td><td>Touch the key to open the door.</td></tr><tr><td><code>toggle("button", "bridge")</code></td><td>Touch the button to make the bridge appear or vanish.</td></tr><tr><td><code>teleport("pad", 0, 10, -50)</code></td><td>Teleports you to x, y, z. Or to another part: <code>teleport("pad", "island")</code>.</td></tr><tr><td><code>speedBoost("pad", 40, 3)</code></td><td>Run super fast for 3 seconds.</td></tr><tr><td><code>superJump("pad", 90, 5)</code></td><td>Jump super high for 5 seconds.</td></tr><tr><td><code>damage("spikes", 25)</code></td><td>Hurts you (a health bar appears). At 0 health you go back.</td></tr><tr><td><code>heal("medkit", 50)</code></td><td>Heals you.</td></tr><tr><td><code>pointsOnTouch("gem", 10)</code></td><td>Gives you points (once).</td></tr><tr><td><code>messageOnTouch("part 1", "Hi!")</code></td><td>Shows a message.</td></tr><tr><td><code>soundOnTouch("part 1", "win")</code></td><td>Plays a sound: "click", "score", "hit", "jump", "lose", "win" or "coin".</td></tr><tr><td><code>badgeOnTouch("secret", "Secret Finder")</code></td><td>Gives you a badge.</td></tr><tr><td><code>talk("Bob", "Hello!")</code></td><td>An npc says something when you walk up to them.</td></tr><tr><td><code>onTouch("part 1", function () { ... })</code></td><td>Runs your own code.</td></tr></table>
<h3>You, the player</h3>
<table class="st-cmds"><tr><td><code>spawn(0, 0, 0)</code></td><td>Where you start.</td></tr><tr><td><code>walkSpeed(30)</code></td><td>How fast you walk (normal is 16).</td></tr><tr><td><code>jumpPower(70)</code></td><td>How high you jump (normal is 52).</td></tr><tr><td><code>gravity(0.5)</code></td><td>Less gravity, like the moon (1 = normal, 2 = heavy).</td></tr><tr><td><code>fly()</code></td><td>Hold Space to fly up.</td></tr><tr><td><code>doubleJump()</code></td><td>Press Space again in the air for a second jump.</td></tr><tr><td><code>zoom(30)</code></td><td>How far away the camera is (4 to 60).</td></tr><tr><td><code>teleportPlayer(0, 10, -50)</code></td><td>Move yourself somewhere.</td></tr><tr><td><code>killPlayer()</code></td><td>Back to your checkpoint.</td></tr><tr><td><code>freeze()</code></td><td>Stop moving. <code>unfreeze()</code> to move again.</td></tr><tr><td><code>playerPosition()</code></td><td>Where you are: <code>playerPosition().y</code> is how high.</td></tr><tr><td><code>distanceTo("part 1")</code></td><td>How far you are from a part.</td></tr><tr><td><code>touching("part 1")</code></td><td>true while you touch the part.</td></tr></table>
<h3>The game</h3>
<table class="st-cmds"><tr><td><code>timer(60)</code></td><td>You have 60 seconds, or it's game over.</td></tr><tr><td><code>win()</code></td><td>You win!</td></tr><tr><td><code>lose("Oh no!")</code></td><td>Game over, with a message.</td></tr><tr><td><code>restart()</code></td><td>Start everything again.</td></tr><tr><td><code>addPoints(5)</code></td><td>Add points. <code>setPoints(0)</code>, <code>getPoints()</code>.</td></tr><tr><td><code>winAtPoints(100)</code></td><td>You win when you reach 100 points.</td></tr><tr><td><code>message("Hi!")</code></td><td>Show a message.</td></tr><tr><td><code>popup("Welcome", "Have fun!")</code></td><td>A big message with an OK button.</td></tr><tr><td><code>playSound("coin")</code></td><td>Play a sound.</td></tr><tr><td><code>random(1, 10)</code></td><td>A random whole number from 1 to 10.</td></tr><tr><td><code>forever(function (dt) { ... })</code></td><td>Runs again and again while you play.</td></tr><tr><td><code>every(2, function () { ... })</code></td><td>Runs every 2 seconds.</td></tr><tr><td><code>wait(3, function () { ... })</code></td><td>Runs once after 3 seconds.</td></tr><tr><td><code>onWin(function () { ... })</code></td><td>Runs when you win.</td></tr><tr><td><code>onDeath(function () { ... })</code></td><td>Runs when you fall or get killed.</td></tr></table>
<h3>Sky and light</h3>
<table class="st-cmds"><tr><td><code>sky("darkblue")</code></td><td>The sky color.</td></tr><tr><td><code>night()</code></td><td>Night time. <code>day()</code> for day.</td></tr><tr><td><code>sunset()</code></td><td>An orange sunset.</td></tr><tr><td><code>fog(5)</code></td><td>Foggy (0 = none, 10 = very foggy).</td></tr></table>
<h3>More building</h3>
<table class="st-cmds"><tr><td><code>bridge("br", 0, 0, -10, 30)</code></td><td>A long narrow bridge going forward (length).</td></tr><tr><td><code>pillar("pl", 5, 0, -10, 12)</code></td><td>A thin pillar (height).</td></tr><tr><td><code>pyramid("py", 0, 0, -30, 5)</code></td><td>A stepped pyramid (levels): "py 1" to "py 5".</td></tr><tr><td><code>spiralStairs("sp", 0, 0, -40, 16)</code></td><td>Stairs going round and up.</td></tr><tr><td><code>ring("rg", 0, 2, -20, 8, 12)</code></td><td>Blocks in a circle (how many, how big).</td></tr><tr><td><code>grid("gd", 0, 0, -20, 4, 4, 6)</code></td><td>A checkerboard of blocks (rows, columns, gap).</td></tr><tr><td><code>fence("fn", 0, 0, 10, 20)</code></td><td>A wooden fence (length).</td></tr><tr><td><code>room("rm", 20, 0, 0, 16)</code></td><td>A closed room with a roof (size).</td></tr><tr><td><code>castle("cs", -40, 0, -40)</code></td><td>A castle with four towers.</td></tr><tr><td><code>bush(x, y, z)</code></td><td>A bush. Also <code>flower(x, y, z)</code>, <code>rock(x, y, z)</code> and <code>lamp(x, y, z)</code>.</td></tr><tr><td><code>mountain(x, y, z, 30)</code></td><td>A snowy mountain (height).</td></tr><tr><td><code>island(x, y, z)</code></td><td>A little sandy island with a tree.</td></tr><tr><td><code>stars(80)</code></td><td>Glowing stars in the sky (great with <code>night()</code>).</td></tr><tr><td><code>scatter("tree", 10, 60)</code></td><td>Puts things in random places: "tree", "rock", "flower", "bush", "cloud", "coin" or "lamp" (how many, how far).</td></tr></table>
<h3>More looks</h3>
<table class="st-cmds"><tr><td><code>fadeOut("part 1", 1)</code></td><td>Slowly disappears (seconds). <code>fadeIn("part 1", 1)</code> brings it back.</td></tr><tr><td><code>flash("part 1", "white")</code></td><td>Flashes a color for a moment.</td></tr><tr><td><code>pulseColors("part 1", "red", "yellow")</code></td><td>Switches between two colors.</td></tr><tr><td><code>shake("part 1")</code></td><td>Keeps shaking.</td></tr><tr><td><code>bob("part 1")</code></td><td>Gently floats up and down.</td></tr><tr><td><code>colorOnTouch("part 1", "green")</code></td><td>Changes color when you touch it.</td></tr></table>
<h3>More movement</h3>
<table class="st-cmds"><tr><td><code>rise("lava", 1)</code></td><td>Keeps going up (speed). Great for rising lava!</td></tr><tr><td><code>sink("part 1", 1)</code></td><td>Keeps going down.</td></tr><tr><td><code>drift("part 1", 2, 0, 0)</code></td><td>Keeps moving (speed left/right, up/down, forward/back).</td></tr><tr><td><code>moveBetween("part 1", 10, 2, -30, 1)</code></td><td>Moves back and forth between where it starts and x, y, z (speed).</td></tr><tr><td><code>elevator("lift", 10, 0.6)</code></td><td>Goes up and down (how high, speed).</td></tr><tr><td><code>orbit("moon", "planet", 8, 1)</code></td><td>Goes round another part (size, speed).</td></tr><tr><td><code>flee("chicken", 6)</code></td><td>Runs away from you when you get close.</td></tr><tr><td><code>wander("pet", 4)</code></td><td>Walks around by itself.</td></tr></table>
<h3>More touch powers</h3>
<table class="st-cmds"><tr><td><code>loseOnTouch("part 1", "Oh no!")</code></td><td>Game over.</td></tr><tr><td><code>addTimeOnTouch("clock", 10)</code></td><td>Adds seconds to the <code>timer</code> (once).</td></tr><tr><td><code>slowOnTouch("mud", 6, 3)</code></td><td>Walk slowly for a while (speed, seconds).</td></tr><tr><td><code>lowGravityOnTouch("pad", 5)</code></td><td>Moon jumps for 5 seconds.</td></tr><tr><td><code>flyOnTouch("pad", 5)</code></td><td>Fly for 5 seconds (hold Jump).</td></tr><tr><td><code>shieldOnTouch("star", 5)</code></td><td>Kill parts can't hurt you for 5 seconds.</td></tr><tr><td><code>hideOnTouch("button", "wall")</code></td><td>Touch it to make another part vanish. <code>showOnTouch("button", "wall")</code> brings one back.</td></tr><tr><td><code>losePointsOnTouch("trap", 5)</code></td><td>Takes away points (once).</td></tr><tr><td><code>counterOnTouch("gem", "Gems", 1)</code></td><td>Adds to a counter (once). See <code>counter</code>.</td></tr><tr><td><code>musicOnTouch("radio", "song")</code></td><td>Starts music (one of your own sounds).</td></tr><tr><td><code>sayOnTouch("part 1", "Wow!")</code></td><td>You say something in a speech bubble.</td></tr><tr><td><code>restartOnTouch("part 1")</code></td><td>Starts the game again.</td></tr><tr><td><code>lifeOnTouch("heart")</code></td><td>An extra life (once), when you use <code>lives</code>.</td></tr></table>
<h3>More for the player</h3>
<table class="st-cmds"><tr><td><code>lives(3)</code></td><td>You have 3 lives. Lose them all and it's game over.</td></tr><tr><td><code>health(150)</code></td><td>Shows a health bar and sets your health. <code>setHealth(50)</code>, <code>getHealth()</code>.</td></tr><tr><td><code>jump()</code></td><td>Makes you jump.</td></tr><tr><td><code>invincible(5)</code></td><td>Kill parts can't hurt you for 5 seconds.</td></tr><tr><td><code>shiftLock()</code></td><td>The camera follows the mouse (<code>shiftLock(false)</code> to stop).</td></tr><tr><td><code>turnCamera(90)</code></td><td>Turns the camera (degrees).</td></tr><tr><td><code>resetSpeed()</code></td><td>Back to your normal walk speed and jump.</td></tr><tr><td><code>say("Hi!")</code></td><td>You say something in a speech bubble.</td></tr><tr><td><code>playerName()</code></td><td>Your name.</td></tr><tr><td><code>isOnGround()</code></td><td>true when you're standing on something.</td></tr></table>
<h3>More for the game</h3>
<table class="st-cmds"><tr><td><code>onKey("E", function () { ... })</code></td><td>Runs your code when you press a key: a letter, a number, "space", "enter", "shift", "up", "down", "left" or "right".</td></tr><tr><td><code>counter("Gems", 0)</code></td><td>A counter shown at the top. <code>addCounter("Gems", 1)</code>, <code>getCounter("Gems")</code>.</td></tr><tr><td><code>showText("Find the key!")</code></td><td>Words at the top of the screen. <code>hideText()</code> takes them away.</td></tr><tr><td><code>winAfter(60)</code></td><td>Survive for 60 seconds to win.</td></tr><tr><td><code>countdown()</code></td><td>3, 2, 1, Go! at the start.</td></tr><tr><td><code>addTime(10)</code></td><td>More seconds on the <code>timer</code>. <code>stopTimer()</code> stops it.</td></tr><tr><td><code>badge("Explorer")</code></td><td>Gives you a badge.</td></tr><tr><td><code>chance(25)</code></td><td>true 25% of the time: <code>if (chance(50)) { ... }</code>.</td></tr><tr><td><code>repeat(5, function (i) { ... })</code></td><td>Runs your code 5 times (i is 1, 2, 3...). Great for making rows of parts!</td></tr></table>
<h3>Sounds</h3>
<table class="st-cmds"><tr><td><code>sound("coin")</code></td><td>Plays a sound: a built-in one ("click", "score", "hit", "jump", "lose", "win", "coin") or one you added with the <b>Sounds</b> button.</td></tr><tr><td><code>music("song")</code></td><td>Plays one of your sounds over and over. <code>stopMusic()</code> stops it.</td></tr><tr><td><code>volume(0.5)</code></td><td>How loud your sounds are (0 to 1).</td></tr></table>
<h3>More sky and light</h3>
<table class="st-cmds"><tr><td><code>dayNightCycle(60)</code></td><td>Day turns to night and back every 60 seconds.</td></tr><tr><td><code>brightness(0.5)</code></td><td>How bright the light is (1 = normal).</td></tr><tr><td><code>sunColor("orange")</code></td><td>The color of the sunlight.</td></tr></table>
<h3>Example: make a row of parts with repeat</h3>
<pre><code>repeat(5, function (i) {
  part("step " + i, 0, i, -10 - i * 6);
  color("step " + i, "blue");
});
killOnTouch("step 3");</code></pre>
<h3>Example: a secret door</h3>
<pre><code>part("button", 5, 0, -10, 2, 1, 2);
color("button", "red");
part("secret door", 0, 3, -20, 6, 6, 1);
onTouch("button", function () {
  message("You found the secret!");
  hide("secret door");
});</code></pre>
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
