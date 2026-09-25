using ChainsawManMod.Content.Items;
using Microsoft.Xna.Framework;
using Terraria;
using Terraria.GameContent.Bestiary;
using Terraria.GameContent.ItemDropRules;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.NPCs
{
	// Beach enemy. Swims through sand, water and air alike, circling the player and lunging every couple of seconds.
	public class SharkDevil : ModNPC
	{
		private const int FrameCount = 4;

		public override void SetStaticDefaults() {
			Main.npcFrameCount[Type] = FrameCount;
		}

		public override void SetDefaults() {
			NPC.width = 50;
			NPC.height = 24;
			NPC.damage = 35;
			NPC.defense = 10;
			NPC.lifeMax = 200;
			NPC.HitSound = SoundID.NPCHit1;
			NPC.DeathSound = SoundID.NPCDeath1;
			NPC.value = 300f;
			NPC.knockBackResist = 0.3f;
			NPC.noGravity = true;
			NPC.noTileCollide = true;
			NPC.aiStyle = -1;
		}

		public override float SpawnChance(NPCSpawnInfo spawnInfo) {
			return spawnInfo.Player.ZoneBeach ? 0.1f : 0f;
		}

		public override void AI() {
			NPC.TargetClosest();
			Player player = Main.player[NPC.target];
			NPC.ai[0]++;

			if (NPC.ai[0] % 120 == 90) {
				// Lunge.
				NPC.velocity = (player.Center - NPC.Center).SafeNormalize(Vector2.UnitX) * 13f;
				NPC.netUpdate = true;
			}
			else if (NPC.ai[0] % 120 < 90) {
				// Circle below the player, as if swimming under the surface.
				Vector2 target = player.Center + new Vector2((float)System.Math.Cos(NPC.ai[0] / 20f) * 160f, 80f);
				DevilUtils.FlyToward(NPC, target, 6f, 25f);
			}

			NPC.spriteDirection = NPC.velocity.X > 0 ? 1 : -1;
			NPC.rotation = NPC.velocity.ToRotation() + (NPC.spriteDirection == 1 ? 0f : MathHelper.Pi);

			// Kicks up whatever it swims through.
			if (Collision.SolidCollision(NPC.position, NPC.width, NPC.height) && Main.rand.NextBool(3)) {
				Dust.NewDust(NPC.position, NPC.width, NPC.height, DustID.Sand);
			}
		}

		public override void FindFrame(int frameHeight) {
			NPC.frameCounter++;
			if (NPC.frameCounter >= 6) {
				NPC.frameCounter = 0;
				NPC.frame.Y = (NPC.frame.Y + frameHeight) % (FrameCount * frameHeight);
			}
		}

		public override void ModifyNPCLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<DevilFlesh>(), 2, 1, 3));
			npcLoot.Add(ItemDropRule.Common(ItemID.SharkFin, 3));
		}

		public override void SetBestiary(BestiaryDatabase database, BestiaryEntry bestiaryEntry) {
			bestiaryEntry.Info.AddRange([new FlavorTextBestiaryInfoElement("Mods.ChainsawManMod.Bestiary.SharkDevil")]);
		}

		public override void HitEffect(NPC.HitInfo hit) {
			DevilUtils.Bleed(NPC, hit);
		}
	}
}
