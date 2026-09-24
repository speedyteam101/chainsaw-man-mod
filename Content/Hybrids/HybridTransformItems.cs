using ChainsawManMod.Common.Players;
using ChainsawManMod.Content.Buffs;
using ChainsawManMod.Content.Items;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Hybrids
{
	// Use to transform into a hybrid form; use again to turn back. Transforming ends any other form, Chainsaw Man included.
	public abstract class HybridTransformItem : ModItem
	{
		public abstract HybridType Hybrid { get; }
		protected abstract int DustType { get; }

		public override void SetDefaults() {
			Item.width = 24;
			Item.height = 24;
			Item.useStyle = ItemUseStyleID.HoldUp;
			Item.useTime = 30;
			Item.useAnimation = 30;
			Item.UseSound = SoundID.Item14;
			Item.value = Item.sellPrice(gold: 3);
			Item.rare = ItemRarityID.LightRed;
		}

		public override bool? UseItem(Player player) {
			if (player.whoAmI == Main.myPlayer) {
				ChainsawManPlayer modPlayer = player.GetModPlayer<ChainsawManPlayer>();
				int hybridBuff = ModContent.BuffType<HybridFormBuff>();

				if (player.HasBuff(hybridBuff) && modPlayer.selectedHybrid == Hybrid) {
					player.ClearBuff(hybridBuff); // turn back
				}
				else {
					player.ClearBuff(ModContent.BuffType<ChainsawDevilForm>());
					modPlayer.selectedHybrid = Hybrid;
					player.AddBuff(hybridBuff, 2);
				}
			}

			for (int i = 0; i < 25; i++) {
				Dust.NewDust(player.position, player.width, player.height, DustType, Main.rand.NextFloat(-3f, 3f), Main.rand.NextFloat(-4f, 0f));
			}
			return true;
		}
	}

	// Reze pulls the pin on her choker.
	public class GrenadePin : HybridTransformItem
	{
		public override HybridType Hybrid => HybridType.Bomb;
		protected override int DustType => DustID.Torch;

		public override void AddRecipes() {
			CreateRecipe().AddIngredient<DevilFlesh>(15).AddIngredient(ItemID.Grenade, 10).AddTile(TileID.Anvils).Register();
		}
	}

	public class KatanaHeart : HybridTransformItem
	{
		public override HybridType Hybrid => HybridType.Katana;
		protected override int DustType => DustID.Silver;

		public override void AddRecipes() {
			CreateRecipe().AddIngredient<DevilFlesh>(15).AddRecipeGroup(RecipeGroupID.IronBar, 12).AddIngredient(ItemID.Silk, 5).AddTile(TileID.Anvils).Register();
		}
	}

	public class BowHeart : HybridTransformItem
	{
		public override HybridType Hybrid => HybridType.Bow;
		protected override int DustType => DustID.Silver;

		public override void AddRecipes() {
			CreateRecipe().AddIngredient<DevilFlesh>(15).AddIngredient(ItemID.WoodenArrow, 100).AddRecipeGroup(RecipeGroupID.IronBar, 5).AddTile(TileID.Anvils).Register();
		}
	}

	public class FlamethrowerHeart : HybridTransformItem
	{
		public override HybridType Hybrid => HybridType.Flamethrower;
		protected override int DustType => DustID.Torch;

		public override void AddRecipes() {
			CreateRecipe().AddIngredient<DevilFlesh>(15).AddIngredient(ItemID.Hellstone, 10).AddTile(TileID.Anvils).Register();
		}
	}

	public class SwordHeart : HybridTransformItem
	{
		public override HybridType Hybrid => HybridType.Sword;
		protected override int DustType => DustID.Silver;

		public override void AddRecipes() {
			CreateRecipe().AddIngredient<DevilFlesh>(15).AddRecipeGroup(RecipeGroupID.IronBar, 15).AddTile(TileID.Anvils).Register();
		}
	}

	public class SpearHeart : HybridTransformItem
	{
		public override HybridType Hybrid => HybridType.Spear;
		protected override int DustType => DustID.Silver;

		public override void AddRecipes() {
			CreateRecipe().AddIngredient<DevilFlesh>(15).AddRecipeGroup(RecipeGroupID.IronBar, 10).AddIngredient(ItemID.Wood, 20).AddTile(TileID.Anvils).Register();
		}
	}

	public class WhipHeart : HybridTransformItem
	{
		public override HybridType Hybrid => HybridType.Whip;
		protected override int DustType => DustID.Blood;

		public override void AddRecipes() {
			CreateRecipe().AddIngredient<DevilFlesh>(15).AddIngredient(ItemID.Chain, 10).AddIngredient(ItemID.Leather, 5).AddTile(TileID.Anvils).Register();
		}
	}
}
