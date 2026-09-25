using ChainsawManMod.Content.Items;
using ChainsawManMod.Content.Projectiles;
using Microsoft.Xna.Framework;
using Terraria;
using Terraria.GameContent.Bestiary;
using Terraria.GameContent.ItemDropRules;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.NPCs
{
	// Hardmode Hallow enemy. Drifts above the player and throws feathers that slow; its touch slows too.
	public class AngelDevil : ModNPC
	{
		private const int FrameCount = 4;

		public override void SetStaticDefaults() {
			Main.npcFrameCount[Type] = FrameCount;
		}

		public override void SetDefaults() {
			NPC.width = 36;
			NPC.height = 44;
			NPC.damage = 60;
			NPC.defense = 25;
			NPC.lifeMax = 600;
			NPC.HitSound = SoundID.NPCHit5;
			NPC.DeathSound = SoundID.NPCDeath6;
			NPC.value = 1200f;
			NPC.knockBackResist = 0.3f;
			NPC.noGravity = true;
			NPC.noTileCollide = true;
			NPC.aiStyle = -1;
		}

		public override float SpawnChance(NPCSpawnInfo spawnInfo) {
			return Main.hardMode && spawnInfo.Player.ZoneHallow ? 0.07f : 0f;
		}

		public override void AI() {
			NPC.TargetClosest();
			Player player = Main.player[NPC.target];
			NPC.ai[0]++;

			Vector2 target = player.Center + new Vector2((float)System.Math.Sin(NPC.ai[0] / 60f) * 200f, -180f);
			DevilUtils.FlyToward(NPC, target, 5f, 30f);

			if (NPC.ai[0] % 100 == 0) {
				Vector2 aim = (player.Center - NPC.Center).SafeNormalize(Vector2.UnitY);
				for (int i = -1; i <= 1; i++) {
					DevilUtils.Shoot(NPC, NPC.Center, aim.RotatedBy(MathHelper.ToRadians(10f * i)) * 9f, ModContent.ProjectileType<FeatherBolt>(), NPC.damage / 3);
				}
			}

			NPC.spriteDirection = NPC.direction;
			Lighting.AddLight(NPC.Center, 0.6f, 0.6f, 0.5f);
		}

		public override void FindFrame(int frameHeight) {
			NPC.frameCounter++;
			if (NPC.frameCounter >= 7) {
				NPC.frameCounter = 0;
				NPC.frame.Y = (NPC.frame.Y + frameHeight) % (FrameCount * frameHeight);
			}
		}

		public override void OnHitPlayer(Player target, Player.HurtInfo hurtInfo) {
			target.AddBuff(BuffID.Slow, 240);
		}

		public override void ModifyNPCLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<DevilFlesh>(), 1, 2, 5));
			npcLoot.Add(ItemDropRule.Common(ItemID.SoulofLight, 2));
		}

		public override void SetBestiary(BestiaryDatabase database, BestiaryEntry bestiaryEntry) {
			bestiaryEntry.Info.AddRange([new FlavorTextBestiaryInfoElement("Mods.ChainsawManMod.Bestiary.AngelDevil")]);
		}

		public override void HitEffect(NPC.HitInfo hit) {
			DevilUtils.Bleed(NPC, hit, DustID.WhiteTorch);
		}
	}
}
