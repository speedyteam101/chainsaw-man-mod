using ChainsawManMod.Content.Projectiles;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Items
{
	// A held chainsaw, modelled after ExampleMod's ExampleDrill. Works as an axe and as a melee weapon.
	public class ChainsawArm : ModItem
	{
		public override void SetStaticDefaults() {
			// Only informs other mods; tModLoader does not apply vanilla chainsaw adjustments to modded items.
			ItemID.Sets.IsChainsaw[Type] = true;
		}

		public override void SetDefaults() {
			Item.damage = 22;
			Item.DamageType = DamageClass.MeleeNoSpeed;
			Item.width = 40;
			Item.height = 24;
			Item.useTime = 6;
			Item.useAnimation = 15;
			Item.useStyle = ItemUseStyleID.Shoot;
			Item.knockBack = 1f;
			Item.value = Item.sellPrice(gold: 1);
			Item.rare = ItemRarityID.Orange;
			Item.UseSound = SoundID.Item23;
			Item.shoot = ModContent.ProjectileType<ChainsawArmProjectile>();
			Item.shootSpeed = 30f;
			Item.noMelee = true;
			Item.noUseGraphic = true;
			Item.channel = true;
			Item.tileBoost = -1;

			// Axe power is shown in game as this value times 5, so 20 = 100% axe power.
			Item.axe = 20;
		}

		public override void AddRecipes() {
			CreateRecipe()
				.AddRecipeGroup(RecipeGroupID.IronBar, 12)
				.AddIngredient(ItemID.Chain, 10)
				.AddTile(TileID.Anvils)
				.Register();
		}
	}
}
