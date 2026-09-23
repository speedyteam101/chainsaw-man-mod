using ChainsawManMod.Content.Items;
using Terraria;
using Terraria.GameContent.Bestiary;
using Terraria.GameContent.ItemDropRules;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.NPCs
{
	// A lump of flesh spat out by the Eternity Devil. While any are alive, the Eternity Devil regenerates.
	public class EternityFleshling : ModNPC
	{
		private const int FrameCount = 4;

		public override void SetStaticDefaults() {
			Main.npcFrameCount[Type] = FrameCount;
		}

		public override void SetDefaults() {
			NPC.width = 26;
			NPC.height = 26;
			NPC.damage = 50;
			NPC.defense = 15;
			NPC.lifeMax = 300;
			NPC.HitSound = SoundID.NPCHit9;
			NPC.DeathSound = SoundID.NPCDeath11;
			NPC.knockBackResist = 0.5f;
			NPC.noGravity = true;
			NPC.noTileCollide = true;
			NPC.aiStyle = -1;
		}

		public override void AI() {
			NPC.TargetClosest();
			Player player = Main.player[NPC.target];
			NPC.ai[0]++;
			DevilUtils.FlyToward(NPC, player.Center, 7f, 35f);
			NPC.rotation += 0.05f * NPC.direction;
		}

		public override void FindFrame(int frameHeight) {
			NPC.frameCounter++;
			if (NPC.frameCounter >= 7) {
				NPC.frameCounter = 0;
				NPC.frame.Y = (NPC.frame.Y + frameHeight) % (FrameCount * frameHeight);
			}
		}

		public override void ModifyNPCLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<DevilFlesh>(), 3));
		}

		public override void SetBestiary(BestiaryDatabase database, BestiaryEntry bestiaryEntry) {
			bestiaryEntry.Info.AddRange([
				new FlavorTextBestiaryInfoElement("Mods.ChainsawManMod.Bestiary.EternityFleshling")
			]);
		}

		public override void HitEffect(NPC.HitInfo hit) {
			DevilUtils.Bleed(NPC, hit);
		}
	}
}
