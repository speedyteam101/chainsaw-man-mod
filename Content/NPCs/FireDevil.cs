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
	// Underworld enemy. Hovers near the player and lobs fireballs that set you on fire.
	public class FireDevil : ModNPC
	{
		private const int FrameCount = 4;

		public override void SetStaticDefaults() {
			Main.npcFrameCount[Type] = FrameCount;
			NPCID.Sets.SpecificDebuffImmunity[Type][BuffID.OnFire] = true;
		}

		public override void SetDefaults() {
			NPC.width = 30;
			NPC.height = 34;
			NPC.damage = 32;
			NPC.defense = 10;
			NPC.lifeMax = 150;
			NPC.HitSound = SoundID.NPCHit5;
			NPC.DeathSound = SoundID.NPCDeath6;
			NPC.value = 300f;
			NPC.knockBackResist = 0.5f;
			NPC.noGravity = true;
			NPC.lavaImmune = true;
			NPC.aiStyle = -1;
		}

		public override float SpawnChance(NPCSpawnInfo spawnInfo) {
			return spawnInfo.Player.ZoneUnderworldHeight ? 0.12f : 0f;
		}

		public override void AI() {
			NPC.TargetClosest();
			Player player = Main.player[NPC.target];
			NPC.ai[0]++;

			// Hover to one side of the player, bobbing up and down.
			Vector2 target = player.Center + new Vector2(-NPC.direction * 180f, -120f + (float)System.Math.Sin(NPC.ai[0] / 25f) * 30f);
			DevilUtils.FlyToward(NPC, target, 5f, 25f);
			if (NPC.collideX) {
				NPC.velocity.X = -NPC.oldVelocity.X;
			}
			if (NPC.collideY) {
				NPC.velocity.Y = -NPC.oldVelocity.Y;
			}

			if (NPC.ai[0] % 120 == 0 && Collision.CanHit(NPC.Center, 1, 1, player.Center, 1, 1)) {
				Vector2 aim = (player.Center - NPC.Center).SafeNormalize(Vector2.UnitY) * 7f;
				DevilUtils.Shoot(NPC, NPC.Center, aim, ModContent.ProjectileType<FireBolt>(), NPC.damage / 2);
			}

			NPC.spriteDirection = NPC.direction;
			Lighting.AddLight(NPC.Center, 0.8f, 0.4f, 0.1f);
			if (Main.rand.NextBool(4)) {
				Dust.NewDust(NPC.position, NPC.width, NPC.height, DustID.Torch);
			}
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
			npcLoot.Add(ItemDropRule.Common(ItemID.Hellstone, 2, 2, 5));
		}

		public override void SetBestiary(BestiaryDatabase database, BestiaryEntry bestiaryEntry) {
			bestiaryEntry.Info.AddRange([
				new FlavorTextBestiaryInfoElement("Mods.ChainsawManMod.Bestiary.FireDevil")
			]);
		}

		public override void HitEffect(NPC.HitInfo hit) {
			DevilUtils.Bleed(NPC, hit, DustID.Torch);
		}
	}
}
