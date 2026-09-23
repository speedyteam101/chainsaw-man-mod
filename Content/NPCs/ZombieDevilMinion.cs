using ChainsawManMod.Content.Items;
using Terraria;
using Terraria.GameContent.Bestiary;
using Terraria.GameContent.ItemDropRules;
using Terraria.ID;
using Terraria.ModLoader;
using Terraria.ModLoader.Utilities;

namespace ChainsawManMod.Content.NPCs
{
	// A zombie controlled by the Zombie Devil. Walks like a vanilla zombie (based on ExampleMod's PartyZombie).
	public class ZombieDevilMinion : ModNPC
	{
		public override void SetStaticDefaults() {
			Main.npcFrameCount[Type] = Main.npcFrameCount[NPCID.Zombie];

			NPCID.Sets.NPCBestiaryDrawModifiers value = new NPCID.Sets.NPCBestiaryDrawModifiers() {
				Velocity = 1f
			};
			NPCID.Sets.NPCBestiaryDrawOffset.Add(Type, value);
		}

		public override void SetDefaults() {
			NPC.width = 18;
			NPC.height = 40;
			NPC.damage = 18;
			NPC.defense = 6;
			NPC.lifeMax = 70;
			NPC.HitSound = SoundID.NPCHit1;
			NPC.DeathSound = SoundID.NPCDeath2;
			NPC.value = 80f;
			NPC.knockBackResist = 0.5f;
			NPC.aiStyle = NPCAIStyleID.Fighter;

			AIType = NPCID.Zombie;
			AnimationType = NPCID.Zombie;
		}

		public override float SpawnChance(NPCSpawnInfo spawnInfo) {
			return SpawnCondition.OverworldNightMonster.Chance * 0.25f;
		}

		public override void ModifyNPCLoot(NPCLoot npcLoot) {
			npcLoot.Add(ItemDropRule.Common(ModContent.ItemType<DevilFlesh>(), 2, 1, 2));
		}

		public override void SetBestiary(BestiaryDatabase database, BestiaryEntry bestiaryEntry) {
			bestiaryEntry.Info.AddRange([
				BestiaryDatabaseNPCsPopulator.CommonTags.SpawnConditions.Times.NightTime,
				new FlavorTextBestiaryInfoElement("Mods.ChainsawManMod.Bestiary.ZombieDevilMinion")
			]);
		}

		public override void HitEffect(NPC.HitInfo hit) {
			int count = NPC.life <= 0 ? 20 : 5;
			for (int i = 0; i < count; i++) {
				Dust.NewDust(NPC.position, NPC.width, NPC.height, DustID.Blood, hit.HitDirection, -1f);
			}
		}
	}
}
