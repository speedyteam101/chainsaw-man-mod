using ChainsawManMod.Content.Items;
using Microsoft.Xna.Framework;
using Terraria;
using Terraria.GameContent.Bestiary;
using Terraria.GameContent.ItemDropRules;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.NPCs
{
	// Pre-Hardmode cave enemy. Drifts slowly through walls toward the player and is hard to see.
	public class GhostDevil : ModNPC
	{
		private const int FrameCount = 4;

		public override void SetStaticDefaults() {
			Main.npcFrameCount[Type] = FrameCount;
		}

		public override void SetDefaults() {
			NPC.width = 28;
			NPC.height = 40;
			NPC.damage = 24;
			NPC.defense = 4;
			NPC.lifeMax = 90;
			NPC.HitSound = SoundID.NPCHit5;
			NPC.DeathSound = SoundID.NPCDeath6;
			NPC.value = 150f;
			NPC.knockBackResist = 0.3f;
			NPC.noGravity = true;
			NPC.noTileCollide = true;
			NPC.alpha = 110;
			NPC.aiStyle = -1;
		}

		public override float SpawnChance(NPCSpawnInfo spawnInfo) {
			return spawnInfo.Player.ZoneRockLayerHeight ? 0.06f : 0f;
		}

		public override void AI() {
			NPC.TargetClosest();
			Player player = Main.player[NPC.target];
			NPC.ai[0]++;

			// Fades in and out while drifting toward the player.
			NPC.alpha = 110 + (int)(System.Math.Sin(NPC.ai[0] / 20f) * 60f);
			DevilUtils.FlyToward(NPC, player.Center, 3.5f, 40f);
			NPC.spriteDirection = NPC.direction;
		}

		public override void FindFrame(int frameHeight) {
			NPC.frameCounter++;
			if (NPC.frameCounter >= 8) {
				NPC.frameCounter = 0;
				NPC.frame.Y = (NPC.frame.Y + frameHeight) % (FrameCount * frameHeight);
			}
		}

		public override Color? GetAlpha(Color drawColor) {
			// Glows faintly so it can be seen in dark caves.
			return Color.Lerp(drawColor, Color.White, 0.4f) * NPC.Opacity;
		}

		public override void ModifyNPCLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<DevilFlesh>(), 2, 1, 2));
		}

		public override void SetBestiary(BestiaryDatabase database, BestiaryEntry bestiaryEntry) {
			bestiaryEntry.Info.AddRange([
				new FlavorTextBestiaryInfoElement("Mods.ChainsawManMod.Bestiary.GhostDevil")
			]);
		}

		public override void HitEffect(NPC.HitInfo hit) {
			DevilUtils.Bleed(NPC, hit, DustID.Smoke);
		}
	}
}
