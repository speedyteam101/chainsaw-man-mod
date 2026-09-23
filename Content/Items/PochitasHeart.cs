using ChainsawManMod.Common.Players;
using Terraria;
using Terraria.ID;
using Terraria.Localization;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Items
{
	// Makes the player a Devil Hybrid: melee hits drink blood, and Pochita saves you from death on a cooldown.
	public class PochitasHeart : ModItem
	{
		public static readonly int MeleeDamageBonus = 8;

		public override LocalizedText Tooltip => base.Tooltip.WithFormatArgs(MeleeDamageBonus, ChainsawManPlayer.ReviveCooldownSeconds / 60);

		public override void SetDefaults() {
			Item.width = 26;
			Item.height = 26;
			Item.accessory = true;
			Item.value = Item.sellPrice(gold: 2);
			Item.rare = ItemRarityID.Orange;
		}

		public override void UpdateAccessory(Player player, bool hideVisual) {
			player.GetModPlayer<ChainsawManPlayer>().hasPochitaHeart = true;
			player.GetDamage(DamageClass.Melee) += MeleeDamageBonus / 100f;
		}

		public override void AddRecipes() {
			CreateRecipe()
				.AddIngredient(ItemID.LifeCrystal)
				.AddIngredient(ItemID.Chain, 5)
				.AddIngredient(ItemID.Shackle)
				.AddTile(TileID.DemonAltar)
				.Register();
		}
	}
}
