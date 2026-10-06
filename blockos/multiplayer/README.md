# BlockOS game server

`relay.js` lets BlockOS players play online together. Every player's game runs on their own
computer; the server only passes along what each player shares (their position, game events,
chat) to the others in the same game room. It also tells friends who's online and passes friend
requests and private messages between them.

Every typed message goes through `chatfilter.js` first, which hides swear words and personal
details (phone numbers, email addresses, links, street addresses, social-media names) with `#`.
Add words to its `BLOCKED` list if you need to.

## Community games (made by players)

Players make games in BlockOS's **Create** page and press **Publish** to put them on the server
they're online on (`community.js`). Every new or updated game waits for a **moderator** to check
it; only then does it show on the **Community** page for everyone. If 3 different players report a
game, it's hidden again until a moderator looks at it. Titles and descriptions go through the
chat filter; the game code itself can't be filtered, which is why games are checked by a person.
Community games run in a sandbox in BlockOS: they can't read anyone's saved data, open websites
or download things, and they don't earn Bricks.

- **Who's a moderator:** anyone who knows the server's moderator key. When you host from the
  BlockOS app (or VM), your own BlockOS is a moderator of that server automatically. For a server
  you run yourself, the key is in `<data folder>/moderator-key.txt` (made the first time the server
  starts), or set your own with `--mod-key` / `BLOCKOS_MOD_KEY`. Type it in BlockOS under
  **Community → Server owner?** to get a **Review** tab. Keep it secret.
- **Where games are kept:** the data folder: `--data DIR` or `BLOCKOS_DATA` (default: `data/` next
  to `relay.js`; `/data` in the Docker image, so mount a volume there; the Mac/Windows app uses its
  own app-data folder, and the VM uses `~/.local/share/blockos/community`). Many hosting services
  wipe a container's files when it restarts, so give it a persistent volume or disk.
- **Skipping the check** (`--auto-approve` / `BLOCKOS_AUTO_APPROVE=1`) makes new games public
  straight away. Only do that on a server for people you know.
- Limits: 300,000 characters per game plus up to 12 sounds (about 1 MB together), 10 games per
  player per server, one publish every 20 seconds. Sounds are kept in `games/<id>.sounds.json`.

## Playing on the same Wi-Fi (easiest)

One person opens **Play Online** in BlockOS and clicks **Start hosting**. Everyone else types the
address it shows (like `192.168.1.23`) under **Join a server**. On a Mac, macOS may ask whether
BlockOS may accept incoming network connections; click **Allow**.

## Playing over the internet, the easy way

In the BlockOS app for Mac or Windows, the host clicks **Start hosting** and then **Let friends
anywhere join** on the Play Online page. BlockOS opens a free Cloudflare quick tunnel (see
`mac-app/tunnel.js`) and shows a `wss://...trycloudflare.com` address for friends to join. No
account is needed, but the address changes every time and Cloudflare gives no uptime guarantee
for these tunnels.

## An always-on server for everyone (like Roblox)

To have servers that are always running, put this folder on a computer that never turns off:
usually a cloud server from a hosting company. That needs an account with the hosting company
(most require you to be 18 or older, so ask a parent) and may cost money.

1. Pick a hosting service that can run a **Docker** container or a **Node.js** app and supports
   **WebSockets** with **HTTPS**. Use this folder (`blockos/multiplayer`) as the app's folder; the
   included `Dockerfile` starts the server. The server listens on the port given in the `PORT`
   environment variable (default 8790) and answers plain web requests with "BlockOS game server",
   which hosting health checks can use.
   - Some free plans put apps to sleep when nobody uses them, so the first player may wait a
     minute while it wakes up. For truly always-on servers, use a paid plan or a small cloud computer.
2. Once it's running, the host gives you an address like `https://blockos-server.example.com`.
   Players join it as `wss://blockos-server.example.com`.
3. Put that address in `blockos/shell/config.js` as `officialServer` and rebuild BlockOS (pushing
   to GitHub rebuilds the Mac and Windows apps). Every copy of BlockOS then goes online there
   automatically, with a **Play Online → Official server** section.

One server process holds all the games: each game has numbered servers (Server 1, Server 2, ...)
with up to 12 players each, and new ones open as players arrive. Players pick one from the game's
page or press Play to join the busiest server that still has room.

Running it yourself on any computer with a public address works the same way:

```sh
npm ci --omit=dev
node relay.js --port 8790 --data ./data   # or: docker build -t blockos-server . && docker run -p 8790:8790 -v blockos-data:/data blockos-server
```

Only share the address with people you know. Chat is filtered, but nobody moderates it.

Limits: 12 players per server of each game, 4 KB per message (3 MB to publish a community game with its sounds), 40 messages per second per player, one chat
message every 0.7 seconds, 120 characters per chat message.
