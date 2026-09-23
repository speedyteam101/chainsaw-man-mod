using ChainsawManMod.Content.Items;
using Microsoft.Xna.Framework;
using Terraria;
using Terraria.GameContent.Bestiary;
using Terraria.GameContent.ItemDropRules;
using Terraria.ID;
using Terraria.ModLoader;
using Terraria.ModLoader.Utilities;

namespace ChainsawManMod.Content.NPCs
{
	// Small flying devil that swoops at the player. Spawns at night in Hardmode, and is summoned by the Bat Devil.
	public class DevilBat : ModNPC
	{
		private const int FrameCount = 4;

		public override void SetStaticDefaults() {
			Main.npcFrameCount[Type] = FrameCount;
		}

		public override void SetDefaults() {
			NPC.width = 30;
			NPC.height = 24;
			NPC.damage = 45;
			NPC.defense = 14;
			NPC.lifeMax = 220;
			NPC.HitSound = SoundID.NPCHit1;
			NPC.DeathSound = SoundID.NPCDeath4;
			NPC.value = 300f;
			NPC.knockBackResist = 0.6f;
			NPC.noGravity = true;
			NPC.aiStyle = -1;
		}

		public override float SpawnChance(NPCSpawnInfo spawnInfo) {
			return Main.hardMode ? SpawnCondition.OverworldNightMonster.Chance * 0.15f : 0f;
		}

		public override void AI() {
			NPC.TargetClosest();
			Player player = Main.player[NPC.target];

			// Swoop toward a point slightly above the player, with a wavy flight path.
			NPC.ai[0]++;
			Vector2 target = player.Center + new Vector2(0f, -30f + (float)System.Math.Sin(NPC.ai[0] / 12f) * 40f);
			Vector2 desired = (target - NPC.Center).SafeNormalize(Vector2.Zero) * 7f;
			NPC.velocity = (NPC.velocity * 29f + desired) / 30f;

			// Bounce off walls instead of sticking to them.
			if (NPC.collideX) {
				NPC.velocity.X = -NPC.oldVelocity.X * 0.6f;
			}
			if (NPC.collideY) {
				NPC.velocity.Y = -NPC.oldVelocity.Y * 0.6f;
			}

			NPC.spriteDirection = NPC.direction;
			NPC.rotation = NPC.velocity.X * 0.05f;
		}

		public override void FindFrame(int frameHeight) {
			NPC.frameCounter++;
			if (NPC.frameCounter >= 5) {
				NPC.frameCounter = 0;
				NPC.frame.Y = (NPC.frame.Y + frameHeight) % (FrameCount * frameHeight);
			}
		}

		public override void ModifyNPCLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<DevilFlesh>(), 2, 1, 3));
		}

		public override void SetBestiary(BestiaryDatabase database, BestiaryEntry bestiaryEntry) {
			bestiaryEntry.Info.AddRange([
				BestiaryDatabaseNPCsPopulator.CommonTags.SpawnConditions.Times.NightTime,
				new FlavorTextBestiaryInfoElement("Mods.ChainsawManMod.Bestiary.DevilBat")
			]);
		}

		public override void HitEffect(NPC.HitInfo hit) {
			int count = NPC.life <= 0 ? 15 : 4;
			for (int i = 0; i < count; i++) {
				Dust.NewDust(NPC.position, NPC.width, NPC.height, DustID.Blood, hit.HitDirection, -1f);
			}
		}
	}
}
