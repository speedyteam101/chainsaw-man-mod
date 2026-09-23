using ChainsawManMod.Content.NPCs;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Items.Consumables
{
	// Summons Makima. Only works after the Moon Lord has been defeated.
	public class MakimasContract : DevilSummonItemBase
	{
		protected override int BossType => ModContent.NPCType<Makima>();

		public override void SetDefaults() {
			base.SetDefaults();
			Item.value = Item.sellPrice(gold: 10);
			Item.rare = ItemRarityID.Red;
		}

		public override bool CanUseItem(Player player) {
			return NPC.downedMoonlord && base.CanUseItem(player);
		}

		public override void AddRecipes() {
			CreateRecipe()
				.AddIngredient(ItemID.LunarBar, 10)
				.AddIngredient<GunDevilFragment>(10)
				.AddIngredient<DevilFlesh>(20)
				.AddTile(TileID.LunarCraftingStation)
				.Register();
		}
	}
}
