using Microsoft.Xna.Framework;
using Terraria;
using Terraria.ID;

namespace ChainsawManMod.Content.NPCs
{
	// Helpers shared by the devil enemies and bosses.
	public static class DevilUtils
	{
		public static int CountActive(int type) {
			int count = 0;
			foreach (NPC other in Main.ActiveNPCs) {
				if (other.type == type) {
					count++;
				}
			}
			return count;
		}

		public static int CountActiveAny(int[] types) {
			int count = 0;
			foreach (NPC other in Main.ActiveNPCs) {
				if (System.Array.IndexOf(types, other.type) >= 0) {
					count++;
				}
			}
			return count;
		}

		// Smoothly steers a flying NPC toward a point.
		public static void FlyToward(NPC npc, Vector2 target, float speed, float inertia) {
			Vector2 desired = (target - npc.Center).SafeNormalize(Vector2.Zero) * speed;
			npc.velocity = (npc.velocity * (inertia - 1f) + desired) / inertia;
		}

		// Spawns a minion NPC from the server and syncs it to clients. Does nothing on multiplayer clients.
		public static void SpawnMinion(NPC parent, int type, Vector2 position) {
			if (Main.netMode == NetmodeID.MultiplayerClient) {
				return;
			}

			NPC minion = NPC.NewNPCDirect(parent.GetSource_FromAI(), (int)position.X, (int)position.Y, type);
			if (minion.whoAmI < Main.maxNPCs && Main.netMode == NetmodeID.Server) {
				NetMessage.SendData(MessageID.SyncNPC, number: minion.whoAmI);
			}
		}

		// Fires a hostile projectile from the server (or in single player).
		public static void Shoot(NPC npc, Vector2 position, Vector2 velocity, int type, int damage, float ai0 = 0f) {
			if (Main.netMode == NetmodeID.MultiplayerClient) {
				return;
			}
			Projectile.NewProjectile(npc.GetSource_FromAI(), position, velocity, type, damage, 0f, Main.myPlayer, ai0: ai0);
		}

		public static void Bleed(NPC npc, NPC.HitInfo hit, int dustType = DustID.Blood) {
			int count = npc.life <= 0 ? (npc.boss ? 80 : 20) : 5;
			for (int i = 0; i < count; i++) {
				Dust.NewDust(npc.position, npc.width, npc.height, dustType, hit.HitDirection * 2f, -2f);
			}
		}
	}
}
