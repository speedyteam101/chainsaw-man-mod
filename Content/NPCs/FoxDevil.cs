using ChainsawManMod.Content.Items;
using System;
using Terraria;
using Terraria.GameContent.Bestiary;
using Terraria.GameContent.ItemDropRules;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.NPCs
{
	// Snow biome enemy. A fast, low-running fox that bites hard.
	public class FoxDevil : ModNPC
	{
		private const int FrameCount = 4;

		public override void SetStaticDefaults() {
			Main.npcFrameCount[Type] = FrameCount;
		}

		public override void SetDefaults() {
			NPC.width = 40;
			NPC.height = 26;
			NPC.damage = 34;
			NPC.defense = 6;
			NPC.lifeMax = 160;
			NPC.HitSound = SoundID.NPCHit1;
			NPC.DeathSound = SoundID.NPCDeath1;
			NPC.value = 250f;
			NPC.knockBackResist = 0.5f;
			NPC.aiStyle = NPCAIStyleID.Fighter;
			AIType = NPCID.Skeleton;
		}

		public override float SpawnChance(NPCSpawnInfo spawnInfo) {
			return spawnInfo.Player.ZoneSnow ? 0.08f : 0f;
		}

		public override void AI() {
			// Faster than the skeleton AI it borrows.
			if (NPC.velocity.Y == 0f && Math.Abs(NPC.velocity.X) < 4.5f) {
				NPC.velocity.X += NPC.direction * 0.15f;
			}
		}

		public override void FindFrame(int frameHeight) {
			NPC.spriteDirection = NPC.direction;
			if (NPC.velocity.Y != 0f) {
				NPC.frame.Y = frameHeight;
				return;
			}
			NPC.frameCounter += Math.Abs(NPC.velocity.X);
			if (NPC.frameCounter >= 7) {
				NPC.frameCounter = 0;
				NPC.frame.Y = (NPC.frame.Y + frameHeight) % (FrameCount * frameHeight);
			}
		}

		public override void OnHitPlayer(Player target, Player.HurtInfo hurtInfo) {
			target.AddBuff(BuffID.Frostburn, 180);
		}

		public override void ModifyNPCLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<DevilFlesh>(), 2, 1, 3));
		}

		public override void SetBestiary(BestiaryDatabase database, BestiaryEntry bestiaryEntry) {
			bestiaryEntry.Info.AddRange([new FlavorTextBestiaryInfoElement("Mods.ChainsawManMod.Bestiary.FoxDevil")]);
		}

		public override void HitEffect(NPC.HitInfo hit) {
			DevilUtils.Bleed(NPC, hit);
		}
	}
}
