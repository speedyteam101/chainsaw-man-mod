using Microsoft.Xna.Framework;
using RobotJack.Content.Projectiles;
using Terraria;
using Terraria.DataStructures;
using Terraria.ID;
using Terraria.ModLoader;

namespace RobotJack.Content.Abilities
{
	// Fire the back thrusters and rocket toward the cursor, burning everything you pass through.
	public class ThrusterDash : RobotAbility
	{
		public override void SetDefaults() {
			base.SetDefaults();
			Item.width = 32;
			Item.height = 32;
			Item.useStyle = ItemUseStyleID.Shoot;
			Item.useTime = 40;
			Item.useAnimation = 40;
			Item.noUseGraphic = true;
			Item.DamageType = DamageClass.Melee;
			Item.damage = 60;
			Item.knockBack = 8f;
			Item.UseSound = SoundID.Item74;
			Item.shoot = ModContent.ProjectileType<ThrusterHitbox>();
			Item.shootSpeed = 1f;
		}

		public override bool Shoot(Player player, EntitySource_ItemUse_WithAmmo source, Vector2 position, Vector2 velocity, int type, int damage, float knockback) {
			// Launch the player toward the cursor and make them briefly invincible.
			player.velocity = velocity.SafeNormalize(Vector2.UnitX * player.direction) * 19f;
			player.immune = true;
			player.immuneTime = 20;
			player.fallStart = (int)(player.position.Y / 16f);

			Projectile.NewProjectile(source, player.Center, Vector2.Zero, type, damage, knockback, player.whoAmI);
			return false;
		}
	}
}
