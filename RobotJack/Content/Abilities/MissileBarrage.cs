using Microsoft.Xna.Framework;
using RobotJack.Content.Projectiles;
using Terraria;
using Terraria.DataStructures;
using Terraria.ID;
using Terraria.ModLoader;

namespace RobotJack.Content.Abilities
{
	// Launches a fan of micro-missiles out of the shoulder pods. They home in on the nearest enemy and explode.
	public class MissileBarrage : RobotAbility
	{
		public const int Missiles = 6;

		public override void SetDefaults() {
			base.SetDefaults();
			Item.width = 32;
			Item.height = 32;
			Item.useStyle = ItemUseStyleID.Shoot;
			Item.useTime = 45;
			Item.useAnimation = 45;
			Item.noUseGraphic = true;
			Item.damage = 45;
			Item.knockBack = 5f;
			Item.UseSound = SoundID.Item61;
			Item.shoot = ModContent.ProjectileType<HomingMissile>();
			Item.shootSpeed = 9f;
		}

		public override bool Shoot(Player player, EntitySource_ItemUse_WithAmmo source, Vector2 position, Vector2 velocity, int type, int damage, float knockback) {
			// Fan out upward and toward the cursor; the missiles curve onto their targets.
			Vector2 aim = velocity.SafeNormalize(Vector2.UnitX * player.direction);
			Vector2 up = new Vector2(0f, -1f);
			for (int i = 0; i < Missiles; i++) {
				float t = i / (float)(Missiles - 1);
				Vector2 dir = Vector2.Lerp(up, aim, 0.35f).SafeNormalize(up).RotatedBy(MathHelper.Lerp(-0.7f, 0.7f, t));
				Vector2 launch = player.MountedCenter + new Vector2(-player.direction * 6f, -14f);
				Projectile.NewProjectile(source, launch, dir * velocity.Length() * Main.rand.NextFloat(0.85f, 1.1f), type, damage, knockback, player.whoAmI);
			}
			return false;
		}
	}
}
