using ChainsawManMod.Content.Projectiles;
using Terraria;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Abilities
{
	// Tier 2: fire a chain from your arm. It damages what it hits and yanks you toward it (enemies or blocks).
	public class ChainHook : DevilAbility
	{
		public override int RequiredTier => 2;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.width = 28;
			Item.height = 28;
			Item.useStyle = ItemUseStyleID.Shoot;
			Item.useTime = 30;
			Item.useAnimation = 30;
			Item.noMelee = true;
			Item.noUseGraphic = true;
			Item.DamageType = DamageClass.Melee;
			Item.damage = 60;
			Item.knockBack = 2f;
			Item.UseSound = SoundID.Item1;
			Item.shoot = ModContent.ProjectileType<ChainHookProjectile>();
			Item.shootSpeed = 22f;
		}

		public override bool CanUseItem(Player player) {
			return base.CanUseItem(player) && player.ownedProjectileCounts[Item.shoot] == 0;
		}
	}
}
