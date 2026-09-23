using ChainsawManMod.Content.Projectiles;
using Microsoft.Xna.Framework;
using Terraria;
using Terraria.DataStructures;
using Terraria.ID;
using Terraria.ModLoader;

namespace ChainsawManMod.Content.Abilities
{
	// Tier 1: rev up and dash toward the cursor, shredding everything you pass through.
	public class RevDash : DevilAbility
	{
		public override int RequiredTier => 1;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.width = 28;
			Item.height = 28;
			Item.useStyle = ItemUseStyleID.Shoot;
			Item.useTime = 40;
			Item.useAnimation = 40;
			Item.noMelee = true;
			Item.noUseGraphic = true;
			Item.DamageType = DamageClass.Melee;
			Item.damage = 70;
			Item.knockBack = 8f;
			Item.UseSound = SoundID.Item23;
			Item.shoot = ModContent.ProjectileType<RevDashHitbox>();
			Item.shootSpeed = 1f;
		}

		public override bool Shoot(Player player, EntitySource_ItemUse_WithAmmo source, Vector2 position, Vector2 velocity, int type, int damage, float knockback) {
			// Launch the player toward the cursor and make them briefly invincible.
			player.velocity = velocity.SafeNormalize(Vector2.UnitX * player.direction) * 18f;
			player.immune = true;
			player.immuneTime = 20;
			player.fallStart = (int)(player.position.Y / 16f); // no fall damage from the dash

			Projectile.NewProjectile(source, player.Center, Vector2.Zero, type, damage, knockback, player.whoAmI);
			return false;
		}
	}
}
