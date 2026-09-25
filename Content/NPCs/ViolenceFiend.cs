using ChainsawManMod.Content.Items;
using System;
using Terraria;
using Terraria.GameContent.Bestiary;
using Terraria.GameContent.ItemDropRules;
using Terraria.ID;
using Terraria.ModLoader;
using Terraria.ModLoader.Utilities;

namespace ChainsawManMod.Content.NPCs
{
	// Hardmode surface enemy at night. A slow, heavy brute that hits very hard and shrugs off knockback.
	public class ViolenceFiend : ModNPC
	{
		private const int FrameCount = 4;

		public override void SetStaticDefaults() {
			Main.npcFrameCount[Type] = FrameCount;
		}

		public override void SetDefaults() {
			NPC.width = 30;
			NPC.height = 52;
			NPC.damage = 80;
			NPC.defense = 30;
			NPC.lifeMax = 900;
			NPC.HitSound = SoundID.NPCHit1;
			NPC.DeathSound = SoundID.NPCDeath2;
			NPC.value = 1500f;
			NPC.knockBackResist = 0.05f;
			NPC.aiStyle = NPCAIStyleID.Fighter;
			AIType = NPCID.Skeleton;
		}

		public override float SpawnChance(NPCSpawnInfo spawnInfo) {
			return Main.hardMode ? SpawnCondition.OverworldNightMonster.Chance * 0.1f : 0f;
		}

		public override void FindFrame(int frameHeight) {
			NPC.spriteDirection = NPC.direction;
			if (NPC.velocity.Y != 0f) {
				NPC.frame.Y = frameHeight;
				return;
			}
			NPC.frameCounter += Math.Abs(NPC.velocity.X) + 0.1f;
			if (NPC.frameCounter >= 7) {
				NPC.frameCounter = 0;
				NPC.frame.Y = (NPC.frame.Y + frameHeight) % (FrameCount * frameHeight);
			}
		}

		public override void OnHitPlayer(Player target, Player.HurtInfo hurtInfo) {
			target.AddBuff(BuffID.Confused, 120);
		}

		public override void ModifyNPCLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<DevilFlesh>(), 1, 3, 6));
		}

		public override void SetBestiary(BestiaryDatabase database, BestiaryEntry bestiaryEntry) {
			bestiaryEntry.Info.AddRange([
				BestiaryDatabaseNPCsPopulator.CommonTags.SpawnConditions.Times.NightTime,
				new FlavorTextBestiaryInfoElement("Mods.ChainsawManMod.Bestiary.ViolenceFiend")
			]);
		}

		public override void HitEffect(NPC.HitInfo hit) {
			DevilUtils.Bleed(NPC, hit);
		}
	}
}
