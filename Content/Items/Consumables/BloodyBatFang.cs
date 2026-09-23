using ChainsawManMod.Content.NPCs;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Items.Consumables
{
	// Summons the Bat Devil. Hardmode only.
	public class BloodyBatFang : DevilSummonItemBase
	{
		protected override int BossType => ModContent.NPCType<BatDevil>();

		public override void SetDefaults() {
			base.SetDefaults();
			Item.width = 20;
			Item.value = Item.sellPrice(gold: 1);
			Item.rare = ItemRarityID.Pink;
		}

		public override bool CanUseItem(Player player) {
			return Main.hardMode && base.CanUseItem(player);
		}

		public override void AddRecipes() {
			CreateRecipe()
				.AddIngredient<DevilFlesh>(15)
				.AddIngredient(ItemID.SoulofNight, 5)
				.AddTile(TileID.MythrilAnvil)
				.Register();
		}
	}
}
