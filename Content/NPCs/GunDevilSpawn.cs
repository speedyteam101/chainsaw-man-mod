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
	// Hardmode surface enemy: a floating chunk of the Gun Devil. Keeps its distance and fires bursts of bullets.
	public class GunDevilSpawn : ModNPC
	{
		private const int FrameCount = 4;

		public override void SetStaticDefaults() {
			Main.npcFrameCount[Type] = FrameCount;
		}

		public override void SetDefaults() {
			NPC.width = 34;
			NPC.height = 34;
			NPC.damage = 50;
			NPC.defense = 20;
			NPC.lifeMax = 350;
			NPC.HitSound = SoundID.NPCHit2;
			NPC.DeathSound = SoundID.NPCDeath7;
			NPC.value = 600f;
			NPC.knockBackResist = 0.3f;
			NPC.noGravity = true;
			NPC.aiStyle = -1;
		}

		public override float SpawnChance(NPCSpawnInfo spawnInfo) {
			return Main.hardMode && spawnInfo.Player.ZoneOverworldHeight ? 0.05f : 0f;
		}

		public override void AI() {
			NPC.TargetClosest();
			Player player = Main.player[NPC.target];
			NPC.ai[0]++;

			// Stay about 300 pixels from the player.
			Vector2 away = (NPC.Center - player.Center).SafeNormalize(Vector2.UnitY);
			DevilUtils.FlyToward(NPC, player.Center + away * 300f + new Vector2(0f, -80f), 6f, 30f);
			if (NPC.collideX) {
				NPC.velocity.X = -NPC.oldVelocity.X;
			}
			if (NPC.collideY) {
				NPC.velocity.Y = -NPC.oldVelocity.Y;
			}

			// Burst of 3 bullets every 2 seconds.
			int cycle = (int)NPC.ai[0] % 120;
			if ((cycle == 100 || cycle == 108 || cycle == 116) && Collision.CanHit(NPC.Center, 1, 1, player.Center, 1, 1)) {
				Vector2 aim = (player.Center - NPC.Center).SafeNormalize(Vector2.UnitY) * 12f;
				DevilUtils.Shoot(NPC, NPC.Center, aim, ModContent.ProjectileType<DevilBullet>(), NPC.damage / 2);
				Terraria.Audio.SoundEngine.PlaySound(SoundID.Item11, NPC.Center);
			}

			NPC.spriteDirection = NPC.direction;
		}

		public override void FindFrame(int frameHeight) {
			NPC.frameCounter++;
			if (NPC.frameCounter >= 6) {
				NPC.frameCounter = 0;
				NPC.frame.Y = (NPC.frame.Y + frameHeight) % (FrameCount * frameHeight);
			}
		}

		public override void ModifyNPCLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<GunDevilFragment>(), 3));
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<DevilFlesh>(), 2, 1, 3));
		}

		public override void SetBestiary(BestiaryDatabase database, BestiaryEntry bestiaryEntry) {
			bestiaryEntry.Info.AddRange([
				new FlavorTextBestiaryInfoElement("Mods.ChainsawManMod.Bestiary.GunDevilSpawn")
			]);
		}

		public override void HitEffect(NPC.HitInfo hit) {
			DevilUtils.Bleed(NPC, hit);
		}
	}
}
