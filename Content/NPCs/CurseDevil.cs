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
	// Hardmode Dungeon enemy. Floats through walls and fires nails that curse (the player can't use items for a moment).
	public class CurseDevil : ModNPC
	{
		private const int FrameCount = 4;

		public override void SetStaticDefaults() {
			Main.npcFrameCount[Type] = FrameCount;
		}

		public override void SetDefaults() {
			NPC.width = 32;
			NPC.height = 40;
			NPC.damage = 55;
			NPC.defense = 20;
			NPC.lifeMax = 500;
			NPC.HitSound = SoundID.NPCHit5;
			NPC.DeathSound = SoundID.NPCDeath6;
			NPC.value = 1000f;
			NPC.knockBackResist = 0.3f;
			NPC.noGravity = true;
			NPC.noTileCollide = true;
			NPC.alpha = 60;
			NPC.aiStyle = -1;
		}

		public override float SpawnChance(NPCSpawnInfo spawnInfo) {
			return Main.hardMode && spawnInfo.Player.ZoneDungeon ? 0.06f : 0f;
		}

		public override void AI() {
			NPC.TargetClosest();
			Player player = Main.player[NPC.target];
			NPC.ai[0]++;

			// Keep a medium distance and fire curse nails.
			Vector2 away = (NPC.Center - player.Center).SafeNormalize(Vector2.UnitY);
			DevilUtils.FlyToward(NPC, player.Center + away * 260f, 4f, 30f);

			if (NPC.ai[0] % 90 == 0) {
				Vector2 aim = (player.Center - NPC.Center).SafeNormalize(Vector2.UnitY) * 10f;
				DevilUtils.Shoot(NPC, NPC.Center, aim, ModContent.ProjectileType<CurseNail>(), NPC.damage / 3);
			}

			NPC.spriteDirection = NPC.direction;
		}

		public override void FindFrame(int frameHeight) {
			NPC.frameCounter++;
			if (NPC.frameCounter >= 8) {
				NPC.frameCounter = 0;
				NPC.frame.Y = (NPC.frame.Y + frameHeight) % (FrameCount * frameHeight);
			}
		}

		public override void OnHitPlayer(Player target, Player.HurtInfo hurtInfo) {
			target.AddBuff(BuffID.Cursed, 120);
		}

		public override void ModifyNPCLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<DevilFlesh>(), 1, 2, 5));
			npcLoot.Add(ItemDropRule.Common(ItemID.Ectoplasm, 3));
		}

		public override void SetBestiary(BestiaryDatabase database, BestiaryEntry bestiaryEntry) {
			bestiaryEntry.Info.AddRange([new FlavorTextBestiaryInfoElement("Mods.ChainsawManMod.Bestiary.CurseDevil")]);
		}

		public override void HitEffect(NPC.HitInfo hit) {
			DevilUtils.Bleed(NPC, hit, DustID.Smoke);
		}
	}
}
