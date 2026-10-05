# BlockOS game server

`relay.js` lets BlockOS players play online together. Every player's game runs on their own
computer; the server only passes along what each player shares (their position, game events,
chat) to the others in the same game room. It also tells friends who's online and passes friend
requests and private messages between them.

Every typed message goes through `chatfilter.js` first, which hides swear words and personal
details (phone numbers, email addresses, links, street addresses, social-media names) with `#`.
Add words to its `BLOCKED` list if you need to.

## Playing on the same Wi-Fi (easiest)

One person opens **Play Online** in BlockOS and clicks **Start hosting**. Everyone else types the
address it shows (like `192.168.1.23`) under **Join a server**. On a Mac, macOS may ask whether
BlockOS may accept incoming network connections; click **Allow**.

## Playing over the internet

Friends who aren't on your Wi-Fi need a server with a public address:

```sh
npm ci --omit=dev
node relay.js --port 8790          # or: docker build -t blockos-server . && docker run -p 8790:8790 blockos-server
```

Run it on any computer or cloud server that's reachable from the internet. Put it behind HTTPS
(most hosting services do this for you) so players can join with a `wss://` address, e.g.
`wss://blockos.example.com`. Only share the address with people you know.

Limits: 24 players per game room, 4 KB per message, 40 messages per second per player, one chat
message every 0.7 seconds, 120 characters per chat message.
