using ChainsawManMod.Content.Items;
using System;
using Terraria;
using Terraria.GameContent.Bestiary;
using Terraria.GameContent.ItemDropRules;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.NPCs
{
	// Jungle enemy (any time). Slithers along the ground and poisons on hit.
	public class SnakeDevil : ModNPC
	{
		private const int FrameCount = 4;

		public override void SetStaticDefaults() {
			Main.npcFrameCount[Type] = FrameCount;
			NPCID.Sets.SpecificDebuffImmunity[Type][BuffID.Poisoned] = true;
		}

		public override void SetDefaults() {
			NPC.width = 44;
			NPC.height = 20;
			NPC.damage = 30;
			NPC.defense = 8;
			NPC.lifeMax = 140;
			NPC.HitSound = SoundID.NPCHit1;
			NPC.DeathSound = SoundID.NPCDeath1;
			NPC.value = 200f;
			NPC.knockBackResist = 0.4f;
			NPC.aiStyle = NPCAIStyleID.Fighter;
			AIType = NPCID.Skeleton;
		}

		public override float SpawnChance(NPCSpawnInfo spawnInfo) {
			return spawnInfo.Player.ZoneJungle ? 0.08f : 0f;
		}

		public override void FindFrame(int frameHeight) {
			NPC.spriteDirection = NPC.direction;
			NPC.frameCounter += Math.Abs(NPC.velocity.X) + 0.2f;
			if (NPC.frameCounter >= 6) {
				NPC.frameCounter = 0;
				NPC.frame.Y = (NPC.frame.Y + frameHeight) % (FrameCount * frameHeight);
			}
		}

		public override void OnHitPlayer(Player target, Player.HurtInfo hurtInfo) {
			target.AddBuff(BuffID.Poisoned, 360);
		}

		public override void ModifyNPCLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<DevilFlesh>(), 2, 1, 3));
		}

		public override void SetBestiary(BestiaryDatabase database, BestiaryEntry bestiaryEntry) {
			bestiaryEntry.Info.AddRange([new FlavorTextBestiaryInfoElement("Mods.ChainsawManMod.Bestiary.SnakeDevil")]);
		}

		public override void HitEffect(NPC.HitInfo hit) {
			DevilUtils.Bleed(NPC, hit);
		}
	}
}
