using Terraria;
using Terraria.Audio;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Items.Consumables
{
	// Shared boss-summoning behaviour, based on ExampleMod's MinionBossSummonItem.
	public abstract class DevilSummonItemBase : ModItem
	{
		protected abstract int BossType { get; }

		public override void SetStaticDefaults() {
			Item.ResearchUnlockCount = 3;
			ItemID.Sets.SortingPriorityBossSpawns[Type] = 12;
		}

		public override void SetDefaults() {
			Item.width = 28;
			Item.height = 28;
			Item.maxStack = 20;
			Item.useAnimation = 30;
			Item.useTime = 30;
			Item.useStyle = ItemUseStyleID.HoldUp;
			Item.consumable = true;
		}

		public override void ModifyResearchSorting(ref ContentSamples.CreativeHelper.ItemGroup itemGroup) {
			itemGroup = ContentSamples.CreativeHelper.ItemGroup.BossSpawners;
		}

		public override bool CanUseItem(Player player) {
			return !NPC.AnyNPCs(BossType);
		}

		public override bool? UseItem(Player player) {
			if (player.whoAmI == Main.myPlayer) {
				SoundEngine.PlaySound(SoundID.Roar, player.position);

				if (Main.netMode != NetmodeID.MultiplayerClient) {
					NPC.SpawnOnPlayer(player.whoAmI, BossType);
				}
				else {
					NetMessage.SendData(MessageID.SpawnBossUseLicenseStartEvent, number: player.whoAmI, number2: BossType);
				}
			}

			return true;
		}
	}
}
