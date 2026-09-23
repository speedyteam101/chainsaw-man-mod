using ChainsawManMod.Content.Items;
using System;
using Terraria;
using Terraria.GameContent.Bestiary;
using Terraria.GameContent.ItemDropRules;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.NPCs
{
	// Pre-Hardmode cave enemy. Scuttles along the ground like a skeleton and poisons on hit.
	public class SpiderDevil : ModNPC
	{
		private const int FrameCount = 4;

		public override void SetStaticDefaults() {
			Main.npcFrameCount[Type] = FrameCount;
		}

		public override void SetDefaults() {
			NPC.width = 36;
			NPC.height = 24;
			NPC.damage = 26;
			NPC.defense = 8;
			NPC.lifeMax = 110;
			NPC.HitSound = SoundID.NPCHit1;
			NPC.DeathSound = SoundID.NPCDeath1;
			NPC.value = 150f;
			NPC.knockBackResist = 0.4f;
			NPC.aiStyle = NPCAIStyleID.Fighter;
			AIType = NPCID.Skeleton;
		}

		public override float SpawnChance(NPCSpawnInfo spawnInfo) {
			return spawnInfo.Player.ZoneRockLayerHeight ? 0.07f : 0f;
		}

		public override void FindFrame(int frameHeight) {
			NPC.spriteDirection = NPC.direction;
			if (NPC.velocity.Y != 0f) {
				NPC.frame.Y = frameHeight;
				return;
			}

			NPC.frameCounter += Math.Abs(NPC.velocity.X);
			if (NPC.frameCounter >= 6) {
				NPC.frameCounter = 0;
				NPC.frame.Y = (NPC.frame.Y + frameHeight) % (FrameCount * frameHeight);
			}
		}

		public override void OnHitPlayer(Player target, Player.HurtInfo hurtInfo) {
			target.AddBuff(BuffID.Poisoned, 300);
		}

		public override void ModifyNPCLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<DevilFlesh>(), 2, 1, 2));
			npcLoot.Add(ItemDropRule.Common(ItemID.Cobweb, 1, 3, 8));
		}

		public override void SetBestiary(BestiaryDatabase database, BestiaryEntry bestiaryEntry) {
			bestiaryEntry.Info.AddRange([
				new FlavorTextBestiaryInfoElement("Mods.ChainsawManMod.Bestiary.SpiderDevil")
			]);
		}

		public override void HitEffect(NPC.HitInfo hit) {
			DevilUtils.Bleed(NPC, hit);
		}
	}
}
