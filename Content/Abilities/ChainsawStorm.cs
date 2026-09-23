using ChainsawManMod.Content.Projectiles;
using Microsoft.Xna.Framework;
using Terraria;
using Terraria.DataStructures;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Abilities
{
	// Tier 3: surround yourself with spinning chainsaw blades for a few seconds.
	public class ChainsawStorm : DevilAbility
	{
		public const int Blades = 4;

		public override int RequiredTier => 3;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.width = 28;
			Item.height = 28;
			Item.useStyle = ItemUseStyleID.HoldUp;
			Item.useTime = 30;
			Item.useAnimation = 30;
			Item.noMelee = true;
			Item.DamageType = DamageClass.Melee;
			Item.damage = 50;
			Item.knockBack = 4f;
			Item.UseSound = SoundID.Item22;
			Item.shoot = ModContent.ProjectileType<StormBlade>();
			Item.shootSpeed = 1f;
		}

		public override bool CanUseItem(Player player) {
			return base.CanUseItem(player) && player.ownedProjectileCounts[Item.shoot] == 0;
		}

		public override bool Shoot(Player player, EntitySource_ItemUse_WithAmmo source, Vector2 position, Vector2 velocity, int type, int damage, float knockback) {
			for (int i = 0; i < Blades; i++) {
				Projectile.NewProjectile(source, player.Center, Vector2.Zero, type, damage, knockback, player.whoAmI, ai0: MathHelper.TwoPi * i / Blades);
			}
			return false;
		}
	}
}
