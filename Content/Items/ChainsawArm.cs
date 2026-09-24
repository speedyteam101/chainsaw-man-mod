using ChainsawManMod.Common.Players;
using ChainsawManMod.Content.Projectiles;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Items
{
	// A held chainsaw, modelled after ExampleMod's ExampleDrill. Works as an axe and as a melee weapon.
	// It grows stronger as the world progresses, and much stronger in Chainsaw Devil form.
	public class ChainsawArm : ModItem
	{
		// Extra base damage unlocked by each progression milestone.
		public static int ProgressionBonus() {
			int bonus = 0;
			if (NPC.downedBoss3) bonus += 15;          // Skeletron
			if (Main.hardMode) bonus += 30;            // Wall of Flesh
			if (NPC.downedMechBossAny) bonus += 30;    // any mechanical boss
			if (NPC.downedPlantBoss) bonus += 40;      // Plantera
			if (NPC.downedMoonlord) bonus += 80;       // Moon Lord
			return bonus;
		}

		// Damage multiplier while transformed, by Starter Cord tier (0 = not transformed).
		public static float FormMultiplier(int formTier) => formTier switch { 3 => 5f, 2 => 3.5f, 1 => 2f, _ => 1f };

		public override void SetStaticDefaults() {
			// Only informs other mods; tModLoader does not apply vanilla chainsaw adjustments to modded items.
			ItemID.Sets.IsChainsaw[Type] = true;
		}

		public override void SetDefaults() {
			Item.damage = 45;
			Item.crit = 16;
			Item.DamageType = DamageClass.MeleeNoSpeed;
			Item.width = 40;
			Item.height = 24;
			Item.useTime = 6;
			Item.useAnimation = 15;
			Item.useStyle = ItemUseStyleID.Shoot;
			Item.knockBack = 3f;
			Item.value = Item.sellPrice(gold: 1);
			Item.rare = ItemRarityID.Orange;
			Item.UseSound = SoundID.Item23;
			Item.shoot = ModContent.ProjectileType<ChainsawArmProjectile>();
			Item.shootSpeed = 30f;
			Item.noMelee = true;
			Item.noUseGraphic = true;
			Item.channel = true;
			Item.tileBoost = -1;

			// Axe power is shown in game as this value times 5, so 35 = 175% axe power.
			Item.axe = 35;
		}

		public override void ModifyWeaponDamage(Player player, ref StatModifier damage) {
			damage.Base += ProgressionBonus();
			damage *= FormMultiplier(player.GetModPlayer<ChainsawManPlayer>().formTier);
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
